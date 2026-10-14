// Aus Tabellenzeilen werden Kontakte.
//
// Welche Spalte was enthält, wird aus der Überschrift geraten und lässt sich
// danach in der Oberfläche umstellen. Die E-Mail-Spalte wird notfalls am
// INHALT erkannt (die Spalte mit den meisten „@"): Eine Liste ohne
// Überschrift ist häufig, und an der Adresse hängt alles.
//
// Nichts wird still verschluckt: Jede Zeile, aus der kein Kontakt wird, steht
// mit Grund in den Hinweisen — eine fehlende Adresse fällt sonst erst auf,
// wenn jemand die Rundmail nicht bekommen hat.

export const FELDER = [
  { schluessel: 'vorname', name: 'Vorname' },
  { schluessel: 'nachname', name: 'Nachname' },
  { schluessel: 'anzeige', name: 'Anzeigename (ganzer Name)' },
  { schluessel: 'mail', name: 'E-Mail' },
  { schluessel: 'mail2', name: 'Zweite E-Mail' },
  { schluessel: 'telefon', name: 'Telefon' },
  { schluessel: 'mobil', name: 'Mobil' },
  { schluessel: 'organisation', name: 'Organisation' },
  { schluessel: 'notiz', name: 'Notiz' },
];

const zwei = (n) => String(n).padStart(2, '0');

// Der Text einer Zelle. Ein Excel-Datum (ein Geburtstag in der Liste) kommt
// als Datum heraus, nicht als Seriennummer.
export function zellText(zelle) {
  if (!zelle) return '';
  if (zelle.art === 'datum' && zelle.datum) {
    const d = zelle.datum;
    return `${zwei(d.tag)}.${zwei(d.monat)}.${d.jahr}`;
  }
  return String(zelle.text || '').trim();
}

