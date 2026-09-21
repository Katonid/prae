// Baut aus den Textblöcken eine EPUB-Datei.
//
// Ein EPUB ist ein ZIP mit vorgeschriebenem Innenleben: eine Datei „mimetype"
// als ERSTER Eintrag und UNGEPACKT (daran erkennen Lesegeräte das Format, ohne
// das Archiv zu öffnen), dazu ein Verzeichnis META-INF, eine Beschreibung
// (content.opf), ein Inhaltsverzeichnis und die Kapitel als XHTML.
//
// Geschrieben wird das ZIP hier selbst — gepackt mit CompressionStream, wo der
// Browser es mitbringt, sonst ungepackt abgelegt. Ungepackt ist ausdrücklich
// erlaubt; die Datei wird dann größer, bleibt aber gültig.

const koder = new TextEncoder();

// -------------------------------------------------------------- ZIP-Schreiber

const CRC_TABELLE = (() => {
  const tabelle = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let wert = i;
    for (let n = 0; n < 8; n++) wert = wert & 1 ? 0xedb88320 ^ (wert >>> 1) : wert >>> 1;
    tabelle[i] = wert >>> 0;
  }
  return tabelle;
})();

function crc32(daten) {
  let wert = 0xffffffff;
  for (let i = 0; i < daten.length; i++) {
    wert = CRC_TABELLE[(wert ^ daten[i]) & 0xff] ^ (wert >>> 8);
  }
  return (wert ^ 0xffffffff) >>> 0;
}

async function packe(daten) {
  if (typeof CompressionStream !== 'function' || daten.length < 64) return null;
  try {
    const strom = new Blob([daten]).stream().pipeThrough(new CompressionStream('deflate-raw'));
    const gepackt = new Uint8Array(await new Response(strom).arrayBuffer());
    return gepackt.length < daten.length ? gepackt : null;
  } catch (fehler) {
    return null;                                     // dann eben ungepackt
  }
}

function dosZeit(datum) {
  const zeit = ((datum.getHours() & 31) << 11) | ((datum.getMinutes() & 63) << 5)
    | ((datum.getSeconds() / 2) & 31);
  const tag = (((datum.getFullYear() - 1980) & 127) << 9) | ((datum.getMonth() + 1) << 5)
    | datum.getDate();
  return { zeit, tag };
}

// Einträge in der übergebenen Reihenfolge; `roh: true` heißt „nicht packen".
export async function zipSchreiben(eintraege, datum = new Date()) {
  const { zeit, tag } = dosZeit(datum);
  const stuecke = [];
  const verzeichnis = [];
  let versatz = 0;

  const schreibe = (laenge, felder) => {
    const puffer = new Uint8Array(laenge);
    const sicht = new DataView(puffer.buffer);
    for (const [stelle, breite, wert] of felder) {
      if (breite === 2) sicht.setUint16(stelle, wert, true);
      else sicht.setUint32(stelle, wert, true);
    }
    return { puffer, sicht };
  };

  for (const eintrag of eintraege) {
    const name = koder.encode(eintrag.name);
    const roh = eintrag.daten instanceof Uint8Array ? eintrag.daten : koder.encode(eintrag.daten);
    const gepackt = eintrag.roh ? null : await packe(roh);
    const daten = gepackt || roh;
    const verfahren = gepackt ? 8 : 0;
    const pruefsumme = crc32(roh);

    const { puffer: kopf, sicht } = schreibe(30, [
      [0, 4, 0x04034b50], [4, 2, 20], [6, 2, 0], [8, 2, verfahren],
      [10, 2, zeit], [12, 2, tag], [14, 4, pruefsumme],
      [18, 4, daten.length], [22, 4, roh.length],
      [26, 2, name.length], [28, 2, 0],
    ]);
    stuecke.push(kopf, name, daten);
    verzeichnis.push({ name, verfahren, pruefsumme, gepackt: daten.length, roh: roh.length, versatz });
    versatz += kopf.length + name.length + daten.length;
    void sicht;
  }

  const verzeichnisAnfang = versatz;
  for (const eintrag of verzeichnis) {
    const { puffer } = schreibe(46, [
      [0, 4, 0x02014b50], [4, 2, 20], [6, 2, 20], [8, 2, 0], [10, 2, eintrag.verfahren],
      [12, 2, zeit], [14, 2, tag], [16, 4, eintrag.pruefsumme],
      [20, 4, eintrag.gepackt], [24, 4, eintrag.roh],
      [28, 2, eintrag.name.length], [30, 2, 0], [32, 2, 0], [34, 2, 0], [36, 2, 0],
      [38, 4, 0], [42, 4, eintrag.versatz],
    ]);
    stuecke.push(puffer, eintrag.name);
    versatz += puffer.length + eintrag.name.length;
  }

  const { puffer: abschluss } = schreibe(22, [
    [0, 4, 0x06054b50], [4, 2, 0], [6, 2, 0],
    [8, 2, verzeichnis.length], [10, 2, verzeichnis.length],
    [12, 4, versatz - verzeichnisAnfang], [16, 4, verzeichnisAnfang], [20, 2, 0],
  ]);
  stuecke.push(abschluss);

  const gesamt = stuecke.reduce((summe, stueck) => summe + stueck.length, 0);
  const aus = new Uint8Array(gesamt);
  let ziel = 0;
  for (const stueck of stuecke) {
    aus.set(stueck, ziel);
    ziel += stueck.length;
  }
  return aus;
}

