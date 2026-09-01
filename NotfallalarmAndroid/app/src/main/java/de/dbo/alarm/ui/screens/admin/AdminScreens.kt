package de.dbo.alarm.ui.screens.admin

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.dbo.alarm.BuildConfig
import de.dbo.alarm.R
import de.dbo.alarm.data.model.AlarmType
import de.dbo.alarm.data.model.Member
import de.dbo.alarm.ui.SessionViewModel
import de.dbo.alarm.ui.components.QrImage
import de.dbo.alarm.ui.components.SectionCard
import de.dbo.alarm.ui.components.StatusDot
import de.dbo.alarm.ui.screens.alarmTypeLabel
import de.dbo.alarm.util.formatDateTime
import de.dbo.alarm.util.formatRelative

/** Devices that have not reported for this long are shown in red. */
private const val STALE_MILLIS = 48L * 60 * 60 * 1000

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AdminScaffold(
    title: String,
    onBack: () -> Unit,
    content: @Composable () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.back))
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
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) { content() }
    }
}

@Composable
fun AdminHomeScreen(
    state: SessionViewModel.State,
    viewModel: AdminViewModel,
    onBack: () -> Unit,
    onDevices: () -> Unit,
    onCodes: () -> Unit,
    onLocations: () -> Unit,
    onInstructions: () -> Unit,
    onHistory: () -> Unit,
    onOpenAlarm: (String) -> Unit,
) {
    AdminScaffold(stringResource(R.string.admin_title), onBack) {
        if (!state.isAdmin) {
            Text(stringResource(R.string.admin_not_admin), color = MaterialTheme.colorScheme.error)
            return@AdminScaffold
        }
        OutlinedButton(onClick = onDevices, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.admin_devices))
        }
        OutlinedButton(onClick = onCodes, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.admin_codes))
        }
        OutlinedButton(onClick = onLocations, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.admin_locations))
        }
        OutlinedButton(onClick = onInstructions, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.admin_instructions))
        }
        OutlinedButton(onClick = onHistory, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.admin_history))
        }
        HorizontalDivider()
        Button(
            onClick = { viewModel.triggerTestAlarm(state.lastLocation, onOpenAlarm) },
            enabled = state.activeAlarms.none { it.type == AlarmType.TEST },
            modifier = Modifier.fillMaxWidth(),
        ) { Text(stringResource(R.string.admin_test_alarm)) }
    }
}

