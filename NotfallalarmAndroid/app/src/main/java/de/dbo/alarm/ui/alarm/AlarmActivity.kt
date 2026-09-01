package de.dbo.alarm.ui.alarm

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.viewmodel.compose.viewModel
import de.dbo.alarm.alarm.ActiveAlarmStore
import de.dbo.alarm.di.ServiceLocator
import de.dbo.alarm.ui.theme.NotfallalarmTheme
import kotlinx.coroutines.launch

/**
 * The alarm screen shown over the lock screen. Lives in its own task with
 * launchMode="singleInstance" so that a second alarm reuses this instance instead of
 * stacking a pile of alarm screens the user has to dismiss one by one.
 */
class AlarmActivity : ComponentActivity() {

    private var groupId by mutableStateOf("")
    private var alarmId by mutableStateOf("")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreen()
        applyIntent(intent)

        setContent {
            NotfallalarmTheme {
                val currentGroup = groupId
                val currentAlarm = alarmId
                if (currentGroup.isNotEmpty() && currentAlarm.isNotEmpty()) {
                    val viewModel: AlarmViewModel = viewModel(
                        key = "$currentGroup/$currentAlarm",
                        factory = AlarmViewModel.Factory(application, currentGroup, currentAlarm),
                    )
                    AlarmScreen(
                        viewModel = viewModel,
                        onClose = { finish() },
                        canGoBack = false,
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyIntent(intent)
    }

    private fun applyIntent(intent: Intent?) {
        val id = intent?.getStringExtra(EXTRA_ALARM_ID).orEmpty()
        val group = intent?.getStringExtra(EXTRA_GROUP_ID).orEmpty()
        alarmId = id.ifEmpty { ActiveAlarmStore.current.value?.alarmId.orEmpty() }
        if (group.isNotEmpty()) {
            groupId = group
            return
        }
        val fromStore = ActiveAlarmStore.current.value?.groupId.orEmpty()
        if (fromStore.isNotEmpty()) {
            groupId = fromStore
            return
        }
        lifecycleScope.launch {
            groupId = ServiceLocator.settings.currentGroupId().orEmpty()
        }
    }

    /**
     * Two halves that are easy to confuse: showWhenLocked puts the window above the lock
     * screen, turnScreenOn wakes the display. Without the second the alarm is only visible
     * once someone happens to pick the phone up.
     */
    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguard.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    companion object {
        const val EXTRA_ALARM_ID = "alarmId"
        const val EXTRA_GROUP_ID = "groupId"
    }
}
