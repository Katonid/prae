package de.dbo.alarm.data

import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.functions.FirebaseFunctions
import kotlinx.coroutines.tasks.await

/** Placeholder project id shipped in google-services.json.template. */
private const val PLACEHOLDER_PROJECT_ID = "PLACEHOLDER-NOT-CONFIGURED"

/**
 * Single place that knows about the Firebase entry points. Callable functions live in
 * europe-west3 (Frankfurt) together with Firestore; the default region would be us-central1
 * and every call would silently go to a function that does not exist there.
 */
object Backend {

    const val FUNCTIONS_REGION = "europe-west3"

    val auth: FirebaseAuth get() = FirebaseAuth.getInstance()

    val firestore: FirebaseFirestore get() = FirebaseFirestore.getInstance()

    val functions: FirebaseFunctions get() = FirebaseFunctions.getInstance(FUNCTIONS_REGION)

    val isConfigured: Boolean
        get() = runCatching {
            FirebaseApp.getInstance().options.projectId
        }.getOrNull().let { it != null && it != PLACEHOLDER_PROJECT_ID }

    suspend fun call(name: String, data: Map<String, Any?>): Map<*, *> {
        val result = functions.getHttpsCallable(name).call(data).await()
        return result.data as? Map<*, *> ?: emptyMap<String, Any?>()
    }
}

/** Firestore document and collection paths, spelled out once. */
object Paths {
    fun group(groupId: String) = Backend.firestore.collection("groups").document(groupId)
    fun members(groupId: String) = group(groupId).collection("members")
    fun member(groupId: String, uid: String) = members(groupId).document(uid)
    fun alarms(groupId: String) = group(groupId).collection("alarms")
    fun alarm(groupId: String, alarmId: String) = alarms(groupId).document(alarmId)
    fun acks(groupId: String, alarmId: String) = alarm(groupId, alarmId).collection("acks")
    fun messages(groupId: String, alarmId: String) = alarm(groupId, alarmId).collection("messages")
    fun androidConfig() = Backend.firestore.collection("config").document("android")
}
