package de.dbo.alarm.util

import kotlin.math.abs
import kotlin.math.floor

/**
 * QR code, computed here rather than pulled in as a library.
 *
 * This is a port of woerterwerkstatt/js/qr.js from the same repository, which is checked
 * against an independent implementation (segno) by scripts/qr-pruefen.py. Only what an
 * invite code needs is implemented: byte mode, error correction level M, versions 1 to 10.
 *
 * A QR code with a single module in the wrong place looks perfectly fine and is read by
 * no camera at all, so nothing here should be "tidied up" without re-running the check
 * in app/src/test/java/de/dbo/alarm/QrCodeTest.kt.
 */
object QrCode {

    /* ---------- arithmetic in GF(256) ---------- */

    private val EXP = IntArray(512)
    private val LOG = IntArray(256)

    init {
        var x = 1
        for (i in 0 until 255) {
            EXP[i] = x
            LOG[x] = i
            x = x shl 1
            if (x and 0x100 != 0) x = x xor 0x11d // the QR standard's polynomial
        }
        for (i in 255 until 512) EXP[i] = EXP[i - 255]
    }

    private fun mul(a: Int, b: Int): Int = if (a == 0 || b == 0) 0 else EXP[LOG[a] + LOG[b]]

    /** Generator polynomial for [count] error correction codewords. */
    private fun generator(count: Int): IntArray {
        var poly = intArrayOf(1)
        for (i in 0 until count) {
            val next = IntArray(poly.size + 1)
            for (j in poly.indices) {
                next[j] = next[j] xor poly[j]
                next[j + 1] = next[j + 1] xor mul(poly[j], EXP[i])
            }
            poly = next
        }
        return poly
    }

    private fun errorCorrection(data: IntArray, count: Int): IntArray {
        val gen = generator(count)
        val rest = IntArray(data.size + count)
        data.copyInto(rest)
        for (i in data.indices) {
            val factor = rest[i]
            if (factor == 0) continue
            for (j in gen.indices) rest[i + j] = rest[i + j] xor mul(gen[j], factor)
        }
        return rest.copyOfRange(data.size, rest.size)
    }

    /* ---------- tables from the standard ---------- */

    /** Per version and level: [ec per block, blocks A, data A, blocks B, data B]. */
    private val BLOCKS_M = arrayOf(
        intArrayOf(0, 0, 0, 0, 0),
        intArrayOf(10, 1, 16, 0, 0), intArrayOf(16, 1, 28, 0, 0), intArrayOf(26, 1, 44, 0, 0),
        intArrayOf(18, 2, 32, 0, 0), intArrayOf(24, 2, 43, 0, 0), intArrayOf(16, 4, 27, 0, 0),
        intArrayOf(18, 4, 31, 0, 0), intArrayOf(22, 2, 38, 2, 39), intArrayOf(22, 3, 36, 2, 37),
        intArrayOf(26, 4, 43, 1, 44),
    )

    private val ALIGNMENT = arrayOf(
        intArrayOf(), intArrayOf(), intArrayOf(6, 18), intArrayOf(6, 22), intArrayOf(6, 26),
        intArrayOf(6, 30), intArrayOf(6, 34), intArrayOf(6, 22, 38), intArrayOf(6, 24, 42),
        intArrayOf(6, 26, 46), intArrayOf(6, 28, 50),
    )

    /** Extra remainder bits after the codewords; versions 2 to 6 need seven. */
    private val REMAINDER_BITS = intArrayOf(0, 0, 7, 7, 7, 7, 7, 0, 0, 0, 0)

    private const val LEVEL_M_BITS = 0b00

    /* ---------- data to bits ---------- */

    private class BitBuffer {
        val bits = ArrayList<Int>()
        fun push(value: Int, length: Int) {
            for (i in length - 1 downTo 0) bits.add((value shr i) and 1)
        }
    }

    private fun dataCodewords(version: Int): Int {
        val (_, b1, d1, b2, d2) = BLOCKS_M[version].toList()
        return b1 * d1 + b2 * d2
    }

