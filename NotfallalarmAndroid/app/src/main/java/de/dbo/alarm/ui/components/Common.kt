package de.dbo.alarm.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import de.dbo.alarm.util.QrCode

@Composable
fun SectionCard(
    modifier: Modifier = Modifier,
    title: String? = null,
    content: @Composable () -> Unit,
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (title != null) {
                Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            }
            content()
        }
    }
}

/**
 * A standing notice, not a snackbar. Everything this app has to say - a missing
 * permission, a new version, a locked-down database - stays true until someone acts on
 * it, and a strip that fades after four seconds is a riddle, not a message.
 */
@Composable
fun Banner(
    title: String,
    text: String,
    modifier: Modifier = Modifier,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
    dismissLabel: String? = null,
    onDismiss: (() -> Unit)? = null,
    container: Color = MaterialTheme.colorScheme.errorContainer,
    onContainer: Color = MaterialTheme.colorScheme.onErrorContainer,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(container)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(title, color = onContainer, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
        Text(text, color = onContainer, style = MaterialTheme.typography.bodyMedium)
        if (actionLabel != null || dismissLabel != null) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (actionLabel != null && onAction != null) {
                    TextButton(onClick = onAction) { Text(actionLabel) }
                }
                if (dismissLabel != null && onDismiss != null) {
                    TextButton(onClick = onDismiss) { Text(dismissLabel) }
                }
            }
        }
    }
}

/**
 * The invite code as a QR image. Drawn module by module rather than rendered to a
 * bitmap, so it stays sharp on a projector and on a printout.
 */
@Composable
fun QrImage(text: String, modifier: Modifier = Modifier, quietZone: Int = 4) {
    val matrix = remember(text) { runCatching { QrCode.matrix(text) }.getOrNull() }
    if (matrix == null) {
        Text("QR-Code konnte nicht erzeugt werden.")
        return
    }
    val size = matrix.size
    val total = size + quietZone * 2
    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(1f)
            .background(Color.White)
    ) {
        val module = this.size.minDimension / total
        for (row in 0 until size) {
            for (col in 0 until size) {
                if (matrix[row][col] != 1) continue
                drawRect(
                    color = Color.Black,
                    topLeft = Offset((col + quietZone) * module, (row + quietZone) * module),
                    size = Size(module, module),
                )
            }
        }
    }
}

@Composable
fun StatusDot(ok: Boolean, modifier: Modifier = Modifier) {
    val color = if (ok) Color(0xFF1B7F4B) else MaterialTheme.colorScheme.error
    Spacer(
        modifier
            .size(12.dp)
            .clip(RoundedCornerShape(6.dp))
            .background(color)
    )
}
