#!/usr/bin/env python3
"""Erzeugt die beiden Benachrichtigungstöne der Alarm-App.

    python3 AlarmiOS/scripts/make-sounds.py

Ergebnis: ``AlarmiOS/Shared/Sounds/alarm.caf`` (25 s) und
``AlarmiOS/Shared/Sounds/allclear.caf`` (3 s). Nicht von Hand bearbeiten.

Warum gerechnet und nicht geladen
---------------------------------

Ein Alarmton ist kein Naturgeräusch, sondern ein Signal: zwei Töne im
Wechsel, harte Flanken, immer gleich. Genau das lässt sich ausrechnen —
ohne fremde Dateien, ohne Lizenzfrage, ohne Netz beim Bauen. Dieselbe
Überlegung wie bei den Endklängen in Tafelbild.

Warum CAF und nicht WAV
-----------------------

``UNNotificationSound(named:)`` nimmt AIFF, WAV und CAF, aber nur mit
einem der Formate Linear PCM, MA4, µLaw oder aLaw und **höchstens 30
Sekunden**. CAF mit Linear PCM ist davon das, was iOS am liebsten mag,
und Apples eigene Anleitung nennt es zuerst.

Warum kein ``afconvert``
------------------------

``afconvert`` gibt es nur auf macOS. Der Bau dieses Repos läuft aber auch
auf Linux-Läufern, und die Töne sollen sich überall neu erzeugen lassen.
CAF ist ein einfacher Container (Kopf, ``desc``-Block, ``data``-Block) —
den schreibt dieses Skript selbst. Wer lieber ``afconvert`` nimmt: Das
Ergebnis ist dasselbe.

Warum 22 050 Hz und Mono
------------------------

Ein Warnton hat seine Energie zwischen 500 und 2 000 Hz; darüber trägt er
nichts bei. Mono bei 22,05 kHz halbiert die Datei zweimal — sie liegt
sowohl im App-Bündel als auch in der Erweiterung, also viermal auf dem
Gerät. Hörbar ist der Unterschied bei einem Rechtecksignal nicht.
"""

from __future__ import annotations

import math
import os
import struct

RATE = 22050            # Abtastrate in Hz
FLANKE = 0.004          # Sekunden Ein-/Ausblendung an jeder Tonkante

HIER = os.path.dirname(os.path.abspath(__file__))
ZIEL = os.path.join(os.path.dirname(HIER), "Shared", "Sounds")


def ton(frequenz: float, dauer: float, obertoene=(1.0, 0.45, 0.22, 0.10)):
    """Ein Ton mit weichen Kanten.

    Die Obertöne machen aus dem Sinus ein sägezahnähnliches Signal. Das ist
    Absicht: Ein reiner Sinus verschwindet in einem lauten Klassenraum, weil
    seine ganze Energie auf einer einzigen Frequenz liegt. Mit Obertönen
    findet der Ton immer eine Lücke im Störgeräusch.

    Die Kanten werden geblendet (``FLANKE``), sonst knackt jeder Tonwechsel:
    Ein Sprung von voller Auslenkung auf Null ist ein Impuls, und der klingt
    nach kaputtem Lautsprecher, nicht nach Alarm.
    """
    anzahl = int(RATE * dauer)
    kante = max(1, int(RATE * FLANKE))
    werte = []
    for i in range(anzahl):
        t = i / RATE
        wert = sum(a * math.sin(2 * math.pi * frequenz * (n + 1) * t)
                   for n, a in enumerate(obertoene))
        wert /= sum(obertoene)
        if i < kante:
            wert *= i / kante
        elif i > anzahl - kante:
            wert *= (anzahl - i) / kante
        werte.append(wert)
    return werte


def stille(dauer: float):
    return [0.0] * int(RATE * dauer)


def alarmton(gesamtdauer: float = 25.0):
    """Zwei Töne im Wechsel, eine Sekunde je Runde.

    Der Wechsel ist das Entscheidende. Ein Dauerton wird nach wenigen
    Sekunden überhört — das Gehör blendet Gleichbleibendes aus. Ein
    Wechsel bleibt vorne.
    """
    runde = ton(960, 0.45) + stille(0.05) + ton(720, 0.45) + stille(0.05)
    werte = []
    while len(werte) < int(RATE * gesamtdauer):
        werte += runde
    return werte[:int(RATE * gesamtdauer)]


def entwarnung():
    """Drei Töne aufwärts, weich ausklingend — das Gegenteil des Alarms.

    Aufwärts und weich, weil die Entwarnung nicht wie ein zweiter Alarm
    klingen darf. Wer den Unterschied erst nach dem Hinsehen bemerkt, hat
    die Entwarnung nicht gehört.
    """
    weich = (1.0, 0.25, 0.08)
    werte = ton(659.25, 0.5, weich) + ton(783.99, 0.5, weich) + ton(1046.5, 1.6, weich)
    # Der letzte Ton klingt zusätzlich exponentiell aus.
    beginn = len(werte) - int(RATE * 1.6)
    for i in range(beginn, len(werte)):
        werte[i] *= math.exp(-2.2 * (i - beginn) / RATE)
    rest = int(RATE * 3.0) - len(werte)
    return (werte + stille(max(0, rest) / RATE))[:int(RATE * 3.0)]


def normiert(werte, spitze: float = 0.92):
    hoch = max(abs(w) for w in werte) or 1.0
    faktor = spitze / hoch
    return [w * faktor for w in werte]


def schreibe_caf(pfad: str, werte) -> None:
    """Schreibt Linear-PCM (16 Bit, mono, big endian) als CAF-Datei.

    CAF ist von Haus aus big endian; ``mFormatFlags = 0`` heißt damit
    „vorzeichenbehaftete Ganzzahl, big endian". Ein gesetztes Bit 0 wäre
    Fließkomma, Bit 1 little endian — beides wollen wir hier nicht.
    """
    roh = b"".join(struct.pack(">h", max(-32768, min(32767, int(w * 32767))))
                   for w in werte)

    kopf = b"caff" + struct.pack(">HH", 1, 0)
    desc = struct.pack(">d4sIIIII",
                       float(RATE),      # mSampleRate
                       b"lpcm",          # mFormatID
                       0,                # mFormatFlags: ganzzahlig, big endian
                       2,                # mBytesPerPacket
                       1,                # mFramesPerPacket
                       1,                # mChannelsPerFrame
                       16)               # mBitsPerChannel
    bloecke = (b"desc" + struct.pack(">q", len(desc)) + desc
               + b"data" + struct.pack(">q", len(roh) + 4)
               + struct.pack(">I", 0) + roh)

    os.makedirs(os.path.dirname(pfad), exist_ok=True)
    with open(pfad, "wb") as datei:
        datei.write(kopf + bloecke)
    sekunden = len(werte) / RATE
    print(f"{pfad}: {sekunden:.1f} s, {os.path.getsize(pfad) // 1024} KiB")


def main() -> None:
    for name, werte in (("alarm.caf", alarmton()), ("allclear.caf", entwarnung())):
        sekunden = len(werte) / RATE
        # Über 30 Sekunden spielt iOS den Ton gar nicht ab — lieber hier
        # scheitern als auf dem Gerät schweigen.
        assert sekunden <= 30.0, f"{name} ist {sekunden:.1f} s lang, erlaubt sind 30"
        schreibe_caf(os.path.join(ZIEL, name), normiert(werte))


if __name__ == "__main__":
    main()
