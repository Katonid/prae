#!/usr/bin/env python3
"""Holt die Ziehklänge und bereitet sie für die App auf.

Warum echte Aufnahmen und keine Synthese? Weil Synthese synthetisch klingt.
Die vorige Fassung rechnete die Klänge im Gerät aus — gefiltertes Rauschen,
nach dem Vorbild der Web-App. Das ergab nie ein glaubwürdiges Kartenmischen.

Alle Quellen stehen unter **CC0** (gemeinfrei, auch kommerziell nutzbar,
keine Namensnennung nötig). Nennung erfolgt trotzdem, in
`TafelbildiOS/Tafelbild/Klaenge/README.md`.

Aufbereitung, für jede Datei gleich:
  * auf einen Kanal mischen (Mono reicht, spart die Hälfte),
  * Stille am Anfang abschneiden,
  * ein Fenster nehmen, das am natürlichen Ende der Aufnahme aufhört —
    der Abschluss (letzter Trommelschlag, aufgestoßener Stapel) soll genau
    dann kommen, wenn der Name erscheint,
  * auf einen einheitlichen Pegel bringen,
  * winzige Ein- und Ausblendung, damit es an den Schnittkanten nicht knackt.

    python3 -m pip install soundfile
    python3 TafelbildiOS/scripts/fetch-sounds.py

Ergebnis: `TafelbildiOS/Tafelbild/Klaenge/*.wav`. Nicht von Hand bearbeiten.
"""

from __future__ import annotations

import io
import os
import urllib.request
import zipfile

import soundfile as sf

# Ein Zug dauert 1,72 s (18 Schritte, siehe ZiehLauf in Ziehklang.swift).
# Etwas Nachklang, damit der Abschluss ausschwingen darf.
ZIEHDAUER = 1.72
NACHKLANG = 0.35
RATE = 44_100

KENNUNG = {"User-Agent": "TafelbildAssetTool/1.0 "
                         "(https://github.com/Katonid/prae; ansansimtob@gmail.com)"}

QUELLEN = {
    "karten": {
        "titel": "Kartenmischen",
        "url": "https://kenney.nl/media/pages/assets/casino-audio/"
               "2472606a04-1721639069/kenney_casino-audio.zip",
        "im_archiv": "Audio/card-shuffle.ogg",
        "urheber": "Kenney Vleugels (kenney.nl), Paket „Casino Audio“",
        "lizenz": "CC0 1.0",
        "nachweis": "https://kenney.nl/assets/casino-audio",
    },
    "trommel": {
        "titel": "Trommelwirbel",
        "url": "https://upload.wikimedia.org/wikipedia/commons/c/c4/Drum_Roll_Intro.ogg",
        "urheber": "Iwan Sounds and DIY",
        "lizenz": "CC0 1.0",
        "nachweis": "https://commons.wikimedia.org/wiki/File:Drum_Roll_Intro.ogg",
    },
    "rad": {
        "titel": "Glücksrad",
        "url": "https://kenney.nl/media/pages/assets/interface-sounds/"
               "fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
        "im_archiv": "Audio/tick_004.ogg",
        # Hier kein fertiger Mitschnitt, sondern ein echter Einzelklick, der
        # auf der Verlangsamungskurve ausgelöst wird. Ein Glücksrad wird ja
        # langsamer — eine feste Aufnahme hat dagegen ihr eigenes Tempo und
        # passte nie zum Bild.
        "reihung": True,
        "urheber": "Kenney Vleugels (kenney.nl), Paket „Interface Sounds“",
        "lizenz": "CC0 1.0",
        "nachweis": "https://kenney.nl/assets/interface-sounds",
    },
}


def hole(url: str) -> bytes:
    """Herunterladen — mit Zwischenspeicher.

    Wikimedia bremst wiederholte Zugriffe aus (HTTP 429), und das zu Recht.
    Wer das Skript mehrfach laufen lässt, soll die Server nicht jedes Mal
    behelligen: Einmal geholt, liegt die Datei unter `.klang-zwischenlager/`
    (nicht im Repo) und wird von dort genommen.
    """
    lager = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         ".klang-zwischenlager")
    os.makedirs(lager, exist_ok=True)
    ablage = os.path.join(lager, url.rsplit("/", 1)[-1])
    if os.path.exists(ablage) and os.path.getsize(ablage) > 4096:
        with open(ablage, "rb") as datei:
            return datei.read()

    anfrage = urllib.request.Request(url, headers=KENNUNG)
    with urllib.request.urlopen(anfrage, timeout=120) as antwort:
        roh = antwort.read()
    with open(ablage, "wb") as datei:
        datei.write(roh)
    return roh


