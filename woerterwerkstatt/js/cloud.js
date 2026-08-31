// Die Netzseite: Konten für Lehrkräfte, Klassen und die Anmeldung der Kinder.
//
// Ohne Netz funktioniert die App vollständig — alle mitgelieferten Bereiche,
// alle fünf Übungen, der ganze Fortschritt liegen im Gerät. Was hier steht,
// betrifft nur das, was zwischen Lehrkraft und Klasse hin und her muss.
//
// Angesprochen werden die REST-Schnittstellen von Firebase (Realtime Database
// und Identity Toolkit) mit derselben `firebase-config.js` aus dem
// Wurzelverzeichnis, die auch der Klassenraum benutzt. Kein SDK: Das wären
// mehrere hundert Kilobyte, die nachgeladen werden müssten — und ohne Netz
// bliebe die App dann beim Start hängen.
//
// Wie die vierstellige PIN eines Kindes geschützt ist
// ----------------------------------------------------
// Gar nicht durch Verstecken im Gerät — das wäre keins. Sondern so:
//
// * Gespeichert wird nie die PIN, sondern ein SHA-256-Abdruck über
//   Klassencode + Benutzername + PIN. Zwei Kinder mit derselben PIN in
//   verschiedenen Klassen haben verschiedene Abdrücke.
// * Der Abdruck liegt in einem Zweig der Datenbank, den NIEMAND lesen darf
//   (`geheim/<CODE>/<Kind>`). Auch nicht die App selbst.
// * Angemeldet wird deshalb durch einen Schreibversuch: Die App schreibt den
//   errechneten Abdruck nach `anmeldung/<CODE>/<Kind>`. Die Datenbankregel
//   lässt das nur zu, wenn er mit dem hinterlegten übereinstimmt. Geht der
//   Schreibversuch durch, war die PIN richtig — ohne dass irgendwer den
//   hinterlegten Abdruck je zu Gesicht bekommt.
//
// Ehrlich dazugesagt: Eine vierstellige PIN hat zehntausend Möglichkeiten, und
// gegen jemanden, der sie alle durchprobiert, hilft ohne eigenen Server
// nichts. Das ist bewusst so — es geht um Rechtschreibfortschritte einer
// Grundschulklasse, nicht um Zeugnisnoten. Wer mehr Schutz braucht, gibt den
// Kindern keinen Zugang, sondern übt am gemeinsamen Gerät.

import { beitrittscode } from './util.js';

const WURZEL = 'woerterwerkstatt';
const KONTO_SCHLUESSEL = 'woerterwerkstatt.konto.v1';

let konfiguration = null;
let start = null;
let kontenMoeglich = null; // null = noch unbekannt
let konto = null;
let verwaltungsrecht = null; // Schulverwaltung: null = ungeprüft (siehe unten)
let verwaltungsfrage = null; // die laufende Prüfung, damit nicht zwei losgehen
const horcher = new Set();

function konfigLaden() {
  return new Promise((fertig, fehler) => {
    if (window.firebaseConfig) { fertig(window.firebaseConfig); return; }
    const knoten = document.createElement('script');
    knoten.src = '../firebase-config.js';
    knoten.addEventListener('load', () => fertig(window.firebaseConfig));
    knoten.addEventListener('error', () => fehler(new Error('Keine Konfiguration gefunden')));
    document.head.appendChild(knoten);
  });
}

function kontoHolen() {
  try {
    const roh = window.localStorage.getItem(KONTO_SCHLUESSEL);
    if (!roh) return;
    const gelesen = JSON.parse(roh);
    if (gelesen && gelesen.refreshToken) konto = gelesen;
  } catch (_) { konto = null; }
}

function kontoSichern() {
  try {
    if (konto) window.localStorage.setItem(KONTO_SCHLUESSEL, JSON.stringify(konto));
    else window.localStorage.removeItem(KONTO_SCHLUESSEL);
  } catch (_) { /* gesperrter Speicher — dann gilt es nur für diese Sitzung */ }
  horcher.forEach((fn) => fn(angemeldet()));
}

export function wolkeStarten() {
  if (start) return start;
  start = (async () => {
    konfiguration = await konfigLaden();
    if (!konfiguration || !konfiguration.databaseURL || !konfiguration.apiKey) {
      throw new Error('Die Konfiguration ist unvollständig');
    }
    kontoHolen();
    kontenPruefen();
    return true;
  })().catch((fehler) => { start = null; throw fehler; });
  return start;
}

async function kontenPruefen() {
  try {
    const antwort = await fetch(`https://identitytoolkit.googleapis.com/v1/projects?key=${konfiguration.apiKey}`);
    kontenMoeglich = antwort.ok;
  } catch (_) {
    kontenMoeglich = null;
  }
  horcher.forEach((fn) => fn(angemeldet()));
}

/** true = Konten nutzbar, false = im Firebase-Projekt nicht freigeschaltet, null = unbekannt. */
export function kontenVerfuegbar() {
  return kontenMoeglich;
}

export function angemeldet() {
  if (!konto) return null;
  return { uid: konto.uid, email: konto.email, name: konto.name };
}

