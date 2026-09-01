package de.dbo.alarm.alarm

import android.content.Intent
import android.os.Bundle
import de.dbo.alarm.data.model.AlarmType

/**
 * The contract between the Cloud Function and both mobile clients. Every value travels
 * as a string because that is all an FCM data message carries; keeping the parsing in
 * one place means a future iOS client can be written against this file.
 */
data class AlarmPayload(
    val kind: Kind,
    val groupId: String,
    val alarmId: String,
    val type: AlarmType,
    val triggeredByName: String,
    val location: String,
    val createdAt: Long,
    val instruction: String,
    val isSelfTest: Boolean,
    val clearedByName: String,
    val clearedAt: Long,
) {
    enum class Kind(val wire: String) {
        ALARM("alarm"),
        ALL_CLEAR("all_clear"),
        PING("ping");

        companion object {
            fun fromWire(value: String?): Kind? = entries.firstOrNull { it.wire == value }
        }
    }

    fun toBundle(): Bundle = Bundle().apply {
        putString(KEY_KIND, kind.wire)
        putString(KEY_GROUP_ID, groupId)
        putString(KEY_ALARM_ID, alarmId)
        putString(KEY_TYPE, type.wire)
        putString(KEY_TRIGGERED_BY_NAME, triggeredByName)
        putString(KEY_LOCATION, location)
        putLong(KEY_CREATED_AT, createdAt)
        putString(KEY_INSTRUCTION, instruction)
        putBoolean(KEY_SELF_TEST, isSelfTest)
        putString(KEY_CLEARED_BY_NAME, clearedByName)
        putLong(KEY_CLEARED_AT, clearedAt)
    }

    companion object {
        const val KEY_KIND = "kind"
        const val KEY_GROUP_ID = "groupId"
        const val KEY_ALARM_ID = "alarmId"
        const val KEY_TYPE = "type"
        const val KEY_TRIGGERED_BY_NAME = "triggeredByName"
        const val KEY_LOCATION = "location"
        const val KEY_CREATED_AT = "createdAt"
        const val KEY_INSTRUCTION = "instruction"
        const val KEY_SELF_TEST = "selfTest"
        const val KEY_CLEARED_BY_NAME = "clearedByName"
        const val KEY_CLEARED_AT = "clearedAt"

        fun fromData(data: Map<String, String>): AlarmPayload? {
            val kind = Kind.fromWire(data[KEY_KIND]) ?: return null
            val type = AlarmType.fromWire(data[KEY_TYPE]) ?: AlarmType.AMOK
            return AlarmPayload(
                kind = kind,
                groupId = data[KEY_GROUP_ID].orEmpty(),
                alarmId = data[KEY_ALARM_ID].orEmpty(),
                type = type,
                triggeredByName = data[KEY_TRIGGERED_BY_NAME].orEmpty(),
                location = data[KEY_LOCATION].orEmpty(),
                createdAt = data[KEY_CREATED_AT]?.toLongOrNull() ?: 0L,
                instruction = data[KEY_INSTRUCTION].orEmpty(),
                isSelfTest = data[KEY_SELF_TEST] == "true",
                clearedByName = data[KEY_CLEARED_BY_NAME].orEmpty(),
                clearedAt = data[KEY_CLEARED_AT]?.toLongOrNull() ?: 0L,
            )
        }

        fun fromIntent(intent: Intent): AlarmPayload? {
            val kind = Kind.fromWire(intent.getStringExtra(KEY_KIND)) ?: return null
            return AlarmPayload(
                kind = kind,
                groupId = intent.getStringExtra(KEY_GROUP_ID).orEmpty(),
                alarmId = intent.getStringExtra(KEY_ALARM_ID).orEmpty(),
                type = AlarmType.fromWire(intent.getStringExtra(KEY_TYPE)) ?: AlarmType.AMOK,
                triggeredByName = intent.getStringExtra(KEY_TRIGGERED_BY_NAME).orEmpty(),
                location = intent.getStringExtra(KEY_LOCATION).orEmpty(),
                createdAt = intent.getLongExtra(KEY_CREATED_AT, 0L),
                instruction = intent.getStringExtra(KEY_INSTRUCTION).orEmpty(),
                isSelfTest = intent.getBooleanExtra(KEY_SELF_TEST, false),
                clearedByName = intent.getStringExtra(KEY_CLEARED_BY_NAME).orEmpty(),
                clearedAt = intent.getLongExtra(KEY_CLEARED_AT, 0L),
            )
        }
    }
}