    private fun fittingVersion(byteCount: Int): Int {
        for (version in 1..10) {
            val header = 4 + if (version < 10) 8 else 16
            val needed = (header + byteCount * 8 + 7) / 8
            if (needed <= dataCodewords(version)) return version
        }
        return 0
    }

    private fun buildCodewords(bytes: IntArray, version: Int): IntArray {
        val capacity = dataCodewords(version)
        val buffer = BitBuffer()
        buffer.push(0b0100, 4) // byte mode
        buffer.push(bytes.size, if (version < 10) 8 else 16)
        for (b in bytes) buffer.push(b, 8)
        val rest = capacity * 8 - buffer.bits.size
        buffer.push(0, minOf(4, maxOf(0, rest)))
        while (buffer.bits.size % 8 != 0) buffer.bits.add(0)

        val codewords = ArrayList<Int>()
        var i = 0
        while (i < buffer.bits.size) {
            var byte = 0
            for (j in 0 until 8) byte = (byte shl 1) or buffer.bits[i + j]
            codewords.add(byte)
            i += 8
        }
        val padding = intArrayOf(0xec, 0x11)
        var p = 0
        while (codewords.size < capacity) {
            codewords.add(padding[p % 2])
            p += 1
        }
        return codewords.toIntArray()
    }

    /** Interleave data and error correction blocks, as the standard requires. */
    private fun interleave(codewords: IntArray, version: Int): IntArray {
        val spec = BLOCKS_M[version]
        val ecCount = spec[0]
        val b1 = spec[1]
        val d1 = spec[2]
        val b2 = spec[3]
        val d2 = spec[4]

        val dataBlocks = ArrayList<IntArray>()
        val ecBlocks = ArrayList<IntArray>()
        var cursor = 0
        repeat(b1) {
            val block = codewords.copyOfRange(cursor, cursor + d1)
            cursor += d1
            dataBlocks.add(block)
            ecBlocks.add(errorCorrection(block, ecCount))
        }
        repeat(b2) {
            val block = codewords.copyOfRange(cursor, cursor + d2)
            cursor += d2
            dataBlocks.add(block)
            ecBlocks.add(errorCorrection(block, ecCount))
        }

        val out = ArrayList<Int>()
        val maxData = maxOf(d1, d2)
        for (i in 0 until maxData) {
            for (block in dataBlocks) if (i < block.size) out.add(block[i])
        }
        for (i in 0 until ecCount) {
            for (block in ecBlocks) out.add(block[i])
        }
        return out.toIntArray()
    }

    /* ---------- the matrix ---------- */

    private const val EMPTY = -1

    private fun emptyMatrix(size: Int): Array<IntArray> =
        Array(size) { IntArray(size) { EMPTY } }

    private fun placeFinder(matrix: Array<IntArray>, row: Int, col: Int) {
        val size = matrix.size
        for (r in -1..7) {
            for (c in -1..7) {
                val y = row + r
                val x = col + c
                if (y < 0 || y >= size || x < 0 || x >= size) continue
                val inRing = (r in 0..6 && (c == 0 || c == 6)) || (c in 0..6 && (r == 0 || r == 6))
                val inCore = r in 2..4 && c in 2..4
                matrix[y][x] = if (inRing || inCore) 1 else 0
            }
        }
    }

    private fun placeAlignment(matrix: Array<IntArray>, version: Int) {
        val points = ALIGNMENT[version]
        for (row in points) {
            for (col in points) {
                if (matrix[row][col] != EMPTY) continue // sits on a finder pattern
                for (r in -2..2) {
                    for (c in -2..2) {
                        matrix[row + r][col + c] =
                            if (abs(r) == 2 || abs(c) == 2 || (r == 0 && c == 0)) 1 else 0
                    }
                }
            }
        }
    }

    private fun bchFormat(value: Int): Int {
        var rest = value shl 10
        for (i in 14 downTo 10) if ((rest shr i) and 1 == 1) rest = rest xor (0b10100110111 shl (i - 10))
        return ((value shl 10) or rest) xor 0b101010000010010
    }

    private fun bchVersion(version: Int): Int {
        var rest = version shl 12
        for (i in 17 downTo 12) if ((rest shr i) and 1 == 1) rest = rest xor (0b1111100100101 shl (i - 12))
        return (version shl 12) or rest
    }

