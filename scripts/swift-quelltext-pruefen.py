#!/usr/bin/env python3
"""Prüft Swift-Dateien auf falsch geschlossene Anführungszeichen.

Hintergrund: Deutsche Anführungszeichen werden gern als „Text" geschrieben —
das schließende Zeichen ist dann ein gerades ", das ein Swift-String-Literal
vorzeitig beendet. Der Compiler meldet daraufhin „unterminated string literal".
Diese Prüfung findet das in Sekunden, ohne Xcode.

Zwei Regeln, weil eine nicht reichte:

1. Ungerade Zahl gerader Anführungszeichen in einer Zeile.
2. Ein „ , das vor dem nächsten geraden " kein “ bekommt. Das fängt den
   Fall, an dem die erste Regel vorbeisah: Stehen ZWEI verunglückte
   Anführungen in einer Zeile („Seite 1", „Seite 2"), ist die Zahl wieder
   gerade — der Compiler stolpert trotzdem.

Aufruf:  python3 scripts/swift-quelltext-pruefen.py [Ordner ...]
"""
import re
import sys
import glob
import os

MEHRZEILIG = '"""'
STRING = re.compile(r'(?<!\\)"')


def ohne_kommentar(zeile):
    """Schneidet einen nachgestellten Kommentar ab — aber nur, wenn das //
    wirklich außerhalb eines Textes steht (sonst zerschnitte es URLs)."""
    offen = False
    vorher = ''
    for i, zeichen in enumerate(zeile):
        if zeichen == '"' and vorher != '\\':
            offen = not offen
        elif zeichen == '/' and vorher == '/' and not offen:
            return zeile[:i - 1]
        vorher = zeichen
    return zeile


def entkerne(zeile):
    """Nimmt heraus, was die Anführungsprüfung sonst in die Irre führt.

    * `\\u{201C}` ist ein geschriebenes “ — also auch als solches lesen.
    * Was in einer Einsetzung `\\(…)` steht, ist Code, kein Text; dort
      stehende Anführungszeichen gehören nicht zum umgebenden Satz.
    * Maskierte Anführungszeichen zählen ohnehin nicht.
    """
    text = (zeile.replace('\\u{201C}', '“')
                 .replace('\\u{201D}', '“')
                 .replace('\\"', ''))
    vorher = None
    while vorher != text:
        vorher = text
        text = re.sub(r'\\\([^()]*\)', '', text)
    return text


def deutsche_anfuehrung(zeile):
    """Findet ein „, das mit einem geraden " geschlossen wird."""
    stelle = zeile.find('„')
    while stelle != -1:
        rest = zeile[stelle + 1:]
        zu = rest.find('“')
        gerade = rest.find('"')
        if gerade != -1 and (zu == -1 or gerade < zu):
            return True
        stelle = zeile.find('„', stelle + 1)
    return False


def pruefe_datei(pfad):
    fehler = []
    in_mehrzeiler = False
    for nummer, zeile in enumerate(open(pfad, encoding='utf-8').read().split('\n'), 1):
        gestutzt = zeile.strip()
        if gestutzt.count(MEHRZEILIG) == 1:
            in_mehrzeiler = not in_mehrzeiler
            continue
        if in_mehrzeiler or gestutzt.startswith('//'):
            continue
        code = ohne_kommentar(zeile)
        ohne_escapes = code.replace('\\"', '')
        if len(STRING.findall(ohne_escapes)) % 2 == 1:
            fehler.append((nummer, 'ungerade Anzahl gerader Anführungszeichen',
                           gestutzt[:120]))
        elif deutsche_anfuehrung(entkerne(code)):
            fehler.append((nummer, '„ wird mit einem geraden " geschlossen',
                           gestutzt[:120]))
    return fehler


def main():
    ordner = sys.argv[1:] or ['.']
    dateien = []
    for eintrag in ordner:
        if os.path.isfile(eintrag):
            dateien.append(eintrag)
        else:
            dateien += glob.glob(os.path.join(eintrag, '**', '*.swift'), recursive=True)

    alle = []
    for datei in sorted(set(dateien)):
        for nummer, grund, text in pruefe_datei(datei):
            alle.append(f"{datei}:{nummer}: {grund} -> {text}")

    if alle:
        print("Gefundene Probleme:")
        for zeile in alle:
            print("  " + zeile)
        print(f"\n{len(alle)} Zeile(n) prüfen — meist ein gerades \" innerhalb eines Textes;")
        print("in deutschen Texten gehört dorthin das schließende Zeichen “.")
        return 1

    print(f"{len(set(dateien))} Swift-Dateien geprüft — alle String-Literale sauber geschlossen.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
