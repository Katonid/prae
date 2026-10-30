#!/usr/bin/env python3
"""Baut aus einer MP4 eine absichtlich ungünstige Fassung für Tests:
erst alle Stücke der ersten Spur, dann alle der zweiten (Bild und Ton nicht
verzahnt), Inhaltsverzeichnis (moov) am Ende. Bild- und Tondaten bleiben gleich.

    python3 scripts/mp4-unverzahnt.py <ein.mp4> <aus.mp4>
"""
import struct, sys

def kisten(d, a, e):
    p = a
    while p + 8 <= e:
        g, art = struct.unpack('>I4s', d[p:p + 8]); k = 8
        if g == 1: g = struct.unpack('>Q', d[p + 8:p + 16])[0]; k = 16
        if g == 0: g = e - p
        yield art.decode('latin1'), p, p + k, p + g
        p += g

def finde(d, a, e, art):
    return next((x for x in kisten(d, a, e) if x[0] == art), None)

ein, aus = sys.argv[1:3]
d = bytearray(open(ein, 'rb').read())
oben = list(kisten(d, 0, len(d)))
moov = next(x for x in oben if x[0] == 'moov')
mv = bytearray(d[moov[1]:moov[3]])
spuren = []
for art, p, s, e in kisten(mv, 8, len(mv)):
    if art != 'trak': continue
    mdia = finde(mv, s, e, 'mdia'); minf = finde(mv, mdia[2], mdia[3], 'minf'); stbl = finde(mv, minf[2], minf[3], 'stbl')
    stsc = finde(mv, stbl[2], stbl[3], 'stsc'); stsz = finde(mv, stbl[2], stbl[3], 'stsz'); stco = finde(mv, stbl[2], stbl[3], 'stco')
    n = struct.unpack('>I', mv[stco[2] + 4:stco[2] + 8])[0]
    offs = [struct.unpack('>I', mv[stco[2] + 8 + 4 * i:stco[2] + 12 + 4 * i])[0] for i in range(n)]
    fest, pz = struct.unpack('>II', mv[stsz[2] + 4:stsz[2] + 12])
    gr = [fest or struct.unpack('>I', mv[stsz[2] + 12 + 4 * i:stsz[2] + 16 + 4 * i])[0] for i in range(pz)]
    scn = struct.unpack('>I', mv[stsc[2] + 4:stsc[2] + 8])[0]
    sc = [struct.unpack('>III', mv[stsc[2] + 8 + 12 * i:stsc[2] + 20 + 12 * i]) for i in range(scn)]
    stuecke, probe = [], 0
    for c in range(n):
        per = [x for x in sc if x[0] - 1 <= c][-1][1]
        stuecke.append((offs[c], sum(gr[probe:probe + per]))); probe += per
    spuren.append((stco[2] + 8, stuecke))
vorne = b''.join(bytes(d[p:e]) for art, p, s, e in oben if art not in ('moov', 'mdat', 'free'))
daten = bytearray(); neu = []
pos = len(vorne) + 8
for tab, st in spuren:
    liste = []
    for alt, g in st:
        liste.append(pos + len(daten)); daten += d[alt:alt + g]
    neu.append((tab, liste))
for tab, liste in neu:
    for i, o in enumerate(liste): mv[tab + 4 * i:tab + 4 * i + 4] = struct.pack('>I', o)
open(aus, 'wb').write(vorne + struct.pack('>I4s', len(daten) + 8, b'mdat') + bytes(daten) + bytes(mv))