    private fun placeFormat(matrix: Array<IntArray>, mask: Int) {
        val size = matrix.size
        val bits = bchFormat((LEVEL_M_BITS shl 3) or mask)
        fun read(i: Int) = (bits shr i) and 1

        // First copy: vertically along the left edge, then horizontally under the top left
        // finder. The order in the standard is NOT mirror symmetric - swapping row and
        // column here yields a code that looks flawless and that no camera reads.
        for (i in 0..5) matrix[i][8] = read(i)
        matrix[7][8] = read(6)
        matrix[8][8] = read(7)
        matrix[8][7] = read(8)
        for (i in 9..14) matrix[8][14 - i] = read(i)

        // Second copy: low bits horizontally at the top right, high bits vertically at the
        // bottom left - the other way round from the first. That is on purpose: if one
        // corner is covered, the other copy is still readable.
        for (i in 0..7) matrix[8][size - 1 - i] = read(i)
        for (i in 8..14) matrix[size - 15 + i][8] = read(i)
        matrix[size - 8][8] = 1 // the always-dark module
    }

    private fun placeVersion(matrix: Array<IntArray>, version: Int) {
        if (version < 7) return
        val size = matrix.size
        val bits = bchVersion(version)
        for (i in 0 until 18) {
            val bit = (bits shr i) and 1
            val row = i / 3
            val col = i % 3
            matrix[size - 11 + col][row] = bit
            matrix[row][size - 11 + col] = bit
        }
    }

    private val MASKS: List<(Int, Int) -> Boolean> = listOf(
        { r, c -> (r + c) % 2 == 0 },
        { r, _ -> r % 2 == 0 },
        { _, c -> c % 3 == 0 },
        { r, c -> (r + c) % 3 == 0 },
        { r, c -> ((r / 2) + (c / 3)) % 2 == 0 },
        { r, c -> ((r * c) % 2) + ((r * c) % 3) == 0 },
        { r, c -> (((r * c) % 2) + ((r * c) % 3)) % 2 == 0 },
        { r, c -> (((r + c) % 2) + ((r * c) % 3)) % 2 == 0 },
    )

    private fun skeleton(version: Int): Array<IntArray> {
        val size = version * 4 + 17
        val matrix = emptyMatrix(size)
        placeFinder(matrix, 0, 0)
        placeFinder(matrix, 0, size - 7)
        placeFinder(matrix, size - 7, 0)
        placeAlignment(matrix, version)
        for (i in 8 until size - 8) {
            val bit = if (i % 2 == 0) 1 else 0
            matrix[6][i] = bit
            matrix[i][6] = bit
        }
        // Reserve the places of format and version info so the data avoids them.
        for (i in 0 until 9) {
            if (matrix[8][i] == EMPTY) matrix[8][i] = 0
            if (matrix[i][8] == EMPTY) matrix[i][8] = 0
        }
        for (i in 0 until 8) {
            if (matrix[8][size - 1 - i] == EMPTY) matrix[8][size - 1 - i] = 0
            if (matrix[size - 1 - i][8] == EMPTY) matrix[size - 1 - i][8] = 0
        }
        matrix[size - 8][8] = 1
        if (version >= 7) {
            for (i in 0 until 18) {
                val row = i / 3
                val col = i % 3
                matrix[size - 11 + col][row] = 0
                matrix[row][size - 11 + col] = 0
            }
        }
        return matrix
    }

    private class Placed(val matrix: Array<IntArray>, val reserved: Array<BooleanArray>)

