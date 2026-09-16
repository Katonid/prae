#!/usr/bin/env python3
"""Bildschirmfotos auf das Maß bringen, das App Store Connect annimmt.

Ein Bildschirmfoto vom Gerät hat die Auflösung DIESES Geräts — ein iPhone 16
Pro liefert 1206 × 2622. App Store Connect nimmt aber nur eine kurze Liste
fester Maße an und weist alles andere ab, ohne zu sagen, was fehlt.

Dieses Skript rechnet die Bilder auf ein angenommenes Maß um:

    python3 scripts/screenshots-aufbereiten.py --ziel iphone-6.9 bild1.png …
    python3 scripts/screenshots-aufbereiten.py --ziel ipad-13 bild1.png …

Drei Entscheidungen stecken darin, und jede hat einen Grund:

1. **Das Seitenverhältnis bleibt.** Skaliert wird auf die größte Fassung, die
   noch hineinpasst; der Rest wird durch WIEDERHOLEN DER RANDSPALTE gefüllt,
   nicht mit einer Farbe. Bei 1206 × 2622 → 1290 × 2796 sind das zwei Pixel
   links und rechts: Mit einer festen Farbe stünde auf dem orangefarbenen
   Alarmbildschirm ein dünner schwarzer Strich am Rand, mit der Wiederholung
   sieht man gar nichts. Ein Bild einfach auf das Zielmaß zu zerren wäre
   bequemer und ginge hier um 0,3 % daneben — unsichtbar, aber gelogen.

2. **Ohne Alphakanal.** App Store Connect weist Bildschirmfotos mit
   Transparenz ab. Geschrieben wird deshalb immer Farbtyp 2 (RGB).

3. **Reines Python.** Keine fremde Bibliothek, wie bei den Tönen und beim
   App-Symbol: Das Skript soll in fünf Jahren noch laufen, ohne dass jemand
   erst eine Installation reparieren muss.

Gerechnet wird bilinear. Für die kleine Vergrößerung hier ist das richtig —
nächster Nachbar ließe die Schrift ausfransen.
"""

import argparse
import pathlib
import struct
import sys
import zlib

# Die Maße, die App Store Connect annimmt. Bewusst kurz gehalten: Was hier
# steht, ist geprüft; alles andere gehört nachgeschlagen und dann ergänzt.
ZIELE = {
    "iphone-6.9": (1290, 2796),
    "iphone-6.5": (1242, 2688),
    "ipad-13": (2048, 2732),
}


