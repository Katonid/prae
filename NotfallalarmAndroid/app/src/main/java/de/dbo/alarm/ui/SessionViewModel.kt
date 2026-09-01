package de.dbo.alarm.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import de.dbo.alarm.BuildConfig
import de.dbo.alarm.data.Backend
import de.dbo.alarm.data.model.Alarm
import de.dbo.alarm.data.model.AppConfig
import de.dbo.alarm.data.model.Group
import de.dbo.alarm.data.model.Member
import de.dbo.alarm.di.ServiceLocator
import de.dbo.alarm.permissions.ReadinessItem
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/**
 * The state every screen needs: who am I, which group, is an alarm running, is this
 * device actually ready. Kept in one place because half of it changes from outside the
 * app - a push message, an admin edit, a permission revoked by the system.
 */
class SessionViewModel(application: Application) : AndroidViewModel(application) {

    data class State(
        val loading: Boolean = true,
        val firebaseConfigured: Boolean = true,
        val groupId: String? = null,
        val groupName: String = "",
        val group: Group? = null,
        val displayName: String = "",
        val uid: String? = null,
        val isAdmin: Boolean = false,
        val members: List<Member> = emptyList(),
        val activeAlarms: List<Alarm> = emptyList(),
        val onboardingDone: Boolean = false,
        val missingReadiness: List<ReadinessItem> = emptyList(),
        val vibrateOnly: Boolean = false,
        val lastLocation: String = "",
        val updateConfig: AppConfig? = null,
    ) {
        val hasGroup: Boolean get() = !groupId.isNullOrEmpty()
        val locations: List<String> get() = group?.locations.orEmpty()
    }

    private val settings = ServiceLocator.settings
    private val auth = ServiceLocator.authRepository
    private val groups = ServiceLocator.groupRepository
    private val alarms = ServiceLocator.alarmRepository
    private val devices = ServiceLocator.deviceRepository(application)
    private val readiness = ServiceLocator.readiness(application)

    private val missingReadiness = MutableStateFlow<List<ReadinessItem>>(emptyList())
    private val updateConfig = MutableStateFlow<AppConfig?>(null)
    private val signedIn = MutableStateFlow(false)

    @OptIn(ExperimentalCoroutinesApi::class)
    private val groupFlow = settings.groupId.flatMapLatest { id ->
        if (id.isNullOrEmpty()) flowOf(null) else groups.observeGroup(id)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    private val membersFlow = settings.groupId.flatMapLatest { id ->
        if (id.isNullOrEmpty()) flowOf(emptyList()) else groups.observeMembers(id)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    private val activeAlarmsFlow = settings.groupId.flatMapLatest { id ->
        if (id.isNullOrEmpty()) flowOf(emptyList()) else alarms.observeActiveAlarms(id)
    }

    private val storedFlow = combine(
        settings.groupId,
        settings.groupName,
        settings.displayName,
        settings.lastLocation,
        settings.vibrateOnly,
    ) { groupId, groupName, displayName, lastLocation, vibrateOnly ->
        Stored(groupId, groupName, displayName, lastLocation, vibrateOnly)
    }

    private data class Stored(
        val groupId: String?,
        val groupName: String,
        val displayName: String,
        val lastLocation: String,
        val vibrateOnly: Boolean,
    )

    val state: StateFlow<State> = combine(
        storedFlow,
        groupFlow,
        membersFlow,
        activeAlarmsFlow,
        combine(settings.onboardingDone, missingReadiness, updateConfig, signedIn) { done, missing, config, ready ->
            listOf(done, missing, config, ready)
        },
    ) { stored, group, members, active, extras ->
        @Suppress("UNCHECKED_CAST")
        val onboardingDone = extras[0] as Boolean
        @Suppress("UNCHECKED_CAST")
        val missing = extras[1] as List<ReadinessItem>
        val config = extras[2] as AppConfig?
        val ready = extras[3] as Boolean
        val uid = auth.uid
        State(
            loading = !ready,
            firebaseConfigured = Backend.isConfigured,
            groupId = stored.groupId,
            groupName = group?.name?.takeIf { it.isNotBlank() } ?: stored.groupName,
            group = group,
            displayName = stored.displayName,
            uid = uid,
            isAdmin = uid != null && group?.adminIds?.contains(uid) == true,
            members = members,
            activeAlarms = active,
            onboardingDone = onboardingDone,
            missingReadiness = missing,
            vibrateOnly = stored.vibrateOnly,
            lastLocation = stored.lastLocation,
            updateConfig = config,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), State())

    init {
        viewModelScope.launch {
            if (!Backend.isConfigured) {
                signedIn.value = true
                return@launch
            }
            runCatching { auth.ensureSignedIn() }
            signedIn.value = true
            refreshReadiness()
            runCatching { devices.syncDevice("start") }
            refreshUpdateConfig()
            syncRoleFromServer()
        }
    }

    /** Re-read on every app start and every return from a settings screen. */
    fun refreshReadiness() {
        val missing = buildList {
            for (item in listOf(
                ReadinessItem.NOTIFICATIONS,
                ReadinessItem.FULL_SCREEN_INTENT,
                ReadinessItem.BATTERY_EXEMPTION,
                ReadinessItem.DND_ACCESS,
            )) {
                if (!readiness.isGranted(item)) add(item)
            }
        }
        missingReadiness.value = missing
        viewModelScope.launch { runCatching { devices.syncDevice("readiness") } }
    }

    private suspend fun refreshUpdateConfig() {
        val config = devices.loadAppConfig() ?: return
        val dismissed = settings.dismissedUpdateVersionCode.first()
        updateConfig.value = config.takeIf {
            it.latestVersionCode > BuildConfig.VERSION_CODE && it.latestVersionCode > dismissed
        }
    }

    /** The role lives in the group document; the local copy only drives the menu. */
    private suspend fun syncRoleFromServer() {
        val groupId = settings.currentGroupId() ?: return
        val uid = auth.uid ?: return
        val member = runCatching { groups.loadMember(groupId, uid) }.getOrNull() ?: return
        settings.setRole(member.role.wire)
    }

    fun dismissUpdate() {
        val config = updateConfig.value ?: return
        viewModelScope.launch { settings.setDismissedUpdateVersionCode(config.latestVersionCode) }
        updateConfig.value = null
    }

    fun setVibrateOnly(value: Boolean) {
        viewModelScope.launch { settings.setVibrateOnly(value) }
    }

    fun setDisplayName(name: String) {
        viewModelScope.launch {
            val groupId = settings.currentGroupId() ?: return@launch
            val uid = auth.uid ?: return@launch
            runCatching { groups.setDisplayName(groupId, uid, name) }
            settings.setDisplayName(name)
        }
    }

    fun finishOnboarding() {
        viewModelScope.launch { settings.setOnboardingDone(true) }
    }

    fun leaveGroup(onDone: () -> Unit) {
        viewModelScope.launch {
            val groupId = settings.currentGroupId()
            val uid = auth.uid
            if (groupId != null && uid != null) runCatching { groups.removeMember(groupId, uid) }
            settings.clearMembership()
            onDone()
        }
    }

    val errorLog: StateFlow<String> =
        settings.errorLog.map { it }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), "")
}
