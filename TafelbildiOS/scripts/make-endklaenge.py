#!/usr/bin/env python3
"""Erzeugt die Endklänge des Timers.

    python3 -m pip install numpy
    python3 TafelbildiOS/scripts/make-endklaenge.py

Ergebnis: ``TafelbildiOS/Tafelbild/Klaenge/endklang-*.wav``.
Nicht von Hand bearbeiten.

Warum hier gerechnet und nicht geladen wird
-------------------------------------------

Bei den Ziehklängen steht in ``fetch-sounds.py`` das Gegenteil: Synthese
klang synthetisch, echte Aufnahmen mussten her. Das galt für
Kartenmischen, Trommelwirbel und Ratsche — Vorgänge aus hundert kleinen
Zufälligkeiten, die sich nicht nachrechnen lassen.

Ein **angeschlagenes Metall** ist das Gegenteil davon. Glocke, Gong,
Klangschale, Triangel und Glockenspiel sind schwingende Körper, und ihr
Klang ist genau das, was die Physik dazu sagt: eine Summe exponentiell
abklingender Teiltöne auf den Eigenfrequenzen des Körpers. Die
Eigenfrequenzen einer Glocke sind seit Jahrhunderten vermessen (Hum,
Prime, Terz, Quinte, Nominal …), die eines frei schwingenden Stabes
stehen in jeder Akustik-Formelsammlung. Wer diese Teiltöne mit den
richtigen Abklingzeiten addiert, bekommt keinen Ersatz für eine Aufnahme,
sondern denselben Vorgang.

Der Vorteil: keine fremden Dateien, keine Lizenzfragen, keine
Netzverbindung beim Bauen — und die Klänge lassen sich auf die Sekunde
genau so lang machen, wie ein Timer-Ende sie braucht.

Aufbereitung, für jede Datei gleich
-----------------------------------

* Mono, 44,1 kHz, 16 Bit — wie die Ziehklänge.
* Anschlagsgeräusch: ein kurzer, gefilterter Rauschstoß. Ohne ihn klingt
  jeder Metallklang wie aus dem Nichts eingeblendet; der Anschlag selbst
  ist Reibung, kein Ton.
* Einheitliche **Lautheit**, nicht einheitlicher Spitzenwert: gemessen
  wird der lauteste Abschnitt von 300 ms. Der Spitzenwert sagt nichts
  darüber, wie laut etwas ankommt — nachzulesen in ``fetch-sounds.py``,
  wo genau das schiefging.
* Winzige Ein- und Ausblendung gegen Knacken an den Rändern.
"""

from __future__ import annotations

import os
import wave

import numpy as np

RATE = 44_100
ZIEL = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    "..", "Tafelbild", "Klaenge")

# Lautheit, gemessen im lautesten 300-ms-Fenster. Etwas kräftiger als die
# Ziehklänge (−14 dBFS): Ein Signal am Ende soll durch eine Klasse kommen.
LAUTHEIT_DBFS = -13.0
FENSTER = 0.300
SPITZE_MAX = 0.97


def zeit(dauer: float) -> np.ndarray:
    return np.arange(int(round(dauer * RATE))) / RATE


def teilton(t: np.ndarray, frequenz: float, abkling: float,
            staerke: float = 1.0, phase: float = 0.0) -> np.ndarray:
    """Ein exponentiell abklingender Teilton.

    ``abkling`` ist die Zeit in Sekunden, nach der die Amplitude auf ein
    Sechzigstel gefallen ist (T60) — das übliche Maß für Nachhall.
    """
    huelle = np.exp(-6.9078 * t / max(abkling, 1e-4))
    return staerke * huelle * np.sin(2 * np.pi * frequenz * t + phase)


