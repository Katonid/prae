#!/usr/bin/env python3
"""Erzeugt js/schriftmasse.js — die Zeichenbreiten der 14 Standardschriften.

Warum das sein muss: Ein PDF bricht Zeilen nicht selbst um. Wer eine Zeile
setzt, muss vorher wissen, wie breit sie wird — sonst läuft sie über den Rand
hinaus, und zwar erst beim Öffnen auf dem Gerät des Nutzers.

Woher die Zahlen kommen: aus den Liberation-Schriften, die auf jedem
Linux-Bau daneben liegen. Sie sind maßgleich mit Arial, Times New Roman und
Courier New — und die wiederum mit Helvetica, Times und Courier, den drei
Familien der 14 Standardschriften, die JEDES PDF-Programm mitbringt. Deshalb
muss in der fertigen PDF keine Schrift eingebettet werden: Die Datei bleibt
ein paar Kilobyte groß und sieht überall gleich aus.

Geraten wird dabei nichts: PRUEFSTEINE unten nennt die Werte aus Adobes
Originaltabellen. Weicht eine ab, bricht das Skript ab — eine falsche Breite
sähe man dem Quelltext nie an, wohl aber der siebten Seite eines Buches.

    python3 scripts/schriftmasse.py
"""

import struct
import sys
from pathlib import Path

SCHRIFTEN = Path('/usr/share/fonts/truetype/liberation')

# Liberation-Datei -> Name im PDF (Standardschrift)
PAARE = [
    ('LiberationSans-Regular.ttf', 'Helvetica'),
    ('LiberationSans-Bold.ttf', 'Helvetica-Bold'),
    ('LiberationSans-Italic.ttf', 'Helvetica-Oblique'),
    ('LiberationSans-BoldItalic.ttf', 'Helvetica-BoldOblique'),
    ('LiberationSerif-Regular.ttf', 'Times-Roman'),
    ('LiberationSerif-Bold.ttf', 'Times-Bold'),
    ('LiberationSerif-Italic.ttf', 'Times-Italic'),
    ('LiberationSerif-BoldItalic.ttf', 'Times-BoldItalic'),
    ('LiberationMono-Regular.ttf', 'Courier'),
    ('LiberationMono-Bold.ttf', 'Courier-Bold'),
    ('LiberationMono-Italic.ttf', 'Courier-Oblique'),
    ('LiberationMono-BoldItalic.ttf', 'Courier-BoldOblique'),
]

# Werte aus den Original-AFM-Dateien von Adobe. Zeichen: Leerzeichen, A, a,
# m, W, Punkt.
PRUEFSTEINE = {
    'Helvetica': (278, 667, 556, 833, 944, 278),
    'Helvetica-Bold': (278, 722, 556, 889, 944, 278),
    'Helvetica-Oblique': (278, 667, 556, 833, 944, 278),
    'Helvetica-BoldOblique': (278, 722, 556, 889, 944, 278),
    'Times-Roman': (250, 722, 444, 778, 944, 250),
    'Times-Bold': (250, 722, 500, 833, 1000, 250),
    'Times-Italic': (250, 611, 500, 722, 833, 250),
    'Times-BoldItalic': (250, 667, 500, 778, 889, 250),
    'Courier': (600, 600, 600, 600, 600, 600),
    'Courier-Bold': (600, 600, 600, 600, 600, 600),
    'Courier-Oblique': (600, 600, 600, 600, 600, 600),
    'Courier-BoldOblique': (600, 600, 600, 600, 600, 600),
}


def tabellen(daten):
    anzahl = struct.unpack('>H', daten[4:6])[0]
    aus = {}
    for i in range(anzahl):
        p = 12 + i * 16
        tag = daten[p:p + 4].decode('latin1')
        off, laenge = struct.unpack('>II', daten[p + 8:p + 16])
        aus[tag] = (off, laenge)
    return aus


