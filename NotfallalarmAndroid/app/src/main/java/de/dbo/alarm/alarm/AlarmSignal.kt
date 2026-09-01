package de.dbo.alarm.alarm

import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import de.dbo.alarm.R
import de.dbo.alarm.data.model.AlarmType

/**
 * Sound and vibration for a running alarm.
 *
 * The whole point of this class is the audio usage: USAGE_ALARM plays on the alarm
 * stream, and the alarm stream is the one stream Android does not mute when the phone
 * is set to silent. Playing the same file with USAGE_NOTIFICATION would be inaudible on
 * exactly the phones we are building this for.
 */
class AlarmSignal(private val context: Context) {

    /** The tone stops after this long; the vibration keeps going until the user answers. */
    private val toneMillis = 20_000L

    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var previousAlarmVolume: Int? = null
    private var previousInterruptionFilter: Int? = null
    private val stopToneRunnable = Runnable { stopTone() }

    private val audioManager: AudioManager
        get() = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val notificationManager: NotificationManager
        get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    @Suppress("DEPRECATION")
    private val vibrator: Vibrator
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

    fun start(type: AlarmType, vibrateOnly: Boolean, onError: (String) -> Unit) {
        runCatching { liftDoNotDisturb() }.onFailure { onError("dnd: ${it.message}") }
        runCatching { startVibration(type) }.onFailure { onError("vibration: ${it.message}") }
        if (!vibrateOnly) {
            runCatching { raiseAlarmVolume() }.onFailure { onError("volume: ${it.message}") }
            runCatching { playLooping(soundFor(type)) }.onFailure { onError("sound: ${it.message}") }
            handler.postDelayed(stopToneRunnable, toneMillis)
        }
    }

    /** The all clear is short, plays once and does not touch volume or Do Not Disturb. */
    fun playAllClear(vibrateOnly: Boolean, onError: (String) -> Unit) {
        runCatching { vibrateOnce() }.onFailure { onError("vibration: ${it.message}") }
        if (vibrateOnly) return
        runCatching { playOnce(R.raw.all_clear) }.onFailure { onError("sound: ${it.message}") }
    }

    fun stop() {
        handler.removeCallbacks(stopToneRunnable)
        stopTone()
        runCatching { vibrator.cancel() }
        restoreAlarmVolume()
        restoreDoNotDisturb()
    }

    /** Silences the tone but leaves volume and Do Not Disturb alone; used by "Ton aus". */
    fun silence() {
        handler.removeCallbacks(stopToneRunnable)
        stopTone()
        runCatching { vibrator.cancel() }
    }

    private fun soundFor(type: AlarmType): Int = when (type) {
        AlarmType.AMOK -> R.raw.alarm_amok
        AlarmType.FIRE -> R.raw.alarm_fire
        AlarmType.MEDICAL -> R.raw.alarm_medical
        AlarmType.TEST -> R.raw.alarm_test
    }

    private fun alarmAttributes(): AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    private fun playLooping(resId: Int) {
        stopTone()
        player = buildPlayer(resId, looping = true).also { it.start() }
    }

    private fun playOnce(resId: Int) {
        stopTone()
        player = buildPlayer(resId, looping = false).also { mp ->
            mp.setOnCompletionListener { stopTone() }
            mp.start()
        }
    }

    private fun buildPlayer(resId: Int, looping: Boolean): MediaPlayer {
        val descriptor = context.resources.openRawResourceFd(resId)
        return MediaPlayer().apply {
            setAudioAttributes(alarmAttributes())
            descriptor.use { setDataSource(it.fileDescriptor, it.startOffset, it.length) }
            isLooping = looping
            setVolume(1f, 1f)
            prepare()
        }
    }

    private fun stopTone() {
        player?.let { mp ->
            runCatching { if (mp.isPlaying) mp.stop() }
            runCatching { mp.release() }
        }
        player = null
    }

    private fun raiseAlarmVolume() {
        val current = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        if (previousAlarmVolume == null) previousAlarmVolume = current
        if (current < max) {
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, max, 0)
        }
    }

    private fun restoreAlarmVolume() {
        val previous = previousAlarmVolume ?: return
        previousAlarmVolume = null
        runCatching { audioManager.setStreamVolume(AudioManager.STREAM_ALARM, previous, 0) }
    }

    /**
     * Only possible with notification policy access. Without it the alarm stream still
     * plays in most Do Not Disturb configurations, which is why the checklist marks this
     * one as recommended rather than required.
     */
    private fun liftDoNotDisturb() {
        if (!notificationManager.isNotificationPolicyAccessGranted) return
        val current = notificationManager.currentInterruptionFilter
        if (current == NotificationManager.INTERRUPTION_FILTER_ALL) return
        previousInterruptionFilter = current
        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
    }

    private fun restoreDoNotDisturb() {
        val previous = previousInterruptionFilter ?: return
        previousInterruptionFilter = null
        if (!notificationManager.isNotificationPolicyAccessGranted) return
        runCatching { notificationManager.setInterruptionFilter(previous) }
    }

    /**
     * A burst of three pulses, then a pause, repeating - so roughly every ten seconds the
     * phone buzzes again until someone answers. A single long pattern would be over before
     * a phone in a jacket pocket is reached.
     */
    private fun startVibration(type: AlarmType) {
        val timings = if (type.isTest) {
            longArrayOf(0, 300, 200, 300, 8_900)
        } else {
            longArrayOf(0, 800, 350, 800, 350, 800, 6_500)
        }
        vibrateWith(VibrationEffect.createWaveform(timings, 0))
    }

    private fun vibrateOnce() {
        vibrateWith(VibrationEffect.createWaveform(longArrayOf(0, 200, 150, 200), -1))
    }

    /**
     * The usage matters as much as it does for the tone: an alarm-class vibration is not
     * suppressed by Do Not Disturb the way a notification-class one is. VibrationAttributes
     * replaced the AudioAttributes overload in Android 13.
     */
    private fun vibrateWith(effect: VibrationEffect) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            vibrator.vibrate(
                effect,
                VibrationAttributes.Builder().setUsage(VibrationAttributes.USAGE_ALARM).build(),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(effect, alarmAttributes())
        }
    }
}
