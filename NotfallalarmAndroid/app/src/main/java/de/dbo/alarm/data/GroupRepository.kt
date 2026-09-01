package de.dbo.alarm.data

import com.google.firebase.firestore.DocumentSnapshot
import de.dbo.alarm.util.millisOrNull
import com.google.firebase.firestore.Query
import de.dbo.alarm.data.model.Group
import de.dbo.alarm.data.model.InviteCode
import de.dbo.alarm.data.model.Member
import de.dbo.alarm.data.model.MemberRole
import de.dbo.alarm.data.model.PermissionState
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await

class GroupRepository {

    /** Result of joining or creating a group, as returned by the callable functions. */
    data class Membership(val groupId: String, val groupName: String, val role: String)

    suspend fun createGroup(name: String, displayName: String): Membership {
        val data = Backend.call("createGroup", mapOf("name" to name, "displayName" to displayName))
        return Membership(
            groupId = data["groupId"] as? String ?: error("createGroup returned no groupId"),
            groupName = data["groupName"] as? String ?: name,
            role = data["role"] as? String ?: MemberRole.ADMIN.wire,
        )
    }

    suspend fun joinGroup(code: String, displayName: String): Membership {
        val data = Backend.call("joinGroup", mapOf("code" to code, "displayName" to displayName))
        return Membership(
            groupId = data["groupId"] as? String ?: error("joinGroup returned no groupId"),
            groupName = data["groupName"] as? String ?: "",
            role = data["role"] as? String ?: MemberRole.MEMBER.wire,
        )
    }

    fun observeGroup(groupId: String): Flow<Group?> = callbackFlow {
        val registration = Paths.group(groupId).addSnapshotListener { snapshot, error ->
            if (error != null) {
                trySend(null)
                return@addSnapshotListener
            }
            trySend(snapshot?.let { groupFrom(it) })
        }
        awaitClose { registration.remove() }
    }

    suspend fun loadGroup(groupId: String): Group? =
        Paths.group(groupId).get().await().takeIf { it.exists() }?.let { groupFrom(it) }

    fun observeMembers(groupId: String): Flow<List<Member>> = callbackFlow {
        val registration = Paths.members(groupId)
            .orderBy("displayName", Query.Direction.ASCENDING)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    trySend(emptyList())
                    return@addSnapshotListener
                }
                trySend(snapshot?.documents.orEmpty().mapNotNull { memberFrom(it) })
            }
        awaitClose { registration.remove() }
    }

    suspend fun loadMember(groupId: String, uid: String): Member? =
        Paths.member(groupId, uid).get().await().takeIf { it.exists() }?.let { memberFrom(it) }

    suspend fun updateLocations(groupId: String, locations: List<String>) {
        Paths.group(groupId).update("locations", locations).await()
    }

    suspend fun updateInstructions(groupId: String, instructions: Map<String, String>) {
        Paths.group(groupId).update("instructions", instructions).await()
    }

    /**
     * Invite codes are stored twice on purpose: as objects for the admin screen and as a
     * plain string array, because Firestore's array-contains cannot match a map and the
     * joinGroup function has to find a group by its code without knowing the group id.
     */
    suspend fun setInviteCodes(groupId: String, codes: List<InviteCode>) {
        val now = System.currentTimeMillis()
        Paths.group(groupId).update(
            mapOf(
                "inviteCodes" to codes.map { it.toMap() },
                "inviteCodeValues" to codes.filter { it.isValidAt(now) }.map { it.code },
            )
        ).await()
    }

    suspend fun setDisplayName(groupId: String, uid: String, displayName: String) {
        Paths.member(groupId, uid).update("displayName", displayName).await()
    }

    suspend fun removeMember(groupId: String, uid: String) {
        Paths.member(groupId, uid).delete().await()
    }

    suspend fun setAdmin(groupId: String, uid: String, isAdmin: Boolean) {
        val group = Paths.group(groupId).get().await()
        @Suppress("UNCHECKED_CAST")
        val current = (group.get("adminIds") as? List<String>).orEmpty()
        val next = if (isAdmin) (current + uid).distinct() else current - uid
        // Never leave a group without anyone who can manage it.
        if (next.isEmpty()) error("Die Gruppe braucht mindestens einen Admin.")
        Paths.group(groupId).update("adminIds", next).await()
        Paths.member(groupId, uid)
            .update("role", if (isAdmin) MemberRole.ADMIN.wire else MemberRole.MEMBER.wire).await()
    }

    private fun groupFrom(snapshot: DocumentSnapshot): Group? {
        if (!snapshot.exists()) return null
        @Suppress("UNCHECKED_CAST")
        val rawCodes = (snapshot.get("inviteCodes") as? List<Map<*, *>>).orEmpty()
        @Suppress("UNCHECKED_CAST")
        val instructions = (snapshot.get("instructions") as? Map<String, Any?>).orEmpty()
        @Suppress("UNCHECKED_CAST")
        return Group(
            id = snapshot.id,
            name = snapshot.getString("name").orEmpty(),
            locations = (snapshot.get("locations") as? List<String>).orEmpty(),
            instructions = instructions.mapNotNull { (key, value) ->
                (value as? String)?.let { key to it }
            }.toMap(),
            adminIds = (snapshot.get("adminIds") as? List<String>).orEmpty(),
            inviteCodes = rawCodes.mapNotNull { InviteCode.fromMap(it) },
        )
    }

    private fun memberFrom(snapshot: DocumentSnapshot): Member? {
        if (!snapshot.exists()) return null
        return Member(
            uid = snapshot.id,
            displayName = snapshot.getString("displayName").orEmpty(),
            role = MemberRole.fromWire(snapshot.getString("role")),
            platform = snapshot.getString("platform").orEmpty(),
            deviceModel = snapshot.getString("deviceModel").orEmpty(),
            appVersion = snapshot.getString("appVersion").orEmpty(),
            appVersionCode = snapshot.getLong("appVersionCode") ?: 0,
            permissionState = PermissionState.fromMap(snapshot.get("permissionState") as? Map<*, *>),
            lastSeen = snapshot.millisOrNull("lastSeen"),
        )
    }
}