def png_lesen(pfad):
    """Gibt (breite, hoehe, bytearray mit RGB je 8 Bit) zurück."""
    roh = pfad.read_bytes()
    if roh[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{pfad.name}: keine PNG-Datei")

    breite = hoehe = bittiefe = farbtyp = None
    daten = bytearray()
    pos = 8
    while pos < len(roh):
        laenge = struct.unpack(">I", roh[pos:pos + 4])[0]
        art = roh[pos + 4:pos + 8]
        inhalt = roh[pos + 8:pos + 8 + laenge]
        pos += 12 + laenge
        if art == b"IHDR":
            breite, hoehe, bittiefe, farbtyp, _, _, verschraenkt = struct.unpack(
                ">IIBBBBB", inhalt)
            if verschraenkt:
                raise ValueError(f"{pfad.name}: verschränktes PNG (Adam7) — "
                                 "kommt von Geräten nicht vor und ist hier "
                                 "nicht eingebaut.")
            if bittiefe not in (8, 16):
                raise ValueError(f"{pfad.name}: Bittiefe {bittiefe} nicht eingebaut.")
            if farbtyp not in (0, 2, 4, 6):
                raise ValueError(f"{pfad.name}: Farbtyp {farbtyp} (Palette?) "
                                 "nicht eingebaut.")
        elif art == b"IDAT":
            daten += inhalt
        elif art == b"IEND":
            break

    kanaele = {0: 1, 2: 3, 4: 2, 6: 4}[farbtyp]
    bpp = kanaele * (bittiefe // 8)
    zeilenbreite = breite * bpp
    entpackt = zlib.decompress(bytes(daten))

    # Entfiltern, Zeile für Zeile. Das ist die langsame Stelle und lässt sich
    # ohne fremde Bibliothek nicht umgehen; ein paar Sekunden je Bild.
    flach = bytearray(zeilenbreite * hoehe)
    vorher = bytearray(zeilenbreite)
    q = 0
    for y in range(hoehe):
        filt = entpackt[q]
        q += 1
        zeile = bytearray(entpackt[q:q + zeilenbreite])
        q += zeilenbreite
        if filt == 1:
            for i in range(bpp, zeilenbreite):
                zeile[i] = (zeile[i] + zeile[i - bpp]) & 0xFF
        elif filt == 2:
            for i in range(zeilenbreite):
                zeile[i] = (zeile[i] + vorher[i]) & 0xFF
        elif filt == 3:
            for i in range(zeilenbreite):
                links = zeile[i - bpp] if i >= bpp else 0
                zeile[i] = (zeile[i] + ((links + vorher[i]) >> 1)) & 0xFF
        elif filt == 4:
            for i in range(zeilenbreite):
                a = zeile[i - bpp] if i >= bpp else 0
                b = vorher[i]
                c = vorher[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                if pa <= pb and pa <= pc:
                    vor = a
                elif pb <= pc:
                    vor = b
                else:
                    vor = c
                zeile[i] = (zeile[i] + vor) & 0xFF
        elif filt != 0:
            raise ValueError(f"{pfad.name}: unbekannter Filter {filt}")
        flach[y * zeilenbreite:(y + 1) * zeilenbreite] = zeile
        vorher = zeile

    # Auf RGB mit 8 Bit bringen. Ein Alphakanal wird verworfen, nicht
    # gemischt: Ein Bildschirmfoto vom Gerät ist deckend, und ein Kanal, der
    # überall 255 ist, hat keinen Inhalt zu verlieren.
    rgb = bytearray(breite * hoehe * 3)
    schritt = bittiefe // 8
    for i in range(breite * hoehe):
        q = i * bpp
        if kanaele >= 3:
            rgb[i * 3] = flach[q]
            rgb[i * 3 + 1] = flach[q + schritt]
            rgb[i * 3 + 2] = flach[q + 2 * schritt]
        else:
            g = flach[q]
            rgb[i * 3] = rgb[i * 3 + 1] = rgb[i * 3 + 2] = g
    return breite, hoehe, rgb


def bilinear(quelle, qb, qh, zb, zh):
    """Streckt RGB-Bytes auf zb × zh, bilinear, in zwei Durchgängen."""
    # Waagerecht.
    xkarte = []
    fx = qb / zb
    for x in range(zb):
        s = (x + 0.5) * fx - 0.5
        s = 0.0 if s < 0 else s
        x0 = int(s)
        x1 = min(x0 + 1, qb - 1)
        w = s - x0
        xkarte.append((x0 * 3, x1 * 3, w))

    zwischen = bytearray(zb * qh * 3)
    for y in range(qh):
        zq = y * qb * 3
        zz = y * zb * 3
        for x, (a, b, w) in enumerate(xkarte):
            o = zz + x * 3
            if w == 0.0:
                zwischen[o:o + 3] = quelle[zq + a:zq + a + 3]
            else:
                for k in range(3):
                    p = quelle[zq + a + k]
                    zwischen[o + k] = int(p + (quelle[zq + b + k] - p) * w + 0.5)

    # Senkrecht.
    ziel = bytearray(zb * zh * 3)
    fy = qh / zh
    breite3 = zb * 3
    for y in range(zh):
        s = (y + 0.5) * fy - 0.5
        s = 0.0 if s < 0 else s
        y0 = int(s)
        y1 = min(y0 + 1, qh - 1)
        w = s - y0
        a = y0 * breite3
        b = y1 * breite3
        o = y * breite3
        if w == 0.0:
            ziel[o:o + breite3] = zwischen[a:a + breite3]
        else:
            oben = zwischen[a:a + breite3]
            unten = zwischen[b:b + breite3]
            ziel[o:o + breite3] = bytes(
                int(p + (u - p) * w + 0.5) for p, u in zip(oben, unten))
    return ziel


def randfuellung(bild, bb, bh, zb, zh):
    """Setzt das Bild mittig in zb × zh und füllt den Rest durch Wiederholen
    der Randzeile beziehungsweise -spalte."""
    links = (zb - bb) // 2
    oben = (zh - bh) // 2
    ziel = bytearray(zb * zh * 3)
    for y in range(zh):
        qy = min(max(y - oben, 0), bh - 1)
        zeile = bytearray(zb * 3)
        qz = qy * bb * 3
        # Die Mitte am Stück, die Ränder als Wiederholung.
        zeile[links * 3:(links + bb) * 3] = bild[qz:qz + bb * 3]
        for x in range(links):
            zeile[x * 3:x * 3 + 3] = bild[qz:qz + 3]
        for x in range(links + bb, zb):
            zeile[x * 3:x * 3 + 3] = bild[qz + (bb - 1) * 3:qz + bb * 3]
        ziel[y * zb * 3:(y + 1) * zb * 3] = zeile
    return ziel


def png_schreiben(pfad, breite, hoehe, rgb):
    roh = bytearray()
    for y in range(hoehe):
        roh.append(0)  # Filter „keiner" — die Datei wird größer, der Code klar.
        roh += rgb[y * breite * 3:(y + 1) * breite * 3]

    def block(art, inhalt):
        return (struct.pack(">I", len(inhalt)) + art + inhalt
                + struct.pack(">I", zlib.crc32(art + inhalt) & 0xFFFFFFFF))

    datei = bytearray(b"\x89PNG\r\n\x1a\n")
    datei += block(b"IHDR", struct.pack(">IIBBBBB", breite, hoehe, 8, 2, 0, 0, 0))
    datei += block(b"IDAT", zlib.compress(bytes(roh), 9))
    datei += block(b"IEND", b"")
    pfad.write_bytes(bytes(datei))


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--ziel", choices=sorted(ZIELE), default="iphone-6.9",
                   help="Zielmaß (Vorgabe: iphone-6.9, also 1290 × 2796)")
    p.add_argument("--ordner", default="screenshots",
                   help="Ausgabeordner (Vorgabe: screenshots)")
    p.add_argument("bilder", nargs="+", help="PNG-Dateien vom Gerät")
    args = p.parse_args()

    zb, zh = ZIELE[args.ziel]
    ordner = pathlib.Path(args.ordner)
    ordner.mkdir(parents=True, exist_ok=True)

    for nummer, name in enumerate(args.bilder, start=1):
        quelle = pathlib.Path(name)
        qb, qh, rgb = png_lesen(quelle)

        faktor = min(zb / qb, zh / qh)
        bb = max(1, min(zb, round(qb * faktor)))
        bh = max(1, min(zh, round(qh * faktor)))
        skaliert = bilinear(rgb, qb, qh, bb, bh)
        fertig = randfuellung(skaliert, bb, bh, zb, zh)

        ziel = ordner / f"{args.ziel}-{nummer:02d}.png"
        png_schreiben(ziel, zb, zh, fertig)
        rand = (zb - bb, zh - bh)
        print(f"{quelle.name}: {qb}×{qh} → {zb}×{zh} "
              f"(Bild {bb}×{bh}, Rand {rand[0]}×{rand[1]} px) → {ziel}")


if __name__ == "__main__":
    sys.exit(main())