def anschlag(dauer: float, hoehe: float = 4000.0, staerke: float = 0.18) -> np.ndarray:
    """Das Geräusch des Schlags selbst — kurzes, gefiltertes Rauschen.

    Ein einpoliger Tiefpass genügt; es geht nicht um eine Klangfarbe,
    sondern darum, dass der Ton einen Anfang hat.
    """
    t = zeit(dauer)
    rauschen = np.random.default_rng(20260829).standard_normal(len(t))
    alpha = 1.0 - np.exp(-2 * np.pi * hoehe / RATE)
    gefiltert = np.zeros_like(rauschen)
    wert = 0.0
    for i, probe in enumerate(rauschen):
        wert += alpha * (probe - wert)
        gefiltert[i] = wert
    huelle = np.exp(-t / max(dauer / 6, 1e-4))
    return staerke * gefiltert * huelle


def lege(laenge: float, teile: list[tuple[float, float, float]],
         schlag: tuple[float, float, float] | None = (0.03, 4000.0, 0.18),
         versatz: float = 0.0) -> np.ndarray:
    """Ein angeschlagener Körper: Anschlag plus seine Eigenschwingungen."""
    t = zeit(laenge)
    klang = np.zeros_like(t)
    phasen = np.random.default_rng(4711).uniform(0, 2 * np.pi, len(teile))
    for (frequenz, abkling, staerke), phase in zip(teile, phasen):
        klang += teilton(t, frequenz, abkling, staerke, phase)
    if schlag is not None:
        dauer, hoehe, staerke = schlag
        stoss = anschlag(dauer, hoehe, staerke)
        klang[:len(stoss)] += stoss
    if versatz > 0:
        klang = np.concatenate([np.zeros(int(round(versatz * RATE))), klang])
    return klang


def mische(*spuren: np.ndarray) -> np.ndarray:
    laenge = max(len(spur) for spur in spuren)
    summe = np.zeros(laenge)
    for spur in spuren:
        summe[:len(spur)] += spur
    return summe


# ---------------------------------------------------------------------------
# Die einzelnen Klänge
# ---------------------------------------------------------------------------

def glocke() -> np.ndarray:
    """Handglocke, wie sie auf dem Lehrerpult steht.

    Die Teiltöne einer Glocke stehen in einem festen, unharmonischen
    Verhältnis zum Schlagton: Hum (0,5), Prime (1), Terz (1,2), Quinte
    (1,5), Nominal (2) und darüber. Tiefe Teiltöne klingen am längsten
    nach — deshalb wird eine Glocke im Ausklang immer dunkler.
    """
    grund = 587.0
    teile = [
        (grund * 0.50, 3.4, 0.42),
        (grund * 1.00, 2.6, 0.60),
        (grund * 1.19, 1.9, 0.44),
        (grund * 1.50, 1.5, 0.36),
        (grund * 2.00, 1.2, 0.50),
        (grund * 2.55, 0.8, 0.22),
        (grund * 3.01, 0.6, 0.17),
        (grund * 4.14, 0.4, 0.11),
        (grund * 5.43, 0.3, 0.07),
    ]
    # Zweimal, wie eine Glocke geschwungen wird.
    return mische(lege(3.6, teile),
                  lege(3.0, teile, versatz=0.62) * 0.85)


def gong() -> np.ndarray:
    """Tiefer Gong — dunkel, lang, zum Zurruhekommen.

    Eine Gong-Platte hat sehr viele dicht liegende Moden. Der Schlag regt
    zuerst die hohen an; sie fallen schnell ab, während die tiefen stehen
    bleiben. Genau das macht das typische „Aufblühen und Dunkelwerden“.
    """
    grund = 98.0
    teile = [
        (grund * 1.00, 6.0, 0.55),
        (grund * 1.52, 5.0, 0.34),
        (grund * 2.03, 4.2, 0.30),
        (grund * 2.74, 3.0, 0.24),
        (grund * 3.46, 2.2, 0.20),
        (grund * 4.31, 1.6, 0.16),
        (grund * 5.62, 1.1, 0.13),
        (grund * 7.18, 0.8, 0.10),
        (grund * 9.04, 0.5, 0.08),
        (grund * 11.7, 0.35, 0.06),
    ]
    return lege(5.0, teile, schlag=(0.06, 1800.0, 0.22))


