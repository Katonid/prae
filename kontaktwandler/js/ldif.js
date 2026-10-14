// Schreibt Kontakte als LDIF (RFC 2849), so wie Thunderbird es selbst
// ausgibt und wieder einliest.
//
// Drei Stellen, an denen ein LDIF still kaputtgeht:
//
// 1. Ein Wert mit Umlaut, ß oder Akzent darf NICHT einfach dastehen. Erlaubt
//    ist dort nur ASCII; alles andere kommt als „attribut:: <Base64 von
//    UTF-8>". Wer „Müller" roh hinschreibt, bekommt je nach Programm
//    „MÃ¼ller" oder gar keinen Eintrag.
// 2. Dasselbe gilt für Werte, die mit Leerzeichen, Doppelpunkt oder „<"
//    anfangen oder mit einem Leerzeichen enden — sonst liest der Empfänger
//    sie als etwas anderes (Base64-Marke, Dateiverweis) oder schneidet ab.
// 3. Im DN („dn: cn=…,mail=…") trennen Kommas die Teile. Ein Komma im
//    Namen („Müller, Anna") muss deshalb als „\," stehen (RFC 4514), sonst
//    zerfällt der Name in zwei Teile.
//
// Zeilen werden nach 76 Zeichen gefaltet; die Fortsetzung beginnt mit EINEM
// Leerzeichen. Weil nach Regel 1 nur ASCII übrig bleibt, ist ein Zeichen
// hier immer genau ein Byte — anders als beim Falten der .ics im
// Terminkonverter muss nicht nach Oktetten gezählt werden.

const BREITE = 76;

function base64(text) {
  const bytes = new TextEncoder().encode(text);
  let binaer = '';
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binaer += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binaer);
}

// SAFE-STRING nach RFC 2849: nur ASCII ohne NUL, CR, LF; nicht beginnend mit
// Leerzeichen, „:" oder „<". Das Leerzeichen am Ende ist erlaubt, wird aber
// von zu vielen Programmen abgeschnitten — also lieber Base64.
function istSicher(wert) {
  if (wert === '') return true;
  if (/[^\x01-\x09\x0b\x0c\x0e-\x7f]/.test(wert)) return false;
  if (/^[ :<]/.test(wert)) return false;
  if (/ $/.test(wert)) return false;
  return true;
}

function falte(zeile) {
  if (zeile.length <= BREITE) return zeile;
  const teile = [zeile.slice(0, BREITE)];
  for (let i = BREITE; i < zeile.length; i += BREITE - 1) {
    teile.push(' ' + zeile.slice(i, i + BREITE - 1));
  }
  return teile.join('\n');
}

export function attribut(name, wert) {
  return falte(istSicher(wert) ? `${name}: ${wert}` : `${name}:: ${base64(wert)}`);
}

// Ein Wert im DN nach RFC 4514: , + " \ < > ; immer, # und Leerzeichen am
// Anfang und das Leerzeichen am Ende ebenfalls.
export function dnWert(wert) {
  return wert
    .replace(/[,+"\\<>;]/g, (z) => '\\' + z)
    .replace(/^([ #])/, '\\$1')
    .replace(/ $/, '\\ ');
}

export function kontaktDn(kontakt) {
  return `cn=${dnWert(kontakt.anzeige)},mail=${dnWert(kontakt.mail)}`;
}

// Reihenfolge und Namen der Attribute wie in Thunderbirds eigener Ausgabe.
const ATTRIBUTE = [
  ['givenName', 'vorname'],
  ['sn', 'nachname'],
  ['cn', 'anzeige'],
  ['mail', 'mail'],
  ['mozillaSecondEmail', 'mail2'],
  ['telephoneNumber', 'telefon'],
  ['mobile', 'mobil'],
  ['o', 'organisation'],
  ['description', 'notiz'],
];

function eintrag(kontakt) {
  const zeilen = [
    attribut('dn', kontaktDn(kontakt)),
    'objectclass: top',
    'objectclass: person',
    'objectclass: organizationalPerson',
    'objectclass: inetOrgPerson',
    'objectclass: mozillaAbPersonAlpha',
  ];
  for (const [name, feld] of ATTRIBUTE) {
    const wert = (kontakt[feld] || '').trim();
    if (wert) zeilen.push(attribut(name, wert));
  }
  return zeilen.join('\n');
}

// Eine Verteilerliste ist in LDIF ein „groupOfNames", dessen Mitglieder
// über ihren DN genannt werden. Sie steht HINTER den Kontakten: Thunderbird
// ordnet die Mitglieder beim Einlesen zu und findet nur, was schon da ist.
function liste(name, kontakte) {
  const zeilen = [
    attribut('dn', `cn=${dnWert(name)}`),
    'objectclass: top',
    'objectclass: groupOfNames',
    attribut('cn', name),
  ];
  for (const kontakt of kontakte) zeilen.push(attribut('member', kontaktDn(kontakt)));
  return zeilen.join('\n');
}

export function ldifBauen(kontakte, einstellungen = {}) {
  const bloecke = kontakte.map(eintrag);
  const listenname = (einstellungen.liste || '').trim();
  if (listenname && kontakte.length) bloecke.push(liste(listenname, kontakte));
  return bloecke.join('\n\n') + '\n';
}
