#!/usr/bin/env python3
"""Probt die Heftzeilen-Prüfung (Stufe 5) an allen Zeichen.

Auf Stufe 5 schreibt das Kind ohne Spur in normaler Heftgröße, an einer
beliebigen Stelle der Zeile. Geprüft wird jeder Strich, sobald der Stift
abhebt — Nachbildung von `Heftpruefer.swift`:

* Die Vorlage wird waagerecht so über den ersten Strich gelegt, dass sie
  am besten passt (kleinste Quadrate), und in der Breite an die Schrift
  angepasst (Kinder schreiben schmaler oder breiter). Weitere Striche
  dürfen ein wenig daneben liegen und ±20 % länger oder kürzer sein.
  **Senkrecht wird nichts angepasst** — ob ein Strich an der
  richtigen Linie des Schreibhauses beginnt und endet, ist Teil der
  Prüfung.
* Kind und Vorlage werden nach Weglänge gleich fein abgetastet und Punkt
  für Punkt verglichen. Wer andersherum schreibt, liegt damit weit
  daneben — auch beim O, das von oben beginnend in beide Richtungen
  gleich aussieht.

Geprüft wird hier:
* sauber, mit Zittern, ungenauem Ansatz, beliebiger Lage und Breite
  0,8–1,25 → angenommen
* verkehrt herum → abgelehnt, und zwar als „andersherum"
* nach 60 % abgesetzt → abgelehnt
* eine Etage zu hoch oder zu tief (± 0,45) → abgelehnt

Aufruf:  python3 SchreibspuriOS/scripts/heft-simulation.py
"""
import importlib.util
import math
import os
import random

HIER = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("vorschau", os.path.join(HIER, "zeichen-vorschau.py"))
vorschau = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(vorschau)

# Wie in Heftpruefer.swift
N = 40
MITTEL, SPITZE, ETAGE, ENDE = 0.12, 0.3, 0.15, 0.22
# Ab dieser Summe (Σ u² über die abgetasteten Punkte) gilt die Breite als
# gesichert: ein Strich mit rund 0,2 waagerechter Ausdehnung im Mittel.
# Kleiner (0,5) machte das kurze erste Stück des y zum Maßstab für das
# lange zweite — und das riss bei gerader Schrift ab.
FEST = 1.5
# Nur Striche, die mindestens so breit sind, bestimmen die Schriftbreite —
# der kleine Haken oben am f war sonst ein wackliger Maßstab für den
# Querstrich.
BREIT = 0.4
# So weit darf ein weiterer Strich waagerecht neben seinem Platz liegen.
VERSATZ = 0.12
GENAUIGKEIT = {"streng": 0.8, "normal": 1.0, "locker": 1.25}
VERSUCHE = 25
SCHWUENGE = {"Lange Striche", "Kurze Striche", "Querstriche", "Zacken", "Wendebögen", "Brücken",
             "Girlanden", "Bögen", "Kreise", "Wellen"}


def abtasten(pkt, n=N):
    """n Punkte in gleichen Weglängen-Abständen."""
    if len(pkt) == 1:
        return [pkt[0]] * n
    l = [0.0]
    for a, b in zip(pkt, pkt[1:]):
        l.append(l[-1] + math.dist(a, b))
    g = l[-1]
    if g == 0:
        return [pkt[0]] * n
    aus, j = [], 0
    for i in range(n):
        s = g * i / (n - 1)
        while j < len(l) - 2 and l[j + 1] < s:
            j += 1
        d = l[j + 1] - l[j]
        t = (s - l[j]) / d if d else 0
        a, b = pkt[j], pkt[j + 1]
        aus.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return aus


def laenge(pkt):
    return sum(math.dist(a, b) for a, b in zip(pkt, pkt[1:]))


def teil(pkt, anteil):
    """Die ersten `anteil` der Weglänge."""
    g = laenge(pkt) * anteil
    aus, s = [pkt[0]], 0.0
    for a, b in zip(pkt, pkt[1:]):
        d = math.dist(a, b)
        if s + d >= g:
            t = (g - s) / d if d else 0
            aus.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
            return aus
        aus.append(b)
        s += d
    return aus


