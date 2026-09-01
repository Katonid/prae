package de.dbo.alarm.ui.screens

import android.app.Application
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Tab
import androidx.compose.material3.PrimaryTabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import de.dbo.alarm.R
import de.dbo.alarm.di.ServiceLocator
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class SetupViewModel(application: Application) : AndroidViewModel(application) {

    data class State(val busy: Boolean = false, val error: String? = null)

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    private val settings = ServiceLocator.settings
    private val auth = ServiceLocator.authRepository
    private val groups = ServiceLocator.groupRepository
    private val devices = ServiceLocator.deviceRepository(application)

    fun join(code: String, displayName: String, onDone: () -> Unit) = run("join") {
        val membership = groups.joinGroup(code.trim().uppercase(), displayName.trim())
        settings.setMembership(membership.groupId, membership.groupName, displayName.trim(), membership.role)
        devices.syncDevice("join")
        onDone()
    }

    fun create(groupName: String, displayName: String, onDone: () -> Unit) = run("create") {
        val membership = groups.createGroup(groupName.trim(), displayName.trim())
        settings.setMembership(membership.groupId, membership.groupName, displayName.trim(), membership.role)
        devices.syncDevice("create")
        onDone()
    }

    private fun run(stage: String, block: suspend () -> Unit) {
        _state.value = State(busy = true)
        viewModelScope.launch {
            runCatching {
                auth.ensureSignedIn()
                block()
            }.onFailure { error ->
                _state.value = State(busy = false, error = readable(stage, error))
            }.onSuccess {
                _state.value = State(busy = false)
            }
        }
    }

    /** Never let a raw error constant reach the screen - it tells the reader nothing. */
    private fun readable(stage: String, error: Throwable): String {
        val message = error.message.orEmpty()
        return when {
            message.contains("UNAUTHENTICATED", true) ||
                message.contains("NOT_FOUND", true) ||
                message.contains("invalid-argument", true) ||
                message.contains("Code", true) && stage == "join" ->
                getApplication<Application>().getString(R.string.setup_error_code)

            message.contains("UNAVAILABLE", true) || message.contains("network", true) ->
                getApplication<Application>().getString(R.string.setup_error_offline)

            else -> getApplication<Application>().getString(R.string.setup_error_generic, message)
        }
    }
}

@Composable
fun SetupScreen(onDone: () -> Unit) {
    val viewModel: SetupViewModel = viewModel()
    val state by viewModel.state.collectAsState()

    var tab by rememberSaveable { mutableIntStateOf(0) }
    var code by rememberSaveable { mutableStateOf("") }
    var displayName by rememberSaveable { mutableStateOf("") }
    var groupName by rememberSaveable { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }

    val nameEmptyMessage = stringResource(R.string.setup_error_name)
    val groupEmptyMessage = stringResource(R.string.setup_error_group_name)

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .imePadding()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            stringResource(R.string.setup_title),
            style = MaterialTheme.typography.headlineMedium,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
        )
        Text(stringResource(R.string.setup_intro), style = MaterialTheme.typography.bodyMedium)

        PrimaryTabRow(selectedTabIndex = tab) {
            Tab(selected = tab == 0, onClick = { tab = 0 }, text = { Text(stringResource(R.string.setup_tab_join)) })
            Tab(selected = tab == 1, onClick = { tab = 1 }, text = { Text(stringResource(R.string.setup_tab_create)) })
        }

        OutlinedTextField(
            value = displayName,
            onValueChange = { displayName = it },
            label = { Text(stringResource(R.string.setup_name_label)) },
            placeholder = { Text(stringResource(R.string.setup_name_hint)) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            keyboardOptions = KeyboardOptions(
                capitalization = KeyboardCapitalization.Words,
                imeAction = ImeAction.Next,
            ),
        )

        if (tab == 0) {
            OutlinedTextField(
                value = code,
                // Only upper-cased, never "corrected": the code alphabet leaves out I, O,
                // 0 and 1 precisely so that no guessing is needed here.
                onValueChange = { code = it.uppercase().filter { c -> c.isLetterOrDigit() }.take(6) },
                label = { Text(stringResource(R.string.setup_code_label)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Characters,
                    imeAction = ImeAction.Done,
                ),
            )
            Button(
                onClick = {
                    localError = if (displayName.isBlank()) nameEmptyMessage else null
                    if (localError == null) viewModel.join(code, displayName, onDone)
                },
                enabled = !state.busy && code.length >= 4,
                modifier = Modifier.fillMaxWidth(),
            ) { Text(stringResource(R.string.setup_join_button)) }
        } else {
            OutlinedTextField(
                value = groupName,
                onValueChange = { groupName = it },
                label = { Text(stringResource(R.string.setup_group_name_label)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Words,
                    imeAction = ImeAction.Done,
                ),
            )
            Text(stringResource(R.string.setup_create_hint), style = MaterialTheme.typography.bodySmall)
            Button(
                onClick = {
                    localError = when {
                        displayName.isBlank() -> nameEmptyMessage
                        groupName.isBlank() -> groupEmptyMessage
                        else -> null
                    }
                    if (localError == null) viewModel.create(groupName, displayName, onDone)
                },
                enabled = !state.busy,
                modifier = Modifier.fillMaxWidth(),
            ) { Text(stringResource(R.string.setup_create_button)) }
        }

        if (state.busy) CircularProgressIndicator()
        val message = localError ?: state.error
        if (message != null) {
            Text(message, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium)
        }
    }
}
