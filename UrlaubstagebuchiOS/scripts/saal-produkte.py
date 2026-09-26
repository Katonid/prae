#!/usr/bin/env python3
"""Erzeugt `Urlaubstagebuch/Model/Saalprodukte.swift` aus den Maßen, die Saal
Digital auf seiner Seite „Profibereich" zeigt — reines Python, ohne fremde
Bibliotheken.

WOHER DIE ZAHLEN KOMMEN (gemessen 26.09.2026). Die Seite
https://www.saal-digital.de/fotobuch/profibereich/ trägt die Tabelle nicht
als Text; ein Skript lädt sie nach, und zwar von

    POST https://services.saal-digital.net/designservice/api/Configurator/GetFormats

mit der Kennung des Händlers und der Artikelgruppe, die im Quelltext der
Seite stehen. Die Antwort nennt je Produkt die Innenseiten (Doppelseite MIT
Beschnitt) und je Seitenzahl den Umschlagbogen (Maß, Buchrücken,
Falzbereich, Beschnitt links/rechts und oben/unten). Gefragt wird mit der
Einheit „mm", damit hier nichts umgerechnet werden muss — und je
Papiersorte einzeln, denn die Rückenbreite hängt am Papier.

WAS DIE APP DARAUS MACHT, steht in `Model/Druckprodukt.swift`; hier wird nur
gelesen und hingeschrieben.

    python3 scripts/saal-produkte.py            # holt die Daten neu
    python3 scripts/saal-produkte.py alle.json  # nimmt eine gesicherte Antwort
"""
import json
import re
import statistics
import subprocess
import sys
import time
from pathlib import Path

URL = "https://services.saal-digital.net/designservice/api/Configurator/GetFormats"
HAENDLER = "61acebfb-7c0a-4004-af5b-b8cda1fe7ece"
ARTIKELGRUPPE = "d35ed0f7-bd26-4e81-b513-c8758ce8f90b"
ZIEL = Path(__file__).resolve().parent.parent / "Urlaubstagebuch" / "Model" / "Saalprodukte.swift"

# Nur Bücher mit Innenseiten zum Selbstgestalten. Fotoheft, Kinderbuch und
# Geschenkbox haben keine Tabelle dieser Art.
REIHEN = {
    "Fotobuch Hardcover": ("hc", "Hardcover"),
    "Fotobuch Hardcover XT (extra thick)": ("xt", "Hardcover XT"),
    "Professional Line Fotobuch": ("pl", "Professional Line"),
    "Professional Line Fotobuch XT": ("plxt", "Professional Line XT"),
    "Fotobuch Softcover": ("sc", "Softcover"),
    "Portfolio Album": ("pa", "Portfolio Album"),
}


def post(tabs):
    body = {"ResellerId": HAENDLER, "SelectedTabs": tabs, "Language": "de_DE",
            "ArticleGroup": ARTIKELGRUPPE, "DisplayMode": 0, "RequestVersion": 1}
    for _ in range(3):
        r = subprocess.run(["curl", "-sS", "-m", "60", "-H", "Content-Type: application/json",
                            "-X", "POST", "--data-binary", json.dumps(body), URL],
                           capture_output=True)
        try:
            return json.loads(r.stdout)
        except ValueError:
            time.sleep(2)
    raise SystemExit("Saal antwortet nicht.")


def holen():
    basis = post([])
    alle = {}
    for g in basis["Groups"]:
        if g.get("Heading") not in REIHEN:
            continue
        data = g["Data"]
        einheit = next(x for x in data if x["Text"] == "Einheit")
        mm = next(c["Id"] for c in einheit["Children"] if c["Text"] == "mm")
        papier = next((x for x in data if x["Text"] == "Innenseiten-Oberfläche"), None)
        for tab in g["Tabs"]:
            for p in (papier["Children"] if papier else [None]):
                settings = []
                for x in data:
                    wahl = next((c["Id"] for c in x["Children"] if c.get("Selected")),
                                x["Children"][0]["Id"])
                    if x is einheit:
                        wahl = mm
                    if papier is not None and x is papier:
                        wahl = p["Id"]
                    settings.append({"GroupIndex": x["Id"], "Selection": wahl})
                t = {k: v for k, v in tab.items() if k != "Settings"}
                t["Selected"] = True
                t["Settings"] = settings
                antwort = post([t])
                gg = next(x for x in antwort["Groups"] if x.get("Heading") == g["Heading"])
                name = next(x["Name"] for x in gg["Tabs"] if x.get("Selected"))
                alle["|".join((g["Heading"], name, p["Text"] if p else ""))] = gg["Tables"]
                time.sleep(0.4)
    return alle


