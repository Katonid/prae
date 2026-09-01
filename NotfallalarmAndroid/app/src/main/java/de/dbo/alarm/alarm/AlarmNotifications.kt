package de.dbo.alarm.alarm

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import de.dbo.alarm.R
import de.dbo.alarm.data.model.AlarmType
import de.dbo.alarm.ui.alarm.AlarmActivity

object AlarmNotifications {

    /** Channel settings cannot be changed once created, so the id carries a version. */
    const val CHANNEL_ALARM = "alarm_v1"
    const val CHANNEL_QUIET = "quiet_v1"

    const val NOTIFICATION_ALARM = 4711
    const val NOTIFICATION_ALL_CLEAR = 4712

    fun createChannels(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val alarm = NotificationChannel(
            CHANNEL_ALARM,
            context.getString(R.string.channel_alarm_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.channel_alarm_desc)
            // No channel sound and no channel vibration: AlarmSignal plays the tone on the
            // alarm stream itself, which is the only stream that survives silent mode.
            // A channel sound would be a second, quieter tone on top of it.
            setSound(null, null)
            enableVibration(false)
            setBypassDnd(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }
        manager.createNotificationChannel(alarm)

        val quiet = NotificationChannel(
            CHANNEL_QUIET,
            context.getString(R.string.channel_quiet_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(R.string.channel_quiet_desc)
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannel(quiet)
    }

    fun titleFor(context: Context, type: AlarmType, isSelfTest: Boolean): String {
        val base = context.getString(
            when (type) {
                AlarmType.AMOK -> R.string.alarm_type_amok
                AlarmType.FIRE -> R.string.alarm_type_fire
                AlarmType.MEDICAL -> R.string.alarm_type_medical
                AlarmType.TEST -> R.string.alarm_type_test
            }
        )
        return if (isSelfTest) "$base (Selbsttest)" else base
    }

    fun buildAlarmNotification(context: Context, alarm: ActiveAlarm): Notification {
        val open = alarmScreenIntent(context, alarm)
        val body = buildString {
            if (alarm.triggeredByName.isNotBlank()) {
                append(context.getString(R.string.alarm_triggered_by, alarm.triggeredByName))
            }
            if (alarm.location.isNotBlank()) {
                if (isNotEmpty()) append(" · ")
                append(alarm.location)
            }
            if (isEmpty()) append(context.getString(R.string.notification_alarm_text))
        }

        return NotificationCompat.Builder(context, CHANNEL_ALARM)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(titleFor(context, alarm.type, alarm.isSelfTest))
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
            .addAction(
                0,
                context.getString(R.string.alarm_silence),
                servicePendingIntent(context, AlarmForegroundService.ACTION_SILENCE),
            )
            .build()
    }

    fun buildAllClearNotification(context: Context, alarm: ActiveAlarm): Notification {
        val text = if (alarm.clearedByName.isNotBlank()) {
            context.getString(
                R.string.alarm_cleared_by,
                alarm.clearedByName,
                de.dbo.alarm.util.formatTime(alarm.clearedAt),
            )
        } else {
            context.getString(R.string.notification_all_clear_title)
        }
        return NotificationCompat.Builder(context, CHANNEL_QUIET)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(context.getString(R.string.notification_all_clear_title))
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(alarmScreenIntent(context, alarm))
            .build()
    }

    fun alarmScreenIntent(context: Context, alarm: ActiveAlarm): PendingIntent {
        val intent = Intent(context, AlarmActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(AlarmActivity.EXTRA_ALARM_ID, alarm.alarmId)
            putExtra(AlarmActivity.EXTRA_GROUP_ID, alarm.groupId)
        }
        return PendingIntent.getActivity(
            context,
            alarm.alarmId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun servicePendingIntent(context: Context, action: String): PendingIntent {
        val intent = Intent(context, AlarmForegroundService::class.java).setAction(action)
        return PendingIntent.getService(
            context,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }


    /**
     * Posting a notification needs POST_NOTIFICATIONS from Android 13 on. Without the
     * check the call is a silent no-op, and the fallback path below exists precisely for
     * the moments when nothing else worked - it has to say so in the error log.
     */
    fun canPost(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    fun cancelAll(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ALARM)
    }
}