export function beiKontoWechsel(fn) {
  horcher.add(fn);
  fn(angemeldet());
  return () => horcher.delete(fn);
}

async function gueltigesZeichen() {
  if (!konto) return null;
  if (konto.laeuftAb && konto.laeuftAb - Date.now() > 60000) return konto.idToken;
  try {
    const antwort = await fetch(`https://securetoken.googleapis.com/v1/token?key=${konfiguration.apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(konto.refreshToken)}`,
    });
    if (!antwort.ok) throw new Error('abgelaufen');
    const daten = await antwort.json();
    konto = Object.assign({}, konto, {
      idToken: daten.id_token,
      refreshToken: daten.refresh_token,
      laeuftAb: Date.now() + Number(daten.expires_in || 3600) * 1000,
    });
    kontoSichern();
    return konto.idToken;
  } catch (_) {
    konto = null;
    kontoSichern();
    return null;
  }
}

/**
 * Eine Anfrage an die Datenbank — immer mit Zeitlimit. Eine hängende
 * Verbindung (Schul-WLAN!) darf eine Klasse nicht endlos auf „einen
 * Augenblick“ warten lassen.
 */
async function anfrage(pfad, optionen = {}, zusatz = {}, zeitlimit = 20000) {
  await wolkeStarten();
  const grund = String(konfiguration.databaseURL).replace(/\/$/, '');
  const adresse = new URL(`${grund}/${pfad}.json`);
  const zeichen = await gueltigesZeichen();
  if (zeichen) adresse.searchParams.set('auth', zeichen);
  for (const [name, wert] of Object.entries(zusatz)) adresse.searchParams.set(name, wert);

  const bremse = new AbortController();
  const uhr = setTimeout(() => bremse.abort(), zeitlimit);
  let antwort;
  try {
    antwort = await fetch(adresse.toString(), Object.assign({}, optionen, { signal: bremse.signal }));
  } catch (fehler) {
    if (fehler && fehler.name === 'AbortError') throw new Error('ZEITUEBERSCHREITUNG');
    throw new Error('KEINE_VERBINDUNG');
  } finally {
    clearTimeout(uhr);
  }
  if (antwort.status === 401 || antwort.status === 403) throw new Error('NICHT_ERLAUBT');
  if (!antwort.ok) {
    const text = await antwort.text().catch(() => '');
    throw new Error(`Server meldet ${antwort.status}${text ? `: ${text.slice(0, 120)}` : ''}`);
  }
  const roh = await antwort.text();
  return roh && roh !== 'null' ? JSON.parse(roh) : null;
}

function schreiben(pfad, wert, methode = 'PUT') {
  return anfrage(pfad, {
    method: methode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(wert),
  });
}

/* ---------- Konto der Lehrkraft ---------- */

function fehlerText(meldung) {
  if (meldung === 'CONFIGURATION_NOT_FOUND' || meldung === 'OPERATION_NOT_ALLOWED') return 'KONTEN_NICHT_AKTIV';
  if (meldung.startsWith('EMAIL_EXISTS')) return 'Diese E-Mail wird schon benutzt.';
  if (meldung.startsWith('INVALID_EMAIL')) return 'Die E-Mail-Adresse sieht nicht richtig aus.';
  if (meldung.startsWith('WEAK_PASSWORD')) return 'Das Passwort braucht mindestens sechs Zeichen.';
  if (meldung.startsWith('EMAIL_NOT_FOUND')) return 'Zu dieser E-Mail gibt es noch kein Konto.';
  if (meldung.startsWith('INVALID_PASSWORD') || meldung.startsWith('INVALID_LOGIN_CREDENTIALS')) return 'E-Mail oder Passwort stimmt nicht.';
  if (meldung.startsWith('TOO_MANY_ATTEMPTS')) return 'Zu viele Versuche — bitte später noch einmal.';
  return meldung || 'Unbekannter Fehler';
}

async function kontoAnfrage(punkt, koerper) {
  await wolkeStarten();
  const antwort = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:${punkt}?key=${konfiguration.apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(Object.assign({ returnSecureToken: true }, koerper)),
  }).catch(() => { throw new Error('Keine Verbindung zum Server.'); });
  const daten = await antwort.json().catch(() => ({}));
  if (!antwort.ok) {
    const meldung = daten && daten.error && daten.error.message ? daten.error.message : '';
    if (meldung === 'CONFIGURATION_NOT_FOUND' || meldung === 'OPERATION_NOT_ALLOWED') kontenMoeglich = false;
    throw new Error(fehlerText(meldung));
  }
  kontenMoeglich = true;
  return daten;
}

function sitzungMerken(daten, name) {
  // Ein anderes Konto, andere Rechte. Auf einem Lehrerrechner in der Schule
  // wechseln sie mehrmals am Tag — ein gemerktes „darf verwalten" von vorhin
  // wäre dann das Recht der Falschen.
  verwaltungsrecht = null;
  verwaltungsfrage = null;
  konto = {
    uid: daten.localId,
    email: daten.email,
    name: name || daten.displayName || '',
    idToken: daten.idToken,
    refreshToken: daten.refreshToken,
    laeuftAb: Date.now() + Number(daten.expiresIn || 3600) * 1000,
  };
  kontoSichern();
  return angemeldet();
}