def lade(quelle: dict):
    roh = hole(quelle["url"])
    if "im_archiv" in quelle:
        with zipfile.ZipFile(io.BytesIO(roh)) as archiv:
            roh = archiv.read(quelle["im_archiv"])
    daten, rate = sf.read(io.BytesIO(roh), always_2d=True)
    # Auf einen Kanal mischen — bei 5.1 ebenso wie bei Stereo.
    mono = [sum(rahmen) / len(rahmen) for rahmen in daten]
    return mono, rate


def schneide(mono, rate):
    """Stille vorn weg, dann das Fenster bis zum natürlichen Ende."""
    schwelle = max(abs(v) for v in mono) * 0.02
    anfang = 0
    for i, v in enumerate(mono):
        if abs(v) > schwelle:
            anfang = max(0, i - int(0.005 * rate))
            break
    # Hinten genauso: nachlaufende Stille interessiert nicht.
    ende = len(mono)
    for i in range(len(mono) - 1, anfang, -1):
        if abs(mono[i]) > schwelle:
            ende = min(len(mono), i + int(0.05 * rate))
            break

    gebraucht = int((ZIEHDAUER + NACHKLANG) * rate)
    if ende - anfang > gebraucht:
        # Das Ende ist der Höhepunkt — also von hinten zählen.
        anfang = ende - gebraucht
    return mono[anfang:ende]


def reihe(klick, rate):
    """Einen echten Klick auf der Ziehkurve aneinanderreihen.

    Dieselben 18 Schritte wie in `ZiehLauf`: von 45 auf 210 ms, Exponent 2,4.
    Kleine Pegelschwankungen, weil eine Ratsche nie zweimal gleich klingt.
    """
    schritte = 18
    zeiten = []
    t = 0.0
    for i in range(schritte):
        zeiten.append(t)
        p = i / (schritte - 1)
        t += (45 + p ** 2.4 * 165) / 1000
    zeiten.append(t)                      # letzter Klick beim Anhalten

    gesamt = int((t + 0.3) * rate)
    spur = [0.0] * gesamt
    for nummer, wann in enumerate(zeiten):
        ab = int(wann * rate)
        # Zum Schluss etwas leiser — das Rad läuft aus.
        pegel = 0.75 + 0.25 * (1 - nummer / len(zeiten))
        for i, v in enumerate(klick):
            j = ab + i
            if j < gesamt:
                spur[j] += v * pegel
    return spur


def blende(stueck, rate):
    ein = int(0.004 * rate)
    aus = int(0.05 * rate)
    n = len(stueck)
    for i in range(min(ein, n)):
        stueck[i] *= i / ein
    for i in range(min(aus, n)):
        stueck[n - 1 - i] *= i / aus
    return stueck


def normiere(stueck, ziel=0.82):
    spitze = max(abs(v) for v in stueck) or 1.0
    faktor = ziel / spitze
    return [v * faktor for v in stueck]


def main():
    wurzel = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ordner = os.path.join(wurzel, "Tafelbild", "Klaenge")
    os.makedirs(ordner, exist_ok=True)

    zeilen = []
    for name, quelle in QUELLEN.items():
        mono, rate = lade(quelle)
        if quelle.get("reihung"):
            stueck = normiere(blende(reihe(schneide(mono, rate), rate), rate))
        else:
            stueck = normiere(blende(schneide(mono, rate), rate))
        pfad = os.path.join(ordner, f"zieh-{name}.wav")
        sf.write(pfad, stueck, rate, subtype="PCM_16")
        groesse = os.path.getsize(pfad) // 1024
        print(f"{quelle['titel']:16} {len(stueck)/rate:4.2f} s  {groesse:4} kB  -> {os.path.basename(pfad)}")
        zeilen.append(f"| {quelle['titel']} | `zieh-{name}.wav` | {quelle['urheber']} | "
                      f"{quelle['lizenz']} | {quelle['nachweis']} |")

    with open(os.path.join(ordner, "README.md"), "w", encoding="utf-8") as datei:
        datei.write(
            "# Klänge beim Ziehen\n\n"
            "Echte Aufnahmen, keine Synthese. Alle Quellen stehen unter **CC0 1.0** —\n"
            "gemeinfrei, auch kommerziell nutzbar, ohne Pflicht zur Namensnennung.\n"
            "Genannt werden sie hier trotzdem; das gehört sich.\n\n"
            "| Klang | Datei | Urheber | Lizenz | Nachweis |\n"
            "|---|---|---|---|---|\n" + "\n".join(zeilen) + "\n\n"
            "Die Dateien sind auf einen Kanal gemischt, auf die Länge eines Zuges\n"
            "(1,72 s plus Nachklang) zugeschnitten und auf gleichen Pegel gebracht.\n\n"
            "**Nicht von Hand bearbeiten** — `TafelbildiOS/scripts/fetch-sounds.py`\n"
            "holt und erzeugt sie.\n")
    print("\nHerkunft und Lizenz stehen in Klaenge/README.md")


if __name__ == "__main__":
    main()
