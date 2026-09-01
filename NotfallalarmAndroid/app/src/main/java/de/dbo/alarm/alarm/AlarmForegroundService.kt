package de.dbo.alarm.alarm

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.ServiceCompat
import de.dbo.alarm.AlarmApp
import de.dbo.alarm.di.ServiceLocator
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * Holds the device awake and signalling for as long as an alarm is running.
 *
 * Why a foreground service at all: a high-priority FCM data message wakes the app for a
 * few seconds only. Sound, vibration and a held screen have to outlive that window, and a
 * foreground service is the one component Android keeps alive for it.
 *
 * Why foregroundServiceType="specialUse": from Android 14 on every foreground service has
 * to name a type. None of the documented types fits - this is not media playback, not a
 * phone call, not a location fix. specialUse is the type the platform provides for exactly
 * that case, and the justification string sits in the manifest next to it. The high-priority
 * message puts the app on the temporary power allowlist, which is what permits starting the
 * service from the background in the first place.
 */
class AlarmForegroundService : Service() {

    /**
     * Hard stop for a running alarm. The vibration is supposed to keep going until someone
     * answers, but a phone left in a drawer must not buzz itself flat overnight.
     */
    private val maxAlarmMillis = 10 * 60 * 1000L
    private val allClearMillis = 12_000L

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private lateinit var signal: AlarmSignal
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        signal = AlarmSignal(this)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_ALARM -> handleAlarm(intent)
            ACTION_ALL_CLEAR -> handleAllClear(intent)
            ACTION_SILENCE -> handleSilence()
            ACTION_STOP -> stopEverything()
            else -> stopEverything()
        }
        return START_NOT_STICKY
    }

    private fun handleAlarm(intent: Intent) {
        val payload = AlarmPayload.fromIntent(intent) ?: run { stopEverything(); return }
        val alarm = ActiveAlarm.from(payload)
        ActiveAlarmStore.set(alarm)

        // startForeground has to happen within seconds of the start request, so it comes
        // before anything that can block - reading settings, opening an audio file.
        startInForeground(AlarmNotifications.buildAlarmNotification(this, alarm))
        acquireWakeLock(maxAlarmMillis)

        scope.launch {
            val vibrateOnly = runCatching { ServiceLocator.settings.vibrateOnly.first() }.getOrDefault(false)
            signal.start(alarm.type, vibrateOnly) { logError("signal", it) }
        }

        // When the platform refuses full-screen intents (Android 14 denies them to
        // sideloaded apps by default) the notification alone would only show a line at the
        // top of the screen. Try to bring the screen up by hand as well - the attempt is
        // free, and on a device where background starts are blocked it simply does nothing.
        if (!ServiceLocator.readiness(this).fullScreenIntentAllowed()) {
            runCatching {
                startActivity(
                    Intent(this, de.dbo.alarm.ui.alarm.AlarmActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        putExtra(de.dbo.alarm.ui.alarm.AlarmActivity.EXTRA_ALARM_ID, alarm.alarmId)
                        putExtra(de.dbo.alarm.ui.alarm.AlarmActivity.EXTRA_GROUP_ID, alarm.groupId)
                    }
                )
            }.onFailure { logError("activityStart", it.message.orEmpty()) }
        }

        scope.launch {
            delay(maxAlarmMillis)
            stopEverything()
        }
    }

    private fun handleAllClear(intent: Intent) {
        val payload = AlarmPayload.fromIntent(intent)
        val existing = ActiveAlarmStore.current.value
        val alarm = when {
            payload != null && existing != null -> existing.copy(
                cleared = true,
                clearedByName = payload.clearedByName,
                clearedAt = payload.clearedAt,
                soundActive = false,
            )
            payload != null -> ActiveAlarm.from(payload).copy(
                cleared = true,
                clearedByName = payload.clearedByName,
                clearedAt = payload.clearedAt,
                soundActive = false,
            )
            else -> existing
        } ?: run { stopEverything(); return }

        ActiveAlarmStore.set(alarm)
        signal.stop()
        startInForeground(AlarmNotifications.buildAllClearNotification(this, alarm))

        scope.launch {
            val vibrateOnly = runCatching { ServiceLocator.settings.vibrateOnly.first() }.getOrDefault(false)
            signal.playAllClear(vibrateOnly) { logError("allclear", it) }
        }

        scope.launch {
            delay(allClearMillis)
            stopEverything()
        }
    }

    private fun handleSilence() {
        signal.silence()
        ActiveAlarmStore.markSilenced()
        val alarm = ActiveAlarmStore.current.value
        if (alarm != null) {
            // Keep the notification, drop the noise: the alarm is still running and the
            // way back to the alarm screen must not disappear with the sound.
            startInForeground(AlarmNotifications.buildAlarmNotification(this, alarm.copy(soundActive = false)))
        } else {
            stopEverything()
        }
    }

    private fun startInForeground(notification: android.app.Notification) {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        runCatching {
            ServiceCompat.startForeground(this, AlarmNotifications.NOTIFICATION_ALARM, notification, type)
        }.onFailure {
            // Last line of defence: if the platform refuses the foreground service we still
            // put the notification up by hand, so at minimum the phone shows and sounds it.
            logError("startForeground", it.message.orEmpty())
            if (!AlarmNotifications.canPost(this)) {
                logError("startForeground", "POST_NOTIFICATIONS fehlt - nichts anzuzeigen")
                return@onFailure
            }
            runCatching {
                @Suppress("MissingPermission")
                androidx.core.app.NotificationManagerCompat.from(this)
                    .notify(AlarmNotifications.NOTIFICATION_ALARM, notification)
            }
        }
    }

    private fun acquireWakeLock(timeout: Long) {
        if (wakeLock?.isHeld == true) return
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$WAKE_LOCK_TAG:alarm").apply {
            setReferenceCounted(false)
            runCatching { acquire(timeout) }
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let { lock -> runCatching { if (lock.isHeld) lock.release() } }
        wakeLock = null
    }

    private fun stopEverything() {
        signal.stop()
        releaseWakeLock()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun logError(stage: String, message: String) {
        scope.launch {
            AlarmApp.logDeliveryError(applicationContext, "service/$stage: $message")
        }
    }

    override fun onDestroy() {
        signal.stop()
        releaseWakeLock()
        scope.cancel()
        super.onDestroy()
    }

    companion object {
        const val ACTION_ALARM = "de.dbo.alarm.action.ALARM"
        const val ACTION_ALL_CLEAR = "de.dbo.alarm.action.ALL_CLEAR"
        const val ACTION_SILENCE = "de.dbo.alarm.action.SILENCE"
        const val ACTION_STOP = "de.dbo.alarm.action.STOP"

        private const val WAKE_LOCK_TAG = "de.dbo.alarm"

        fun intentFor(context: Context, payload: AlarmPayload): Intent {
            val action = if (payload.kind == AlarmPayload.Kind.ALL_CLEAR) ACTION_ALL_CLEAR else ACTION_ALARM
            return Intent(context, AlarmForegroundService::class.java)
                .setAction(action)
                .putExtras(payload.toBundle())
        }

        fun stop(context: Context) {
            // Wrapped: if the service is not running, starting it just to stop it would
            // throw on Android 8+ when the caller happens to be in the background.
            runCatching {
                context.startService(
                    Intent(context, AlarmForegroundService::class.java).setAction(ACTION_STOP)
                )
            }
        }
    }
}
