package de.dbo.alarm.util

import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentSnapshot

/**
 * Timestamps are written by the server wherever the ordering matters, but a field can
 * still arrive as a plain number (an older client, or the moment between a local write
 * and the server's echo). Reading both shapes keeps the UI from showing "never".
 */
fun DocumentSnapshot.millisOrNull(field: String): Long? = when (val value = get(field)) {
    is Timestamp -> value.toDate().time
    is Number -> value.toLong()
    else -> null
}