@Composable
fun AdminDevicesScreen(
    state: SessionViewModel.State,
    viewModel: AdminViewModel,
    onBack: () -> Unit,
) {
    var pendingRemoval by remember { mutableStateOf<Member?>(null) }
    val message by viewModel.message.collectAsState()

    AdminScaffold(stringResource(R.string.admin_devices), onBack) {
        Button(onClick = { viewModel.pingAll() }, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.admin_ping_all))
        }
        if (message != null) Text(message.orEmpty(), style = MaterialTheme.typography.bodySmall)

        val newestVersion = state.members.maxOfOrNull { it.appVersionCode } ?: BuildConfig.VERSION_CODE.toLong()
        for (member in state.members) {
            val stale = member.lastSeen == null ||
                System.currentTimeMillis() - member.lastSeen > STALE_MILLIS
            SectionCard {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    StatusDot(!stale)
                    Column(Modifier.weight(1f)) {
                        Text(
                            member.displayName.ifBlank { "?" } +
                                if (member.isAdmin) " · ${stringResource(R.string.home_role_admin)}" else "",
                            fontWeight = FontWeight.SemiBold,
                        )
                        Text(
                            formatRelative(member.lastSeen)
                                ?.let { stringResource(R.string.admin_device_lastseen, it) }
                                ?: stringResource(R.string.admin_device_never),
                            style = MaterialTheme.typography.bodySmall,
                            color = if (stale) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                if (stale) {
                    Text(
                        stringResource(R.string.admin_devices_stale),
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
                Text(member.deviceModel.ifBlank { "-" }, style = MaterialTheme.typography.bodySmall)
                Text(
                    stringResource(R.string.admin_device_version, member.appVersion.ifBlank { "-" }) +
                        if (member.appVersionCode in 1 until newestVersion) {
                            " · " + stringResource(R.string.admin_device_outdated)
                        } else {
                            ""
                        },
                    style = MaterialTheme.typography.bodySmall,
                    color = if (member.appVersionCode in 1 until newestVersion) {
                        MaterialTheme.colorScheme.error
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                )
                val missing = buildList {
                    if (!member.permissionState.notifications) add("Benachrichtigungen")
                    if (!member.permissionState.fullScreenIntent) add("Vollbild")
                    if (!member.permissionState.batteryExempt) add("Akku")
                    if (!member.permissionState.dndAccess) add("Nicht stören")
                }
                Text(
                    if (missing.isEmpty()) {
                        stringResource(R.string.admin_device_permissions_ok)
                    } else {
                        stringResource(R.string.admin_device_permissions_missing, missing.joinToString(", "))
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = if (missing.isEmpty()) {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    } else {
                        MaterialTheme.colorScheme.error
                    },
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = { viewModel.pingOne(member.uid) }) { Text("Ping") }
                    OutlinedButton(onClick = { viewModel.setAdmin(member.uid, !member.isAdmin) }) {
                        Text(
                            stringResource(
                                if (member.isAdmin) R.string.admin_revoke_admin else R.string.admin_make_admin
                            )
                        )
                    }
                    if (member.uid != state.uid) {
                        OutlinedButton(onClick = { pendingRemoval = member }) {
                            Text(stringResource(R.string.delete))
                        }
                    }
                }
            }
        }
    }

    val removal = pendingRemoval
    if (removal != null) {
        AlertDialog(
            onDismissRequest = { pendingRemoval = null },
            title = { Text(stringResource(R.string.admin_device_remove)) },
            text = { Text(stringResource(R.string.admin_device_remove_confirm, removal.displayName)) },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.removeMember(removal.uid)
                    pendingRemoval = null
                }) { Text(stringResource(R.string.ok)) }
            },
            dismissButton = {
                TextButton(onClick = { pendingRemoval = null }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}

@Composable
fun AdminCodesScreen(
    state: SessionViewModel.State,
    viewModel: AdminViewModel,
    onBack: () -> Unit,
) {
    var qrCode by remember { mutableStateOf<String?>(null) }
    val codes = state.group?.inviteCodes.orEmpty()
    val now = System.currentTimeMillis()

    AdminScaffold(stringResource(R.string.admin_codes), onBack) {
        Button(onClick = { viewModel.createInviteCode(codes) }, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.admin_code_new))
        }
        for (code in codes.sortedByDescending { it.createdAt }) {
            SectionCard {
                Text(code.code, fontSize = 28.sp, fontWeight = FontWeight.ExtraBold)
                Text(
                    if (code.isValidAt(now)) {
                        stringResource(R.string.admin_code_valid_until, formatDateTime(code.expiresAt))
                    } else {
                        stringResource(R.string.admin_code_expired)
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = if (code.isValidAt(now)) {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    } else {
                        MaterialTheme.colorScheme.error
                    },
                )
                if (code.isValidAt(now)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { qrCode = code.code }) {
                            Text(stringResource(R.string.admin_code_show_qr))
                        }
                        OutlinedButton(onClick = { viewModel.revokeInviteCode(codes, code.code) }) {
                            Text(stringResource(R.string.admin_code_revoke))
                        }
                    }
                }
            }
        }
    }

    val shown = qrCode
    if (shown != null) {
        AlertDialog(
            onDismissRequest = { qrCode = null },
            title = { Text(shown) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    QrImage(shown)
                    Text(stringResource(R.string.admin_code_qr_hint), style = MaterialTheme.typography.bodySmall)
                }
            },
            confirmButton = { TextButton(onClick = { qrCode = null }) { Text(stringResource(R.string.close)) } },
        )
    }
}

