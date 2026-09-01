package de.dbo.alarm.di

import android.content.Context
import de.dbo.alarm.data.AlarmRepository
import de.dbo.alarm.data.AuthRepository
import de.dbo.alarm.data.DeviceRepository
import de.dbo.alarm.data.GroupRepository
import de.dbo.alarm.data.Settings
import de.dbo.alarm.permissions.DeviceReadiness

/**
 * Manual dependency injection. The graph is six objects deep and half of them are needed
 * inside a FirebaseMessagingService, where a code-generating framework buys nothing but a
 * build step - so no Hilt here.
 */
object ServiceLocator {

    private lateinit var appContext: Context

    fun init(context: Context) {
        appContext = context.applicationContext
    }

    val settings: Settings by lazy { Settings(appContext) }
    val authRepository: AuthRepository by lazy { AuthRepository() }
    val groupRepository: GroupRepository by lazy { GroupRepository() }
    val alarmRepository: AlarmRepository by lazy { AlarmRepository() }

    private val readiness: DeviceReadiness by lazy { DeviceReadiness(appContext) }

    private val deviceRepository: DeviceRepository by lazy {
        DeviceRepository(appContext, settings, authRepository, readiness)
    }

    @Suppress("UNUSED_PARAMETER")
    fun readiness(context: Context): DeviceReadiness = readiness

    @Suppress("UNUSED_PARAMETER")
    fun deviceRepository(context: Context): DeviceRepository = deviceRepository
}
