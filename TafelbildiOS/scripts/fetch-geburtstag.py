#!/usr/bin/env python3
"""Holt die Geburtstagsklänge und bereitet sie für die App auf.

    python3 -m pip install numpy soundfile
    python3 TafelbildiOS/scripts/fetch-geburtstag.py

Ergebnis: ``TafelbildiOS/Tafelbild/Klaenge/geburtstag-*.wav``.
Nicht von Hand bearbeiten.

Warum echte Aufnahmen
---------------------

Ansage des Nutzers: „keine blechernen synthetischen Klänge, sondern
wirklich etwas, was einen Wow-Effekt erzeugt". Ein Blasorchester lässt
sich nicht nachrechnen — Blech lebt von Atem, Ansatz und Saal, und
gerade der Versuch klänge dann tatsächlich blechern. Also echte
Aufnahmen, wie schon bei den Ziehklängen (``fetch-sounds.py``).

Alle Quellen sind **gemeinfrei**: Aufnahmen von Musikkorps der
US-Streitkräfte sind als Werk der US-Regierung ohne Urheberrechtsschutz,
die übrigen stehen auf Wikimedia Commons als Public Domain.

Die Ausnahme ist das Geburtstagslied
------------------------------------

Die Melodie („Zum Geburtstag viel Glück", ursprünglich „Good Morning to
All" von Mildred Hill, gestorben 1916) ist in der EU seit 1987
gemeinfrei. Eine brauchbare freie **Aufnahme** davon gibt es aber
nicht. Sie wird deshalb gerechnet — auf einem **Glockenspiel**, und das
ist hier kein Notbehelf: Ein angeschlagener Metallstab IST eine Summe
abklingender Teiltöne, genau das, was ``make-endklaenge.py`` schon für
die Endklänge des Timers macht. Blech wäre synthetisch geworden,
Glockenspiel wird es nicht.

Aufbereitung
------------

* Mono, 44,1 kHz, 16 Bit — wie alle Klänge dieser App.
* Auf eine brauchbare Länge zugeschnitten: Ein Tusch im Unterricht darf
  ein paar Sekunden dauern, keine Minute.
* Stille am Anfang weg, weiche Blende an beiden Enden.
* Einheitliche **Lautheit**, gemessen im lautesten Fenster von 300 ms —
  nicht am Spitzenwert (siehe ``fetch-sounds.py``).

Wikimedia drosselt
------------------

Zu viele Anfragen hintereinander beantwortet Commons mit 429. Zwischen
den Abrufen wird deshalb gewartet, und bei 429 wird mit wachsendem
Abstand erneut versucht.
"""

from __future__ import annotations

import io
import os
import time
import urllib.error
import urllib.request
import wave

import numpy as np
import soundfile as sf

RATE = 44_100
ZIEL = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    "..", "Tafelbild", "Klaenge")

LAUTHEIT_DBFS = -13.0
FENSTER = 0.300
SPITZE_MAX = 0.97

KENNUNG = {"User-Agent": "TafelbildAssetTool/1.0 "
                         "(https://github.com/Katonid/prae; ansansimtob@gmail.com)"}

# Pause zwischen zwei Abrufen bei Wikimedia.
HOEFLICH = 6.0

QUELLEN = {
    "tusch": {
        "titel": "Tusch",
        "urls": ["https://upload.wikimedia.org/wikipedia/commons/6/65/"
                 "Ceremonial_Fanfare_-_Concert_Band_-_United_States_Air_Force_"
                 "Heritage_of_America_Band.mp3"],
        "urheber": "United States Air Force Heritage of America Band",
        "lizenz": "gemeinfrei (Werk der US-Regierung)",
        "nachweis": "https://commons.wikimedia.org/wiki/File:Ceremonial_Fanfare_"
                    "-_Concert_Band_-_United_States_Air_Force_Heritage_of_America_Band.mp3",
        # Der Anfang ist der Auftritt — mehr braucht eine Klasse nicht.
        "dauer": 7.0,
    },
    "applaus": {
        "titel": "Applaus und Hurra",
        # WAV und MP3, nicht Ogg: Die Applaus-Aufnahmen auf Commons liegen
        # zwar mit der Endung .ogg da, enthalten aber Opus — und das packt
        # libsndfile nicht aus. Mehrere Adressen sind trotzdem vorgesehen;
        # genommen wird die erste, die sich öffnen lässt.
        "urls": ["https://upload.wikimedia.org/wikipedia/commons/0/02/"
                 "619016_mrrap4food_clapping-then-leaving.mp3"],
        "urheber": "mrrap4food",
        "lizenz": "CC0 1.0",
        "nachweis": "https://commons.wikimedia.org/wiki/File:619016_mrrap4food_"
                    "clapping-then-leaving.mp3",
        "dauer": 5.0,
    },
}


# ---------------------------------------------------------------------------
# Holen
# ---------------------------------------------------------------------------

