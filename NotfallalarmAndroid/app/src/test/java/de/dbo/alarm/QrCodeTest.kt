package de.dbo.alarm

import de.dbo.alarm.util.QrCode
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Writes the computed matrices to build/qr-matrices.txt so that scripts/qr-pruefen.py can
 * compare them against an independent implementation. A QR code with one module in the
 * wrong place looks perfectly fine and is read by no camera, so the shape alone proves
 * nothing - the cross-check is the point.
 */
class QrCodeTest {

    private val samples = listOf("K7M2QX", "ABC123", "https://example.org/beitritt?code=K7M2QX")

    @Test
    fun writesMatricesForCrossCheck() {
        val out = StringBuilder()
        for (text in samples) {
            for (mask in 0 until 8) {
                val matrix = QrCode.matrix(text, mask)
                out.append(text).append('\t').append(mask).append('\t').append(matrix.size).append('\n')
                for (row in matrix) out.append(row.joinToString("")).append('\n')
            }
        }
        val file = File("build/qr-matrices.txt")
        file.parentFile?.mkdirs()
        file.writeText(out.toString())
        assertTrue(file.length() > 0)
    }

    @Test
    fun sizeMatchesVersion() {
        // Six characters fit into version 1, which is 21 modules across.
        assertEquals(21, QrCode.matrix("K7M2QX").size)
    }

    @Test
    fun quietZoneIsNotPartOfTheMatrix() {
        val matrix = QrCode.matrix("K7M2QX")
        // Top left finder pattern: the outer ring is dark, the gap around the core is light.
        assertEquals(1, matrix[0][0])
        assertEquals(0, matrix[1][1])
        assertEquals(1, matrix[2][2])
    }
}
