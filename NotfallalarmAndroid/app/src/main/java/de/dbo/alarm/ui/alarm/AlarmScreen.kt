package de.dbo.alarm.ui.alarm

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.core.net.toUri
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.dbo.alarm.R
import de.dbo.alarm.alarm.AlarmForegroundService
import de.dbo.alarm.data.model.AckStatus
import de.dbo.alarm.data.model.AlarmType
import de.dbo.alarm.ui.screens.alarmTypeLabel
import de.dbo.alarm.ui.theme.AlarmColors
import de.dbo.alarm.util.formatTime

/**
 * The screen a colleague sees when an alarm comes in - on the lock screen, at arm's
 * length, possibly in a dark room. Type, place and what to do come first and large; the
 * live list and the chat sit below, for whoever has a moment to scroll.
 */
@Composable
fun AlarmScreen(
    viewModel: AlarmViewModel,
    onClose: () -> Unit,
    canGoBack: Boolean,
) {
    val context = LocalContext.current
    val alarm by viewModel.alarm.collectAsState()
    val acks by viewModel.acks.collectAsState()
    val messages by viewModel.messages.collectAsState()
    val memberCount by viewModel.memberCount.collectAsState()
    val isAdmin by viewModel.isAdmin.collectAsState()
    val busy by viewModel.busy.collectAsState()
    val isSelfTest by viewModel.isSelfTest.collectAsState()

    var confirmClear by remember { mutableStateOf(false) }
    var draft by remember { mutableStateOf("") }

    val current = alarm
    val type = current?.type ?: AlarmType.AMOK
    val cleared = current?.isActive == false
    val headerColor = if (cleared) AlarmColors.AllClear else AlarmColors.forType(type)
    val myAck = acks.firstOrNull { it.uid == viewModel.myUid }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .background(headerColor)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            if (type.isTest && !cleared) {
                Text(
                    stringResource(R.string.alarm_test_banner),
                    color = Color.White,
                    fontWeight = FontWeight.ExtraBold,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color.Black.copy(alpha = 0.28f))
                        .padding(10.dp),
                    textAlign = TextAlign.Center,
                )
            }
            Text(
                if (cleared) stringResource(R.string.alarm_cleared_title) else alarmTypeLabel(type),
                color = Color.White,
                fontSize = 40.sp,
                fontWeight = FontWeight.ExtraBold,
            )
            if (cleared) {
                Text(
                    stringResource(
                        R.string.alarm_cleared_by,
                        current.clearedByName.orEmpty().ifBlank { "-" },
                        formatTime(current.clearedAt ?: 0),
                    ),
                    color = Color.White,
                    fontSize = 18.sp,
                )
            } else {
                val triggeredByName = current?.triggeredByName.orEmpty()
                if (triggeredByName.isNotBlank()) {
                    Text(
                        stringResource(R.string.alarm_triggered_by, triggeredByName),
                        color = Color.White,
                        fontSize = 18.sp,
                    )
                }
                val locationText = current?.location.orEmpty()
                if (locationText.isNotBlank()) {
                    Text(
                        stringResource(R.string.alarm_at_location, locationText),
                        color = Color.White,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
                Text(
                    stringResource(R.string.alarm_at_time, formatTime(current?.createdAt ?: 0)),
                    color = Color.White,
                    fontSize = 18.sp,
                )
            }
        }

        Column(
            Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            val instruction = current?.instruction.orEmpty()
            if (instruction.isNotBlank() && !cleared) {
                Text(
                    stringResource(R.string.alarm_instruction_title),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                Text(instruction, style = MaterialTheme.typography.bodyLarge)
            }

            if (!cleared && !isSelfTest) {
                Button(
                    onClick = {
                        viewModel.acknowledge(AckStatus.SECURED)
                        // Answering is the confirmation the vibration was waiting for.
                        AlarmForegroundService.stop(context)
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(72.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1B7F4B)),
                ) { Text(stringResource(R.string.alarm_ack_secured), fontSize = 18.sp, fontWeight = FontWeight.Bold) }

                Button(
                    onClick = {
                        viewModel.acknowledge(AckStatus.HELP_NEEDED)
                        AlarmForegroundService.stop(context)
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(72.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AlarmColors.Fire),
                ) { Text(stringResource(R.string.alarm_ack_help), fontSize = 18.sp, fontWeight = FontWeight.Bold) }

                Button(
                    onClick = {
                        // ACTION_DIAL, never ACTION_CALL: the number is prefilled and the
                        // person presses the green button. The app must not place a call by
                        // itself, and CALL_PHONE is a permission we deliberately do not ask for.
                        val number = if (type == AlarmType.MEDICAL) "112" else "110"
                        context.startActivity(
                            Intent(Intent.ACTION_DIAL, "tel:$number".toUri())
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(72.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AlarmColors.Medical),
                ) {
                    Text(
                        stringResource(
                            if (type == AlarmType.MEDICAL) R.string.alarm_call_112 else R.string.alarm_call_110
                        ),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }

                OutlinedButton(
                    onClick = { AlarmForegroundService.stop(context) },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(stringResource(R.string.alarm_silence)) }
            }

            if (isSelfTest && !cleared) {
                OutlinedButton(
                    onClick = { AlarmForegroundService.stop(context) },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(stringResource(R.string.alarm_silence)) }
                Text(
                    stringResource(R.string.checklist_selftest_ok),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
            }

            if (myAck != null && !isSelfTest) {
                Text(
                    stringResource(R.string.alarm_your_answer, ackLabel(myAck.status)),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                )
            }

            if (!isSelfTest) {
            HorizontalDivider()

            Text(
                pluralStringResource(
                    R.plurals.alarm_responses,
                    acks.size,
                    acks.size,
                    memberCount.coerceAtLeast(acks.size),
                ),
                style = MaterialTheme.typography.titleMedium,
            )
            val helpNeeded = acks.count { it.status == AckStatus.HELP_NEEDED }
            if (helpNeeded > 0) {
                Text(
                    pluralStringResource(R.plurals.alarm_help_needed_count, helpNeeded, helpNeeded),
                    color = MaterialTheme.colorScheme.error,
                    fontWeight = FontWeight.Bold,
                )
            }

            // The full list with names is an admin view. Everyone else sees the count -
            // during an alarm a list of thirty names is noise, not information.
            if (isAdmin) {
                for (ack in acks) {
                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(ack.displayName.ifBlank { "?" }, style = MaterialTheme.typography.bodyMedium)
                        Text(
                            buildString {
                                append(ackLabel(ack.status))
                                if (ack.location.isNotBlank()) append(" · ").append(ack.location)
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = if (ack.status == AckStatus.HELP_NEEDED) {
                                MaterialTheme.colorScheme.error
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant
                            },
                        )
                    }
                }
            }

            val mayClear = isAdmin || current?.triggeredBy == viewModel.myUid
            if (!cleared && mayClear) {
                Button(
                    onClick = { confirmClear = true },
                    enabled = !busy,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(stringResource(R.string.alarm_clear_button)) }
            }

            HorizontalDivider()

            Text(stringResource(R.string.alarm_chat_title), style = MaterialTheme.typography.titleMedium)
            for (message in messages) {
                Column(Modifier.fillMaxWidth()) {
                    Text(
                        "${message.senderName.ifBlank { "?" }} · ${formatTime(message.at)}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(message.text, style = MaterialTheme.typography.bodyMedium)
                }
            }
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.Bottom,
            ) {
                OutlinedTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    label = { Text(stringResource(R.string.alarm_chat_hint)) },
                    modifier = Modifier.weight(1f),
                    maxLines = 3,
                )
                Button(
                    onClick = {
                        viewModel.sendMessage(draft)
                        draft = ""
                    },
                    enabled = draft.isNotBlank(),
                ) { Text(stringResource(R.string.alarm_chat_send)) }
            }
            }

            OutlinedButton(onClick = onClose, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(if (canGoBack) R.string.back else R.string.close))
            }
        }
    }

    if (confirmClear) {
        AlertDialog(
            onDismissRequest = { confirmClear = false },
            title = { Text(stringResource(R.string.alarm_clear_button)) },
            text = { Text(stringResource(R.string.alarm_clear_confirm)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmClear = false
                    viewModel.clear {}
                }) { Text(stringResource(R.string.ok)) }
            },
            dismissButton = {
                TextButton(onClick = { confirmClear = false }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}

@Composable
private fun ackLabel(status: AckStatus): String = stringResource(
    when (status) {
        AckStatus.SECURED -> R.string.ack_status_secured
        AckStatus.HELP_NEEDED -> R.string.ack_status_help_needed
        AckStatus.SEEN -> R.string.ack_status_seen
    }
)