def klangschale() -> np.ndarray:
    """Klangschale — ruhig, mit dem typischen Schweben.

    Eine Schale ist nie ganz rund. Dadurch spaltet sich jede Mode in zwei
    dicht benachbarte Frequenzen auf, und die beiden schweben gegeneinander
    — das langsame An- und Abschwellen, an dem man eine Schale erkennt.
    """
    grund = 311.0
    schwebung = 0.7
    teile: list[tuple[float, float, float]] = []
    for faktor, abkling, staerke in [(1.00, 7.0, 0.60),
                                     (2.72, 4.5, 0.30),
                                     (5.41, 2.6, 0.16),
                                     (8.90, 1.4, 0.09)]:
        teile.append((grund * faktor, abkling, staerke))
        teile.append((grund * faktor + schwebung, abkling, staerke))
    return lege(6.0, teile, schlag=(0.04, 2600.0, 0.12))


def triangel() -> np.ndarray:
    """Triangel — hell, klar, ohne erkennbare Tonhöhe.

    Ein gebogener Stab hat Moden, die zu keinem Grundton passen. Deshalb
    hört man keine Note, sondern ein Funkeln. Die Frequenzen stehen
    absichtlich krumm zueinander.
    """
    teile = [
        (2093.0, 3.2, 0.34),
        (2765.0, 2.9, 0.30),
        (3412.0, 2.6, 0.27),
        (4187.0, 2.2, 0.24),
        (5231.0, 1.8, 0.20),
        (6412.0, 1.4, 0.16),
        (7845.0, 1.0, 0.12),
        (9120.0, 0.7, 0.08),
    ]
    return mische(lege(3.4, teile, schlag=(0.02, 9000.0, 0.14)),
                  lege(2.6, teile, schlag=(0.02, 9000.0, 0.10), versatz=0.20) * 0.7,
                  lege(2.2, teile, schlag=(0.02, 9000.0, 0.08), versatz=0.38) * 0.5)


def glockenspiel() -> np.ndarray:
    """Drei Töne aufwärts — ein freundliches „fertig“.

    Ein frei schwingender Metallstab hat Teiltöne bei rund dem 2,76-, 5,4-
    und 8,9-fachen der Grundfrequenz. Gespielt werden c'''–e'''–g''',
    ein Durdreiklang.
    """
    stufen = [(1046.5, 0.00), (1318.5, 0.16), (1568.0, 0.32)]
    spuren = []
    for grund, versatz in stufen:
        teile = [
            (grund * 1.00, 1.9, 0.60),
            (grund * 2.76, 1.0, 0.22),
            (grund * 5.40, 0.55, 0.10),
            (grund * 8.93, 0.30, 0.05),
        ]
        spuren.append(lege(2.4, teile, schlag=(0.015, 7000.0, 0.09),
                           versatz=versatz))
    return mische(*spuren)


def wecker() -> np.ndarray:
    """Klingel — der Klöppel schlägt schnell hin und her.

    Kein durchgehender Ton, sondern viele einzelne Schläge auf dieselbe
    kleine Glocke: elf pro Sekunde, anderthalb Sekunden lang. So klingt
    ein mechanischer Wecker, und so hört man ihn auch bei Unruhe.
    """
    grund = 1046.0
    teile = [
        (grund * 1.00, 0.32, 0.55),
        (grund * 1.21, 0.26, 0.34),
        (grund * 1.51, 0.20, 0.26),
        (grund * 2.02, 0.16, 0.30),
        (grund * 2.67, 0.11, 0.16),
        (grund * 3.55, 0.08, 0.10),
    ]
    takt = 1.0 / 11.0
    spuren = []
    for nummer in range(17):
        # Kein Schlag gleicht dem vorigen: Der Klöppel trifft mal härter,
        # mal weicher. Streng gleiche Schläge klingen nach Maschine.
        staerke = 0.82 + 0.18 * ((nummer * 7) % 5) / 4.0
        spuren.append(lege(0.5, teile, schlag=(0.008, 6000.0, 0.10),
                           versatz=nummer * takt) * staerke)
    return mische(*spuren)


