#!/usr/bin/env python3
"""Erzeugt `Urlaubstagebuch/Model/Whitewallprodukte.swift` aus Whitewalls
eigenen InDesign-Vorlagen — reines Python, ohne fremde Bibliotheken.

WOHER DIE ZAHLEN KOMMEN (gemessen 26.09.2026). Whitewalls Seite „PDF-Upload"
bietet je Format, Papier und Seitenzahl eine Vorlage zum Herunterladen an,
unter einer festen Adresse:

    https://downloads.whitewall.com/indesign/cover_<Format>_paper-<Papier>_<Seiten>.idml
    https://downloads.whitewall.com/indesign/block_<Format>_paper-<Papier>_<Seiten>.idml

Eine IDML-Datei ist ein ZIP. In `Resources/Preferences.xml` stehen Seitenmaß
und Beschnitt (in Punkt), in den Spreads die Hilfslinien — beim Umschlag je
drei um jede Rückenkante (Kante und 2 mm links und rechts). Daraus folgt der
Rücken, und zwar für JEDE Seitenzahl gemessen: Er wächst in Stufen (28 und 32
Seiten haben bei A4 hoch auf Fuji-Papier beide 11 mm), eine Rechnung
dazwischen wäre also geraten.

Die Namen der Formate und Papiere stehen in keiner Liste, die sich abrufen
ließe; sie sind durch Nachfragen gefunden (eine Adresse, die es nicht gibt,
antwortet mit 403). Abgefragt werden 28 bis 200 Seiten in Viererschritten —
Whitewall bietet nichts anderes an.

    python3 scripts/whitewall-produkte.py
"""
import concurrent.futures as cf
import io
import re
import sys
import urllib.request
import zipfile
from pathlib import Path

BASIS = "https://downloads.whitewall.com/indesign/"
ZIEL = Path(__file__).resolve().parent.parent / "Urlaubstagebuch" / "Model" / "Whitewallprodukte.swift"
STAND = "26.09.2026"
PT = 25.4 / 72

# Schlüssel in der Adresse → Reihe (Whitewalls Produktname), Kürzel.
FORMATE = [
    ("A4portrait", "Exhibition A4 hoch", "a4h"),
    ("A4landscape", "Exhibition A4 quer", "a4q"),
    ("A4square", "Story Quadrat", "sq20"),
    ("A3square", "Gallery Quadrat", "sq29"),
    ("A3portrait", "Portfolio A3 hoch", "a3h"),
    ("A3landscape", "Portfolio A3 quer", "a3q"),
]
PAPIERE = [
    ("fujiCrystal-semi-matte", "Fotopapier seidenmatt", "Fuji Crystal Archive Lustre", "lustre"),
    ("fujiCrystal-glossy", "Fotopapier glänzend", "Fuji Crystal Archive Glossy", "glossy"),
    ("fujiCrystal-velvet", "Fotopapier tiefmatt", "Fuji Crystal Archive Velvet", "velvet"),
    ("digital-glossy", "Inkjet glänzend", "Fedrigoni Symbol Freelife Gloss", "inkgloss"),
    ("digital-highgloss", "Inkjet hochglänzend", "Fedrigoni Symbol Freelife Gloss mit Hochglanzlack", "inkhigh"),
    ("digital-matte", "Inkjet seidenmatt", "Sappi Magno Volume", "inkmatt"),
]
SEITEN = list(range(28, 204, 4))


def lesen(name):
    try:
        daten = urllib.request.urlopen(BASIS + name, timeout=60).read()
    except Exception:
        return None
    z = zipfile.ZipFile(io.BytesIO(daten))
    pref = z.read("Resources/Preferences.xml").decode("utf-8")

    def wert(schluessel):
        return float(re.search(schluessel + r'="([^"]+)"', pref).group(1)) * PT

    beschnitt = {k: float(v) * PT for k, v in re.findall(
        r'DocumentBleed(TopOffset|BottomOffset|InsideOrLeftOffset|OutsideOrRightOffset)="([^"]+)"', pref)}
    linien = set()
    for n in z.namelist():
        if n.startswith("Spreads/"):
            s = z.read(n).decode("utf-8")
            for x in re.findall(r'<Guide [^>]*Orientation="Vertical"[^>]*Location="([^"]+)"', s):
                linien.add(round(float(x) * PT, 2))
    return {"breite": wert("PageWidth"), "hoehe": wert("PageHeight"),
            "beschnitt": beschnitt, "linien": sorted(linien)}


def r(x):
    return round(x * 100) / 100