const ADRESSE = /[^\s@<>()[\]{},;:"'´`]+@[^\s@<>()[\]{},;:"'´`]+\.[^\s@<>()[\]{},;:"'´`.]{2,}/gu;

// Alle Adressen in einer Zelle — auch „Anna <anna@example.org>",
// „mailto:anna@example.org" und zwei Adressen mit ; oder Zeilenumbruch.
export function adressenIn(text) {
  return Array.from(String(text || '').matchAll(ADRESSE), (t) => t[0]
    .replace(/^mailto:/i, '')
    .replace(/[.]+$/, ''));
}

const einfach = (text) => String(text || '').toLowerCase().replace(/[^a-zäöüß0-9]/g, '');

// Erkennung je Feld an der Überschrift. Die Reihenfolge zählt: „E-Mail 2"
// muss vor „E-Mail" geprüft werden, „Vorname" vor „Name".
const MERKMALE = [
  ['mail2', (t) => /mail/.test(t) && /(2|zweit|weitere|alternativ)/.test(t)],
  ['mail', (t) => /mail/.test(t)],
  ['mobil', (t) => /(mobil|handy|cell)/.test(t)],
  ['telefon', (t) => /^(tel|telefon|phone|festnetz|rufnummer|telefonnummer)/.test(t) || /telefon/.test(t)],
  ['vorname', (t) => /(vorname|rufname|firstname|givenname)/.test(t)],
  ['nachname', (t) => /(nachname|familienname|zuname|lastname|surname)/.test(t)],
  ['anzeige', (t) => /^(anzeigename|displayname|fullname|vollständigername|kontakt|schüler|schülerin|schülername|person|teilnehmer|teilnehmerin|mitglied)$/.test(t)],
  ['organisation', (t) => /^(firma|organisation|organization|schule|unternehmen|company|institution|verein)$/.test(t)],
  ['notiz', (t) => /^(notiz|notizen|bemerkung|bemerkungen|anmerkung|kommentar|notes?|hinweis|klasse|gruppe|funktion)$/.test(t)],
];

function anzahlSpalten(zeilen) {
  return zeilen.reduce((max, z) => Math.max(max, z.zellen.length), 0);
}

// Ist die erste Zeile eine Überschrift? Ja, wenn darin keine Adresse steht,
// darunter aber schon.
export function hatKopfzeile(zeilen) {
  if (zeilen.length < 2) return false;
  const oben = zeilen[0].zellen.some((z) => adressenIn(zellText(z)).length);
  if (oben) return false;
  return zeilen.slice(1, 6).some((zeile) => zeile.zellen.some((z) => adressenIn(zellText(z)).length));
}

// Gibt { feld: spaltenIndex } zurück, -1 heißt „keine Spalte".
export function zuordnungRaten(zeilen, kopf) {
  const zuordnung = Object.fromEntries(FELDER.map((f) => [f.schluessel, -1]));
  const spalten = anzahlSpalten(zeilen);
  const vergeben = new Set();

  if (kopf && zeilen.length) {
    const ueberschriften = Array.from({ length: spalten }, (_, i) => einfach(zellText(zeilen[0].zellen[i])));
    for (const [feld, passt] of MERKMALE) {
      const index = ueberschriften.findIndex((t, i) => t && !vergeben.has(i) && passt(t));
      if (index >= 0) { zuordnung[feld] = index; vergeben.add(index); }
    }
    // „E-Mail Mutter" und „E-Mail Vater": die zweite Mailspalte ist die
    // zweite Adresse.
    if (zuordnung.mail2 < 0) {
      const noch = ueberschriften.findIndex((t, i) => !vergeben.has(i) && /mail/.test(t));
      if (noch >= 0) { zuordnung.mail2 = noch; vergeben.add(noch); }
    }
    // „Name" allein: neben einer Vornamen-Spalte ist es der Nachname, sonst
    // der ganze Name.
    const name = ueberschriften.findIndex((t, i) => !vergeben.has(i) && /^(name|namen)$/.test(t));
    if (name >= 0) {
      const feld = zuordnung.vorname >= 0 && zuordnung.nachname < 0 ? 'nachname'
        : zuordnung.anzeige < 0 ? 'anzeige' : null;
      if (feld) { zuordnung[feld] = name; vergeben.add(name); }
    }
  }

  // Die Adresse notfalls am Inhalt erkennen.
  const daten = kopf ? zeilen.slice(1) : zeilen;
  if (zuordnung.mail < 0) {
    let beste = -1, meiste = 0;
    for (let i = 0; i < spalten; i++) {
      if (vergeben.has(i)) continue;
      const treffer = daten.filter((z) => adressenIn(zellText(z.zellen[i])).length).length;
      if (treffer > meiste) { beste = i; meiste = treffer; }
    }
    if (beste >= 0) { zuordnung.mail = beste; vergeben.add(beste); }
  }

  // Ohne Überschrift: Die erste Textspalte, in der keine Adresse steht, wird
  // der Name — besser als gar keiner, und die Auswahl darüber zeigt es an.
  if (!kopf && zuordnung.anzeige < 0 && zuordnung.vorname < 0 && zuordnung.nachname < 0) {
    for (let i = 0; i < spalten; i++) {
      if (vergeben.has(i)) continue;
      const texte = daten.map((z) => zellText(z.zellen[i])).filter(Boolean);
      if (texte.length && texte.every((t) => !adressenIn(t).length && !/^[\d\s+/()-]+$/.test(t))) {
        zuordnung.anzeige = i;
        break;
      }
    }
  }
  return zuordnung;
}

// Beschriftung einer Spalte für die Auswahllisten: Buchstabe und
// Überschrift — oder, ohne Überschrift, der erste Wert als Beispiel.
export function spaltenNamen(zeilen, kopf) {
  const spalten = anzahlSpalten(zeilen);
  return Array.from({ length: spalten }, (_, i) => {
    let buchstabe = '';
    for (let n = i + 1; n > 0; n = Math.floor((n - 1) / 26)) {
      buchstabe = String.fromCharCode(65 + ((n - 1) % 26)) + buchstabe;
    }
    const daten = kopf ? zeilen.slice(1) : zeilen;
    const titel = kopf ? zellText(zeilen[0].zellen[i]) : '';
    const beispiel = (daten.find((z) => zellText(z.zellen[i])) || { zellen: [] }).zellen[i];
    const zusatz = titel || (beispiel ? `z. B. „${zellText(beispiel).slice(0, 30)}"` : '(leer)');
    return `Spalte ${buchstabe} · ${zusatz}`;
  });
}

