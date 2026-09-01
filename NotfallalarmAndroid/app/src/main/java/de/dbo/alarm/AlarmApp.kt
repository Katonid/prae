package de.dbo.alarm

import android.app.Application
import android.content.Context
import de.dbo.alarm.alarm.AlarmNotifications
import de.dbo.alarm.di.ServiceLocator
import de.dbo.alarm.util.formatDateTime

class AlarmApp : Application() {

    override fun onCreate() {
        super.onCreate()
        ServiceLocator.init(this)
        AlarmNotifications.createChannels(this)
    }

    companion object {
        /**
         * Every failure on the delivery path is written down locally and travels with the
         * next ping. A phone that stayed silent is otherwise a phone with nothing to say.
         */
        suspend fun logDeliveryError(context: Context, message: String) {
            ServiceLocator.init(context)
            runCatching {
                ServiceLocator.settings.appendError("${formatDateTime(System.currentTimeMillis())} $message")
            }
        }
    }
}
