package de.dbo.alarm.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "alarm_settings")

/**
 * Everything that belongs to this installation on this phone. Nothing here is synced;
 * a restored backup would only produce a member entry that can never be reached, which
 * is why the app also opts out of cloud backup entirely.
 */
class Settings(private val context: Context) {

    private object Keys {
        val GROUP_ID = stringPreferencesKey("groupId")
        val GROUP_NAME = stringPreferencesKey("groupName")
        val DISPLAY_NAME = stringPreferencesKey("displayName")
        val ROLE = stringPreferencesKey("role")
        val LAST_LOCATION = stringPreferencesKey("lastLocation")
        val VIBRATE_ONLY = booleanPreferencesKey("vibrateOnly")
        val ONBOARDING_DONE = booleanPreferencesKey("onboardingDone")
        val SELF_TEST_PASSED = booleanPreferencesKey("selfTestPassed")
        val MANUFACTURER_HINT_DONE = booleanPreferencesKey("manufacturerHintDone")
        val SEEN_ALARM_IDS = stringSetPreferencesKey("seenAlarmIds")
        val ERROR_LOG = stringPreferencesKey("errorLog")
        val DISMISSED_UPDATE = longPreferencesKey("dismissedUpdateVersionCode")
        val LAST_TOKEN = stringPreferencesKey("lastUploadedToken")
    }

    /** How many alarm ids we remember for duplicate suppression. */
    private val seenAlarmIdCap = 50

    val groupId: Flow<String?> = context.dataStore.data.map { it[Keys.GROUP_ID] }
    val groupName: Flow<String> = context.dataStore.data.map { it[Keys.GROUP_NAME].orEmpty() }
    val displayName: Flow<String> = context.dataStore.data.map { it[Keys.DISPLAY_NAME].orEmpty() }
    val role: Flow<String> = context.dataStore.data.map { it[Keys.ROLE] ?: "member" }
    val lastLocation: Flow<String> = context.dataStore.data.map { it[Keys.LAST_LOCATION].orEmpty() }
    val vibrateOnly: Flow<Boolean> = context.dataStore.data.map { it[Keys.VIBRATE_ONLY] ?: false }
    val onboardingDone: Flow<Boolean> = context.dataStore.data.map { it[Keys.ONBOARDING_DONE] ?: false }
    val selfTestPassed: Flow<Boolean> = context.dataStore.data.map { it[Keys.SELF_TEST_PASSED] ?: false }
    val manufacturerHintDone: Flow<Boolean> = context.dataStore.data.map { it[Keys.MANUFACTURER_HINT_DONE] ?: false }
    val errorLog: Flow<String> = context.dataStore.data.map { it[Keys.ERROR_LOG].orEmpty() }
    val dismissedUpdateVersionCode: Flow<Long> = context.dataStore.data.map { it[Keys.DISMISSED_UPDATE] ?: 0L }

    suspend fun currentGroupId(): String? = groupId.first()

    suspend fun setMembership(groupId: String, groupName: String, displayName: String, role: String) {
        context.dataStore.edit {
            it[Keys.GROUP_ID] = groupId
            it[Keys.GROUP_NAME] = groupName
            it[Keys.DISPLAY_NAME] = displayName
            it[Keys.ROLE] = role
        }
    }

    suspend fun setGroupName(name: String) = context.dataStore.edit { it[Keys.GROUP_NAME] = name }

    suspend fun setDisplayName(name: String) = context.dataStore.edit { it[Keys.DISPLAY_NAME] = name }

    suspend fun setRole(role: String) = context.dataStore.edit { it[Keys.ROLE] = role }

    suspend fun setLastLocation(location: String) = context.dataStore.edit { it[Keys.LAST_LOCATION] = location }

    suspend fun setVibrateOnly(value: Boolean) = context.dataStore.edit { it[Keys.VIBRATE_ONLY] = value }

    suspend fun setOnboardingDone(value: Boolean) = context.dataStore.edit { it[Keys.ONBOARDING_DONE] = value }

    suspend fun setSelfTestPassed(value: Boolean) = context.dataStore.edit { it[Keys.SELF_TEST_PASSED] = value }

    suspend fun setManufacturerHintDone(value: Boolean) =
        context.dataStore.edit { it[Keys.MANUFACTURER_HINT_DONE] = value }

    suspend fun setDismissedUpdateVersionCode(value: Long) =
        context.dataStore.edit { it[Keys.DISMISSED_UPDATE] = value }

    suspend fun clearMembership() {
        context.dataStore.edit {
            it.remove(Keys.GROUP_ID)
            it.remove(Keys.GROUP_NAME)
            it.remove(Keys.ROLE)
            it.remove(Keys.SEEN_ALARM_IDS)
            it[Keys.ONBOARDING_DONE] = false
            it[Keys.SELF_TEST_PASSED] = false
        }
    }

    /** True when this alarm id had not been seen before. Marks it as seen either way. */
    suspend fun markAlarmSeen(alarmId: String): Boolean {
        var isNew = false
        context.dataStore.edit { prefs ->
            val seen = prefs[Keys.SEEN_ALARM_IDS].orEmpty()
            isNew = alarmId !in seen
            if (isNew) {
                // Bounded on purpose: an unbounded set would grow with every alarm and
                // has to be read on the delivery path, where every millisecond counts.
                val trimmed = if (seen.size >= seenAlarmIdCap) seen.drop(seen.size - seenAlarmIdCap + 1).toSet() else seen
                prefs[Keys.SEEN_ALARM_IDS] = trimmed + alarmId
            }
        }
        return isNew
    }

    suspend fun lastUploadedToken(): String? = context.dataStore.data.map { it[Keys.LAST_TOKEN] }.first()

    suspend fun setLastUploadedToken(token: String) = context.dataStore.edit { it[Keys.LAST_TOKEN] = token }

    /**
     * Local error trail. Anything that goes wrong on the delivery path lands here and is
     * sent along with the next ping; without it a phone that stays silent tells us nothing.
     */
    suspend fun appendError(line: String) {
        context.dataStore.edit { prefs ->
            val existing = prefs[Keys.ERROR_LOG].orEmpty()
            val combined = if (existing.isEmpty()) line else "$existing\n$line"
            prefs[Keys.ERROR_LOG] = combined.lines().takeLast(30).joinToString("\n")
        }
    }

    suspend fun clearErrorLog() = context.dataStore.edit { it.remove(Keys.ERROR_LOG) }
}