    /** Lay the data bits in a zigzag from bottom right upwards. */
    private fun placeData(skeleton: Array<IntArray>, codewords: IntArray, remainderBits: Int): Placed {
        val size = skeleton.size
        val reserved = Array(size) { r -> BooleanArray(size) { c -> skeleton[r][c] != EMPTY } }
        val matrix = Array(size) { r -> skeleton[r].copyOf() }

        val bits = ArrayList<Int>(codewords.size * 8 + remainderBits)
        for (word in codewords) for (i in 7 downTo 0) bits.add((word shr i) and 1)
        repeat(remainderBits) { bits.add(0) }

        var cursor = 0
        var upwards = true
        var column = size - 1
        while (column > 0) {
            if (column == 6) column -= 1 // the vertical timing line is skipped
            for (step in 0 until size) {
                val row = if (upwards) size - 1 - step else step
                for (offset in 0..1) {
                    val x = column - offset
                    if (reserved[row][x]) continue
                    matrix[row][x] = if (cursor < bits.size) bits[cursor] else 0
                    cursor += 1
                }
            }
            upwards = !upwards
            column -= 2
        }
        return Placed(matrix, reserved)
    }

    private fun applyMask(placed: Placed, mask: Int): Array<IntArray> {
        val fn = MASKS[mask]
        return Array(placed.matrix.size) { r ->
            IntArray(placed.matrix.size) { c ->
                val value = placed.matrix[r][c]
                if (placed.reserved[r][c]) value else if (fn(r, c)) value xor 1 else value
            }
        }
    }

    /** The four penalty rules of the standard - the fewer points, the easier to read. */
    private fun penalty(matrix: Array<IntArray>): Int {
        val n = matrix.size
        var sum = 0

        fun runs(get: (Int, Int) -> Int) {
            for (a in 0 until n) {
                var running = 1
                for (b in 1 until n) {
                    if (get(a, b) == get(a, b - 1)) {
                        running += 1
                    } else {
                        if (running >= 5) sum += 3 + (running - 5)
                        running = 1
                    }
                }
                if (running >= 5) sum += 3 + (running - 5)
            }
        }
        runs { a, b -> matrix[a][b] }
        runs { a, b -> matrix[b][a] }

        for (r in 0 until n - 1) {
            for (c in 0 until n - 1) {
                val value = matrix[r][c]
                if (value == matrix[r][c + 1] && value == matrix[r + 1][c] && value == matrix[r + 1][c + 1]) {
                    sum += 3
                }
            }
        }

        val pattern1 = intArrayOf(1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0)
        val pattern2 = intArrayOf(0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1)
        fun matches(get: (Int, Int) -> Int, a: Int, b: Int, pattern: IntArray): Boolean {
            for (i in 0 until 11) if (get(a, b + i) != pattern[i]) return false
            return true
        }
        for (a in 0 until n) {
            var b = 0
            while (b + 11 <= n) {
                if (matches({ y, x -> matrix[y][x] }, a, b, pattern1) ||
                    matches({ y, x -> matrix[y][x] }, a, b, pattern2)
                ) sum += 40
                if (matches({ y, x -> matrix[x][y] }, a, b, pattern1) ||
                    matches({ y, x -> matrix[x][y] }, a, b, pattern2)
                ) sum += 40
                b += 1
            }
        }

        var dark = 0
        for (row in matrix) for (value in row) dark += value
        val share = (dark * 100.0) / (n * n)
        sum += (floor(abs(share - 50) / 5)).toInt() * 10
        return sum
    }

    /**
     * The finished code as a matrix of 0 and 1.
     * [mask] forces one mask and exists only for the cross-check in the unit test;
     * in normal use the best mask is searched for.
     */
    fun matrix(text: String, mask: Int? = null): Array<IntArray> {
        val bytes = text.toByteArray(Charsets.UTF_8).map { it.toInt() and 0xff }.toIntArray()
        val version = fittingVersion(bytes.size)
        require(version != 0) { "text too long for a QR code up to version 10" }
        val codewords = interleave(buildCodewords(bytes, version), version)
        val placed = placeData(skeleton(version), codewords, REMAINDER_BITS[version])

        fun build(number: Int): Array<IntArray> {
            val attempt = applyMask(placed, number)
            placeFormat(attempt, number)
            placeVersion(attempt, version)
            return attempt
        }

        if (mask != null) return build(mask)

        var best: Array<IntArray>? = null
        var bestPenalty = Int.MAX_VALUE
        for (number in 0 until 8) {
            val attempt = build(number)
            val points = penalty(attempt)
            if (points < bestPenalty) {
                bestPenalty = points
                best = attempt
            }
        }
        return best!!
    }
}