def hole(url: str, versuche: int = 4) -> bytes:
    wartezeit = HOEFLICH
    for nummer in range(versuche):
        try:
            anfrage = urllib.request.Request(url, headers=KENNUNG)
            with urllib.request.urlopen(anfrage, timeout=90) as antwort:
                return antwort.read()
        except urllib.error.HTTPError as fehler:
            if fehler.code != 429 or nummer == versuche - 1:
                raise
            print(f"    gedrosselt, warte {wartezeit:.0f} s …")
            time.sleep(wartezeit)
            wartezeit *= 2
    raise RuntimeError("nicht erreichbar")


def alsMono(roh: bytes) -> np.ndarray:
    daten, rate = sf.read(io.BytesIO(roh), always_2d=True, dtype="float64")
    mono = daten.mean(axis=1)
    if rate != RATE:
        # Lineare Neuabtastung genügt: Die Quellen liegen bei 44,1 oder
        # 48 kHz, der Unterschied ist ein Nachbarschaftsverhältnis.
        alt = np.arange(len(mono)) / rate
        neu = np.arange(0, alt[-1], 1 / RATE)
        mono = np.interp(neu, alt, mono)
    return mono


# ---------------------------------------------------------------------------
# Zuschneiden und aufbereiten
# ---------------------------------------------------------------------------

def ohneVorlauf(signal: np.ndarray, schwelle: float = 0.02) -> np.ndarray:
    """Stille am Anfang weg — ein Tusch soll sofort losgehen."""
    laut = np.flatnonzero(np.abs(signal) > schwelle)
    if len(laut) == 0:
        return signal
    beginn = max(0, laut[0] - int(0.02 * RATE))
    return signal[beginn:]


def lautheit(signal: np.ndarray) -> float:
    breite = int(FENSTER * RATE)
    if len(signal) <= breite:
        return float(np.sqrt(np.mean(signal ** 2)))
    summe = np.convolve(signal ** 2, np.ones(breite), mode="valid")
    return float(np.sqrt(summe.max() / breite))


def blenden(signal: np.ndarray, ein: float = 0.005, aus: float = 0.25) -> np.ndarray:
    n_ein, n_aus = int(ein * RATE), min(int(aus * RATE), len(signal) // 3)
    if n_ein > 0:
        signal[:n_ein] *= np.linspace(0, 1, n_ein)
    if n_aus > 0:
        signal[-n_aus:] *= np.linspace(1, 0, n_aus)
    return signal


def schreibe(name: str, signal: np.ndarray) -> None:
    signal = blenden(np.asarray(signal, dtype=np.float64).copy())

    ist = lautheit(signal)
    if ist > 0:
        signal *= (10 ** (LAUTHEIT_DBFS / 20)) / ist
    spitze = np.abs(signal).max()
    if spitze > SPITZE_MAX:
        signal *= SPITZE_MAX / spitze

    ganze = np.clip(np.round(signal * 32767), -32768, 32767).astype("<i2")
    pfad = os.path.join(ZIEL, f"geburtstag-{name}.wav")
    with wave.open(pfad, "wb") as datei:
        datei.setnchannels(1)
        datei.setsampwidth(2)
        datei.setframerate(RATE)
        datei.writeframes(ganze.tobytes())
    print(f"  {os.path.basename(pfad):30s} {len(signal) / RATE:5.2f} s  "
          f"Spitze {20 * np.log10(max(np.abs(signal).max(), 1e-9)):6.2f} dBFS")


# ---------------------------------------------------------------------------
# Das Geburtstagslied — gerechnet, auf einem Glockenspiel
# ---------------------------------------------------------------------------

def aWichtung(frequenz: float) -> float:
    """Wie laut das Ohr eine Frequenz empfindet, in dB (A-Bewertung).

    Bei 1 kHz ist das Gehör rund 10 dB empfindlicher als bei 350 Hz.
    Deshalb sagt der gemessene Pegel eines Obertons nichts darüber, wie
    laut er ANKOMMT — genau daran ist die erste Fassung dieses Liedes
    gescheitert: Der Grundton lag 14 dB über dem Oberton und war trotzdem
    kaum durchzuhören.
    """
    f2 = frequenz ** 2
    oben = (12194.0 ** 2) * f2 ** 2
    unten = ((f2 + 20.6 ** 2)
             * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2))
             * (f2 + 12194.0 ** 2))
    return 20 * np.log10(oben / unten) + 2.0