def zeichenzuordnung(daten, stelle):
    """cmap, Format 4 — die Zuordnung Unicode-Nummer -> Glyphe."""
    fmt = struct.unpack('>H', daten[stelle:stelle + 2])[0]
    if fmt != 4:
        raise SystemExit(f'cmap-Format {fmt} wird hier nicht gelesen')
    segX2 = struct.unpack('>H', daten[stelle + 6:stelle + 8])[0]
    seg = segX2 // 2
    ende = [struct.unpack('>H', daten[stelle + 14 + i * 2:stelle + 16 + i * 2])[0] for i in range(seg)]
    p = stelle + 16 + segX2                      # das eine übersprungene Feld ist reservedPad
    start = [struct.unpack('>H', daten[p + i * 2:p + 2 + i * 2])[0] for i in range(seg)]
    p += segX2
    delta = [struct.unpack('>h', daten[p + i * 2:p + 2 + i * 2])[0] for i in range(seg)]
    p += segX2
    bereichAb = p
    bereich = [struct.unpack('>H', daten[p + i * 2:p + 2 + i * 2])[0] for i in range(seg)]

    def glyphe(nummer):
        for i in range(seg):
            if nummer <= ende[i]:
                if nummer < start[i]:
                    return 0
                if bereich[i] == 0:
                    return (nummer + delta[i]) & 0xffff
                wo = bereichAb + i * 2 + bereich[i] + (nummer - start[i]) * 2
                g = struct.unpack('>H', daten[wo:wo + 2])[0]
                return 0 if g == 0 else (g + delta[i]) & 0xffff
        return 0

    return glyphe


def breiten(pfad):
    """Die Vorschubbreiten für die WinAnsi-Codes 32 bis 255, in 1/1000 em."""
    daten = pfad.read_bytes()
    t = tabellen(daten)
    kopf = t['head'][0]
    em = struct.unpack('>H', daten[kopf + 18:kopf + 20])[0]
    hhea = t['hhea'][0]
    anzahlHM = struct.unpack('>H', daten[hhea + 34:hhea + 36])[0]
    hmtx = t['hmtx'][0]
    vorschub = [struct.unpack('>H', daten[hmtx + i * 4:hmtx + i * 4 + 2])[0] for i in range(anzahlHM)]

    cm = t['cmap'][0]
    anzahl = struct.unpack('>H', daten[cm + 2:cm + 4])[0]
    ziel = None
    for i in range(anzahl):
        pid, eid, off = struct.unpack('>HHI', daten[cm + 4 + i * 8:cm + 4 + i * 8 + 8])
        if (pid, eid) in ((3, 1), (0, 3), (0, 4)):
            ziel = cm + off
            if (pid, eid) == (3, 1):
                break
    if ziel is None:
        raise SystemExit(f'{pfad.name}: keine brauchbare cmap')
    glyphe = zeichenzuordnung(daten, ziel)

    aus = []
    for code in range(32, 256):
        try:
            zeichen = bytes([code]).decode('cp1252')
        except UnicodeDecodeError:
            aus.append(0)                        # im WinAnsi-Satz unbelegt
            continue
        g = glyphe(ord(zeichen))
        aus.append(round(vorschub[g if g < len(vorschub) else -1] * 1000 / em) if g else 0)
    return aus


