package de.dbo.alarm.ui.screens.admin

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import de.dbo.alarm.data.model.Alarm
import de.dbo.alarm.data.model.AlarmType
import de.dbo.alarm.data.model.InviteCode
import de.dbo.alarm.di.ServiceLocator
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlin.random.Random

class AdminViewModel(application: Application) : AndroidViewModel(application) {

    private val settings = ServiceLocator.settings
    private val groups = ServiceLocator.groupRepository
    private val alarms = ServiceLocator.alarmRepository
    private val devices = ServiceLocator.deviceRepository(application)

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    @OptIn(ExperimentalCoroutinesApi::class)
    val history: StateFlow<List<Alarm>> = settings.groupId.flatMapLatest { id ->
        if (id.isNullOrEmpty()) flowOf(emptyList()) else alarms.observeHistory(id)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    fun pingAll() = withGroup { groupId ->
        devices.pingAll(groupId)
        _message.value = getApplication<Application>().getString(de.dbo.alarm.R.string.admin_ping_sent)
    }

    fun pingOne(uid: String) = withGroup { groupId -> devices.pingOne(groupId, uid) }

    fun triggerTestAlarm(location: String, onDone: (String) -> Unit) = withGroup { groupId ->
        val alarmId = alarms.triggerAlarm(groupId, AlarmType.TEST, location)
        onDone(alarmId)
    }

    fun removeMember(uid: String) = withGroup { groupId -> groups.removeMember(groupId, uid) }

    fun setAdmin(uid: String, isAdmin: Boolean) = withGroup { groupId -> groups.setAdmin(groupId, uid, isAdmin) }

    fun saveLocations(locations: List<String>) = withGroup { groupId ->
        groups.updateLocations(groupId, locations.map { it.trim() }.filter { it.isNotEmpty() })
    }

    fun saveInstructions(instructions: Map<String, String>) = withGroup { groupId ->
        groups.updateInstructions(groupId, instructions)
    }

    /**
     * Six characters without I, O, 0 and 1 - the pairs that get misread when a code is
     * copied off a whiteboard. Valid for seven days by default; a code that never expires
     * is a code that is still on a staffroom noticeboard next summer.
     */
    fun createInviteCode(existing: List<InviteCode>, days: Int = 7) = withGroup { groupId ->
        val now = System.currentTimeMillis()
        val code = buildString {
            repeat(6) { append(CODE_ALPHABET[Random.nextInt(CODE_ALPHABET.length)]) }
        }
        val next = existing + InviteCode(
            code = code,
            createdAt = now,
            expiresAt = now + days * 24L * 60 * 60 * 1000,
        )
        groups.setInviteCodes(groupId, next)
    }

    fun revokeInviteCode(existing: List<InviteCode>, code: String) = withGroup { groupId ->
        val next = existing.map { if (it.code == code) it.copy(revoked = true) else it }
        groups.setInviteCodes(groupId, next)
    }

    fun consumeMessage() {
        _message.value = null
    }

    private fun withGroup(block: suspend (String) -> Unit) {
        viewModelScope.launch {
            val groupId = settings.currentGroupId() ?: return@launch
            runCatching { block(groupId) }.onFailure { _message.value = it.message }
        }
    }

    private companion object {
        const val CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    }
}
