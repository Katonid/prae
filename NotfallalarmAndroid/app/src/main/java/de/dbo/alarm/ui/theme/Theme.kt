package de.dbo.alarm.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import de.dbo.alarm.data.model.AlarmType

/**
 * One colour per alarm type, readable at arm's length and distinguishable for the most
 * common colour blindness: red, orange, blue and grey differ in brightness as well as hue,
 * and every screen that uses them also spells the type out in words.
 */
object AlarmColors {
    val Amok = Color(0xFFB3141B)
    val AmokDark = Color(0xFF7C0E13)
    val Fire = Color(0xFFC75300)
    val FireDark = Color(0xFF8C3A00)
    val Medical = Color(0xFF10559A)
    val MedicalDark = Color(0xFF0B3C6E)
    val Test = Color(0xFF4A4F55)
    val TestDark = Color(0xFF32363A)
    val AllClear = Color(0xFF1B5E4A)

    fun forType(type: AlarmType, dark: Boolean = false): Color = when (type) {
        AlarmType.AMOK -> if (dark) AmokDark else Amok
        AlarmType.FIRE -> if (dark) FireDark else Fire
        AlarmType.MEDICAL -> if (dark) MedicalDark else Medical
        AlarmType.TEST -> if (dark) TestDark else Test
    }
}

private val LightColors = lightColorScheme(
    primary = Color(0xFFB3141B),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFFFDAD7),
    onPrimaryContainer = Color(0xFF410004),
    secondary = Color(0xFF10559A),
    onSecondary = Color.White,
    error = Color(0xFF8C0009),
    surface = Color(0xFFFCFCFC),
    background = Color(0xFFF6F6F6),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFFFB3AC),
    onPrimary = Color(0xFF680008),
    primaryContainer = Color(0xFF930010),
    onPrimaryContainer = Color(0xFFFFDAD7),
    secondary = Color(0xFF9FCAFF),
    onSecondary = Color(0xFF00325B),
    error = Color(0xFFFFB4AB),
    surface = Color(0xFF141314),
    background = Color(0xFF101010),
)

@Composable
fun NotfallalarmTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) DarkColors else LightColors
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            (view.context as? Activity)?.let { activity ->
                WindowCompat.setDecorFitsSystemWindows(activity.window, false)
            }
        }
    }
    MaterialTheme(colorScheme = colors, content = content)
}
