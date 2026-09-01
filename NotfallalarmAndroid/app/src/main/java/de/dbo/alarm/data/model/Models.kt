package de.dbo.alarm.data.model

/**
 * Wire values are shared with the Cloud Functions backend and with a future iOS client,
 * so they are spelled out here instead of relying on enum names.
 */
enum class AlarmType(val wire: String) {
    AMOK("amok"),
    FIRE("fire"),
    MEDICAL("medical"),
    TEST("test");

    val isTest: Boolean get() = this == TEST

    companion object {
        fun fromWire(value: String?): AlarmType? = entries.firstOrNull { it.wire == value }
    }
}

enum class AlarmStatus(val wire: String) {
    ACTIVE("active"),
    CLEARED("cleared");

    companion object {
        fun fromWire(value: String?): AlarmStatus = entries.firstOrNull { it.wire == value } ?: ACTIVE
    }
}

enum class AckStatus(val wire: String) {
    SECURED("secured"),
    HELP_NEEDED("help_needed"),
    SEEN("seen");

    companion object {
        fun fromWire(value: String?): AckStatus = entries.firstOrNull { it.wire == value } ?: SEEN
    }
}

enum class MemberRole(val wire: String) {
    ADMIN("admin"),
    MEMBER("member");

    companion object {
        fun fromWire(value: String?): MemberRole = entries.firstOrNull { it.wire == value } ?: MEMBER
    }
}

data class PermissionState(
    val notifications: Boolean = false,
    val fullScreenIntent: Boolean = false,
    val batteryExempt: Boolean = false,
    val dndAccess: Boolean = false,
) {
    /** Everything the alarm path really depends on; DND access is a recommendation. */
    val allRequiredGranted: Boolean get() = notifications && fullScreenIntent && batteryExempt

    fun toMap(): Map<String, Any> = mapOf(
        "notifications" to notifications,
        "fullScreenIntent" to fullScreenIntent,
        "batteryExempt" to batteryExempt,
        "dndAccess" to dndAccess,
    )

    companion object {
        fun fromMap(map: Map<*, *>?): PermissionState {
            if (map == null) return PermissionState()
            fun flag(key: String) = map[key] as? Boolean ?: false
            return PermissionState(
                notifications = flag("notifications"),
                fullScreenIntent = flag("fullScreenIntent"),
                batteryExempt = flag("batteryExempt"),
                dndAccess = flag("dndAccess"),
            )
        }
    }
}

data class Member(
    val uid: String,
    val displayName: String,
    val role: MemberRole = MemberRole.MEMBER,
    val platform: String = "",
    val deviceModel: String = "",
    val appVersion: String = "",
    val appVersionCode: Long = 0,
    val permissionState: PermissionState = PermissionState(),
    val lastSeen: Long? = null,
) {
    val isAdmin: Boolean get() = role == MemberRole.ADMIN
}

data class InviteCode(
    val code: String,
    val createdAt: Long = 0,
    val expiresAt: Long = 0,
    val revoked: Boolean = false,
) {
    fun isValidAt(now: Long): Boolean = !revoked && expiresAt > now

    fun toMap(): Map<String, Any> = mapOf(
        "code" to code,
        "createdAt" to createdAt,
        "expiresAt" to expiresAt,
        "revoked" to revoked,
    )

    companion object {
        fun fromMap(map: Map<*, *>): InviteCode? {
            val code = map["code"] as? String ?: return null
            return InviteCode(
                code = code,
                createdAt = (map["createdAt"] as? Number)?.toLong() ?: 0,
                expiresAt = (map["expiresAt"] as? Number)?.toLong() ?: 0,
                revoked = map["revoked"] as? Boolean ?: false,
            )
        }
    }
}

data class Group(
    val id: String,
    val name: String = "",
    val locations: List<String> = emptyList(),
    val instructions: Map<String, String> = emptyMap(),
    val adminIds: List<String> = emptyList(),
    val inviteCodes: List<InviteCode> = emptyList(),
) {
    fun instructionFor(type: AlarmType): String? = instructions[type.wire]?.takeIf { it.isNotBlank() }
}

data class Alarm(
    val id: String,
    val groupId: String,
    val type: AlarmType,
    val triggeredBy: String = "",
    val triggeredByName: String = "",
    val location: String = "",
    val createdAt: Long = 0,
    val status: AlarmStatus = AlarmStatus.ACTIVE,
    val clearedAt: Long? = null,
    val clearedBy: String? = null,
    val clearedByName: String? = null,
    /** Copied onto the alarm when it is created, so the alarm screen works offline. */
    val instruction: String = "",
) {
    val isActive: Boolean get() = status == AlarmStatus.ACTIVE
}

data class AckEntry(
    val uid: String,
    val status: AckStatus,
    val displayName: String = "",
    val location: String = "",
    val at: Long = 0,
)

data class ChatMessage(
    val id: String,
    val text: String,
    val senderName: String,
    val senderUid: String = "",
    val at: Long = 0,
)

data class AppConfig(
    val latestVersionCode: Long = 0,
    val apkUrl: String = "",
    val releaseNotes: String = "",
    val latestVersionName: String = "",
)
