package de.dbo.alarm.ui.screens

import android.app.Application
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import de.dbo.alarm.R
import de.dbo.alarm.data.model.AlarmType
import de.dbo.alarm.di.ServiceLocator
import de.dbo.alarm.ui.SessionViewModel
import de.dbo.alarm.ui.theme.AlarmColors
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class TriggerViewModel(application: Application) : AndroidViewModel(application) {

    sealed interface Send {
        data object Idle : Send
        data object Sending : Send
        data class Retrying(val secondsLeft: Int) : Send
        data class Failed(val message: String) : Send
        data class Sent(val alarmId: String) : Send
    }

    private val _send = MutableStateFlow<Send>(Send.Idle)
    val send: StateFlow<Send> = _send.asStateFlow()

    private val alarms = ServiceLocator.alarmRepository
    private val settings = ServiceLocator.settings

    /**
     * Tries for half a minute before giving up. An alarm that fails silently because the
     * hallway has no reception is the worst possible outcome, so every state the attempt
     * goes through is on screen.
     */
    fun trigger(groupId: String, type: AlarmType, location: String) {
        if (_send.value is Send.Sending || _send.value is Send.Retrying) return
        _send.value = Send.Sending
        viewModelScope.launch {
            settings.setLastLocation(location)
            val deadline = System.currentTimeMillis() + RETRY_WINDOW_MILLIS
            var lastError: Throwable? = null
            while (System.currentTimeMillis() < deadline) {
                val result = runCatching { alarms.triggerAlarm(groupId, type, location) }
                result.onSuccess { alarmId ->
                    _send.value = Send.Sent(alarmId)
                    return@launch
                }
                lastError = result.exceptionOrNull()
                val secondsLeft = ((deadline - System.currentTimeMillis()) / 1000).toInt()
                _send.value = Send.Retrying(secondsLeft.coerceAtLeast(0))
                delay(RETRY_STEP_MILLIS)
            }
            val offline = lastError?.message?.contains("UNAVAILABLE", true) == true ||
                lastError?.message?.contains("network", true) == true
            _send.value = Send.Failed(
                if (offline || lastError == null) {
                    getApplication<Application>().getString(R.string.trigger_offline)
                } else {
                    getApplication<Application>().getString(R.string.setup_error_generic, lastError.message.orEmpty())
                }
            )
        }
    }

    fun reset() {
        _send.value = Send.Idle
    }

    private companion object {
        const val RETRY_WINDOW_MILLIS = 30_000L
        const val RETRY_STEP_MILLIS = 3_000L
    }
}

