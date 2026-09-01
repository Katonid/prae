package de.dbo.alarm.data

import android.content.Context
import android.os.Build
import com.google.firebase.firestore.FieldValue
import com.google.firebase.messaging.FirebaseMessaging
import de.dbo.alarm.BuildConfig
import de.dbo.alarm.permissions.DeviceReadiness
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.tasks.await

/**
 * Keeps the member document in step with what this phone can actually do. The admin
 * device list is only worth reading if this runs on every app start and on every ping.
 */
class DeviceRepository(
    private val context: Context,
    private val settings: Settings,
    private val auth: AuthRepository,
    private val readiness: DeviceReadiness,
) {

    /**
     * getInstance()/getToken() carry a deprecation in favour of register(), which delivers
     * the token asynchronously through FirebaseMessagingService.onRegistered. That callback
     * is answered too, but the ping reply has to be able to read the current token right
     * here - a device that cannot state its token is a device no alarm reaches.
     */
    @Suppress("DEPRECATION")
    suspend fun currentToken(): String = FirebaseMessaging.getInstance().token.await()

    /**
     * Writes token, permission state, version and lastSeen in one go.
     * Silently does nothing when there is no group yet - the member document only
     * exists after joining.
     */
    suspend fun syncDevice(reason: String) {
        val groupId = settings.currentGroupId() ?: return
        val uid = auth.uid ?: return
        val token = runCatching { currentToken() }.getOrNull()
        val errors = settings.errorLog.first()

        val update = buildMap<String, Any> {
            if (token != null) put("fcmToken", token)
            put("platform", "android")
            put("deviceModel", "${Build.MANUFACTURER} ${Build.MODEL}")
            put("androidRelease", Build.VERSION.RELEASE.orEmpty())
            put("appVersion", BuildConfig.VERSION_NAME)
            put("appVersionCode", BuildConfig.VERSION_CODE.toLong())
            put("permissionState", readiness.state().toMap())
            put("lastSeen", FieldValue.serverTimestamp())
            put("lastSeenReason", reason)
            put("lastErrors", errors)
        }

        Paths.member(groupId, uid).set(update, com.google.firebase.firestore.SetOptions.merge()).await()
        if (token != null) settings.setLastUploadedToken(token)
        if (errors.isNotEmpty()) settings.clearErrorLog()
    }

    /** Called from onNewToken; writing it immediately is the difference between a
     *  delivered alarm and a silent phone after a reinstall or a cache wipe. */
    suspend fun uploadToken(token: String) {
        val groupId = settings.currentGroupId() ?: return
        val uid = auth.uid ?: return
        Paths.member(groupId, uid)
            .set(mapOf("fcmToken" to token), com.google.firebase.firestore.SetOptions.merge())
            .await()
        settings.setLastUploadedToken(token)
    }

    suspend fun loadAppConfig(): de.dbo.alarm.data.model.AppConfig? = runCatching {
        val snapshot = Paths.androidConfig().get().await()
        if (!snapshot.exists()) return@runCatching null
        de.dbo.alarm.data.model.AppConfig(
            latestVersionCode = snapshot.getLong("latestVersionCode") ?: 0,
            apkUrl = snapshot.getString("apkUrl").orEmpty(),
            releaseNotes = snapshot.getString("releaseNotes").orEmpty(),
            latestVersionName = snapshot.getString("latestVersionName").orEmpty(),
        )
    }.getOrNull()

    suspend fun runSelfTest() {
        val groupId = settings.currentGroupId()
            ?: error("Ohne Gruppe gibt es kein Gerät, an das der Selbsttest gehen könnte.")
        Backend.call("selfTest", mapOf("groupId" to groupId))
    }

    suspend fun pingAll(groupId: String) {
        Backend.call("ping", mapOf("groupId" to groupId))
    }

    suspend fun pingOne(groupId: String, uid: String) {
        Backend.call("ping", mapOf("groupId" to groupId, "uid" to uid))
    }
}