function namensform(vorname, nachname, reihenfolge) {
  if (vorname && nachname) return reihenfolge === 'nv' ? `${nachname}, ${vorname}` : `${vorname} ${nachname}`;
  return vorname || nachname || '';
}

export function kontakteBauen(zeilen, { kopf, zuordnung, reihenfolge = 'vn' }) {
  const kontakte = [];
  const hinweise = [];
  const gesehen = new Map();
  const wert = (zeile, feld) => (zuordnung[feld] >= 0 ? zellText(zeile.zellen[zuordnung[feld]]) : '')
    .replace(/\s+/g, ' ').trim();

  if (zuordnung.mail < 0) {
    return { kontakte, hinweise: [{ zeile: 0, text: 'Keine Spalte ist als „E-Mail" gewählt.' }] };
  }

  for (const zeile of kopf ? zeilen.slice(1) : zeilen) {
    const rohMail = zellText(zeile.zellen[zuordnung.mail]);
    const adressen = adressenIn(rohMail);
    const zweite = zuordnung.mail2 >= 0 ? adressenIn(zellText(zeile.zellen[zuordnung.mail2])) : [];

    let vorname = wert(zeile, 'vorname');
    let nachname = wert(zeile, 'nachname');
    let anzeige = wert(zeile, 'anzeige');
    const wer = anzeige || namensform(vorname, nachname, 'vn') || '';

    if (!adressen.length) {
      hinweise.push({
        zeile: zeile.nummer,
        text: rohMail
          ? `${wer || 'ohne Namen'}: „${rohMail}" ist keine gültige E-Mail-Adresse.`
          : `${wer || zeile.zellen.map(zellText).filter(Boolean).join(' · ')}: keine E-Mail-Adresse.`,
      });
      continue;
    }

    const mail = adressen[0];
    const schluessel = mail.toLowerCase();
    if (gesehen.has(schluessel)) {
      hinweise.push({ zeile: zeile.nummer, text: `${mail} steht schon in Zeile ${gesehen.get(schluessel)} — doppelt, nur einmal übernommen.` });
      continue;
    }
    gesehen.set(schluessel, zeile.nummer);

    // Zwei Adressen in einer Zelle (Eltern!) — die zweite wird zur zweiten
    // Adresse desselben Kontakts. Eine dritte hat in Thunderbird keinen Platz.
    const weitere = [...adressen.slice(1), ...zweite].filter((a) => a.toLowerCase() !== schluessel);
    const mail2 = weitere[0] || '';
    if (weitere.length > 1) {
      hinweise.push({ zeile: zeile.nummer, text: `${mail}: mehr als zwei Adressen — nicht übernommen: ${weitere.slice(1).join(', ')}.` });
    }

    // „Müller, Anna" in einer einzigen Namensspalte ist eindeutig genug, um
    // Vor- und Nachnamen auszufüllen. Ein Name mit Leerzeichen dagegen nicht
    // („Anna Lena Müller", „Hans von Bergen") — da wird nichts geraten.
    if (anzeige && !vorname && !nachname) {
      const teile = anzeige.split(',').map((t) => t.trim());
      if (teile.length === 2 && teile[0] && teile[1]) {
        [nachname, vorname] = teile;
        anzeige = namensform(vorname, nachname, reihenfolge);
      }
    }
    if (!anzeige) anzeige = namensform(vorname, nachname, reihenfolge) || mail;

    kontakte.push({
      zeile: zeile.nummer,
      vorname,
      nachname,
      anzeige,
      mail,
      mail2,
      telefon: wert(zeile, 'telefon'),
      mobil: wert(zeile, 'mobil'),
      organisation: wert(zeile, 'organisation'),
      notiz: wert(zeile, 'notiz'),
    });
  }
  return { kontakte, hinweise };
}
