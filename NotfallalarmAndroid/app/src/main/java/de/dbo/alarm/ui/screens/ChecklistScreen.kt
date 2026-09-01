package de.dbo.alarm.ui.screens

import android.Manifest
import android.app.Application
import android.content.Intent
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.core.net.toUri
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import de.dbo.alarm.R
import de.dbo.alarm.alarm.ActiveAlarmStore
import de.dbo.alarm.di.ServiceLocator
import de.dbo.alarm.permissions.ManufacturerHints
import de.dbo.alarm.permissions.ReadinessItem
import de.dbo.alarm.ui.components.SectionCard
import de.dbo.alarm.ui.components.StatusDot
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout

class ChecklistViewModel(application: Application) : AndroidViewModel(application) {

    enum class SelfTest { IDLE, WAITING, PASSED, FAILED }

    private val settings = ServiceLocator.settings
    private val devices = ServiceLocator.deviceRepository(application)
    private val readiness = ServiceLocator.readiness(application)

    private val _states = MutableStateFlow<Map<ReadinessItem, Boolean>>(emptyMap())
    val states: StateFlow<Map<ReadinessItem, Boolean>> = _states.asStateFlow()

    private val _selfTest = MutableStateFlow(SelfTest.IDLE)
    val selfTest: StateFlow<SelfTest> = _selfTest.asStateFlow()

    private val _manufacturerDone = MutableStateFlow(false)
    val manufacturerDone: StateFlow<Boolean> = _manufacturerDone.asStateFlow()

    init {
        refresh()
        viewModelScope.launch {
            if (settings.selfTestPassed.first()) _selfTest.value = SelfTest.PASSED
            _manufacturerDone.value = settings.manufacturerHintDone.first()
        }
    }

    fun refresh() {
        _states.value = mapOf(
            ReadinessItem.NOTIFICATIONS to readiness.notificationsGranted(),
            ReadinessItem.FULL_SCREEN_INTENT to readiness.fullScreenIntentAllowed(),
            ReadinessItem.BATTERY_EXEMPTION to readiness.batteryExempt(),
            ReadinessItem.DND_ACCESS to readiness.dndAccess(),
        )
        viewModelScope.launch { runCatching { devices.syncDevice("checklist") } }
    }

    fun markManufacturerDone() {
        _manufacturerDone.value = true
        viewModelScope.launch { settings.setManufacturerHintDone(true) }
    }

    /**
     * Sends a test alarm to this device only and waits for it to actually arrive. The whole
     * point is that nothing here is simulated: the message travels the same path as a real
     * alarm, so a phone that fails the test would have failed the real thing too.
     */
    fun startSelfTest() {
        if (_selfTest.value == SelfTest.WAITING) return
        _selfTest.value = SelfTest.WAITING
        val startedAt = System.currentTimeMillis()
        viewModelScope.launch {
            val sent = runCatching { devices.runSelfTest() }
            if (sent.isFailure) {
                _selfTest.value = SelfTest.FAILED
                return@launch
            }
            val arrived = runCatching {
                withTimeout(SELF_TEST_TIMEOUT_MILLIS) {
                    ActiveAlarmStore.selfTestArrived.first { it >= startedAt }
                }
            }
            if (arrived.isSuccess) {
                _selfTest.value = SelfTest.PASSED
                settings.setSelfTestPassed(true)
            } else {
                _selfTest.value = if (arrived.exceptionOrNull() is TimeoutCancellationException) {
                    SelfTest.FAILED
                } else {
                    SelfTest.FAILED
                }
            }
        }
    }