export async function kontoAnlegen(email, passwort, name) {
  const daten = await kontoAnfrage('signUp', { email, password: passwort });
  if (name) await kontoAnfrage('update', { idToken: daten.idToken, displayName: name }).catch(() => {});
  const sitzung = sitzungMerken(daten, name);
  await schreiben(`${WURZEL}/users/${sitzung.uid}/profil`, { email, name: name || '', angelegtAm: Date.now() }).catch(() => {});
  return sitzung;
}

export async function anmelden(email, passwort) {
  const daten = await kontoAnfrage('signInWithPassword', { email, password: passwort });
  const sitzung = sitzungMerken(daten, daten.displayName);
  // Das Verzeichnis nachziehen. Nur beim ANLEGEN eines Kontos wurde bisher
  // ein Profil geschrieben — wer sich vor dieser Fassung angemeldet hat oder
  // bei wem der Schreibvorgang damals durchfiel, stand für die
  // Schulverwaltung ohne E-Mail da. Und ohne E-Mail lässt sich keine
  // Kennwort-Mail schicken: Der Knopf war ausgerechnet für die Kolleginnen
  // grau, um die es geht.
  //
  // Der Name wird bewusst NICHT mitgeschrieben: Hat die Verwaltung ihn
  // geändert, überschriebe ihn sonst die nächste Anmeldung der Lehrkraft.
  await schreiben(`${WURZEL}/users/${sitzung.uid}/profil`, {
    email: sitzung.email,
    zuletztAngemeldet: Date.now(),
  }, 'PATCH').catch(() => {});
  return sitzung;
}

export function abmelden() {
  konto = null;
  verwaltungsrecht = null;
  verwaltungsfrage = null;
  kontoSichern();
}

/* ---------- Eigene Bereiche im Konto ---------- */

export async function bereicheHochladen(bereiche) {
  if (!konto) throw new Error('Kein Konto angemeldet');
  const nutzlast = {};
  for (const bereich of bereiche) nutzlast[bereich.id] = bereich;
  await schreiben(`${WURZEL}/users/${konto.uid}/bereiche`, nutzlast);
}

export async function bereicheHolen() {
  if (!konto) throw new Error('Kein Konto angemeldet');
  const gelesen = await anfrage(`${WURZEL}/users/${konto.uid}/bereiche`);
  return gelesen ? Object.values(gelesen) : [];
}

/**
 * Was ist da schiefgegangen — in einem Satz, den man lesen kann.
 *
 * Der wichtigste Fall ist `NICHT_ERLAUBT`: Die Datenbank weist alles ab, weil
 * die Regeln für den Zweig `woerterwerkstatt` in der Firebase-Konsole fehlen.
 * Genau das ist im August 2026 passiert — es ließ sich keine Klasse anlegen,
 * und die App meldete dazu „NICHT_ERLAUBT". Das ist keine Meldung, das ist
 * ein Rätsel. Wer den Fehler sieht, muss erfahren, was zu tun ist.
 */
export function klartext(fehler) {
  const meldung = String((fehler && fehler.message) || fehler || '');
  if (meldung === 'NICHT_ERLAUBT') {
    return 'Die Datenbank lässt das nicht zu. Sehr wahrscheinlich fehlen ihre Regeln: '
      + 'In der Firebase-Konsole muss unter „Realtime Database → Regeln" der Inhalt von '
      + 'firebase-rules.json stehen (beide Zweige, klassenraum UND woerterwerkstatt). '
      + 'Ohne sie ist der Zweig dieser App gesperrt.';
  }
  if (meldung === 'KEINE_VERBINDUNG') return 'Keine Verbindung zur Datenbank. Ist das Gerät im Netz?';
  if (meldung === 'ZEITUEBERSCHREITUNG') return 'Die Datenbank hat zu lange nicht geantwortet. Noch einmal versuchen?';
  if (meldung === 'KONTEN_NICHT_AKTIV') {
    return 'In diesem Firebase-Projekt sind Konten nicht freigeschaltet '
      + '(Konsole → Authentication → Anmeldemethode → E-Mail/Passwort).';
  }
  return meldung || 'Unbekannter Fehler';
}

/**
 * Steht der Zweig dieser App in der Datenbank offen?
 *
 * Ein einzelner Lesezugriff auf einen Pfad, den es nicht gibt. Sind die Regeln
 * eingespielt, kommt `null` zurück; fehlen sie, weist die Datenbank ab. So
 * lässt sich der häufigste Einrichtungsfehler zeigen, BEVOR jemand eine halbe
 * Stunde lang rätselt, warum ein Knopf nichts tut.
 *
 * Rückgabe: 'ok' | 'regeln-fehlen' | 'kein-netz'
 */
export async function regelnPruefen() {
  try {
    await anfrage(`${WURZEL}/klassen/__pruefung`, {}, {}, 8000);
    return 'ok';
  } catch (fehler) {
    return String(fehler.message) === 'NICHT_ERLAUBT' ? 'regeln-fehlen' : 'kein-netz';
  }
}