private enum class Step { TYPE, LOCATION, COUNTDOWN, RESULT }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TriggerScreen(
    state: SessionViewModel.State,
    onClose: () -> Unit,
    onOpenAlarm: (String) -> Unit,
) {
    val viewModel: TriggerViewModel = viewModel()
    val send by viewModel.send.collectAsState()

    var step by remember { mutableStateOf(Step.TYPE) }
    var type by remember { mutableStateOf<AlarmType?>(null) }
    var location by remember { mutableStateOf(state.lastLocation) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.trigger_title)) },
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
            when (step) {
                Step.TYPE -> {
                    Text(
                        stringResource(R.string.trigger_choose_type),
                        style = MaterialTheme.typography.titleLarge,
                    )
                    for (candidate in AlarmType.entries) {
                        // A drill is an exercise the school runs, not something an
                        // individual sets off in a corridor.
                        if (candidate.isTest && !state.isAdmin) continue
                        val alreadyRunning = state.activeAlarms.any { it.type == candidate }
                        Button(
                            onClick = {
                                type = candidate
                                step = if (state.locations.isEmpty()) Step.COUNTDOWN else Step.LOCATION
                            },
                            enabled = !alreadyRunning,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(84.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = AlarmColors.forType(candidate),
                                contentColor = MaterialTheme.colorScheme.onPrimary,
                            ),
                        ) {
                            Text(alarmTypeLabel(candidate), fontSize = 22.sp, fontWeight = FontWeight.Bold)
                        }
                        if (alreadyRunning) {
                            Text(
                                stringResource(R.string.trigger_duplicate),
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                    }
                    OutlinedButton(onClick = onClose, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.cancel))
                    }
                }

                Step.LOCATION -> {
                    Text(
                        stringResource(R.string.trigger_choose_location),
                        style = MaterialTheme.typography.titleLarge,
                    )
                    // The place chosen last time comes first and is highlighted. Under
                    // stress the room is almost always the same one, and the thumb should
                    // not have to hunt down a list for it.
                    val ordered = state.locations.sortedByDescending { it == state.lastLocation }
                    for (candidate in ordered) {
                        val selected = candidate == location
                        if (selected) {
                            Button(
                                onClick = {
                                    location = candidate
                                    step = Step.COUNTDOWN
                                },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(64.dp),
                            ) { Text(candidate, fontSize = 18.sp) }
                        } else {
                            OutlinedButton(
                                onClick = {
                                    location = candidate
                                    step = Step.COUNTDOWN
                                },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(64.dp),
                            ) { Text(candidate, fontSize = 18.sp) }
                        }
                    }
                    OutlinedButton(
                        onClick = {
                            location = ""
                            step = Step.COUNTDOWN
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text(stringResource(R.string.trigger_location_unknown)) }
                    OutlinedButton(onClick = { step = Step.TYPE }, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.back))
                    }
                }

                Step.COUNTDOWN -> {
                    val chosen = type
                    if (chosen == null) {
                        step = Step.TYPE
                    } else {
                        CountdownStep(
                            type = chosen,
                            location = location,
                            onCancel = { step = Step.TYPE },
                            onElapsed = {
                                val groupId = state.groupId
                                if (groupId != null) {
                                    viewModel.trigger(groupId, chosen, location)
                                    step = Step.RESULT
                                }
                            },
                        )
                    }
                }

                Step.RESULT -> {
                    when (val current = send) {
                        is TriggerViewModel.Send.Sent -> {
                            Text(stringResource(R.string.trigger_sent), style = MaterialTheme.typography.headlineSmall)
                            Button(
                                onClick = { onOpenAlarm(current.alarmId) },
                                modifier = Modifier.fillMaxWidth(),
                            ) { Text(stringResource(R.string.home_open_alarm)) }
                        }

                        is TriggerViewModel.Send.Failed -> {
                            Text(
                                current.message,
                                color = MaterialTheme.colorScheme.error,
                                style = MaterialTheme.typography.titleMedium,
                            )
                            Button(
                                onClick = {
                                    viewModel.reset()
                                    step = Step.COUNTDOWN
                                },
                                modifier = Modifier.fillMaxWidth(),
                            ) { Text(stringResource(R.string.retry)) }
                            OutlinedButton(onClick = onClose, modifier = Modifier.fillMaxWidth()) {
                                Text(stringResource(R.string.close))
                            }
                        }

                        is TriggerViewModel.Send.Retrying -> Text(
                            stringResource(R.string.trigger_retrying, current.secondsLeft),
                            style = MaterialTheme.typography.titleMedium,
                        )

                        else -> Text(
                            stringResource(R.string.trigger_sending),
                            style = MaterialTheme.typography.titleMedium,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CountdownStep(
    type: AlarmType,
    location: String,
    onCancel: () -> Unit,
    onElapsed: () -> Unit,
) {
    var secondsLeft by remember { mutableStateOf(COUNTDOWN_SECONDS) }

    androidx.compose.runtime.LaunchedEffect(type, location) {
        secondsLeft = COUNTDOWN_SECONDS
        while (secondsLeft > 0) {
            delay(1000)
            secondsLeft -= 1
        }
        onElapsed()
    }

    Column(
        Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            alarmTypeLabel(type),
            style = MaterialTheme.typography.headlineMedium,
            color = AlarmColors.forType(type),
            fontWeight = FontWeight.Bold,
        )
        if (location.isNotBlank()) Text(location, style = MaterialTheme.typography.titleMedium)
        Text(
            stringResource(R.string.trigger_countdown_title),
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center,
        )
        Text("$secondsLeft", fontSize = 88.sp, fontWeight = FontWeight.ExtraBold)
        Text(pluralStringResource(R.plurals.trigger_countdown_seconds, secondsLeft, secondsLeft))
        Button(
            onClick = onCancel,
            modifier = Modifier
                .fillMaxWidth()
                .height(96.dp),
        ) {
            Text(stringResource(R.string.trigger_countdown_cancel), fontSize = 26.sp, fontWeight = FontWeight.Bold)
        }
    }
}

private const val COUNTDOWN_SECONDS = 5
