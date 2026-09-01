package de.dbo.alarm.data

import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.Query
import de.dbo.alarm.data.model.AckEntry
import de.dbo.alarm.data.model.AckStatus
import de.dbo.alarm.data.model.Alarm
import de.dbo.alarm.data.model.AlarmStatus
import de.dbo.alarm.data.model.AlarmType
import de.dbo.alarm.data.model.ChatMessage
import de.dbo.alarm.util.millisOrNull
import com.google.firebase.firestore.FieldValue
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await

class AlarmRepository {

    /** Returns the id of the alarm that was created. */
    suspend fun triggerAlarm(groupId: String, type: AlarmType, location: String): String {
        val data = Backend.call(
            "triggerAlarm",
            mapOf("groupId" to groupId, "type" to type.wire, "location" to location),
        )
        return data["alarmId"] as? String ?: error("triggerAlarm returned no alarmId")
    }

    suspend fun clearAlarm(groupId: String, alarmId: String) {
        Backend.call("clearAlarm", mapOf("groupId" to groupId, "alarmId" to alarmId))
    }

    suspend fun loadAlarm(groupId: String, alarmId: String): Alarm? =
        Paths.alarm(groupId, alarmId).get().await().takeIf { it.exists() }?.let { alarmFrom(groupId, it) }

    fun observeAlarm(groupId: String, alarmId: String): Flow<Alarm?> = callbackFlow {
        val registration = Paths.alarm(groupId, alarmId).addSnapshotListener { snapshot, error ->
            if (error != null) {
                trySend(null)
                return@addSnapshotListener
            }
            trySend(snapshot?.let { alarmFrom(groupId, it) })
        }
        awaitClose { registration.remove() }
    }

    /** Active alarms, newest first. Used for the home screen and the duplicate guard. */
    fun observeActiveAlarms(groupId: String): Flow<List<Alarm>> = callbackFlow {
        val registration = Paths.alarms(groupId)
            .whereEqualTo("status", AlarmStatus.ACTIVE.wire)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    trySend(emptyList())
                    return@addSnapshotListener
                }
                val alarms = snapshot?.documents.orEmpty()
                    .mapNotNull { alarmFrom(groupId, it) }
                    .sortedByDescending { it.createdAt }
                trySend(alarms)
            }
        awaitClose { registration.remove() }
    }

    fun observeHistory(groupId: String, limit: Long = 50): Flow<List<Alarm>> = callbackFlow {
        val registration = Paths.alarms(groupId)
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .limit(limit)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    trySend(emptyList())
                    return@addSnapshotListener
                }
                trySend(snapshot?.documents.orEmpty().mapNotNull { alarmFrom(groupId, it) })
            }
        awaitClose { registration.remove() }
    }

    suspend fun acknowledge(
        groupId: String,
        alarmId: String,
        uid: String,
        status: AckStatus,
        displayName: String,
        location: String,
    ) {
        Paths.acks(groupId, alarmId).document(uid).set(
            mapOf(
                "status" to status.wire,
                "displayName" to displayName,
                "location" to location,
                "at" to FieldValue.serverTimestamp(),
            )
        ).await()
    }

    fun observeAcks(groupId: String, alarmId: String): Flow<List<AckEntry>> = callbackFlow {
        val registration = Paths.acks(groupId, alarmId).addSnapshotListener { snapshot, error ->
            if (error != null) {
                trySend(emptyList())
                return@addSnapshotListener
            }
            val acks = snapshot?.documents.orEmpty().map { doc ->
                AckEntry(
                    uid = doc.id,
                    status = AckStatus.fromWire(doc.getString("status")),
                    displayName = doc.getString("displayName").orEmpty(),
                    location = doc.getString("location").orEmpty(),
                    at = doc.millisOrNull("at") ?: 0,
                )
            }.sortedBy { it.displayName.lowercase() }
            trySend(acks)
        }
        awaitClose { registration.remove() }
    }

    suspend fun loadAcks(groupId: String, alarmId: String): List<AckEntry> =
        Paths.acks(groupId, alarmId).get().await().documents.map { doc ->
            AckEntry(
                uid = doc.id,
                status = AckStatus.fromWire(doc.getString("status")),
                displayName = doc.getString("displayName").orEmpty(),
                location = doc.getString("location").orEmpty(),
                at = doc.millisOrNull("at") ?: 0,
            )
        }

    suspend fun sendMessage(groupId: String, alarmId: String, uid: String, senderName: String, text: String) {
        Paths.messages(groupId, alarmId).add(
            mapOf(
                "text" to text,
                "senderName" to senderName,
                "senderUid" to uid,
                "at" to FieldValue.serverTimestamp(),
            )
        ).await()
    }

    fun observeMessages(groupId: String, alarmId: String): Flow<List<ChatMessage>> = callbackFlow {
        val registration = Paths.messages(groupId, alarmId)
            .orderBy("at", Query.Direction.ASCENDING)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    trySend(emptyList())
                    return@addSnapshotListener
                }
                trySend(
                    snapshot?.documents.orEmpty().map { doc ->
                        ChatMessage(
                            id = doc.id,
                            text = doc.getString("text").orEmpty(),
                            senderName = doc.getString("senderName").orEmpty(),
                            senderUid = doc.getString("senderUid").orEmpty(),
                            at = doc.millisOrNull("at") ?: 0,
                        )
                    }
                )
            }
        awaitClose { registration.remove() }
    }

    private fun alarmFrom(groupId: String, snapshot: DocumentSnapshot): Alarm? {
        if (!snapshot.exists()) return null
        val type = AlarmType.fromWire(snapshot.getString("type")) ?: return null
        return Alarm(
            id = snapshot.id,
            groupId = groupId,
            type = type,
            triggeredBy = snapshot.getString("triggeredBy").orEmpty(),
            triggeredByName = snapshot.getString("triggeredByName").orEmpty(),
            location = snapshot.getString("location").orEmpty(),
            createdAt = snapshot.millisOrNull("createdAt") ?: 0,
            status = AlarmStatus.fromWire(snapshot.getString("status")),
            clearedAt = snapshot.millisOrNull("clearedAt"),
            clearedBy = snapshot.getString("clearedBy"),
            clearedByName = snapshot.getString("clearedByName"),
            instruction = snapshot.getString("instruction").orEmpty(),
        )
    }
}