/* ---------- Klassen ---------- */

/** Aus PIN, Klassencode und Namen einen Abdruck rechnen (SHA-256, als Hex). */
export async function abdruck(code, kind, pin) {
  const text = `woerterwerkstatt:${String(code).toUpperCase()}:${String(kind).toLowerCase()}:${String(pin)}`;
  const bytes = new TextEncoder().encode(text);
  const roh = await window.crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(roh)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** Benutzernamen vereinheitlichen: Kinder tippen mal groß, mal klein. */
export function namensschluessel(name) {
  return String(name || '').trim().toLocaleLowerCase('de-DE')
    .replace(/ä/g, 'ae').replace(/ö/g, 'oe').replace(/ü/g, 'ue').replace(/ß/g, 'ss')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 24);
}

/**
 * Eine Klasse anlegen. Der Code ist der Schlüssel: Wer ihn hat (per QR-Code
 * oder abgetippt), kann beitreten. Deshalb sechs Zeichen ohne I, O, 0 und 1.
 */
export async function klasseAnlegen({ name, bereiche = [], auftrag = null }) {
  if (!konto) throw new Error('Zum Anlegen einer Klasse braucht es ein Konto.');
  let code = beitrittscode();
  // Im äußerst unwahrscheinlichen Fall einer Doppelvergabe: neu würfeln.
  //
  // Der Fehler wird hier NICHT mehr verschluckt. Vorher stand da ein
  // `.catch(() => null)`, und damit lief eine gesperrte Datenbank stumm durch
  // bis zum Schreibversuch — der Prüfblick, der den Grund kennt, warf ihn weg.
  for (let versuch = 0; versuch < 5; versuch += 1) {
    const belegt = await anfrage(`${WURZEL}/klassen/${code}/angelegtAm`);
    if (!belegt) break;
    code = beitrittscode();
  }
  const klasse = {
    name: name || 'Meine Klasse',
    besitzer: konto.uid,
    besitzerName: konto.name || '',
    angelegtAm: Date.now(),
    bereiche: bereiche.reduce((sammlung, bereich) => { sammlung[bereich.id] = bereich; return sammlung; }, {}),
    auftrag,
  };
  await schreiben(`${WURZEL}/klassen/${code}`, klasse);
  await schreiben(`${WURZEL}/users/${konto.uid}/klassen/${code}`, { name: klasse.name, angelegtAm: klasse.angelegtAm });
  return Object.assign({ code }, klasse);
}

export async function klasseHolen(code) {
  const klasse = await anfrage(`${WURZEL}/klassen/${String(code).toUpperCase()}`);
  if (!klasse) throw new Error('KLASSE_UNBEKANNT');
  return Object.assign({ code: String(code).toUpperCase() }, klasse);
}

export async function klasseAendern(code, teile) {
  await schreiben(`${WURZEL}/klassen/${String(code).toUpperCase()}`, teile, 'PATCH');
}

/**
 * Eine Klasse löschen — samt allem, was an ihrem Code hängt.
 *
 * Zwei Dinge, die leicht schiefgehen:
 *
 * 1. **Die Reihenfolge.** Ob jemand `geheim/<CODE>` anfassen darf, liest die
 *    Datenbank an `klassen/<CODE>/besitzer` ab. Ist die Klasse zuerst weg,
 *    gibt es keinen Besitzer mehr — und die PIN-Abdrücke bleiben für immer
 *    liegen. Also erst die Nebenzweige, dann die Klasse.
 * 2. **Wessen Liste.** Löscht die Schulverwaltung, gehört die Klasse einer
 *    anderen Lehrkraft; deren Eintrag muss weg, nicht der eigene.
 */
export async function klasseLoeschen(code, besitzer = null) {
  const gross = String(code).toUpperCase();
  for (const zweig of ['geheim', 'anmeldung', 'protokoll']) {
    await anfrage(`${WURZEL}/${zweig}/${gross}`, { method: 'DELETE' }).catch(() => {});
  }
  await anfrage(`${WURZEL}/klassen/${gross}`, { method: 'DELETE' });
  const wem = besitzer || (konto ? konto.uid : null);
  if (wem) await anfrage(`${WURZEL}/users/${wem}/klassen/${gross}`, { method: 'DELETE' }).catch(() => {});
}

export async function klassenDerLehrkraft() {
  if (!konto) return [];
  const gelesen = await anfrage(`${WURZEL}/users/${konto.uid}/klassen`);
  if (!gelesen) return [];
  return Object.entries(gelesen).map(([code, eintrag]) => Object.assign({ code }, eintrag));
}

/**
 * Eine eigene Klasse (wieder) in die eigene Liste eintragen.
 *
 * `users/<uid>/klassen` ist nur ein VERZEICHNIS; die Klasse selbst steht unter
 * `klassen/<CODE>`. Fehlt der Verzeichniseintrag, ist die Klasse auf jedem
 * anderen Gerät unsichtbar — obwohl sie da ist, der QR-Code gilt und die
 * Kinder weiter üben. Das Anlegen schreibt beides, aber es sind zwei
 * Schreibvorgänge: Bricht der zweite ab (Netz weg im Schulhaus, Regeln noch
 * nicht eingespielt, Tab zugemacht), steht die Klasse ohne Eintrag da.
 *
 * Rückgabe: { stand, klasse } mit stand aus
 *   'eingetragen' | 'stand-schon-drin' | 'fremd' | 'unbekannt'
 */