def zahlen(text):
    text = re.sub("<[^>]+>", "", text).replace("\xa0", " ").replace(",", ".")
    return [float(x) for x in re.findall(r"[0-9]+(?:\.[0-9]+)?", text)]


def kopf(tabelle):
    return [re.sub("<br />", " ", h.get("Text") or "") for h in tabelle["Header"]]


def auswerten(alle):
    produkte = {}
    for schluessel, tabellen in alle.items():
        reihe, name, papier = schluessel.split("|")
        tb = {t["Heading"]: t for t in tabellen if "Heading" in t}
        if "Innenseiten" not in tb or "Cover" not in tb:
            continue
        # Das Maß im Namen („Fotobuch 21 x 28", „40 x 30 Professional Line").
        cm = [float(x) for x in re.findall(r"(\d+)\s*x\s*(\d+)", name.replace("\xa0", " "))[0]]

        innen = [re.sub("<[^>]+>", "", c) for c in tb["Innenseiten"]["Body"][0]]
        ik = {h: i for i, h in enumerate(kopf(tb["Innenseiten"]))}
        von, bis = (int(x) for x in zahlen(innen[ik["Seitenanzahl"]])[:2])
        w, h = zahlen(innen[ik["Abmessungen"]])
        b = zahlen(innen[ik["Beschnitt"]])[0]
        # Eine Antwort kam für „42 x 28" in Zentimetern zurück, obwohl mm
        # gewählt war. Erkannt wird das am Maß selbst: Kein Fotobuch ist
        # unter zehn Zentimeter breit.
        faktor = 10.0 if w < 100 else 1.0
        w, h, b = w * faktor, h * faktor, b * faktor
        # Doppelseite oder Einzelseite? Entscheidet das Maß im Namen: Die
        # Hälfte der Vorlage liegt beim Buch mit Doppelseiten dort, beim
        # Portfolio Album die ganze.
        doppelt = abs((w - 2 * b) / 2 - cm[0] * 10) < abs((w - 2 * b) - cm[0] * 10)
        seite_b = (w - 2 * b) / 2 if doppelt else w - 2 * b
        seite_h = h - 2 * b

        ck = {x: i for i, x in enumerate(kopf(tb["Cover"]))}
        zeilen = [[re.sub("<[^>]+>", "", c) for c in r] for r in tb["Cover"]["Body"]]
        umschlag = None
        einzelteil = None
        if "Buchrücken" in ck:
            roh = []
            for r in zeilen:
                cw, ch = (x * faktor for x in zahlen(r[ck["Abmessungen"]])[:2])
                sp = zahlen(r[ck["Buchrücken"]])[0] * faktor
                falz = zahlen(r[ck["Falzbereich"]])[0] * faktor
                if "Beschnitt links/rechts" in ck:
                    seitlich = zahlen(r[ck["Beschnitt links/rechts"]])[0] * faktor
                    oben = zahlen(r[ck["Beschnitt oben/unten"]])[0] * faktor
                else:
                    seitlich = oben = zahlen(r[ck["Beschnitt"]])[0] * faktor
                ab = int(zahlen(r[ck["Seitenanzahl"]])[0])
                roh.append((ab, cw, ch, sp, falz, seitlich, oben))
            oben = roh[0][6]
            seitlich = roh[0][5]
            hoehe = roh[0][2] - 2 * oben
            # DIE HÄLFTE IST FEST, DER RÜCKEN FOLGT DER GESAMTBREITE.
            # Saals Rückenspalte ist gerundet und springt in anderen
            # Schritten als die Bogenbreite; beide zugleich gehen nicht auf.
            # Genau getroffen wird die BOGENBREITE — die prüft der Dienst an
            # der Datei. Der Beschnitt links/rechts, der über den oben/unten
            # hinausgeht, liegt in der App als Teil der Hälfte.
            haelfte = statistics.median((cw - 2 * oben - sp) / 2 for _, cw, _, sp, *_ in roh)
            haelfte = round(haelfte * 20) / 20
            stufen = []
            for ab, cw, _, sp, falz, *_ in roh:
                eff = round(cw - 2 * oben - 2 * haelfte, 2)
                if not stufen or stufen[-1][1] != eff or stufen[-1][2] != cw or stufen[-1][3] != sp:
                    stufen.append((ab, eff, cw, sp, falz))
            umschlag = dict(haelfte=haelfte, hoehe=hoehe, anschnitt=oben, seitlich=seitlich,
                            stufen=stufen, hoehe_bogen=roh[0][2])
        else:
            cw, ch = (x * faktor for x in zahlen(zeilen[0][ck["Abmessungen"]])[:2])
            cb = zahlen(zeilen[0][ck["Beschnitt"]])[0] * faktor
            einzelteil = (cw, ch, cb)

        kern = (reihe, name, json.dumps(umschlag), json.dumps(einzelteil), seite_b, seite_h, b,
                doppelt, von, bis)
        produkte.setdefault(kern, []).append(papier)
    return produkte


