package de.dbo.alarm.ui.screens

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
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import de.dbo.alarm.BuildConfig
import de.dbo.alarm.R
import de.dbo.alarm.ui.SessionViewModel
import de.dbo.alarm.ui.components.SectionCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    session: SessionViewModel,
    state: SessionViewModel.State,
    onBack: () -> Unit,
    onOpenChecklist: () -> Unit,
    onLeft: () -> Unit,
) {
    val errorLog by session.errorLog.collectAsState()
    var name by remember(state.displayName) { mutableStateOf(state.displayName) }
    var confirmLeave by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.settings_title)) },
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
        ) {
            SectionCard(title = stringResource(R.string.settings_section_signal)) {
                Row(
                    Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(stringResource(R.string.settings_vibrate_only))
                        Text(
                            stringResource(R.string.settings_vibrate_only_desc),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Switch(checked = state.vibrateOnly, onCheckedChange = { session.setVibrateOnly(it) })
                }
            }

            SectionCard(title = stringResource(R.string.settings_section_device)) {
                OutlinedButton(onClick = onOpenChecklist, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.settings_checklist))
                }
                Text(
                    stringResource(R.string.settings_version, BuildConfig.VERSION_NAME, BuildConfig.VERSION_CODE),
                    style = MaterialTheme.typography.bodySmall,
                )
            }

            SectionCard(title = stringResource(R.string.settings_section_group)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(stringResource(R.string.settings_display_name)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Button(
                    onClick = { session.setDisplayName(name.trim()) },
                    enabled = name.isNotBlank() && name.trim() != state.displayName,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(stringResource(R.string.save)) }
                Text(
                    "${stringResource(R.string.home_group_label)}: ${state.groupName.ifBlank { "-" }}",
                    style = MaterialTheme.typography.bodySmall,
                )
                OutlinedButton(onClick = { confirmLeave = true }, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.settings_leave_group))
                }
            }

            SectionCard(title = stringResource(R.string.settings_privacy)) {
                Text(stringResource(R.string.settings_privacy_text), style = MaterialTheme.typography.bodySmall)
            }

            SectionCard(title = stringResource(R.string.settings_errorlog)) {
                Text(
                    errorLog.ifBlank { stringResource(R.string.settings_errorlog_empty) },
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
    }

    if (confirmLeave) {
        AlertDialog(
            onDismissRequest = { confirmLeave = false },
            title = { Text(stringResource(R.string.settings_leave_group)) },
            text = { Text(stringResource(R.string.settings_leave_confirm)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmLeave = false
                    session.leaveGroup(onLeft)
                }) { Text(stringResource(R.string.ok)) }
            },
            dismissButton = {
                TextButton(onClick = { confirmLeave = false }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}