export async function klasseWiederEintragen(code) {
  if (!konto) throw new Error('Dafür braucht es das Konto der Lehrkraft.');
  const gross = String(code).toUpperCase();
  const klasse = await anfrage(`${WURZEL}/klassen/${gross}`);
  if (!klasse) return { stand: 'unbekannt' };
  // Ohne Besitzer wird nichts angenommen. Den Code haben alle Kinder der
  // Klasse; er darf niemandem ein fremdes Klassenbuch in die Hand geben.
  if (klasse.besitzer !== konto.uid) return { stand: 'fremd', klasse };
  const drin = await anfrage(`${WURZEL}/users/${konto.uid}/klassen/${gross}`).catch(() => null);
  if (drin) return { stand: 'stand-schon-drin', klasse };
  await schreiben(`${WURZEL}/users/${konto.uid}/klassen/${gross}`, {
    name: klasse.name || 'Klasse',
    angelegtAm: klasse.angelegtAm || Date.now(),
  });
  return { stand: 'eingetragen', klasse };
}

/* ---------- Kinder ---------- */

export async function kinderHolen(code) {
  const gelesen = await anfrage(`${WURZEL}/klassen/${String(code).toUpperCase()}/kinder`);
  if (!gelesen) return [];
  return Object.entries(gelesen).map(([schluessel, eintrag]) => Object.assign({ schluessel }, eintrag));
}

/**
 * Ein Kind meldet sich zum ersten Mal an: Name aussuchen, PIN setzen.
 * Ist der Name schon vergeben, kommt NAME_VERGEBEN zurück — dann muss das
 * Kind einen anderen nehmen (oder es IST das Kind und meldet sich an).
 */
export async function kindAnlegen(code, anzeigename, pin) {
  const gross = String(code).toUpperCase();
  const schluessel = namensschluessel(anzeigename);
  if (!schluessel) throw new Error('NAME_LEER');
  if (!/^\d{4}$/.test(String(pin))) throw new Error('PIN_FORMAT');
  const vorhanden = await anfrage(`${WURZEL}/klassen/${gross}/kinder/${schluessel}/angelegtAm`).catch(() => null);
  if (vorhanden) throw new Error('NAME_VERGEBEN');
  const geheim = await abdruck(gross, schluessel, pin);
  // Erst das Geheimnis: Schlägt das fehl (Regeln nicht eingespielt), gibt es
  // hinterher kein Kind ohne PIN, das niemand mehr anmelden kann.
  await schreiben(`${WURZEL}/geheim/${gross}/${schluessel}`, geheim);
  await schreiben(`${WURZEL}/klassen/${gross}/kinder/${schluessel}`, {
    name: String(anzeigename).trim().slice(0, 30),
    angelegtAm: Date.now(),
    zuletzt: Date.now(),
  });
  return { schluessel, name: String(anzeigename).trim().slice(0, 30) };
}

/**
 * Anmeldung: Der Abdruck wird in einen Zweig geschrieben, den die Datenbank
 * nur dann annimmt, wenn er mit dem hinterlegten übereinstimmt. Kein Lesen des
 * Geheimnisses, nirgends.
 */
export async function kindAnmelden(code, anzeigename, pin, ohnePin = false) {
  const gross = String(code).toUpperCase();
  const schluessel = namensschluessel(anzeigename);
  const kind = await anfrage(`${WURZEL}/klassen/${gross}/kinder/${schluessel}`).catch(() => null);
  if (!kind) throw new Error('KIND_UNBEKANNT');
  // Hat die Lehrkraft es für ihre Klasse erlaubt, genügen Name und
  // Klassencode. Das ist bequem und ehrlich gesagt kein Schutz mehr: Wer den
  // Code hat, kommt als jedes Kind hinein. Die Entscheidung gehört deshalb
  // der Lehrkraft und steht in der Klasse, nicht hier.
  if (ohnePin && !pin) {
    await schreiben(`${WURZEL}/klassen/${gross}/kinder/${schluessel}/zuletzt`, Date.now()).catch(() => {});
    return { schluessel, name: kind.name || anzeigename };
  }
  const geheim = await abdruck(gross, schluessel, pin);
  try {
    await schreiben(`${WURZEL}/anmeldung/${gross}/${schluessel}`, geheim);
  } catch (fehler) {
    if (String(fehler.message) === 'NICHT_ERLAUBT') throw new Error('PIN_FALSCH');
    throw fehler;
  }
  await schreiben(`${WURZEL}/klassen/${gross}/kinder/${schluessel}/zuletzt`, Date.now()).catch(() => {});
  return { schluessel, name: kind.name || anzeigename };
}

