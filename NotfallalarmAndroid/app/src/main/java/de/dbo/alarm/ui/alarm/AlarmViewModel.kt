package de.dbo.alarm.ui.alarm

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import de.dbo.alarm.data.model.AckEntry
import de.dbo.alarm.data.model.AckStatus
import de.dbo.alarm.data.model.Alarm
import de.dbo.alarm.data.model.ChatMessage
import de.dbo.alarm.alarm.ActiveAlarmStore
import de.dbo.alarm.data.model.AlarmStatus
import de.dbo.alarm.di.ServiceLocator
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class AlarmViewModel(
    application: Application,
    private val groupId: String,
    private val alarmId: String,
) : AndroidViewModel(application) {

    private val alarms = ServiceLocator.alarmRepository
    private val groups = ServiceLocator.groupRepository
    private val settings = ServiceLocator.settings
    private val auth = ServiceLocator.authRepository

    /**
     * The stored alarm, with the push payload as a fallback.
     *
     * Two cases need it. A self test never creates a document at all - it exists only as a
     * message. And a phone that is offline, or that was woken by the push before Firestore
     * caught up, would otherwise show an empty red screen with no type and no place. The
     * payload carries everything the screen needs, so it is used until the document arrives.
     */
    val alarm: StateFlow<Alarm?> = combine(
        alarms.observeAlarm(groupId, alarmId),
        ActiveAlarmStore.current,
    ) { stored, pushed ->
        stored ?: pushed?.takeIf { it.alarmId == alarmId }?.let { active ->
            Alarm(
                id = active.alarmId,
                groupId = active.groupId,
                type = active.type,
                triggeredByName = active.triggeredByName,
                location = active.location,
                createdAt = active.createdAt,
                status = if (active.cleared) AlarmStatus.CLEARED else AlarmStatus.ACTIVE,
                clearedAt = active.clearedAt.takeIf { it > 0 },
                clearedByName = active.clearedByName.takeIf { it.isNotBlank() },
                instruction = active.instruction,
            )
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    /**
     * A self test has no document, no other recipients and nothing to answer. Showing the
     * usual buttons would write acknowledgements into a path whose alarm does not exist.
     */
    val isSelfTest: StateFlow<Boolean> = ActiveAlarmStore.current
        .map { it?.alarmId == alarmId && it.isSelfTest }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), alarmId.startsWith("selftest-"))

    val acks: StateFlow<List<AckEntry>> = alarms.observeAcks(groupId, alarmId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val messages: StateFlow<List<ChatMessage>> = alarms.observeMessages(groupId, alarmId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val memberCount: StateFlow<Int> = groups.observeMembers(groupId).map { it.size }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), 0)

    val isAdmin: StateFlow<Boolean> = groups.observeGroup(groupId)
        .map { group -> auth.uid != null && group?.adminIds?.contains(auth.uid) == true }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    val myUid: String? get() = auth.uid

    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error

    fun acknowledge(status: AckStatus) {
        val uid = auth.uid ?: return
        viewModelScope.launch {
            val displayName = runCatching { settings.displayName.first() }.getOrDefault("")
            val location = alarm.value?.location.orEmpty()
            runCatching { alarms.acknowledge(groupId, alarmId, uid, status, displayName, location) }
                .onFailure { _error.value = it.message }
        }
    }

    fun clear(onDone: () -> Unit) {
        _busy.value = true
        viewModelScope.launch {
            runCatching { alarms.clearAlarm(groupId, alarmId) }
                .onFailure { _error.value = it.message }
                .onSuccess { onDone() }
            _busy.value = false
        }
    }

    fun sendMessage(text: String) {
        val uid = auth.uid ?: return
        if (text.isBlank()) return
        viewModelScope.launch {
            val displayName = runCatching { settings.displayName.first() }.getOrDefault("")
            runCatching { alarms.sendMessage(groupId, alarmId, uid, displayName, text.trim()) }
                .onFailure { _error.value = it.message }
        }
    }

    class Factory(
        private val application: Application,
        private val groupId: String,
        private val alarmId: String,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            AlarmViewModel(application, groupId, alarmId) as T
    }
}
