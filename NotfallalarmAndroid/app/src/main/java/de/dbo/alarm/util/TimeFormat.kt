package de.dbo.alarm.util

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val germany = Locale.GERMANY

fun formatTime(millis: Long): String =
    if (millis <= 0) "--:--" else SimpleDateFormat("HH:mm", germany).format(Date(millis))

fun formatDateTime(millis: Long): String =
    if (millis <= 0) "-" else SimpleDateFormat("dd.MM.yyyy, HH:mm", germany).format(Date(millis))

/** "vor 3 Minuten" style, kept coarse - the device list only needs to answer
 *  "has this phone reported recently or not". */
fun formatRelative(millis: Long?): String? {
    if (millis == null || millis <= 0) return null
    val diff = System.currentTimeMillis() - millis
    val minutes = diff / 60_000
    return when {
        minutes < 1 -> "gerade eben"
        minutes < 60 -> "vor $minutes Min."
        minutes < 60 * 24 -> "vor ${minutes / 60} Std."
        else -> "vor ${minutes / (60 * 24)} Tagen"
    }
}
