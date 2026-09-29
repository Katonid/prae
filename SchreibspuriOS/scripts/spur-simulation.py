#!/usr/bin/env python3
"""Probt die Nachspur-Prüfung an allen Zeichen, ohne Gerät und ohne Xcode.

Bildet `Spurpruefer.swift` und `Strich.naechsteStelle` nach und lässt je
Strich einen „Finger" nachspuren:

* sauber, aber mit Zittern und Versatz bis `ZITTERN` × Toleranz
  → muss angenommen werden,
* verkehrt herum → darf nie angenommen werden,
* nur 60 % des Wegs, dann abgesetzt → darf nie angenommen werden.

Wer die Suchfenster in `Spurpruefer.swift` oder einen Weg in
`Zeichensatz.swift` ändert, lässt das hier laufen. Die Zahlen unten müssen
mit dem Swift-Code übereinstimmen.

Aufruf:  python3 SchreibspuriOS/scripts/spur-simulation.py
"""
import importlib.util
import math
import os
import random

HIER = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("vorschau", os.path.join(HIER, "zeichen-vorschau.py"))
vorschau = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(vorschau)

# Wie in Spurpruefer.swift
ZURUECK, VORAUS, GLEICHSTAND, FANG, ZIEL = 1.5, 3.5, 0.05, 1.5, 0.9
TOLERANZEN = {"streng": 0.07, "normal": 0.1, "locker": 0.14}
ZITTERN = 0.5
VERSUCHE = 30


class Strich:
    def __init__(self, weg):
        p = []
        for q in vorschau.abtasten(weg):
            if not p or math.dist(p[-1], q) > 0.0005:
                p.append(q)
        self.p = p
        self.l = [0.0]
        for a, b in zip(p, p[1:]):
            self.l.append(self.l[-1] + math.dist(a, b))
        self.gesamt = self.l[-1]

    def punkt(self, s):
        for i in range(len(self.p) - 1):
            if self.l[i + 1] >= s:
                d = self.l[i + 1] - self.l[i]
                t = (s - self.l[i]) / d if d else 0
                a, b = self.p[i], self.p[i + 1]
                return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
        return self.p[-1]

    def naechste_stelle(self, q, von, bis, bezug, gleichstand):
        if len(self.p) < 2:
            return 0, math.dist(q, self.p[0])
        kandidaten = []
        for i in range(len(self.p) - 1):
            s0, s1 = self.l[i], self.l[i + 1]
            if s1 < von or s0 > bis:
                continue
            a, b = self.p[i], self.p[i + 1]
            d = s1 - s0
            t = ((q[0] - a[0]) * (b[0] - a[0]) + (q[1] - a[1]) * (b[1] - a[1])) / (d * d) if d else 0
            t_min = max(0, (von - s0) / d) if d else 0
            t_max = min(1, (bis - s0) / d) if d else 0
            t = min(max(t, t_min), t_max)
            fuss = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            kandidaten.append((s0 + t * d, math.dist(q, fuss)))
        bester = min(kandidaten, key=lambda k: k[1])
        entfernung = lambda s: (s - bezug) * 0.4 if s >= bezug else bezug - s
        gleich = [k for k in kandidaten if k[1] <= bester[1] + gleichstand]
        return min(gleich, key=lambda k: entfernung(k[0]))


def nachspuren(strich, punkte, tol):
    """'ok' oder der Grund der Ablehnung — wie Spurpruefer.swift."""
    if math.dist(punkte[0], strich.p[0]) > tol * FANG:
        return "start"
    f, letzter = 0.0, punkte[0]
    for p in punkte:
        n = max(1, math.ceil(math.dist(letzter, p) / (tol * 0.4)))
        for k in range(1, n + 1):
            q = (letzter[0] + (p[0] - letzter[0]) * k / n, letzter[1] + (p[1] - letzter[1]) * k / n)
            if strich.gesamt < 0.001:
                if math.dist(q, strich.p[0]) > tol * 1.8:
                    return "spur"
                continue
            s, d = strich.naechste_stelle(q, max(0, f - tol * ZURUECK), f + tol * VORAUS, f, tol * GLEICHSTAND)
            if d > tol:
                return f"spur bei {f:.2f}"
            f = max(f, s)
        letzter = p
    if strich.gesamt < 0.001 or f >= strich.gesamt - tol * ZIEL:
        return "ok"
    return f"abgesetzt bei {f:.2f}/{strich.gesamt:.2f}"


def main():
    random.seed(1)
    fehler = 0
    for name_tol, tol in TOLERANZEN.items():
        for name, wege in vorschau.lesen():
            for weg in wege:
                strich = Strich(weg)
                for _ in range(VERSUCHE):
                    grenze = tol * ZITTERN
                    ox, oy = random.uniform(-grenze, grenze), random.uniform(-grenze, grenze)
                    punkte, s = [], 0.0
                    schritt = random.uniform(0.01, 0.08)
                    while s < strich.gesamt:
                        x, y = strich.punkt(s)
                        ox = max(-grenze, min(grenze, ox + random.uniform(-0.01, 0.01)))
                        oy = max(-grenze, min(grenze, oy + random.uniform(-0.01, 0.01)))
                        punkte.append((x + ox, y + oy))
                        s += schritt
                    punkte.append(strich.p[-1])
                    ergebnis = nachspuren(strich, punkte, tol)
                    if ergebnis != "ok":
                        print(f"[{name_tol}] {name}: sauber nachgespurt, abgelehnt ({ergebnis}) – {weg}")
                        fehler += 1
                        break
                if strich.gesamt > 0.3:
                    rueckwaerts = [strich.punkt(strich.gesamt * (1 - k / 100)) for k in range(101)]
                    if nachspuren(strich, rueckwaerts, tol) == "ok":
                        print(f"[{name_tol}] {name}: verkehrt herum angenommen – {weg}")
                        fehler += 1
                    halb = [strich.punkt(strich.gesamt * 0.6 * k / 100) for k in range(101)]
                    if nachspuren(strich, halb, tol) == "ok":
                        print(f"[{name_tol}] {name}: halb geschrieben angenommen – {weg}")
                        fehler += 1
    print("Alles in Ordnung." if fehler == 0 else f"{fehler} Auffälligkeiten.")
    raise SystemExit(1 if fehler else 0)


if __name__ == "__main__":
    main()
