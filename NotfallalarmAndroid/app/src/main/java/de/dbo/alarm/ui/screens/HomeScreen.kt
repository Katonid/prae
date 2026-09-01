package de.dbo.alarm.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.dbo.alarm.R
import de.dbo.alarm.ui.SessionViewModel
import de.dbo.alarm.ui.components.Banner
import de.dbo.alarm.ui.components.SectionCard
import de.dbo.alarm.ui.theme.AlarmColors
import de.dbo.alarm.util.formatDateTime

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    state: SessionViewModel.State,
    blockingReadinessCount: Int,
    onTrigger: () -> Unit,
    onOpenAlarm: (String) -> Unit,
    onOpenChecklist: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenAdmin: () -> Unit,
    onOpenUpdate: (String) -> Unit,
    onDismissUpdate: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(state.groupName.ifBlank { stringResource(R.string.app_name) }) },
                actions = {
                    if (state.isAdmin) {
                        IconButton(onClick = onOpenAdmin) {
                            Icon(Icons.Default.AdminPanelSettings, stringResource(R.string.home_admin))
                        }
                    }
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Default.Settings, stringResource(R.string.home_settings))
                    }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            val update = state.updateConfig
            if (update != null) {
                Banner(
                    title = stringResource(R.string.update_title),
                    text = buildString {
                        append(
                            stringResource(
                                R.string.update_text,
                                update.latestVersionName.ifBlank { update.latestVersionCode.toString() },
                                de.dbo.alarm.BuildConfig.VERSION_NAME,
                            )
                        )
                        if (update.releaseNotes.isNotBlank()) append("\n\n").append(update.releaseNotes)
                    },
                    actionLabel = stringResource(R.string.update_button),
                    onAction = { onOpenUpdate(update.apkUrl) },
                    dismissLabel = stringResource(R.string.update_later),
                    onDismiss = onDismissUpdate,
                    container = MaterialTheme.colorScheme.secondaryContainer,
                    onContainer = MaterialTheme.colorScheme.onSecondaryContainer,
                )
            }

            if (blockingReadinessCount > 0) {
                Banner(
                    title = stringResource(R.string.checklist_title),
                    text = pluralStringResource(
                        R.plurals.home_checklist_banner,
                        blockingReadinessCount,
                        blockingReadinessCount,
                    ),
                    actionLabel = stringResource(R.string.home_checklist_banner_action),
                    onAction = onOpenChecklist,
                )
            }

            val active = state.activeAlarms.firstOrNull()
            if (active != null) {
                Banner(
                    title = stringResource(R.string.home_active_alarm),
                    text = "${alarmTypeLabel(active.type)} · ${active.location.ifBlank { "-" }} · " +
                        formatDateTime(active.createdAt),
                    actionLabel = stringResource(R.string.home_open_alarm),
                    onAction = { onOpenAlarm(active.id) },
                    container = AlarmColors.forType(active.type),
                    onContainer = MaterialTheme.colorScheme.onPrimary,
                )
            }

            Button(
                onClick = onTrigger,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = AlarmColors.Amok,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            ) {
                Text(
                    stringResource(R.string.home_trigger),
                    fontSize = 30.sp,
                    fontWeight = FontWeight.ExtraBold,
                )
            }

            SectionCard {
                Text(
                    "${stringResource(R.string.home_group_label)}: ${state.groupName.ifBlank { "-" }}",
                    style = MaterialTheme.typography.bodyMedium,
                )
                Text(
                    "${state.displayName} · " + stringResource(
                        if (state.isAdmin) R.string.home_role_admin else R.string.home_role_member
                    ),
                    style = MaterialTheme.typography.bodyMedium,
                )
                OutlinedButton(onClick = onOpenChecklist, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.settings_checklist))
                }
            }
        }
    }
}

@Composable
fun alarmTypeLabel(type: de.dbo.alarm.data.model.AlarmType): String = stringResource(
    when (type) {
        de.dbo.alarm.data.model.AlarmType.AMOK -> R.string.alarm_type_amok
        de.dbo.alarm.data.model.AlarmType.FIRE -> R.string.alarm_type_fire
        de.dbo.alarm.data.model.AlarmType.MEDICAL -> R.string.alarm_type_medical
        de.dbo.alarm.data.model.AlarmType.TEST -> R.string.alarm_type_test
    }
)
