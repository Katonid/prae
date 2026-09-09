#!/usr/bin/env python3
"""Erzeugt die Benachrichtigungstöne der Alarm-App.

    python3 AlarmiOS/scripts/make-sounds.py

Ergebnis in ``AlarmiOS/Shared/Sounds/``: ``alarm.wav`` (25 s),
``allclear.wav`` (3 s) und die drei leisen Töne ``dezent.wav``,
``holz.wav`` und ``tropfen.wav`` (je 10 s). Nicht von Hand bearbeiten.

Warum es leise Töne gibt
------------------------

Die Schule möchte einen Probealarm — und im Zweifel auch einen echten —
zunächst VOR DEN KINDERN verbergen (Ansage des Nutzers, 09/2026). Ein
durchdringendes Zweitonsignal auf dreißig iPads ist dafür das Gegenteil
von brauchbar.

Die Lautstärke steckt dabei in der DATEI, nicht in einer Einstellung. Seit
1.0.29 sind kritische Hinweise an, und die spielen mit
``withAudioVolume: 1.0`` — also unabhängig davon, wie laut das iPad
gestellt ist. Ein leiser Ton lässt sich damit nur so bauen: als leise
gerechnete Wellenform. Die drei leisen Töne sind auf 0,22 bis 0,32 Spitze
normiert statt auf 0,92, also rund 9 bis 12 dB unter dem Alarm.

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


def glocke(frequenz: float, dauer: float, obertoene, abfall: float):
    """Ein angeschlagener Klang: weicher Einsatz, exponentielles Ausklingen.

    Das ist die Bauform für alles Harmlose. Ein Alarm hat harte Kanten und
    hält die Lautstärke; ein Signal, das niemandem auffallen soll, klingt
    aus wie ein angeschlagenes Metall oder Holz — es fängt an und hört von
    selbst auf.
    """
    anzahl = int(RATE * dauer)
    einsatz = max(1, int(RATE * 0.012))
    werte = []
    for i in range(anzahl):
        t = i / RATE
        wert = sum(a * math.sin(2 * math.pi * frequenz * f * t)
                   for f, a in obertoene)
        wert *= math.exp(-abfall * t)
        if i < einsatz:
            wert *= i / einsatz
        werte.append(wert)
    return werte


def gemischt(*spuren):
    """Legt mehrere gleich lange Spuren übereinander."""
    laenge = max(len(s) for s in spuren)
    summe = [0.0] * laenge
    for spur in spuren:
        for i, w in enumerate(spur):
            summe[i] += w
    return summe


def wiederholt(runde, gesamtdauer: float):
    werte = []
    while len(werte) < int(RATE * gesamtdauer):
        werte += runde
    return werte[:int(RATE * gesamtdauer)]


def dezent():
    """Zwei weiche Töne, wie eine Kalendererinnerung.

    A5 und E6 — eine Quinte, das freundlichste Intervall, das es gibt. Wer
    das im Klassenraum hört, denkt an einen Termin und nicht an Gefahr.
    """
    oben = [(1.0, 1.0), (2.0, 0.18), (3.0, 0.05)]
    runde = (glocke(880.0, 0.55, oben, 5.0)
             + glocke(1318.5, 0.75, oben, 4.2)
             + stille(1.2))
    return wiederholt(runde, 10.0)


def holz():
    """Marimba: Grundton mit den Teiltönen eines angeschlagenen Stabes.

    Ein Holzstab schwingt nicht in Vielfachen seines Grundtons, sondern
    ungefähr im Verhältnis 1 : 4 : 10. Genau das macht den warmen, kurzen
    Klang, den niemand für ein Warnsignal hält — und es ist der Grund,
    warum hier keine Obertonreihe steht.
    """
    stab = [(1.0, 1.0), (4.0, 0.30), (10.0, 0.11)]
    runde = (glocke(523.25, 0.5, stab, 7.0)
             + glocke(659.25, 0.6, stab, 6.0)
             + stille(1.4))
    return wiederholt(runde, 10.0)


def tropfen():
    """Ein kurzer Blubb mit fallender Tonhöhe — der leiseste der vier.

    Die fallende Tonhöhe ist das, was aus einem Piepen ein Geräusch macht.
    Ein gleichbleibender kurzer Ton klingt nach Gerät; einer, der fällt,
    klingt nach Wassertropfen und wird nicht als Meldung gelesen.
    """
    anzahl = int(RATE * 0.14)
    einsatz = max(1, int(RATE * 0.006))
    blubb = []
    phase = 0.0
    for i in range(anzahl):
        t = i / RATE
        frequenz = 1200.0 - 520.0 * (t / 0.14)
        phase += 2 * math.pi * frequenz / RATE
        wert = math.sin(phase) * math.exp(-11.0 * t)
        if i < einsatz:
            wert *= i / einsatz
        blubb.append(wert)
    return wiederholt(blubb + stille(1.5), 10.0)


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
    # Die Spitze je Datei ist die Lautstärke: Kritische Hinweise spielen mit
    # withAudioVolume 1.0, unabhängig vom Lautstärkeregler des iPads. Leise
    # wird ein Ton deshalb nur dadurch, dass er leise GERECHNET ist.
    dateien = (
        ("alarm.wav", alarmton(), 0.92),
        ("allclear.wav", entwarnung(), 0.92),
        ("dezent.wav", dezent(), 0.30),
        ("holz.wav", holz(), 0.32),
        ("tropfen.wav", tropfen(), 0.22),
    )
    for name, werte, spitze in dateien:
        sekunden = len(werte) / RATE
        # Über 30 Sekunden spielt iOS den Ton gar nicht ab — lieber hier
        # scheitern als auf dem Gerät schweigen.
        assert sekunden <= 30.0, f"{name} ist {sekunden:.1f} s lang, erlaubt sind 30"
        schreibe_wav(os.path.join(ZIEL, name), normiert(werte, spitze))


if __name__ == "__main__":
    main()