/** Die Lehrkraft setzt eine vergessene PIN neu. Geht nur als Besitzerin. */
export async function pinNeuSetzen(code, schluessel, pin) {
  if (!konto) throw new Error('Dafür braucht es das Konto der Lehrkraft.');
  if (!/^\d{4}$/.test(String(pin))) throw new Error('PIN_FORMAT');
  const gross = String(code).toUpperCase();
  await schreiben(`${WURZEL}/geheim/${gross}/${schluessel}`, await abdruck(gross, schluessel, pin));
}

export async function kindEntfernen(code, schluessel) {
  const gross = String(code).toUpperCase();
  await anfrage(`${WURZEL}/klassen/${gross}/kinder/${schluessel}`, { method: 'DELETE' });
  await anfrage(`${WURZEL}/geheim/${gross}/${schluessel}`, { method: 'DELETE' }).catch(() => {});
}

/**
 * Der Fortschritt eines Kindes. Absichtlich klein gehalten: nur Sterne je
 * Päckchen und Stufe, keine einzelnen Wörter und keine Eingaben. Was ein Kind
 * falsch getippt hat, geht niemanden etwas an außer dem Kind selbst.
 */
export async function fortschrittMelden(code, schluessel, fortschritt) {
  const gross = String(code).toUpperCase();
  await schreiben(`${WURZEL}/klassen/${gross}/kinder/${schluessel}/fortschritt`, fortschritt);
}

/* ---------- Wortprotokoll ---------- */

/**
 * Ein Schlüssel, den die Datenbank als Pfad annimmt. Firebase verbietet in
 * Schlüsseln . # $ / [ ] — „der Tornister" ist erlaubt, „3,50 €/kg" wäre es
 * nicht. Ein eigener Bereich kann alles Mögliche enthalten, deshalb wird
 * hier gesäubert statt gehofft.
 */