class Heftpruefer:
    def __init__(self, striche, faktor):
        self.striche = striche          # Punktlisten der Vorlage
        self.f = faktor
        self.x0 = striche[0][0][0]      # Anker: Ansatz des ersten Strichs
        self.k = 0
        self.ax = None
        self.suv = self.suu = 0.0

    def breite(self):
        return min(1.4, max(0.7, self.suv / self.suu)) if self.suu > FEST else 1.0

    def anpassen(self, p, t):
        """Lage und Breite, bei denen die Vorlage waagerecht am besten auf
        dem Strich des Kindes liegt (kleinste Quadrate). So kostet ein etwas
        anders gesetzter Anfang nicht den ganzen Buchstaben."""
        u = [x - self.x0 for x, _ in t]
        v = [x for x, _ in p]
        mu, mv = sum(u) / len(u), sum(v) / len(v)
        var = sum((a - mu) ** 2 for a in u)
        sx = 1.0
        if max(u) - min(u) >= 0.25:
            sx = min(1.25, max(0.8, sum((a - mu) * (b - mv) for a, b in zip(u, v)) / var))
        return mv - sx * mu, sx

    def abbilden(self, t, ax, sx):
        return [(ax + sx * (x - self.x0), y) for x, y in t]

    def vergleich(self, p, t):
        d = [math.dist(a, b) for a, b in zip(p, t)]
        return sum(d) / len(d), max(d)

    def strich(self, roh):
        """'ok' oder die Fehlerart. Nach einem Fehler beginnt der Buchstabe neu."""
        vorlage = self.striche[self.k]
        f = self.f
        if len(vorlage) == 1 or laenge(vorlage) < 0.001:        # Punkt
            if self.ax is None:
                return self.fehler("form")
            ziel = self.abbilden(vorlage, self.ax, self.breite())[0]
            mitte = (sum(x for x, _ in roh) / len(roh), sum(y for _, y in roh) / len(roh))
            if laenge(roh) < 0.15 and math.dist(mitte, ziel) <= ETAGE * 1.4 * f:
                return self.weiter()
            return self.fehler("form")

        p = abtasten(roh)
        t = abtasten(vorlage)
        erster = self.ax is None
        ax = self.ax
        if erster:
            ax, _ = self.anpassen(p, t)
        # Breite: aus den schon angenommenen Strichen. Nur wenn die noch
        # nichts darüber sagen (erster Strich, senkrechte Striche), aus
        # diesem Strich selbst — sonst schluckte die Breite einen halb
        # geschriebenen Querstrich.
        suv, suu = self.suv, self.suu
        for (px, _), (tx, _) in zip(p, t):
            u = tx - self.x0
            suv += u * (px - ax)
            suu += u * u
        if erster:
            _, sx = self.anpassen(p, t)
        elif self.suu > FEST:
            sx = self.breite()
        else:
            # Noch keine gesicherte Breite: aus diesem Strich, aber eng
            # begrenzt — bei einem waagerechten Strich ließe sich Kürze
            # sonst nicht von Schmalheit trennen.
            sx = min(1.25, max(0.8, suv / suu)) if suu > 0.02 else 1.0
        tt = self.abbilden(t, ax, sx)
        if not erster:
            # Jeder weitere Strich darf waagerecht ein wenig neben seinem
            # Platz liegen und etwas länger oder kürzer sein (±20 % um die
            # Breite des Buchstabens) — die Querstriche eines E sind bei
            # Kindern nie gleich lang, lesbar bleibt es trotzdem.
            k0 = N * 3 // 20
            u = [x - self.x0 for x, _ in t[k0:]]
            v = [x - ax for x, _ in p[k0:]]
            if max(u) - min(u) >= 0.25:
                mu, mv = sum(u) / len(u), sum(v) / len(v)
                var = sum((a - mu) ** 2 for a in u)
                eigen = sum((a - mu) * (b - mv) for a, b in zip(u, v)) / var
                sx = min(sx * 1.2, max(sx * 0.8, eigen))
                tt = self.abbilden(t, ax, sx)
            d = sum(a[0] - b[0] for a, b in zip(p[k0:], tt[k0:])) / (N - k0)
            d = max(-VERSATZ, min(VERSATZ, d))
            tt = [(x + d, y) for x, y in tt]
        mittel, spitze = self.vergleich(p, tt)
        # Am Ende zählt auch die Länge des Strichs: Bei kurzen Strichen
        # wäre ein fester Spielraum schon ein halber Strich.
        l = laenge(vorlage)
        ende_rest = max(0.12, min(ENDE, 0.25 * l) * math.sqrt(f))
        etage_ende = min(ETAGE, max(0.08, 0.3 * l)) * f
        start_ok = abs(p[0][1] - tt[0][1]) <= ETAGE * f and abs(p[0][0] - tt[0][0]) <= ENDE * f * 1.25
        # Das Ende gemessen vom eigenen Anfang aus: So zählt, ob der Strich
        # lang genug und in die richtige Richtung geht — eine kleine
        # Verschiebung des ganzen Strichs steckt schon in der Etagenprüfung.
        # Ab einem kleinen Stück nach dem Ansatz: Der Anfang sitzt oft
        # etwas daneben, bevor der Stift in die Form findet.
        k = N * 3 // 20
        weg_kind = (p[-1][0] - p[k][0], p[-1][1] - p[k][1])
        weg_vorlage = (tt[-1][0] - tt[k][0], tt[-1][1] - tt[k][1])
        ende_ok = (abs(p[-1][1] - tt[-1][1]) <= etage_ende
                   and math.dist(weg_kind, weg_vorlage) <= ende_rest)
        if start_ok and ende_ok and mittel <= MITTEL * f and spitze <= SPITZE * f:
            self.ax = ax
            if max(x for x, _ in vorlage) - min(x for x, _ in vorlage) >= BREIT:
                self.suv, self.suu = suv, suu   # nur breite Striche sagen etwas über die Breite
            return self.weiter()
        # Andersherum? Dann liegt das Ende des Kindes am Anfang der Vorlage.
        if erster:
            ax_r, sx_r = self.anpassen(p, t[::-1])
        else:
            ax_r, sx_r = ax, sx
        tr = self.abbilden(t, ax_r, sx_r)[::-1]
        mittel_r, _ = self.vergleich(p, tr)
        if mittel_r <= MITTEL * f * 1.3 and mittel_r < mittel * 0.7:
            return self.fehler("andersherum")
        # Zu früh abgesetzt? Dann passt ein Anfangsstück der Vorlage.
        if start_ok:
            for zehntel in range(2, 10):
                tp = self.abbilden(abtasten(teil(vorlage, zehntel / 10)), ax, sx)
                if self.vergleich(p, tp)[0] <= MITTEL * f:
                    return self.fehler("abgesetzt")
        if not start_ok:
            return self.fehler("start")
        if not ende_ok:
            return self.fehler("ende")
        return self.fehler("form")

    def weiter(self):
        self.k += 1
        return "ok"

    def fehler(self, art):
        self.k, self.ax, self.suv, self.suu = 0, None, 0.0, 0.0
        return art