// ------------------------------------------------------------------- EPUB

function maskiere(text) {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    // Steuerzeichen sind in XML verboten; ein einziges macht die ganze Datei
    // unlesbar, und das Lesegerät sagt dazu nur „beschädigt".
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, '');
}

const nummer = (n) => String(n).padStart(3, '0');

// Kapitel schneiden: an jeder Überschrift der obersten vorkommenden Ebene.
// Ohne Überschriften wird nach Länge geteilt — ein einziges XHTML mit
// tausend Absätzen öffnet auf älteren Lesegeräten quälend langsam.
export function kapitelSchneiden(bloecke, titel) {
  const ebenen = bloecke.filter((b) => b.ueberschrift).map((b) => b.ebene || 2);
  let oberste = ebenen.length ? Math.min(...ebenen) : null;
  // Eine Stufe, die nur EINMAL vorkommt, ist ein Titel und keine
  // Einteilung: Danach zu schneiden ergäbe ein einziges Kapitel, das das
  // ganze Buch enthält — und ein Inhaltsverzeichnis mit einem Eintrag.
  if (oberste !== null && ebenen.filter((e) => e === oberste).length === 1) {
    const tiefer = ebenen.filter((e) => e > oberste);
    if (tiefer.length) oberste = Math.min(...tiefer);
  }
  const kapitel = [];
  let aktuell = null;

  const neu = (ueberschrift) => {
    aktuell = { titel: ueberschrift || titel, bloecke: [], hatUeberschrift: Boolean(ueberschrift) };
    kapitel.push(aktuell);
  };

  for (const block of bloecke) {
    const trennt = oberste !== null && block.ueberschrift && (block.ebene || 2) === oberste;
    if (trennt || !aktuell) {
      if (trennt) neu(block.text);
      else neu(null);
    }
    if (oberste === null && aktuell.bloecke.length >= 120) neu(null);
    aktuell.bloecke.push(block);
  }
  if (!kapitel.length) neu(null);
  return kapitel.filter((k) => k.bloecke.length);
}

