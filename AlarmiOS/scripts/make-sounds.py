#!/usr/bin/env python3
"""Erzeugt die beiden Benachrichtigungstöne der Alarm-App.

    python3 AlarmiOS/scripts/make-sounds.py

Ergebnis: ``AlarmiOS/Shared/Sounds/alarm.wav`` (25 s) und
``AlarmiOS/Shared/Sounds/allclear.wav`` (3 s). Nicht von Hand bearbeiten.

Warum gerechnet und nicht geladen
---------------------------------

Ein Alarmton ist kein Naturgeräusch, sondern ein Signal: zwei Töne im
Wechsel, harte Flanken, immer gleich. Genau das lässt sich ausrechnen —
ohne fremde Dateien, ohne Lizenzfrage, ohne Netz beim Bauen. Dieselbe
Überlegung wie bei den Endklängen in Tafelbild.

Warum WAV und nicht CAF
-----------------------

Zuerst war es CAF, von Hand geschrieben — der Container ist einfach genug
dafür (Kopf, ``desc``-Block, ``data``-Block), und ``file`` erkannte das
Ergebnis anstandslos. Auf dem Gerät spielte iOS trotzdem den
Standard-Mitteilungston: Was es nicht laden kann, ersetzt es
stillschweigend, ohne einen Fehler zu melden.

Ein selbst geschriebener Container ist an dieser Stelle die falsche Sparsamkeit.
WAV schreibt Pythons ``wave`` aus der Standardbibliothek — kein fremdes
Paket, aber auch nichts, was ich selbst zusammengesetzt habe. ``UNNotificationSound``
nimmt WAV genauso an wie CAF.

Ob die Datei am Ende wirklich im App-Bündel liegt, sagt die Diagnose in der
App („Zustellung prüfen"): Sie schlägt sie dort nach und nennt die Größe.
Raten muss man das nicht.

Warum 44 100 Hz und Mono
------------------------

Mono, weil ein Warnton keine Richtung braucht. 44,1 kHz, weil das die
Abtastrate ist, mit der niemand streitet — bei einem Ton, der im Ernstfall
funktionieren muss, ist das die zwei Megabyte wert.
"""

from __future__ import annotations

import math
import os
import struct
import wave

RATE = 44100            # Abtastrate in Hz
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


def schreibe_wav(pfad: str, werte) -> None:
    """Schreibt 16-Bit-Mono-PCM als WAV.

    Über ``wave`` aus der Standardbibliothek: Der Kopf einer RIFF-Datei ist
    zwar auch von Hand zu schreiben, aber genau das war der Fehler zuvor.
    """
    roh = b"".join(struct.pack("<h", max(-32768, min(32767, int(w * 32767))))
                   for w in werte)
    os.makedirs(os.path.dirname(pfad), exist_ok=True)
    with wave.open(pfad, "wb") as datei:
        datei.setnchannels(1)
        datei.setsampwidth(2)
        datei.setframerate(RATE)
        datei.writeframes(roh)
    sekunden = len(werte) / RATE
    print(f"{pfad}: {sekunden:.1f} s, {os.path.getsize(pfad) // 1024} KiB")


def main() -> None:
    for name, werte in (("alarm.wav", alarmton()), ("allclear.wav", entwarnung())):
        sekunden = len(werte) / RATE
        # Über 30 Sekunden spielt iOS den Ton gar nicht ab — lieber hier
        # scheitern als auf dem Gerät schweigen.
        assert sekunden <= 30.0, f"{name} ist {sekunden:.1f} s lang, erlaubt sind 30"
        schreibe_wav(os.path.join(ZIEL, name), normiert(werte))


if __name__ == "__main__":
    main()