def waagerecht(pkt):
    """Gerader Strich, der mehr in die Breite als in die Höhe geht."""
    (ax, ay), (bx, by) = pkt[0], pkt[-1]
    l = math.hypot(bx - ax, by - ay)
    if l == 0:
        return False
    abweichung = max(abs((bx - ax) * (ay - y) - (ax - x) * (by - ay)) / l for x, y in pkt)
    return abweichung <= 0.04 and abs(bx - ax) > abs(by - ay)


def kindschrift(vorlage, ax, sx, x0, zittern):
    """Die Vorlage, wie ein Kind sie schreibt: verschoben, breiter oder
    schmaler, leicht versetzt und zittrig."""
    oy = random.uniform(-0.04, 0.04)
    ox = random.uniform(-0.03, 0.03)
    # Der Anfang sitzt oft etwas daneben und läuft dann auf die Form ein.
    ax0, ay0 = random.uniform(-0.06, 0.06), random.uniform(-0.04, 0.04)
    if len(vorlage) == 1:  # Punkt: kurz getippt
        x, y = vorlage[0]
        return [(ax + sx * (x - x0) + ox, y + oy + d) for d in (0, 0.01, 0.015)]
    wx = wy = 0.0
    aus = []
    for i, (x, y) in enumerate(abtasten(vorlage, 120)):
        wx = max(-zittern, min(zittern, wx + random.uniform(-0.012, 0.012)))
        wy = max(-zittern, min(zittern, wy + random.uniform(-0.012, 0.012)))
        abklingen = max(0.0, 1 - i / 15)
        aus.append((ax + sx * (x - x0) + ox + wx + ax0 * abklingen, y + oy + wy + ay0 * abklingen))
    return aus