function kapitelXhtml(kapitel, sprache) {
  const koerper = kapitel.bloecke.map((block, index) => {
    const text = maskiere(block.text);
    if (block.marke) return `  <p class="marke">${text}</p>`;
    if (block.ueberschrift) {
      const stufe = index === 0 ? 'h1' : `h${Math.min(3, (block.ebene || 2) + 0)}`;
      return `  <${stufe}>${text}</${stufe}>`;
    }
    return `  <p>${text}</p>`;
  }).join('\n');

  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="${sprache}" lang="${sprache}">
<head>
  <meta charset="utf-8"/>
  <title>${maskiere(kapitel.titel)}</title>
  <link rel="stylesheet" type="text/css" href="../stil.css"/>
</head>
<body>
${koerper}
</body>
</html>
`;
}

// Der Stil einer EPUB ist ein VORSCHLAG, keine Anweisung. Ein Lesegerät
// bringt seine eigene Schrift, seinen Zeilenabstand und seine Ränder mit,
// und der Leser stellt sie ein — in Bücher (Apple Books) entscheidet
// darüber der Schalter zwischen „Original" und einer eigenen Schrift.
// Deshalb steht hier nur, was sonst falsch aussähe, und die gewählte
// Schrift als Wunsch. Eingebettet wird keine: Eine Schriftdatei wöge mehr
// als das ganze Buch, und weitergeben darf man längst nicht jede.
function stil(schriftCss, abstand) {
  return `/* Schrift und Zeilenabstand sind ein Vorschlag — das Lesegerät
   und sein Besitzer haben das letzte Wort. */
body { margin: 0 1em;${schriftCss ? ` font-family: ${schriftCss};` : ''}`
    + `${abstand ? ` line-height: ${abstand};` : ''} }
h1, h2, h3 { line-height: 1.25; margin: 1.4em 0 .6em; }
h1 { font-size: 1.5em; }
h2 { font-size: 1.25em; }
h3 { font-size: 1.1em; }
p { margin: 0 0 .8em; text-align: justify; hyphens: auto; }
p.marke { text-align: center; opacity: .6; font-size: .85em; }
`;
}

function kennung() {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) return `urn:uuid:${crypto.randomUUID()}`;
  const zufall = [...Array(32)].map(() => Math.floor(Math.random() * 16).toString(16)).join('');
  return `urn:uuid:${zufall.slice(0, 8)}-${zufall.slice(8, 12)}-4${zufall.slice(13, 16)}`
    + `-a${zufall.slice(17, 20)}-${zufall.slice(20, 32)}`;
}

export async function epubBauen(bloecke, einstellungen = {}) {
  const titel = (einstellungen.titel || 'Textauszug').trim() || 'Textauszug';
  const verfasser = (einstellungen.verfasser || '').trim();
  const sprache = einstellungen.sprache || 'de';
  const jetzt = einstellungen.jetzt || new Date();
  const gestempelt = `${jetzt.toISOString().slice(0, 19)}Z`;
  const buchId = einstellungen.kennung || kennung();

  const kapitel = kapitelSchneiden(bloecke, titel);
  const dateien = kapitel.map((teil, i) => ({
    id: `k${nummer(i + 1)}`,
    pfad: `text/k${nummer(i + 1)}.xhtml`,
    titel: teil.titel,
    inhalt: kapitelXhtml(teil, sprache),
  }));

  const opf = `<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="buchid" xml:lang="${sprache}">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="buchid">${maskiere(buchId)}</dc:identifier>
    <dc:title>${maskiere(titel)}</dc:title>
    <dc:language>${sprache}</dc:language>
${verfasser ? `    <dc:creator id="verfasser">${maskiere(verfasser)}</dc:creator>\n` : ''}    <meta property="dcterms:modified">${gestempelt}</meta>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="stil" href="stil.css" media-type="text/css"/>
${dateien.map((d) => `    <item id="${d.id}" href="${d.pfad}" media-type="application/xhtml+xml"/>`).join('\n')}
  </manifest>
  <spine toc="ncx">
${dateien.map((d) => `    <itemref idref="${d.id}"/>`).join('\n')}
  </spine>
</package>
`;

  const nav = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="${sprache}" lang="${sprache}">
<head><meta charset="utf-8"/><title>Inhalt</title></head>
<body>
  <nav epub:type="toc" id="toc">
    <h1>Inhalt</h1>
    <ol>
${dateien.map((d) => `      <li><a href="${d.pfad}">${maskiere(d.titel)}</a></li>`).join('\n')}
    </ol>
  </nav>
</body>
</html>
`;

  // Das alte Inhaltsverzeichnis kommt mit: Lesegeräte, die kein EPUB 3
  // sprechen, finden sonst überhaupt keine Gliederung.
  const ncx = `<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1" xml:lang="${sprache}">
  <head>
    <meta name="dtb:uid" content="${maskiere(buchId)}"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
  </head>
  <docTitle><text>${maskiere(titel)}</text></docTitle>
  <navMap>
${dateien.map((d, i) => `    <navPoint id="np${nummer(i + 1)}" playOrder="${i + 1}">
      <navLabel><text>${maskiere(d.titel)}</text></navLabel>
      <content src="${d.pfad}"/>
    </navPoint>`).join('\n')}
  </navMap>
</ncx>
`;

  const container = `<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
`;

  const eintraege = [
    // MUSS der erste Eintrag sein und MUSS ungepackt abgelegt werden.
    { name: 'mimetype', daten: 'application/epub+zip', roh: true },
    { name: 'META-INF/container.xml', daten: container },
    { name: 'OEBPS/content.opf', daten: opf },
    { name: 'OEBPS/nav.xhtml', daten: nav },
    { name: 'OEBPS/toc.ncx', daten: ncx },
    { name: 'OEBPS/stil.css', daten: stil(einstellungen.schriftCss, einstellungen.zeilenabstand) },
    ...dateien.map((d) => ({ name: `OEBPS/${d.pfad}`, daten: d.inhalt })),
  ];

  const daten = await zipSchreiben(eintraege, jetzt);
  return { daten, kapitel: dateien.length };
}

