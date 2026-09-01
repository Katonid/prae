package de.dbo.alarm.data

import com.google.firebase.auth.FirebaseUser
import kotlinx.coroutines.tasks.await

/**
 * Anonymous auth only. Staff should not have to invent a password for an app they open
 * twice a year, and an e-mail address would be one more piece of personal data to keep.
 */
class AuthRepository {

    val uid: String? get() = Backend.auth.currentUser?.uid

    suspend fun ensureSignedIn(): FirebaseUser {
        Backend.auth.currentUser?.let { return it }
        val result = Backend.auth.signInAnonymously().await()
        return requireNotNull(result.user) { "anonymous sign-in returned no user" }
    }

    fun signOut() = Backend.auth.signOut()
}