@Composable
fun AdminLocationsScreen(
    state: SessionViewModel.State,
    viewModel: AdminViewModel,
    onBack: () -> Unit,
) {
    val locations = remember(state.group?.locations) {
        mutableStateListOf<String>().also { it.addAll(state.locations) }
    }
    var draft by remember { mutableStateOf("") }

    AdminScaffold(stringResource(R.string.admin_locations), onBack) {
        Text(stringResource(R.string.admin_locations_hint), style = MaterialTheme.typography.bodySmall)
        locations.forEachIndexed { index, value ->
            Row(
                Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedTextField(
                    value = value,
                    onValueChange = { locations[index] = it },
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                )
                OutlinedButton(onClick = { locations.removeAt(index) }) { Text(stringResource(R.string.delete)) }
            }
        }
        Row(
            Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            OutlinedTextField(
                value = draft,
                onValueChange = { draft = it },
                label = { Text(stringResource(R.string.admin_location_new)) },
                modifier = Modifier.weight(1f),
                singleLine = true,
            )
            OutlinedButton(
                onClick = {
                    if (draft.isNotBlank()) {
                        locations.add(draft.trim())
                        draft = ""
                    }
                },
            ) { Text(stringResource(R.string.add)) }
        }
        Button(
            onClick = { viewModel.saveLocations(locations.toList()) },
            modifier = Modifier.fillMaxWidth(),
        ) { Text(stringResource(R.string.save)) }
    }
}

@Composable
fun AdminInstructionsScreen(
    state: SessionViewModel.State,
    viewModel: AdminViewModel,
    onBack: () -> Unit,
) {
    val defaults = mapOf(
        AlarmType.AMOK to R.string.default_instruction_amok,
        AlarmType.FIRE to R.string.default_instruction_fire,
        AlarmType.MEDICAL to R.string.default_instruction_medical,
        AlarmType.TEST to R.string.default_instruction_test,
    )
    val texts = remember(state.group?.instructions) {
        mutableStateListOf<Pair<AlarmType, String>>().also { list ->
            for (type in AlarmType.entries) {
                list.add(type to state.group?.instructions?.get(type.wire).orEmpty())
            }
        }
    }

    AdminScaffold(stringResource(R.string.admin_instructions), onBack) {
        Text(stringResource(R.string.admin_instructions_hint), style = MaterialTheme.typography.bodySmall)
        texts.forEachIndexed { index, (type, value) ->
            val fallback = stringResource(defaults.getValue(type))
            SectionCard(title = alarmTypeLabel(type)) {
                OutlinedTextField(
                    value = value,
                    onValueChange = { texts[index] = type to it },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 3,
                    placeholder = { Text(fallback, style = MaterialTheme.typography.bodySmall) },
                )
                OutlinedButton(onClick = { texts[index] = type to fallback }) {
                    Text("Vorschlag einsetzen")
                }
            }
        }
        Button(
            onClick = {
                viewModel.saveInstructions(
                    texts.filter { it.second.isNotBlank() }.associate { it.first.wire to it.second.trim() }
                )
            },
            modifier = Modifier.fillMaxWidth(),
        ) { Text(stringResource(R.string.save)) }
    }
}

@Composable
fun AdminHistoryScreen(
    viewModel: AdminViewModel,
    onBack: () -> Unit,
    onOpenAlarm: (String) -> Unit,
) {
    val history by viewModel.history.collectAsState()
    AdminScaffold(stringResource(R.string.admin_history), onBack) {
        if (history.isEmpty()) {
            Text(stringResource(R.string.admin_history_empty))
        }
        for (alarm in history) {
            SectionCard {
                Text(alarmTypeLabel(alarm.type), fontWeight = FontWeight.SemiBold)
                Text(formatDateTime(alarm.createdAt), style = MaterialTheme.typography.bodySmall)
                if (alarm.location.isNotBlank()) {
                    Text(alarm.location, style = MaterialTheme.typography.bodySmall)
                }
                if (alarm.triggeredByName.isNotBlank()) {
                    Text(
                        stringResource(R.string.alarm_triggered_by, alarm.triggeredByName),
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
                Text(
                    if (alarm.isActive) {
                        stringResource(R.string.admin_history_active)
                    } else {
                        stringResource(
                            R.string.admin_history_cleared,
                            de.dbo.alarm.util.formatDateTime(alarm.clearedAt ?: 0),
                        )
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = if (alarm.isActive) {
                        MaterialTheme.colorScheme.error
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                )
                OutlinedButton(onClick = { onOpenAlarm(alarm.id) }, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.home_open_alarm))
                }
            }
        }
    }
}