def main():
    if not SCHRIFTEN.is_dir():
        raise SystemExit(f'{SCHRIFTEN} fehlt — Paket fonts-liberation installieren.\n'
                         'Ohne die Schriften lässt sich die Tabelle nicht neu rechnen; '
                         'die erzeugte js/schriftmasse.js liegt im Repo und gilt weiter.')

    zeilen = []
    for datei, name in PAARE:
        werte = breiten(SCHRIFTEN / datei)
        probe = tuple(werte[c - 32] for c in (32, 65, 97, 109, 87, 46))
        soll = PRUEFSTEINE[name]
        if probe != soll:
            raise SystemExit(f'{name}: {probe} statt {soll} — die Schrift ist nicht maßgleich.')
        zeilen.append(f"  '{name}':\n    '" + ' '.join(str(w) for w in werte) + "',")

    inhalt = '''// ERZEUGT von scripts/schriftmasse.py — nicht von Hand ändern.
//
// Die Vorschubbreiten der 14 Standardschriften, in Tausendstel der
// Schriftgröße, für die WinAnsi-Codes 32 bis 255 (0 = dort steht kein
// Zeichen). Ein PDF bricht keine Zeile selbst um: Wer setzt, muss messen.
//
// Eingebettet wird deshalb keine Schrift — Helvetica, Times und Courier
// bringt jedes PDF-Programm mit, und die fertige Datei bleibt ein paar
// Kilobyte groß.

const ROH = {
%s
};

const GEMESSEN = new Map();

// Die vier Schnitte je Familie. Die Namen sind die, die im PDF stehen.
export const FAMILIEN = {
  serifenlos: {
    name: 'Serifenlos (Helvetica)',
    normal: 'Helvetica',
    fett: 'Helvetica-Bold',
    kursiv: 'Helvetica-Oblique',
    fettkursiv: 'Helvetica-BoldOblique',
    css: 'Helvetica, Arial, sans-serif',
  },
  serif: {
    name: 'Mit Serifen (Times)',
    normal: 'Times-Roman',
    fett: 'Times-Bold',
    kursiv: 'Times-Italic',
    fettkursiv: 'Times-BoldItalic',
    css: '"Times New Roman", Times, serif',
  },
  schreibmaschine: {
    name: 'Schreibmaschine (Courier)',
    normal: 'Courier',
    fett: 'Courier-Bold',
    kursiv: 'Courier-Oblique',
    fettkursiv: 'Courier-BoldOblique',
    css: '"Courier New", Courier, monospace',
  },
};

export function familie(schluessel) {
  return FAMILIEN[schluessel] || FAMILIEN.serifenlos;
}

// Einmal aus der Zeichenkette in Zahlen — danach ist jede Messung ein
// Tabellenzugriff.
function tabelle(schriftname) {
  let werte = GEMESSEN.get(schriftname);
  if (!werte) {
    const roh = ROH[schriftname];
    if (!roh) throw new Error(`Unbekannte Schrift: ${schriftname}`);
    werte = new Uint16Array(256);
    const teile = roh.split(' ');
    for (let i = 0; i < teile.length; i++) werte[i + 32] = Number(teile[i]);
    GEMESSEN.set(schriftname, werte);
  }
  return werte;
}

// Welche der zwölf Tabellen gehört zu dieser Schrift? Gebraucht beim LESEN
// einer fremden PDF: Eine Standardschrift bringt kein /Widths mit — sie
// muss keines mitbringen, jedes Programm kennt ihre Maße. Ohne diese
// Zuordnung nimmt der Leser für jedes Zeichen 500/1000 an, und dann steht
// das „i" so breit da wie das „m": Zeilen, Leerzeichen und die Erkennung
// von Absätzen hängen aber genau an dieser Zahl.
//
// Der Name darf einen Vorsatz für eine Teilmenge tragen (ABCDEF+Arial-BoldMT),
// und Arial, Helvetica und Nimbus Sans sind dasselbe Maß.
export function standardbreiten(grundname) {
  if (!grundname) return null;
  const roh = String(grundname).replace(/^[A-Z]{6}\+/, '').toLowerCase().replace(/[^a-z]/g, '');
  let schluessel = null;
  if (/courier|mono/.test(roh)) schluessel = 'schreibmaschine';
  else if (/helvetica|arial|sans|grotesk|verdana|tahoma/.test(roh)) schluessel = 'serifenlos';
  else if (/times|roman|serif|georgia|garamond|book/.test(roh)) schluessel = 'serif';
  if (!schluessel) return null;                // lieber raten lassen als falsch messen

  const satz = FAMILIEN[schluessel];
  const fett = /bold|black|heavy|semibold/.test(roh);
  const kursiv = /italic|oblique/.test(roh);
  if (fett && kursiv) return tabelle(satz.fettkursiv);
  if (fett) return tabelle(satz.fett);
  if (kursiv) return tabelle(satz.kursiv);
  return tabelle(satz.normal);
}

// Die Breite einer Folge von WinAnsi-BYTES, in Punkt.
export function breite(bytes, schriftname, groesse) {
  const werte = tabelle(schriftname);
  let summe = 0;
  for (let i = 0; i < bytes.length; i++) summe += werte[bytes[i]] || 0;
  return (summe * groesse) / 1000;
}
''' % '\n'.join(zeilen)

    ziel = Path(__file__).resolve().parent.parent / 'js' / 'schriftmasse.js'
    ziel.write_text(inhalt, encoding='utf-8')
    print(f'{ziel} geschrieben ({len(inhalt) // 1024} KB, {len(PAARE)} Schnitte)')


if __name__ == '__main__':
    sys.exit(main())
