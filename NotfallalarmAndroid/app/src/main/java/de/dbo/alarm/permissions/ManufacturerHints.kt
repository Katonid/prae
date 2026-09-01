package de.dbo.alarm.permissions

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.annotation.StringRes
import de.dbo.alarm.R

/**
 * Several manufacturers put apps to sleep no matter what the platform APIs say. There is
 * no supported way to read that state, so the app can only explain where the switch sits
 * and, where a known activity exists, open it. Every deep link is wrapped in a resolve
 * check: these components are undocumented and disappear between firmware versions.
 */
object ManufacturerHints {

    data class Hint(
        @param:StringRes val title: Int,
        @param:StringRes val text: Int,
    )

    fun hintFor(): Hint = when (Build.MANUFACTURER.lowercase()) {
        "samsung" -> Hint(R.string.hint_samsung_title, R.string.hint_samsung_text)
        "xiaomi", "redmi", "poco" -> Hint(R.string.hint_xiaomi_title, R.string.hint_xiaomi_text)
        "huawei", "honor" -> Hint(R.string.hint_huawei_title, R.string.hint_huawei_text)
        "oppo", "oneplus", "realme" -> Hint(R.string.hint_oppo_title, R.string.hint_oppo_text)
        "vivo" -> Hint(R.string.hint_vivo_title, R.string.hint_vivo_text)
        else -> Hint(R.string.hint_generic_title, R.string.hint_generic_text)
    }

    /** True when this manufacturer is known for its own background restrictions. */
    fun hasKnownRestrictions(): Boolean = Build.MANUFACTURER.lowercase() in KNOWN_MANUFACTURERS

    private val KNOWN_MANUFACTURERS = setOf(
        "samsung", "xiaomi", "redmi", "poco", "huawei", "honor",
        "oppo", "oneplus", "realme", "vivo",
    )

    private val CANDIDATES = listOf(
        "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
        "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
        "com.huawei.systemmanager" to "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
        "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
        "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
        "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
        "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
        "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
        "com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity",
    )

    fun settingsIntent(context: Context): Intent? {
        for ((pkg, cls) in CANDIDATES) {
            val intent = Intent().setComponent(ComponentName(pkg, cls))
            val resolved = context.packageManager.resolveActivity(intent, 0) != null
            if (resolved) return intent
        }
        return null
    }
}
