// Von Unicode nach WinAnsi — der Zeichensatz, den ein PDF ohne eingebettete
// Schrift versteht.
//
// Die 14 Standardschriften kennen 224 Zeichen, nicht 150.000. Was darin
// steht, deckt deutschen Text vollständig ab: Umlaute, ß, die typografischen
// Anführungszeichen „ " ‚ ', Gedankenstrich, Auslassungspunkte, das
// Eurozeichen. Was NICHT darin steht — ein Pfeil, ein griechischer
// Buchstabe, ein Emoji —, wird durch ein Fragezeichen ersetzt und GEZÄHLT:
// Die App sagt hinterher, wie viele Zeichen sie nicht setzen konnte. Ein
// stillschweigend verschlucktes Zeichen wäre genau die Art Fehler, die erst
// auf Seite sieben auffällt.

// Die Codes 0x80 bis 0x9F sind der einzige Teil, in dem WinAnsi von Latin-1
// abweicht; darüber sind Code und Unicode-Nummer dieselben.
const OBEN = {
  0x20ac: 0x80, 0x201a: 0x82, 0x0192: 0x83, 0x201e: 0x84, 0x2026: 0x85,
  0x2020: 0x86, 0x2021: 0x87, 0x02c6: 0x88, 0x2030: 0x89, 0x0160: 0x8a,
  0x2039: 0x8b, 0x0152: 0x8c, 0x017d: 0x8e, 0x2018: 0x91, 0x2019: 0x92,
  0x201c: 0x93, 0x201d: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97,
  0x02dc: 0x98, 0x2122: 0x99, 0x0161: 0x9a, 0x203a: 0x9b, 0x0153: 0x9c,
  0x017e: 0x9e, 0x0178: 0x9f,
};

// Wird VOR der Zuordnung nachgeschlagen, darf also auch Zeichen betreffen,
// die es in WinAnsi gibt. Zwei davon sind wichtig: Das weiche Trennzeichen
// hat dort eine sichtbare Gestalt — unverändert stünde mitten im Wort ein
// Bindestrich. Und ein geschütztes Leerzeichen ist ein Leerzeichen; die
// PDF kennt ohnehin nur Zeilen, die schon umbrochen sind.
const ERSATZ = {
  0x00ad: '', 0x200b: '', 0x200c: '', 0x200d: '', 0xfeff: '',
  0x00a0: ' ', 0x2007: ' ', 0x2009: ' ', 0x202f: ' ', 0x2002: ' ',
  0x2003: ' ', 0x0009: ' ', 0x000a: ' ', 0x000d: ' ',
  0x2010: '-', 0x2011: '-', 0x2012: '-', 0x2015: '—', 0x2212: '-',
  0x2032: "'", 0x2033: '"', 0x02bc: "'", 0x2044: '/',
  0x2190: '<-', 0x2192: '->', 0x2194: '<->', 0x21d2: '=>',
  0x2264: '<=', 0x2265: '>=', 0x2260: '!=',
  0x25cf: '•', 0x25aa: '•', 0x25a0: '•', 0x25e6: '•', 0x2219: '•',
  0x2043: '•', 0x2500: '-', 0x2013: '–',
};

function einzeln(nummer) {
  if (nummer >= 0x20 && nummer <= 0x7e) return nummer;
  if (OBEN[nummer] !== undefined) return OBEN[nummer];
  if (nummer >= 0xa0 && nummer <= 0xff) return nummer;
  return null;
}

function anhaengen(bytes, text) {
  for (const zeichen of text) {
    const byte = einzeln(zeichen.codePointAt(0));
    if (byte !== null) bytes.push(byte);
  }
}

// Gibt die Bytes zurück und dazu, wie oft ein Zeichen nicht zu setzen war.
export function nachWinAnsi(text) {
  const bytes = [];
  let ersetzt = 0;
  const unbekannt = new Set();

  for (const zeichen of String(text)) {
    const nummer = zeichen.codePointAt(0);

    const ausweich = ERSATZ[nummer];
    if (ausweich !== undefined) { anhaengen(bytes, ausweich); continue; }

    const gerade = einzeln(nummer);
    if (gerade !== null) { bytes.push(gerade); continue; }

    // Ein zusammengesetztes Zeichen kann nach der Zerlegung passen (ein ē
    // aus e und Strich darüber). Erst danach ist es wirklich nicht
    // darstellbar — und der Grundbuchstabe ist mehr wert als ein
    // Fragezeichen.
    const zerlegt = zeichen.normalize('NFKD').replace(/[̀-ͯ]/g, '');
    if (zerlegt && [...zerlegt].every((z) => einzeln(z.codePointAt(0)) !== null)) {
      anhaengen(bytes, zerlegt);
      continue;
    }

    bytes.push(0x3f);                      // Fragezeichen — sichtbar, nicht still
    ersetzt++;
    if (unbekannt.size < 12) unbekannt.add(zeichen);
  }

  return { bytes: Uint8Array.from(bytes), ersetzt, unbekannt: [...unbekannt] };
}