def piep() -> np.ndarray:
    """Drei kurze Töne — nüchtern, unaufdringlich, sofort verstanden.

    Reiner Ton mit weicher Hülle. Ein hart ein- und ausgeschalteter
    Sinus knackt an beiden Enden; die Kuppe verhindert das.
    """
    laenge, pause, frequenz = 0.13, 0.09, 880.0
    t = zeit(laenge)
    kuppe = np.sin(np.pi * np.linspace(0, 1, len(t))) ** 0.6
    ton = kuppe * (np.sin(2 * np.pi * frequenz * t)
                   + 0.22 * np.sin(4 * np.pi * frequenz * t))
    spuren = []
    for nummer in range(3):
        versatz = int(round(nummer * (laenge + pause) * RATE))
        spuren.append(np.concatenate([np.zeros(versatz), ton]))
    return mische(*spuren)


KLAENGE = {
    "glocke": glocke,
    "gong": gong,
    "klangschale": klangschale,
    "triangel": triangel,
    "glockenspiel": glockenspiel,
    "wecker": wecker,
    "piep": piep,
}


# ---------------------------------------------------------------------------
# Aufbereitung und Ausgabe
# ---------------------------------------------------------------------------

def lautheit(signal: np.ndarray) -> float:
    """Effektivwert des lautesten Fensters von 300 ms.

    Über die ganze Datei gemessen käme ein langer Gong viel zu leise
    heraus — sein Ausklang zieht den Mittelwert nach unten, obwohl der
    Anschlag laut ist.
    """
    breite = int(FENSTER * RATE)
    if len(signal) <= breite:
        return float(np.sqrt(np.mean(signal ** 2)))
    quadrate = signal ** 2
    summe = np.convolve(quadrate, np.ones(breite), mode="valid")
    return float(np.sqrt(summe.max() / breite))


def blenden(signal: np.ndarray, ein: float = 0.002, aus: float = 0.05) -> np.ndarray:
    n_ein, n_aus = int(ein * RATE), int(aus * RATE)
    if n_ein > 0:
        signal[:n_ein] *= np.linspace(0, 1, n_ein)
    if n_aus > 0:
        signal[-n_aus:] *= np.linspace(1, 0, n_aus)
    return signal


def schreibe(name: str, signal: np.ndarray) -> None:
    signal = blenden(np.asarray(signal, dtype=np.float64))

    ist = lautheit(signal)
    if ist > 0:
        signal *= (10 ** (LAUTHEIT_DBFS / 20)) / ist

    spitze = np.abs(signal).max()
    if spitze > SPITZE_MAX:
        signal *= SPITZE_MAX / spitze

    ganze = np.clip(np.round(signal * 32767), -32768, 32767).astype("<i2")
    pfad = os.path.join(ZIEL, f"endklang-{name}.wav")
    with wave.open(pfad, "wb") as datei:
        datei.setnchannels(1)
        datei.setsampwidth(2)
        datei.setframerate(RATE)
        datei.writeframes(ganze.tobytes())
    print(f"  {os.path.basename(pfad):28s} {len(signal) / RATE:5.2f} s  "
          f"Spitze {20 * np.log10(max(np.abs(signal).max(), 1e-9)):6.2f} dBFS")


def main() -> None:
    os.makedirs(ZIEL, exist_ok=True)
    print("Endklänge des Timers:")
    for name, bauen in KLAENGE.items():
        schreibe(name, bauen())


if __name__ == "__main__":
    main()
