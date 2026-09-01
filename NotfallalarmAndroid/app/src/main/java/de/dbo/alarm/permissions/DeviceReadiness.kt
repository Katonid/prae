package de.dbo.alarm.permissions

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.net.toUri
import de.dbo.alarm.data.model.PermissionState

/** One entry of the readiness checklist. */
enum class ReadinessItem {
    NOTIFICATIONS,
    FULL_SCREEN_INTENT,
    BATTERY_EXEMPTION,
    DND_ACCESS,
    MANUFACTURER,
    SELF_TEST,
}

/**
 * Reads the state of everything the alarm path depends on and hands out the intent that
 * takes the user straight to the matching system screen. Checked again on every app start,
 * because a system update or a "battery saver" sweep can revoke any of it silently.
 */
class DeviceReadiness(private val context: Context) {

    fun notificationsGranted(): Boolean {
        val enabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return enabled
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        return enabled && granted
    }

    /**
     * Before Android 14 the permission is a normal one and granted at install time.
     * From 14 on only calling and alarm-clock apps get it by default, so a sideloaded
     * app has to be allowed by hand - and without it the screen never lights up.
     */
    fun fullScreenIntentAllowed(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        return notificationManager.canUseFullScreenIntent()
    }

    fun batteryExempt(): Boolean {
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return power.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun dndAccess(): Boolean = notificationManager.isNotificationPolicyAccessGranted

    fun state(): PermissionState = PermissionState(
        notifications = notificationsGranted(),
        fullScreenIntent = fullScreenIntentAllowed(),
        batteryExempt = batteryExempt(),
        dndAccess = dndAccess(),
    )

    fun isGranted(item: ReadinessItem): Boolean = when (item) {
        ReadinessItem.NOTIFICATIONS -> notificationsGranted()
        ReadinessItem.FULL_SCREEN_INTENT -> fullScreenIntentAllowed()
        ReadinessItem.BATTERY_EXEMPTION -> batteryExempt()
        ReadinessItem.DND_ACCESS -> dndAccess()
        ReadinessItem.MANUFACTURER -> false // answered by the user, not readable
        ReadinessItem.SELF_TEST -> false // answered by the self test, not readable
    }

    fun settingsIntentFor(item: ReadinessItem): Intent? = when (item) {
        ReadinessItem.NOTIFICATIONS -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)

        ReadinessItem.FULL_SCREEN_INTENT ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, appUri)
            } else {
                null
            }

        // Deliberately the direct request dialog and not the settings list: the list is
        // three taps deep and half of the staff never finds the app in it.
        ReadinessItem.BATTERY_EXEMPTION ->
            @Suppress("BatteryLife")
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, appUri)

        ReadinessItem.DND_ACCESS -> Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)

        ReadinessItem.MANUFACTURER -> ManufacturerHints.settingsIntent(context)

        ReadinessItem.SELF_TEST -> null
    }

    private val appUri: Uri get() = "package:${context.packageName}".toUri()

    private val notificationManager: NotificationManager
        get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
