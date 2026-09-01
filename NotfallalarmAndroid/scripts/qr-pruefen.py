#!/usr/bin/env python3
"""Cross-check the Kotlin QR encoder against independent implementations.

Run the unit test first, it writes the matrices:
    ./gradlew :app:testDebugUnitTest
    python3 scripts/qr-pruefen.py

Needs segno (module comparison) and opencv-python (actually reading the code back).
Both are check-only tools and are not part of the app.
"""

from __future__ import annotations

import os
import sys

MATRIX_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "app", "build", "qr-matrices.txt")


def load(path: str):
    """Yields (text, mask, matrix) triples."""
    with open(path, encoding="utf-8") as handle:
        lines = [line.rstrip("\n") for line in handle]
    index = 0
    while index < len(lines):
        if not lines[index]:
            index += 1
            continue
        text, mask, size = lines[index].split("\t")
        mask, size = int(mask), int(size)
        matrix = [[int(c) for c in lines[index + 1 + row]] for row in range(size)]
        yield text, mask, matrix
        index += 1 + size


# Which modules the standard fixes for a given version, regardless of the data.
# The data area and the format information are deliberately left out: the standard
# leaves the fill bytes after the terminator open, segno fills differently, and from
# different fill bytes follows a different best mask and therefore a different format
# information. That the format information is right is proven by the read-back below -
# a reader that cannot recover the mask from it reads nothing at all.
def function_pattern_cells(size: int):
    version = (size - 17) // 4
    cells = set()

    def block(top: int, left: int, height: int, width: int) -> None:
        for r in range(top, top + height):
            for c in range(left, left + width):
                if 0 <= r < size and 0 <= c < size:
                    cells.add((r, c))

    # Finder patterns including their separators.
    block(0, 0, 8, 8)
    block(0, size - 8, 8, 8)
    block(size - 8, 0, 8, 8)
    # Timing lines.
    for i in range(8, size - 8):
        cells.add((6, i))
        cells.add((i, 6))
    # Alignment patterns.
    centres = {
        1: [], 2: [6, 18], 3: [6, 22], 4: [6, 26], 5: [6, 30],
        6: [6, 34], 7: [6, 22, 38], 8: [6, 24, 42], 9: [6, 26, 46], 10: [6, 28, 50],
    }[version]
    for row in centres:
        for col in centres:
            if (row, col) in {(6, 6), (6, centres[-1] if centres else 6), (centres[-1] if centres else 6, 6)}:
                continue
            block(row - 2, col - 2, 5, 5)
    # The always dark module.
    cells.add((size - 8, 8))

    # Strip the format information, which shares rows and columns with the finders.
    for i in range(9):
        cells.discard((i, 8))
        cells.discard((8, i))
    for i in range(8):
        cells.discard((8, size - 1 - i))
        cells.discard((size - 1 - i, 8))
    cells.add((size - 8, 8))
    return cells


def compare_with_segno(cases) -> int:
    import segno

    failures = 0
    for text, mask, matrix in cases:
        # encoding="utf-8" matters: without it segno uses ISO-8859-1 for byte mode and
        # needs one byte for an umlaut where this implementation always writes two.
        code = segno.make(
            text, error="m", mode="byte", encoding="utf-8", boost_error=False, micro=False
        )
        reference = [[1 if value else 0 for value in row] for row in code.matrix]
        if len(reference) != len(matrix):
            print(f"FEHLER {text!r} Maske {mask}: Groesse {len(matrix)} statt {len(reference)}")
            failures += 1
            continue
        wrong = [
            (r, c)
            for (r, c) in function_pattern_cells(len(matrix))
            if matrix[r][c] != reference[r][c]
        ]
        if wrong:
            print(f"FEHLER {text!r} Maske {mask}: {len(wrong)} feste Module falsch, erstes bei {sorted(wrong)[0]}")
            failures += 1
    return failures


def read_back(cases) -> int:
    """The decisive test: does a camera decoder get the text back out?"""
    import cv2
    import numpy as np

    failures = 0
    detector = cv2.QRCodeDetector()
    seen = set()
    for text, mask, matrix in cases:
        if (text, mask) in seen:
            continue
        seen.add((text, mask))
        size = len(matrix)
        quiet = 4
        scale = 8
        total = (size + 2 * quiet) * scale
        image = np.full((total, total), 255, dtype=np.uint8)
        for r in range(size):
            for c in range(size):
                if matrix[r][c]:
                    y = (r + quiet) * scale
                    x = (c + quiet) * scale
                    image[y:y + scale, x:x + scale] = 0
        decoded, _, _ = detector.detectAndDecode(image)
        if decoded != text:
            print(f"FEHLER {text!r} Maske {mask}: zurückgelesen {decoded!r}")
            failures += 1
    return failures


def main() -> int:
    path = os.path.normpath(MATRIX_FILE)
    if not os.path.exists(path):
        print(f"{path} fehlt - erst ./gradlew :app:testDebugUnitTest laufen lassen.")
        return 2
    cases = list(load(path))
    print(f"{len(cases)} Codes geprüft aus {path}")

    failures = 0
    try:
        failures += compare_with_segno(cases)
        print("segno-Vergleich der festen Muster: fertig")
    except ImportError:
        print("segno fehlt - Modulvergleich übersprungen (pip install segno)")
    try:
        failures += read_back(cases)
        print("Rücklesen mit OpenCV: fertig")
    except ImportError:
        print("opencv-python fehlt - Rücklesen übersprungen (pip install opencv-python-headless)")

    if failures:
        print(f"\n{failures} Fehler.")
        return 1
    print("\nAlles in Ordnung.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