function pfadschluessel(text) {
  return String(text).replace(/[.#$/[\]]/g, '_').slice(0, 120) || '_';
}

/**
 * Das Wortprotokoll eines Kindes melden.
 *
 * Es liegt NICHT unter `klassen/<CODE>` — dort darf lesen, wer den Code hat,
 * und das sind alle Kinder der Klasse. Was ein Kind falsch geschrieben hat,
 * geht seine Mitschüler nichts an. Der Zweig `protokoll/<CODE>/<Kind>` ist
 * deshalb so geregelt, dass jedes Kind hineinschreiben, aber nur die
 * angemeldete Besitzerin der Klasse lesen darf.
 */
export async function protokollMelden(code, kind, name, woerter) {
  const gross = String(code).toUpperCase();
  const nutzlast = {};
  for (const eintrag of Object.values(woerter || {})) {
    if (!eintrag || !eintrag.wort) continue;
    nutzlast[pfadschluessel(`${eintrag.bereichId}|${eintrag.wort}`)] = {
      w: eintrag.wort,
      b: eintrag.bereichName || '',
      a: eintrag.art || '',
      v: eintrag.versuche || 0,
      r: eintrag.richtig || 0,
      f: eintrag.fehler || 0,
      z: eintrag.zuletzt || 0,
      s: eintrag.stufen || {},
      e: eintrag.eingaben || [],
    };
  }
  await schreiben(`${WURZEL}/protokoll/${gross}/${kind}`, {
    name: name || kind,
    aktualisiert: Date.now(),
    woerter: nutzlast,
  });
}

/** Das Protokoll der ganzen Klasse. Lesen darf das nur die Lehrkraft. */
export async function protokollDerKlasse(code) {
  const gelesen = await anfrage(`${WURZEL}/protokoll/${String(code).toUpperCase()}`, {}, {}, 60000);
  if (!gelesen) return [];
  return Object.entries(gelesen).map(([schluessel, eintrag]) => ({
    schluessel,
    name: (eintrag && eintrag.name) || schluessel,
    aktualisiert: (eintrag && eintrag.aktualisiert) || 0,
    woerter: Object.values((eintrag && eintrag.woerter) || {}),
  }));
}

export async function protokollLoeschen(code, kind = null) {
  const gross = String(code).toUpperCase();
  await anfrage(`${WURZEL}/protokoll/${gross}${kind ? `/${kind}` : ''}`, { method: 'DELETE' });
}

export async function fortschrittDerKlasse(code) {
  const kinder = await kinderHolen(code);
  return kinder.map((kind) => ({
    schluessel: kind.schluessel,
    name: kind.name,
    zuletzt: kind.zuletzt || 0,
    fortschritt: kind.fortschritt || {},
  }));
}

/* ---------- Schulverwaltung ---------- */

/*
 * Wer verwalten darf, entscheiden die Datenbankregeln — nicht die App.
 *
 * Die App trägt deshalb weder eine Adresse noch eine Liste mit sich herum,
 * sondern PROBIERT: Das Verzeichnis aller Lehrkräfte darf nur eine Verwaltung
 * lesen. Geht der Griff durch, ist man Verwaltung. Damit stehen die Rechte an
 * genau einer Stelle (`firebase-rules.json`), und eine weitere Verwaltung
 * braucht keine neue Fassung der App.
 *
 * `shallow=true` holt dabei nur die Schlüssel — die Antwort bleibt ein paar
 * Zeilen lang, gleichgültig wie groß das Kollegium ist.
 *
 * Der gemerkte Stand (`verwaltungsrecht`, oben bei `konto`) wird bei jedem
 * Kontowechsel zurückgesetzt — sonst trüge die nächste Anmeldung die Rechte
 * der vorigen mit sich.
 */
export async function verwaltungPruefen(erneut = false) {
  if (!konto) { verwaltungsrecht = false; return false; }
  if (verwaltungsrecht !== null && !erneut) return verwaltungsrecht;
  // Die Kopfleiste wird beim Start zweimal gezeichnet (einmal beim Aufbau,
  // einmal, sobald das Konto steht). Ohne dieses Versprechen ginge die Frage
  // zweimal ins Netz — und bei einer Lehrkraft ohne Recht zweimal ins Leere.
  if (verwaltungsfrage && !erneut) return verwaltungsfrage;
  verwaltungsfrage = (async () => {
    try {
      await anfrage(`${WURZEL}/users`, {}, { shallow: 'true' }, 10000);
      verwaltungsrecht = true;
    } catch (fehler) {
      // Nur ein klares Nein wird gemerkt. Bei Netzärger bleibt die Frage
      // offen, sonst verschwände der Zugang nach einem Aussetzer bis zum
      // Neuladen.
      if (String(fehler.message) === 'NICHT_ERLAUBT') verwaltungsrecht = false;
      return false;
    } finally {
      verwaltungsfrage = null;
    }
    return true;
  })();
  return verwaltungsfrage;
}

/** Die Adresse der Firebase-Konsole — für das, was von hier aus nicht geht. */
export function konsolenadresse(bereich = 'authentication/users') {
  const kennung = konfiguration && konfiguration.projectId;
  return kennung ? `https://console.firebase.google.com/project/${kennung}/${bereich}` : null;
}

/**
 * Alle Lehrkräfte mit ihren Klassen.
 *
 * Gelesen wird der ganze Zweig `users` — dort hängen neben dem Profil auch
 * die eigenen Bereiche der Lehrkräfte. Bei einem Kollegium sind das ein paar
 * Dutzend Kilobyte; für eine Ansicht, die man selten öffnet, ist eine Abfrage
 * besser als vierzig.
 */
export async function alleLehrkraefte() {
  const gelesen = await anfrage(`${WURZEL}/users`, {}, {}, 30000);
  if (!gelesen) return [];
  const verwaltungen = await anfrage(`${WURZEL}/admins`).catch(() => null);
  return Object.entries(gelesen).map(([uid, eintrag]) => {
    const profil = (eintrag && eintrag.profil) || {};
    const klassen = Object.entries((eintrag && eintrag.klassen) || {})
      .map(([code, k]) => Object.assign({ code }, k));
    return {
      uid,
      email: profil.email || '',
      name: profil.name || '',
      angelegtAm: profil.angelegtAm || 0,
      zuletztAngemeldet: profil.zuletztAngemeldet || 0,
      klassen,
      bereiche: Object.keys((eintrag && eintrag.bereiche) || {}).length,
      verwaltung: !!(verwaltungen && verwaltungen[uid]),
      ichSelbst: !!konto && konto.uid === uid,
    };
  }).sort((a, b) => (a.name || a.email || a.uid).localeCompare(b.name || b.email || b.uid, 'de'));
}

/**
 * Klassencodes, zu denen es keine Lehrkraft (mehr) gibt.
 *
 * Sie entstehen, wenn ein Konto in der Firebase-Konsole verschwindet, ohne
 * dass die Klassen mitgingen. Über die Liste der Lehrkräfte wären sie nicht
 * zu finden — und niemand käme je wieder an sie heran.
 */
export async function verwaisteKlassen(lehrkraefte) {
  const alle = await anfrage(`${WURZEL}/klassen`, {}, { shallow: 'true' }, 20000);
  if (!alle) return [];
  const bekannt = new Set(lehrkraefte.flatMap((l) => l.klassen.map((k) => k.code)));
  return Object.keys(alle).filter((code) => !bekannt.has(code) && code !== '__pruefung');
}

/**
 * Eine Lehrkraft anlegen, ohne sich dabei selbst abzumelden.
 *
 * `signUp` gibt ein Zeichen für das NEUE Konto zurück. Würde es wie bei der
 * eigenen Anmeldung gesichert, wäre die Verwaltung anschließend als die eben
 * angelegte Lehrkraft unterwegs — und hätte keine Rechte mehr. Es wird
 * deshalb nur für den Anzeigenamen benutzt und dann fallen gelassen; das
 * Profil schreibt die Verwaltung mit ihrem eigenen Zeichen.
 */
export async function lehrkraftAnlegen(email, geheimwort, name) {
  if (!konto) throw new Error('Dafür braucht es ein angemeldetes Konto.');
  const daten = await kontoAnfrage('signUp', { email, password: geheimwort });
  if (name) await kontoAnfrage('update', { idToken: daten.idToken, displayName: name }).catch(() => {});
  await schreiben(`${WURZEL}/users/${daten.localId}/profil`, {
    email,
    name: name || '',
    angelegtAm: Date.now(),
    angelegtVon: konto.uid,
  });
  return { uid: daten.localId, email, name: name || '' };
}

/** Den angezeigten Namen einer Lehrkraft ändern. */
export async function lehrkraftUmbenennen(uid, name) {
  await schreiben(`${WURZEL}/users/${uid}/profil/name`, String(name).trim().slice(0, 60));
}

/**
 * Eine Mail zum Zurücksetzen des Kennworts schicken.
 *
 * Das ist der einzige Weg zu einem fremden Zugang: Es zu SETZEN verlangt das
 * Zeichen des betroffenen Kontos, und das hat niemand außer der Lehrkraft
 * selbst. Der Umweg über die Mail ist dabei kein Notbehelf — ein Kennwort,
 * das die Verwaltung kennt, ist keines.
 */
export async function zugangsmailSenden(email) {
  await kontoAnfrage('sendOobCode', { requestType: 'PASSWORD_RESET', email });
}

/** Verwaltungsrecht geben oder nehmen. Steht in der Datenbank, nicht in der App. */
export async function verwaltungsrechtSetzen(uid, an, name = '') {
  if (an) await schreiben(`${WURZEL}/admins/${uid}`, { name, seit: Date.now() });
  else await anfrage(`${WURZEL}/admins/${uid}`, { method: 'DELETE' });
}

/**
 * Eine Lehrkraft samt allem, was ihr gehört, aus der Datenbank nehmen.
 *
 * Was hier NICHT verschwindet, ist die Anmeldung selbst: Ein fremdes
 * Firebase-Konto entfernt nur das Admin-SDK auf einem Server oder ein Mensch
 * in der Firebase-Konsole. Der Dienstschlüssel dafür wäre in einer Web-App
 * der Generalschlüssel zur Datenbank, mitgeliefert auf jedem Kindergerät —
 * schlimmer als das Problem. Diese Funktion räumt deshalb die Daten weg, und
 * die Oberfläche schickt danach in die Konsole.
 */
export async function lehrkraftLoeschen(uid, klassen = []) {
  for (const code of klassen) await klasseLoeschen(code, uid);
  await verwaltungsrechtSetzen(uid, false).catch(() => {});
  await anfrage(`${WURZEL}/users/${uid}`, { method: 'DELETE' });
}

/**
 * Ein Kind umbenennen.
 *
 * Der Name IST der Schlüssel, und er steckt zugleich im PIN-Abdruck (siehe
 * `abdruck`). Ein Umbenennen ohne neue PIN gibt es deshalb nicht — der alte
 * Abdruck passt zum neuen Namen nicht mehr, und lesen lässt er sich nirgends.
 * Mitgenommen werden Sterne und Wortprotokoll: Sie hängen am Kind, nicht am
 * Namen, und wären sonst bei einem Tippfehler im Vornamen verloren.
 */
export async function kindUmbenennen(code, altSchluessel, neuerName, neuePin) {
  const gross = String(code).toUpperCase();
  const neu = namensschluessel(neuerName);
  const angezeigt = String(neuerName).trim().slice(0, 30);
  if (!neu) throw new Error('NAME_LEER');
  if (!/^\d{4}$/.test(String(neuePin))) throw new Error('PIN_FORMAT');
  // Nur anders geschrieben (Anna → anna): Dann bleibt der Schlüssel, und mit
  // ihm die PIN. Ein neues Geheimnis wäre hier eine Schikane.
  if (neu === altSchluessel) {
    await schreiben(`${WURZEL}/klassen/${gross}/kinder/${neu}/name`, angezeigt);
    return { schluessel: neu, pinNeu: false };
  }
  const belegt = await anfrage(`${WURZEL}/klassen/${gross}/kinder/${neu}/angelegtAm`).catch(() => null);
  if (belegt) throw new Error('NAME_VERGEBEN');
  const alt = await anfrage(`${WURZEL}/klassen/${gross}/kinder/${altSchluessel}`);
  if (!alt) throw new Error('KIND_UNBEKANNT');

  // Erst das Neue vollständig anlegen, dann das Alte wegnehmen: Bricht es
  // dazwischen ab, gibt es ein Kind zu viel — nie eines zu wenig.
  await schreiben(`${WURZEL}/geheim/${gross}/${neu}`, await abdruck(gross, neu, neuePin));
  await schreiben(`${WURZEL}/klassen/${gross}/kinder/${neu}`, Object.assign({}, alt, {
    name: angezeigt,
    umbenanntAm: Date.now(),
  }));
  const protokoll = await anfrage(`${WURZEL}/protokoll/${gross}/${altSchluessel}`).catch(() => null);
  if (protokoll) {
    await schreiben(`${WURZEL}/protokoll/${gross}/${neu}`,
      Object.assign({}, protokoll, { name: angezeigt })).catch(() => {});
    await anfrage(`${WURZEL}/protokoll/${gross}/${altSchluessel}`, { method: 'DELETE' }).catch(() => {});
  }
  await kindEntfernen(gross, altSchluessel);
  return { schluessel: neu, pinNeu: true };
}
