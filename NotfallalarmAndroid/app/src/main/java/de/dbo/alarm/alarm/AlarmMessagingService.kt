package de.dbo.alarm.alarm

import android.content.Context
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import de.dbo.alarm.AlarmApp
import de.dbo.alarm.di.ServiceLocator
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout

/**
 * Entry point of the whole delivery path.
 *
 * Only data messages are handled - the backend never sends a `notification` block. A
 * notification message would be drawn by the system while the app stays asleep, and none
 * of the things that matter here (alarm-stream tone, screen on, wake lock) would happen.
 *
 * onMessageReceived runs on a background thread while the system holds a wake lock for
 * this process, which is why the short blocking sections below are safe.
 */
class AlarmMessagingService : FirebaseMessagingService() {

    /** Anything older than this is history, not an alarm. Protects against a message that
     *  the network held back and delivers half an hour later. */
    private val maxAgeMillis = 3 * 60 * 1000L

    override fun onMessageReceived(message: RemoteMessage) {
        val payload = AlarmPayload.fromData(message.data)
        if (payload == null) {
            logError("payload: unreadable data message ${message.data.keys}")
            return
        }

        when (payload.kind) {
            AlarmPayload.Kind.PING -> handlePing()
            AlarmPayload.Kind.ALARM -> handleAlarm(payload)
            AlarmPayload.Kind.ALL_CLEAR -> handleAllClear(payload)
        }
    }

    private fun handlePing() {
        blocking("ping") {
            ServiceLocator.deviceRepository(applicationContext).syncDevice("ping")
        }
    }

    private fun handleAlarm(payload: AlarmPayload) {
        if (payload.alarmId.isBlank()) {
            logError("alarm: message without alarmId")
            return
        }

        val age = System.currentTimeMillis() - payload.createdAt
        if (payload.createdAt > 0 && age > maxAgeMillis) {
            Log.w(TAG, "dropping stale alarm ${payload.alarmId}, ${age / 1000}s old")
            return
        }

        val isNew = blocking("dedupe") {
            ServiceLocator.settings.markAlarmSeen(payload.alarmId)
        } ?: true
        if (!isNew) {
            Log.i(TAG, "duplicate alarm ${payload.alarmId} ignored")
            return
        }

        startAlarmService(payload)
    }

    private fun handleAllClear(payload: AlarmPayload) {
        // Keyed separately from the alarm itself, otherwise the all clear for an alarm we
        // have already seen would look like a duplicate and never reach the device.
        val isNew = blocking("dedupe") {
            ServiceLocator.settings.markAlarmSeen("clear:${payload.alarmId}")
        } ?: true
        if (!isNew) return
        startAlarmService(payload)
    }

    private fun startAlarmService(payload: AlarmPayload) {
        val intent = AlarmForegroundService.intentFor(this, payload)
        val started = runCatching { ContextCompat.startForegroundService(this, intent) }
        if (started.isSuccess) return

        logError("startForegroundService: ${started.exceptionOrNull()?.message}")
        // Fallback: no service, but the phone still has to make a noise and show something.
        runCatching {
            val alarm = ActiveAlarm.from(payload)
            ActiveAlarmStore.set(alarm)
            AlarmSignal(this).start(
                alarm.type,
                vibrateOnly = false,
                onError = { logError("fallbackSignal: $it") },
            )
            if (AlarmNotifications.canPost(this)) {
                @Suppress("MissingPermission")
                NotificationManagerCompat.from(this).notify(
                    AlarmNotifications.NOTIFICATION_ALARM,
                    AlarmNotifications.buildAlarmNotification(this, alarm),
                )
            } else {
                logError("fallbackNotification: POST_NOTIFICATIONS fehlt")
            }
        }.onFailure { logError("fallbackNotification: ${it.message}") }
    }

    /**
     * Written straight away. A token that changes while the app is closed and is only
     * uploaded at the next app start means every alarm in between goes nowhere.
     *
     * Both callbacks are answered: onRegistered is the current name, onNewToken the one
     * older SDK builds still call. uploadToken merges, so being called twice costs a write
     * and nothing else - being called neither time would cost the alarm.
     */
    override fun onRegistered(token: String) {
        storeToken(token)
    }

    @Deprecated("Superseded by onRegistered; kept so older SDK builds still reach us.")
    @Suppress("DEPRECATION")
    override fun onNewToken(token: String) {
        storeToken(token)
    }

    private fun storeToken(token: String) {
        blocking("token") {
            ServiceLocator.deviceRepository(applicationContext).uploadToken(token)
        }
    }

    /**
     * Runs a suspending piece of work to completion inside the FCM callback. Bounded, so a
     * network hiccup cannot hold the message dispatcher.
     */
    private fun <T> blocking(stage: String, block: suspend () -> T): T? = runCatching {
        runBlocking { withTimeout(BLOCKING_TIMEOUT_MILLIS) { block() } }
    }.onFailure {
        if (it is TimeoutCancellationException) {
            logError("$stage: timed out")
        } else {
            logError("$stage: ${it.message}")
        }
    }.getOrNull()

    private fun logError(message: String) {
        Log.w(TAG, message)
        runCatching {
            runBlocking { AlarmApp.logDeliveryError(applicationContext as Context, "fcm/$message") }
        }
    }

    companion object {
        private const val TAG = "AlarmMessaging"
        private const val BLOCKING_TIMEOUT_MILLIS = 8_000L
    }
}