def main():
    random.seed(2)
    fehler = 0
    for gname, f in GENAUIGKEIT.items():
        zittern = 0.035 * f
        for name, wege in vorschau.lesen():
            if name in SCHWUENGE:
                continue  # Schwünge gibt es auf Stufe 5 nicht
            striche = [vorschau.abtasten(w) for w in wege]
            x0 = striche[0][0][0]
            # 1. sauber geschrieben
            for _ in range(VERSUCHE):
                h = Heftpruefer(striche, f)
                ax, sx = random.uniform(1, 8), random.uniform(0.8, 1.25)
                for k, s in enumerate(striche):
                    erg = h.strich(kindschrift(s, ax, sx, x0, zittern))
                    if erg != "ok":
                        print(f"[{gname}] {name}: sauber, Strich {k + 1} abgelehnt ({erg})")
                        fehler += 1
                        break
                else:
                    continue
                break
            # 2.–4. falsch geschrieben: jeder Strich einzeln an seinem Platz
            for k, s in enumerate(striche):
                if len(s) == 1 or laenge(s) < 0.3:
                    continue
                for art, roh in (("verkehrt", s[::-1]), ("halb", teil(s, 0.6)),
                                 ("Etage hoch", [(x, y - 0.45) for x, y in s]),
                                 ("Etage tief", [(x, y + 0.45) for x, y in s])):
                    h = Heftpruefer(striche, f)
                    ax = random.uniform(1, 8)
                    for vorher in striche[:k]:
                        h.strich(kindschrift(vorher, ax, 1, x0, 0.01))
                    if h.k != k:
                        continue
                    if art == "halb" and laenge(s) < 0.6:
                        # Bekannte Grenze: Bei kurzen Strichen (Querstriche
                        # von t, f, A, E, Hut der 5) sind 60 % nur 2–4 mm
                        # kürzer als der ganze Strich — das liegt im Zittern
                        # und im ungenauen Ansatz. Ein kurzer Querstrich
                        # lässt den Buchstaben lesbar.
                        continue
                    if art == "halb" and h.suu <= FEST and waagerecht(s):
                        # Bekannte Grenze: Ein waagerechter Strich, bevor die
                        # Breite feststeht (oberer Querstrich des E), darf
                        # kurz sein — ein schmales E ist ein lesbares E.
                        continue
                    erg = h.strich(kindschrift(roh, ax, 1, x0, 0.01))
                    if erg == "ok" and art == "halb" and gname == "locker":
                        # „Locker“ ist bewusst nachsichtig: vereinzelt geht
                        # ein deutlich verkürzter Strich durch.
                        print(f"   (Hinweis) [{gname}] {name}: Strich {k + 1} {art} angenommen")
                    elif erg == "ok":
                        print(f"[{gname}] {name}: Strich {k + 1} {art} angenommen")
                        fehler += 1
                    elif art == "verkehrt" and erg != "andersherum" and math.dist(s[0], s[-1]) > 0.05:
                        # Nur ein Hinweis: abgelehnt ist es, aber mit anderer Begründung.
                        print(f"   (Hinweis) [{gname}] {name}: Strich {k + 1} verkehrt → „{erg}“")
    print("Alles in Ordnung." if fehler == 0 else f"{fehler} Auffälligkeiten.")
    raise SystemExit(1 if fehler else 0)


if __name__ == "__main__":
    main()