def glockenspielton(frequenz: float, dauer: float, staerke: float = 1.0) -> np.ndarray:
    """Ein angeschlagenes Metall — mit HARMONISCHEN Teiltönen.

    Die erste Fassung nahm die Teiltöne eines frei schwingenden Stabes
    (2,76 / 5,40 / 8,93 mal die Grundfrequenz). Physikalisch richtig für
    ein Glockenspiel — und genau deshalb falsch für ein Lied: 2,76 ist
    weder Oktave noch Quinte, sondern liegt dazwischen. Das Ohr sucht
    sich daraus eine Tonhöhe, die nicht die gespielte ist, und die
    Tonart wird unklar (vom Nutzer gemeldet).

    Jetzt liegen die Teiltöne auf Oktave, Duodezime und Doppeloktave —
    ganzzahlige Vielfache. Die stützen die Tonhöhe, statt gegen sie zu
    arbeiten. Das Ergebnis klingt nach Celesta oder Spieldose statt nach
    Glockenspiel; für ein Geburtstagslied ist das kein Verlust.

    Die Anteile werden zusätzlich nach dem **Gehör** gedämpft (siehe
    `aWichtung`): Ein Oberton bei 1 kHz muss leiser angesetzt werden als
    ein Grundton bei 350 Hz, damit beide gleich laut ankommen.
    """
    t = np.arange(int(dauer * RATE)) / RATE
    klang = np.zeros_like(t)
    grundgehoer = aWichtung(frequenz)
    for faktor, abkling, anteil in [(1.0, 2.4, 1.00),
                                    (2.0, 1.3, 0.16),
                                    (3.0, 0.7, 0.05),
                                    (4.0, 0.4, 0.02)]:
        teilfrequenz = frequenz * faktor
        # Ausgleich: Was das Ohr lauter hört, wird leiser angesetzt.
        ausgleich = 10 ** ((grundgehoer - aWichtung(teilfrequenz)) / 20)
        huelle = np.exp(-6.9078 * t / abkling)
        klang += anteil * min(1.0, ausgleich) * huelle * np.sin(2 * np.pi * teilfrequenz * t)

    # Der Anschlag: ein sehr kurzer Stoß mit etwas Unharmonischem darin.
    # Er gibt dem Ton seinen Beginn, ist aber nach 60 ms vorbei und kann
    # der Tonhöhe deshalb nichts mehr anhaben.
    n = int(0.06 * RATE)
    abfall = np.exp(-np.arange(n) / (0.012 * RATE))
    rauschen = np.random.default_rng(1877).standard_normal(n)
    klang[:n] += 0.035 * rauschen * abfall
    klang[:n] += 0.05 * abfall * np.sin(2 * np.pi * frequenz * 2.76 * t[:n])
    return staerke * klang


def lied() -> np.ndarray:
    """„Zum Geburtstag viel Glück" — zwei Zeilen, in F-Dur.

    Melodie gemeinfrei (Mildred Hill, † 1916). Notiert als
    (Halbtonabstand zum Grundton, Länge in Schlägen).
    """
    grundton = 349.23  # f'
    takt = 0.42        # Sekunden je Schlag

    # Zum Ge-burts-tag viel Glück / Zum Ge-burts-tag viel Glück
    noten = [(0, 0.75), (0, 0.25), (2, 1), (0, 1), (5, 1), (4, 2),
             (0, 0.75), (0, 0.25), (2, 1), (0, 1), (7, 1), (5, 2),
             # Zum Ge-burts-tag lie-be(r) …
             (0, 0.75), (0, 0.25), (12, 1), (9, 1), (5, 1), (4, 1), (2, 2),
             # Zum Ge-burts-tag viel Glück
             (10, 0.75), (10, 0.25), (9, 1), (5, 1), (7, 1), (5, 3)]

    gesamt = sum(laenge for _, laenge in noten) * takt + 2.4
    spur = np.zeros(int(gesamt * RATE))
    stelle = 0.0
    for halbton, laenge in noten:
        frequenz = grundton * (2 ** (halbton / 12))
        # Jeder Ton darf über die eigene Länge hinaus ausklingen — sonst
        # klingt es abgehackt statt nach einem Instrument.
        ton = glockenspielton(frequenz, laenge * takt + 1.8)
        beginn = int(stelle * RATE)
        ende = min(beginn + len(ton), len(spur))
        spur[beginn:ende] += ton[:ende - beginn]
        stelle += laenge * takt
    return spur


# ---------------------------------------------------------------------------

def main() -> None:
    os.makedirs(ZIEL, exist_ok=True)
    print("Geburtstagsklänge:")

    for name, quelle in QUELLEN.items():
        # Schon geholt? Dann nicht noch einmal — Commons drosselt, und die
        # Datei liegt ohnehin im Repo. Zum Erneuern die Datei löschen.
        if os.path.exists(os.path.join(ZIEL, f"geburtstag-{name}.wav")):
            print(f"  {quelle['titel']}: liegt schon vor")
            continue
        print(f"  {quelle['titel']} …")
        mono = None
        for url in quelle["urls"]:
            try:
                mono = ohneVorlauf(alsMono(hole(url)))
                break
            except Exception as fehler:
                print(f"    {url.rsplit('/', 1)[-1][:40]}: {fehler}")
                time.sleep(HOEFLICH)
        if mono is None:
            raise RuntimeError("Keine Quelle liess sich oeffnen: " + quelle["titel"])
        laenge = int(quelle["dauer"] * RATE)
        schreibe(name, mono[:laenge])
        time.sleep(HOEFLICH)

    print("  Geburtstagslied (gerechnet) …")
    schreibe("lied", lied())


if __name__ == "__main__":
    main()
