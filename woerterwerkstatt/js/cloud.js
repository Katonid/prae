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
  return sitzungMerken(daten, daten.displayName);
}

export function abmelden() {
  konto = null;
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
  for (let versuch = 0; versuch < 5; versuch += 1) {
    const belegt = await anfrage(`${WURZEL}/klassen/${code}/angelegtAm`).catch(() => null);
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

export async function klasseLoeschen(code) {
  const gross = String(code).toUpperCase();
  await anfrage(`${WURZEL}/klassen/${gross}`, { method: 'DELETE' });
  if (konto) await anfrage(`${WURZEL}/users/${konto.uid}/klassen/${gross}`, { method: 'DELETE' }).catch(() => {});
}

export async function klassenDerLehrkraft() {
  if (!konto) return [];
  const gelesen = await anfrage(`${WURZEL}/users/${konto.uid}/klassen`);
  if (!gelesen) return [];
  return Object.entries(gelesen).map(([code, eintrag]) => Object.assign({ code }, eintrag));
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
export async function kindAnmelden(code, anzeigename, pin) {
  const gross = String(code).toUpperCase();
  const schluessel = namensschluessel(anzeigename);
  const kind = await anfrage(`${WURZEL}/klassen/${gross}/kinder/${schluessel}`).catch(() => null);
  if (!kind) throw new Error('KIND_UNBEKANNT');
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

export async function fortschrittDerKlasse(code) {
  const kinder = await kinderHolen(code);
  return kinder.map((kind) => ({
    schluessel: kind.schluessel,
    name: kind.name,
    zuletzt: kind.zuletzt || 0,
    fortschritt: kind.fortschritt || {},
  }));
}