def zahl(x):
    x = r(x)
    return str(int(x)) if x == int(x) else repr(x)


def main():
    auftraege = []
    for f, _, _ in FORMATE:
        for p, _, _, _ in PAPIERE:
            auftraege.append(("block", f, p, 28))
            for n in SEITEN:
                auftraege.append(("cover", f, p, n))

    ergebnis = {}
    with cf.ThreadPoolExecutor(8) as ex:
        for auftrag, antwort in zip(auftraege, ex.map(
                lambda a: lesen(f"{a[0]}_{a[1]}_paper-{a[2]}_{a[3]}.idml"), auftraege)):
            if antwort:
                ergebnis[auftrag] = antwort
    print(f"{len(ergebnis)} Vorlagen gelesen", file=sys.stderr)

    zeilen = []
    for f, reihe, fk in FORMATE:
        for p, papier, sorte, pk in PAPIERE:
            block = ergebnis.get(("block", f, p, 28))
            if not block:
                continue
            b = block["beschnitt"]
            # Einzelseiten, Beschnitt oben/unten/außen, am Bund keiner.
            assert abs(b["InsideOrLeftOffset"]) < 0.01, (f, p, b)
            anschnitt = r(b["TopOffset"])
            stufen = []
            haelfte = hoehe = cb = cs = None
            von = bis = None
            for n in SEITEN:
                c = ergebnis.get(("cover", f, p, n))
                if not c:
                    continue
                # Die sechs Linien: je drei um die linke und die rechte
                # Rückenkante (Kante in der Mitte, 2 mm davor und dahinter).
                l = c["linien"]
                assert len(l) == 6, (f, p, n, l)
                links, rechts = l[1], l[4]
                ruecken = r(rechts - links)
                h = r(links)
                assert abs(r(c["breite"] - rechts) - h) < 0.05, (f, p, n, c["breite"], l)
                if haelfte is None:
                    haelfte, hoehe = h, r(c["hoehe"])
                    cb = r(c["beschnitt"]["TopOffset"])
                    cs = r(c["beschnitt"]["InsideOrLeftOffset"])
                assert abs(h - haelfte) < 0.05 and abs(r(c["hoehe"]) - hoehe) < 0.05, (f, p, n)
                von = n if von is None else von
                bis = n
                if not stufen or stufen[-1][1] != ruecken:
                    bogen = r(2 * haelfte + ruecken + 2 * cs)
                    stufen.append((n, ruecken, bogen))
            if not stufen:
                continue
            st = ", ".join(f".init({n}, {zahl(ru)}, {zahl(bo)}, {zahl(ru)}, 0)"
                           for n, ru, bo in stufen)
            zeilen.append(f"""        Druckprodukt(
            id: "ww-{fk}-{pk}",
            anbieter: "WhiteWall",
            reihe: "{reihe}",
            name: "{papier}",
            papiere: "{sorte}",
            seiteBreite: {zahl(block['breite'])}, seiteHoehe: {zahl(block['hoehe'])},
            anschnitt: {zahl(anschnitt)}, doppelseiten: false, anschnittAmBund: false,
            sicherheitsabstand: 5, sicherheitsabstandInnen: 0, seiteEinsLinks: false,
            seitenVon: {von}, seitenBis: {bis}, seitenSchritt: 4,
            quelle: "Aus WhiteWalls InDesign-Vorlagen am \\(Whitewallprodukte.stand) gelesen",
            umschlag: .init(haelfteBreite: {zahl(haelfte)}, haelfteHoehe: {zahl(hoehe)}, anschnitt: {zahl(cb)}, anschnittSeitlich: {zahl(cs)}, bogenhoehe: {zahl(hoehe + 2 * cb)}, stufen: [{st}])),""")

    text = f"""// ERZEUGT von `scripts/whitewall-produkte.py` — nicht von Hand bearbeiten.
//
// Die Maße stehen so da, wie sie in WhiteWalls InDesign-Vorlagen am {STAND}
// standen (downloads.whitewall.com/indesign/…), in Millimetern — der Rücken
// für jede Seitenzahl einzeln gelesen. Wer sie erneuern will, lässt das
// Skript noch einmal laufen.
enum Whitewallprodukte {{
    static let stand = "{STAND}"

    static let alle: [Druckprodukt] = [
{chr(10).join(zeilen)}
    ]
}}
"""
    ZIEL.write_text(text, encoding="utf-8")
    print(f"{len(zeilen)} Produkte nach {ZIEL}", file=sys.stderr)


if __name__ == "__main__":
    main()