// Aus einem von Hand geänderten Text wieder Blöcke machen.
//
// Nötig, weil der Text im Feld bearbeitet werden darf: Danach passen die
// gemerkten Blöcke nicht mehr. Die Schriftgrößen sind dann verloren, also
// entscheidet die Gestalt — kurz, ohne Satzzeichen am Ende, und ein Absatz
// folgt darauf.
export function bloeckeAusText(text) {
  const stuecke = text.split(/\n{2,}/).map((s) => s.trim()).filter(Boolean);
  const istMarke = (stueck) => /^---\s*Seite\s+\d+\s*---$/i.test(stueck);
  // Gestalt einer Überschrift: eine kurze einzelne Zeile, die nicht wie ein
  // Satz endet.
  const gestalt = stuecke.map((stueck) => stueck.length <= 70 && !/\n/.test(stueck)
    && !/[.!?:;,]$/.test(stueck) && !istMarke(stueck));

  const bloecke = stuecke.map((stueck, i) => {
    // Dazu muss etwas folgen, das sie überschreibt. Für die ERSTE Zeile
    // gilt auch die nächste Überschrift als Beleg: „Mein Bericht" steht
    // über „Kapitel 1", also über einer ebenso kurzen Zeile. Für alle
    // anderen bleibt es beim längeren Absatz — sonst würde aus einem
    // „Mit freundlichen Grüßen" über einem Namen eine Überschrift.
    const folgt = i + 1 < stuecke.length
      && (stuecke[i + 1].length > stueck.length
        || (i === 0 && stuecke.length > 2 && gestalt[1]));
    return { text: stueck, marke: istMarke(stueck), ueberschrift: gestalt[i] && folgt, ebene: 2 };
  });

  // Die erste Überschrift, unter der weitere stehen, ist der TITEL des
  // Textes: in der PDF größer gesetzt, in der EPUB kein eigenes Kapitel.
  if (bloecke.length && bloecke[0].ueberschrift
      && bloecke.some((block, i) => i > 0 && block.ueberschrift)) {
    bloecke[0].ebene = 1;
  }
  return bloecke;
}