    private companion object {
        const val SELF_TEST_TIMEOUT_MILLIS = 45_000L
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChecklistScreen(onDone: () -> Unit, showFinishButton: Boolean) {
    val viewModel: ChecklistViewModel = viewModel()
    val context = LocalContext.current
    val states by viewModel.states.collectAsState()
    val selfTest by viewModel.selfTest.collectAsState()
    val manufacturerDone by viewModel.manufacturerDone.collectAsState()

    // Everything on this list can be revoked in system settings, so it is read again every
    // time the screen comes back to the foreground - not just once when it is created.
    val lifecycleOwner = LocalLifecycleOwner.current
    androidx.compose.runtime.DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) viewModel.refresh()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val notificationPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { viewModel.refresh() }

    LaunchedEffect(Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && states[ReadinessItem.NOTIFICATIONS] != true) {
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    val hint = ManufacturerHints.hintFor()
    val allRequiredDone = states[ReadinessItem.NOTIFICATIONS] == true &&
        states[ReadinessItem.FULL_SCREEN_INTENT] == true &&
        states[ReadinessItem.BATTERY_EXEMPTION] == true &&
        selfTest == ChecklistViewModel.SelfTest.PASSED

    Scaffold(
        topBar = { TopAppBar(title = { Text(stringResource(R.string.checklist_title)) }) },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(stringResource(R.string.checklist_intro), style = MaterialTheme.typography.bodyMedium)

            ChecklistRow(
                title = stringResource(R.string.checklist_notifications),
                description = stringResource(R.string.checklist_notifications_desc),
                granted = states[ReadinessItem.NOTIFICATIONS] == true,
                required = true,
                onOpen = {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        states[ReadinessItem.NOTIFICATIONS] != true
                    ) {
                        notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                    }
                    openSettings(context, ReadinessItem.NOTIFICATIONS)
                },
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ChecklistRow(
                    title = stringResource(R.string.checklist_fullscreen),
                    description = stringResource(R.string.checklist_fullscreen_desc),
                    granted = states[ReadinessItem.FULL_SCREEN_INTENT] == true,
                    required = true,
                    onOpen = { openSettings(context, ReadinessItem.FULL_SCREEN_INTENT) },
                )
            }

            ChecklistRow(
                title = stringResource(R.string.checklist_battery),
                description = stringResource(R.string.checklist_battery_desc),
                granted = states[ReadinessItem.BATTERY_EXEMPTION] == true,
                required = true,
                onOpen = { openSettings(context, ReadinessItem.BATTERY_EXEMPTION) },
            )

            ChecklistRow(
                title = stringResource(R.string.checklist_dnd),
                description = stringResource(R.string.checklist_dnd_desc),
                granted = states[ReadinessItem.DND_ACCESS] == true,
                required = false,
                onOpen = { openSettings(context, ReadinessItem.DND_ACCESS) },
            )

            if (ManufacturerHints.hasKnownRestrictions()) {
                SectionCard(title = stringResource(hint.title)) {
                    Text(stringResource(hint.text), style = MaterialTheme.typography.bodyMedium)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { openSettings(context, ReadinessItem.MANUFACTURER) }) {
                            Text(stringResource(R.string.checklist_open_settings))
                        }
                        OutlinedButton(onClick = { viewModel.markManufacturerDone() }) {
                            Text(stringResource(R.string.hint_done))
                        }
                    }
                    if (manufacturerDone) {
                        Text(stringResource(R.string.checklist_ok), fontWeight = FontWeight.Bold)
                    }
                }
            }

            SectionCard(title = stringResource(R.string.checklist_selftest)) {
                Text(stringResource(R.string.checklist_selftest_desc), style = MaterialTheme.typography.bodyMedium)
                when (selfTest) {
                    ChecklistViewModel.SelfTest.WAITING ->
                        Text(stringResource(R.string.checklist_selftest_waiting))

                    ChecklistViewModel.SelfTest.PASSED ->
                        Text(stringResource(R.string.checklist_selftest_ok), fontWeight = FontWeight.Bold)

                    ChecklistViewModel.SelfTest.FAILED -> Text(
                        stringResource(R.string.checklist_selftest_failed),
                        color = MaterialTheme.colorScheme.error,
                    )

                    ChecklistViewModel.SelfTest.IDLE -> Unit
                }
                Button(
                    onClick = { viewModel.startSelfTest() },
                    enabled = selfTest != ChecklistViewModel.SelfTest.WAITING,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(stringResource(R.string.checklist_selftest_start)) }
            }

            if (allRequiredDone) {
                Text(stringResource(R.string.checklist_all_done), fontWeight = FontWeight.Bold)
            }

            if (showFinishButton) {
                Button(
                    onClick = onDone,
                    enabled = allRequiredDone,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(stringResource(R.string.checklist_finish)) }
            } else {
                OutlinedButton(onClick = onDone, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.back))
                }
            }
        }
    }
}

@Composable
private fun ChecklistRow(
    title: String,
    description: String,
    granted: Boolean,
    required: Boolean,
    onOpen: () -> Unit,
) {
    SectionCard {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            StatusDot(granted)
            Column(Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.SemiBold)
                Text(
                    stringResource(if (required) R.string.checklist_required else R.string.checklist_recommended) +
                        " · " +
                        stringResource(if (granted) R.string.checklist_ok else R.string.checklist_missing),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Text(description, style = MaterialTheme.typography.bodySmall)
        if (!granted) {
            OutlinedButton(onClick = onOpen, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.checklist_open_settings))
            }
        }
    }
}

private fun openSettings(context: android.content.Context, item: ReadinessItem) {
    val intent = ServiceLocator.readiness(context).settingsIntentFor(item)
    val opened = intent != null &&
        runCatching { context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }.isSuccess
    if (opened) return
    // No known deep link on this firmware - the app's own settings page is at least
    // one tap from everything, which beats leaving the button dead.
    runCatching {
        context.startActivity(
            Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(("package:" + context.packageName).toUri())
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }
}