def s(text):
    return json.dumps(text, ensure_ascii=False).replace("×", "\\u{00D7}")


def zahl(x):
    x = round(x, 2)
    return str(int(x)) if x == int(x) else repr(x)


def schreiben(produkte):
    zeilen = []
    kennungen = set()
    for (reihe, name, umschlag, einzelteil, sb, sh, b, doppelt, von, bis), papiere in produkte.items():
        kurz, reihenname = REIHEN[reihe]
        masse = re.findall(r"(\d+)\s*x\s*(\d+)", name.replace("\xa0", " "))[0]
        zusatz = " (ca. A4)" if "ca. A4" in name else ""
        titel = f"{masse[0]} × {masse[1]}{zusatz}"
        kennung = f"saal-{kurz}-{masse[0]}x{masse[1]}"
        if len([k for k in produkte if k[0] == reihe and k[1] == name]) > 1:
            erstes = papiere[0].lower()
            kennung += "-" + ("foto" if erstes.startswith("fotopapier")
                              else re.sub(r"[^a-z]", "", erstes.replace("-", " ").split()[0]))
        assert kennung not in kennungen, kennung
        kennungen.add(kennung)
        u = json.loads(umschlag)
        e = json.loads(einzelteil)
        teile = [
            f"id: {s(kennung)}",
            f"reihe: {s(reihenname)}",
            f"name: {s(titel)}",
            f"papiere: {s(', '.join(papiere))}",
            f"seiteBreite: {zahl(sb)}, seiteHoehe: {zahl(sh)}",
            f"anschnitt: {zahl(b)}, doppelseiten: {'true' if doppelt else 'false'}",
            f"seitenVon: {von}, seitenBis: {bis}",
        ]
        if u:
            stufen = ", ".join(
                f".init({ab}, {zahl(eff)}, {zahl(cw)}, {zahl(sp)}, {zahl(fz)})"
                for ab, eff, cw, sp, fz in u["stufen"])
            teile.append(
                f"umschlag: .init(haelfteBreite: {zahl(u['haelfte'])}, haelfteHoehe: {zahl(u['hoehe'])}, "
                f"anschnitt: {zahl(u['anschnitt'])}, anschnittSeitlich: {zahl(u['seitlich'])}, "
                f"bogenhoehe: {zahl(u['hoehe_bogen'])}, stufen: [{stufen}])")
        if e:
            teile.append(f"einzelteil: .init(breite: {zahl(e[0])}, hoehe: {zahl(e[1])}, anschnitt: {zahl(e[2])})")
        zeilen.append("        Druckprodukt(\n            " + ",\n            ".join(teile) + "),")
    text = f"""// ERZEUGT von `scripts/saal-produkte.py` — nicht von Hand bearbeiten.
//
// Die Maße stehen so da, wie Saal Digital sie am {time.strftime('%d.%m.%Y')} über die
// Schnittstelle seiner Seite „Profibereich" herausgegeben hat, in Millimetern.
// Wer sie erneuern will, lässt das Skript noch einmal laufen.
enum Saalprodukte {{
    static let stand = {s(time.strftime('%d.%m.%Y'))}

    static let alle: [Druckprodukt] = [
{chr(10).join(zeilen)}
    ]
}}
"""
    ZIEL.write_text(text, encoding="utf-8")
    print(f"{len(zeilen)} Produkte nach {ZIEL} geschrieben.")


if __name__ == "__main__":
    daten = json.load(open(sys.argv[1])) if len(sys.argv) > 1 else holen()
    schreiben(auswerten(daten))
