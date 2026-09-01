package de.dbo.alarm.alarm

import de.dbo.alarm.data.model.AlarmType
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

data class ActiveAlarm(
    val groupId: String,
    val alarmId: String,
    val type: AlarmType,
    val triggeredByName: String,
    val location: String,
    val createdAt: Long,
    val instruction: String,
    val isSelfTest: Boolean = false,
    val cleared: Boolean = false,
    val clearedByName: String = "",
    val clearedAt: Long = 0,
    val soundActive: Boolean = true,
) {
    companion object {
        fun from(payload: AlarmPayload) = ActiveAlarm(
            groupId = payload.groupId,
            alarmId = payload.alarmId,
            type = payload.type,
            triggeredByName = payload.triggeredByName,
            location = payload.location,
            createdAt = payload.createdAt,
            instruction = payload.instruction,
            isSelfTest = payload.isSelfTest,
        )
    }
}

/**
 * The single source of truth for "is an alarm running right now". The messaging service,
 * the foreground service and the alarm screen are three separate processes' worth of
 * lifecycle; a shared object keeps them from each holding their own half-truth.
 */
object ActiveAlarmStore {

    private val _current = MutableStateFlow<ActiveAlarm?>(null)
    val current: StateFlow<ActiveAlarm?> = _current.asStateFlow()

    /**
     * Emitted whenever a self test actually reaches the device - the checklist waits on it.
     * The value is the local arrival time, not the alarm id: replay is on so that a screen
     * recreated by a rotation still sees the arrival, and the checklist has to be able to
     * tell this run's arrival from last week's.
     */
    private val _selfTestArrived = MutableSharedFlow<Long>(replay = 1)
    val selfTestArrived: SharedFlow<Long> = _selfTestArrived.asSharedFlow()

    fun set(alarm: ActiveAlarm) {
        _current.value = alarm
        if (alarm.isSelfTest) _selfTestArrived.tryEmit(System.currentTimeMillis())
    }

    fun markCleared(alarmId: String, clearedByName: String, clearedAt: Long) {
        _current.update { existing ->
            if (existing == null || (alarmId.isNotEmpty() && existing.alarmId != alarmId)) {
                existing
            } else {
                existing.copy(
                    cleared = true,
                    clearedByName = clearedByName,
                    clearedAt = clearedAt,
                    soundActive = false,
                )
            }
        }
    }

    fun markSilenced() {
        _current.update { it?.copy(soundActive = false) }
    }

    fun clear() {
        _current.value = null
    }
}
