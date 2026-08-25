// Optionale Cloud-Funktionen über die REST-Schnittstellen von Firebase:
// Klassenräume per Code teilen, live folgen, Geräte abgleichen und
// (falls im Projekt aktiviert) Konten.
// Ohne Netz funktioniert die App vollständig lokal — hier scheitern dann nur
// Teilen und Konto, alles andere läuft weiter.

import { shareCode, randomInt } from './util.js';

const ROOT = 'klassenraum';
const AUTH_STORAGE = 'klassenraum.auth.v1';

let config = null;
let bootPromise = null;
let accountsEnabled = null; // null = noch unbekannt
let account = null;
const listeners = new Set();

function loadConfigScript() {
  return new Promise((resolve, reject) => {
    if (window.firebaseConfig) {
      resolve(window.firebaseConfig);
      return;
    }
    const script = document.createElement('script');
    script.src = '../firebase-config.js';
    script.addEventListener('load', () => resolve(window.firebaseConfig));
    script.addEventListener('error', () => reject(new Error('Konfiguration nicht gefunden')));
    document.head.appendChild(script);
  });
}

function restoreAccount() {
  try {
    const raw = window.localStorage.getItem(AUTH_STORAGE);
    if (!raw) return;
    const stored = JSON.parse(raw);
    if (stored && stored.refreshToken) account = stored;
  } catch (_) {
    account = null;
  }
}

function persistAccount() {
  try {
    if (account) window.localStorage.setItem(AUTH_STORAGE, JSON.stringify(account));
    else window.localStorage.removeItem(AUTH_STORAGE);
  } catch (_) { /* Speicher voll oder gesperrt — dann eben nur für diese Sitzung */ }
  listeners.forEach((listener) => listener(currentAccount()));
}

export function initCloud() {
  if (bootPromise) return bootPromise;
  bootPromise = (async () => {
    config = await loadConfigScript();
    if (!config || !config.databaseURL || !config.apiKey) throw new Error('Unvollständige Konfiguration');
    restoreAccount();
    probeAccounts();
    return true;
  })().catch((error) => {
    bootPromise = null;
    throw error;
  });
  return bootPromise;
}

async function probeAccounts() {
  try {
    const response = await fetch(`https://identitytoolkit.googleapis.com/v1/projects?key=${config.apiKey}`);
    accountsEnabled = response.ok;
  } catch (_) {
    accountsEnabled = null;
  }
  listeners.forEach((listener) => listener(currentAccount()));
}

export function cloudReady() {
  return Boolean(config);
}

/** true = Konten nutzbar, false = im Firebase-Projekt nicht aktiviert, null = unbekannt. */
export function accountsAvailable() {
  return accountsEnabled;
}

export function currentAccount() {
  if (!account) return null;
  return { uid: account.uid, email: account.email, name: account.name };
}

export function onAccountChanged(listener) {
  listeners.add(listener);
  listener(currentAccount());
  return () => listeners.delete(listener);
}

async function validToken() {
  if (!account) return null;
  if (account.expiresAt && account.expiresAt - Date.now() > 60000) return account.idToken;
  try {
    const response = await fetch(`https://securetoken.googleapis.com/v1/token?key=${config.apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(account.refreshToken)}`,
    });
    if (!response.ok) throw new Error('refresh');
    const data = await response.json();
    account = Object.assign({}, account, {
      idToken: data.id_token,
      refreshToken: data.refresh_token,
      expiresAt: Date.now() + Number(data.expires_in || 3600) * 1000,
    });
    persistAccount();
    return account.idToken;
  } catch (_) {
    account = null;
    persistAccount();
    return null;
  }
}

async function dbUrl(path, params = {}) {
  await initCloud();
  const base = String(config.databaseURL).replace(/\/$/, '');
  const url = new URL(`${base}/${path}.json`);
  const token = await validToken();
  if (token) url.searchParams.set('auth', token);
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
  return url.toString();
}

async function dbRequest(path, options = {}, params = {}) {
  const url = await dbUrl(path, params);
  const response = await fetch(url, options);
  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`Server meldet ${response.status}${text ? `: ${text.slice(0, 120)}` : ''}`);
  }
  const raw = await response.text();
  return raw && raw !== 'null' ? JSON.parse(raw) : null;
}

function normalizeCode(code) {
  return String(code || '').toUpperCase().trim();
}

/* ---------- Teilen ---------- */

export async function publishBoard(board, existing = {}) {
  await initCloud();
  const code = existing.code || shareCode();
  const editKey = existing.editKey || `${shareCode()}${shareCode()}`;
  const payload = {
    board: JSON.parse(JSON.stringify(board)),
    updatedAt: Date.now(),
    editKey,
    owner: account ? account.uid : null,
    ownerName: (account && account.name) || existing.ownerName || '',
  };
  await dbRequest(`${ROOT}/shares/${code}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return { code, editKey, updatedAt: payload.updatedAt };
}

export async function fetchShare(code) {
  return dbRequest(`${ROOT}/shares/${normalizeCode(code)}`);
}

export async function removeShare(code) {
  await dbRequest(`${ROOT}/shares/${normalizeCode(code)}`, { method: 'DELETE' });
}

/**
 * Auf Änderungen eines geteilten Klassenraums hören.
 * Bevorzugt den Ereignisstrom der Datenbank, fällt sonst auf regelmäßiges Nachfragen zurück.
 */
export async function subscribeShare(code, handler) {
  return subscribePath(`${ROOT}/shares/${normalizeCode(code)}`, handler);
}

/**
 * Allgemeiner Zuhörer auf einen Pfad der Datenbank.
 * Mit `granular` bekommt `handler(null, { path, data })` einzelne Änderungen
 * gemeldet, statt jedes Mal den ganzen Pfad neu zu laden.
 */
export async function subscribePath(path, handler, { granular = false } = {}) {
  await initCloud();
  let stopped = false;
  let source = null;
  let poller = null;
  let pending = null;

  const pull = async () => {
    try {
      const payload = await dbRequest(path);
      if (!stopped) handler(payload, null);
    } catch (_) { /* nächster Versuch später */ }
  };

  const startPolling = () => {
    if (poller || stopped) return;
    poller = setInterval(pull, 8000);
  };

  await pull();

  const onEvent = (event) => {
    // Der Ereignisstrom liefert { path, data } — damit lässt sich gezielt
    // nur der geänderte Datensatz übernehmen statt alles neu zu laden.
    let detail = null;
    try {
      detail = JSON.parse(event.data);
    } catch (_) {
      detail = null;
    }
    if (granular && detail && typeof detail.path === 'string' && detail.path !== '/') {
      if (!stopped) handler(null, detail);
      return;
    }
    if (pending) clearTimeout(pending);
    pending = setTimeout(pull, 250);
  };

  if (typeof window.EventSource === 'function') {
    try {
      source = new window.EventSource(await dbUrl(path));
      source.addEventListener('put', onEvent);
      source.addEventListener('patch', onEvent);
      source.addEventListener('error', () => {
        if (source && source.readyState === 2) startPolling();
      });
    } catch (_) {
      startPolling();
    }
  } else {
    startPolling();
  }

  return () => {
    stopped = true;
    if (pending) clearTimeout(pending);
    if (poller) clearInterval(poller);
    if (source) source.close();
  };
}

/* ---------- Konten ---------- */

function translateAuthError(message) {
  if (message === 'CONFIGURATION_NOT_FOUND' || message === 'OPERATION_NOT_ALLOWED') return 'KONTEN_NICHT_AKTIV';
  if (message.startsWith('EMAIL_EXISTS')) return 'Diese E-Mail wird bereits verwendet.';
  if (message.startsWith('INVALID_EMAIL')) return 'Die E-Mail-Adresse sieht nicht richtig aus.';
  if (message.startsWith('WEAK_PASSWORD')) return 'Das Passwort braucht mindestens 6 Zeichen.';
  if (message.startsWith('EMAIL_NOT_FOUND')) return 'Zu dieser E-Mail gibt es noch kein Konto.';
  if (message.startsWith('INVALID_PASSWORD') || message.startsWith('INVALID_LOGIN_CREDENTIALS')) return 'E-Mail oder Passwort stimmt nicht.';
  if (message.startsWith('TOO_MANY_ATTEMPTS')) return 'Zu viele Versuche — bitte später erneut probieren.';
  return message || 'Unbekannter Fehler';
}

async function identityRequest(endpoint, body) {
  await initCloud();
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:${endpoint}?key=${config.apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(Object.assign({ returnSecureToken: true }, body)),
  }).catch(() => {
    throw new Error('Keine Verbindung zum Server.');
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = data && data.error && data.error.message ? data.error.message : '';
    if (message === 'CONFIGURATION_NOT_FOUND' || message === 'OPERATION_NOT_ALLOWED') accountsEnabled = false;
    throw new Error(translateAuthError(message));
  }
  accountsEnabled = true;
  return data;
}

function storeSession(data, name) {
  account = {
    uid: data.localId,
    email: data.email,
    name: name || data.displayName || '',
    idToken: data.idToken,
    refreshToken: data.refreshToken,
    expiresAt: Date.now() + Number(data.expiresIn || 3600) * 1000,
  };
  persistAccount();
  return currentAccount();
}

export async function signUp(email, password, name) {
  const data = await identityRequest('signUp', { email, password });
  if (name) {
    await identityRequest('update', { idToken: data.idToken, displayName: name }).catch(() => {});
  }
  const session = storeSession(data, name);
  await dbRequest(`${ROOT}/users/${session.uid}/profile`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, name: name || '', createdAt: Date.now() }),
  }).catch(() => {});
  return session;
}

export async function signIn(email, password) {
  const data = await identityRequest('signInWithPassword', { email, password });
  return storeSession(data, data.displayName);
}

export async function signOutAccount() {
  account = null;
  persistAccount();
}

/* ---------- Sicherung im Konto ---------- */

export async function pushBackup(state) {
  if (!account) throw new Error('Kein Konto angemeldet');
  await dbRequest(`${ROOT}/users/${account.uid}/backup`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ updatedAt: Date.now(), boards: state.boards, lists: state.lists }),
  });
}

export async function pullBackup() {
  if (!account) throw new Error('Kein Konto angemeldet');
  return dbRequest(`${ROOT}/users/${account.uid}/backup`);
}

/* ---------- Abgleich zwischen Geräten ---------- */

const SPACE_ALPHABET = 'abcdefghijkmnopqrstuvwxyz23456789';
const LINK_MINUTES = 60;

/** Unverwechselbare, nicht erratbare Kennung eines Abgleich-Bereichs. */
function spaceId() {
  let out = 's';
  for (let i = 0; i < 24; i += 1) out += SPACE_ALPHABET[randomInt(SPACE_ALPHABET.length)];
  return out;
}

function spacePath(id, rest = '') {
  return `${ROOT}/spaces/${encodeURIComponent(id)}${rest}`;
}

/** Legt einen neuen Bereich an und gibt dessen Kennung zurück. */
export async function createSpace(name) {
  await initCloud();
  const id = spaceId();
  await dbRequest(spacePath(id, '/meta'), {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ createdAt: Date.now(), name: name || '' }),
  });
  return id;
}

export async function fetchSpace(id) {
  return dbRequest(spacePath(id));
}

/** Einen einzelnen Datensatz (Tafel oder Liste) ablegen. */
export async function putRecord(id, kind, recordId, record) {
  return dbRequest(spacePath(id, `/${kind}/${encodeURIComponent(recordId)}`), {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(record),
  });
}

export async function subscribeSpace(id, handler) {
  return subscribePath(spacePath(id), handler, { granular: true });
}

/** Kurzer Kopplungscode, der eine Stunde lang auf den Bereich zeigt. */
export async function createLinkCode(id) {
  await initCloud();
  const code = shareCode();
  await dbRequest(`${ROOT}/links/${code}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ spaceId: id, createdAt: Date.now(), expiresAt: Date.now() + LINK_MINUTES * 60000 }),
  });
  return { code, expiresAt: Date.now() + LINK_MINUTES * 60000 };
}

export async function resolveLinkCode(code) {
  const entry = await dbRequest(`${ROOT}/links/${normalizeCode(code)}`);
  if (!entry || !entry.spaceId) throw new Error('CODE_UNBEKANNT');
  if (entry.expiresAt && entry.expiresAt < Date.now()) throw new Error('CODE_ABGELAUFEN');
  return entry.spaceId;
}

/* ---------- Dateien (Klänge, Videos) im Abgleich-Bereich ---------- */

// Dateien liegen bewusst NEBEN dem Bereich (media/<Kennung>/<Datei-Id>):
// So holt der volle Bereichsabruf nicht bei jedem Abgleich alle Dateien mit.
function mediaPath(spaceId, mediaId = '') {
  const base = `${ROOT}/media/${encodeURIComponent(spaceId)}`;
  return mediaId ? `${base}/${encodeURIComponent(mediaId)}` : base;
}

export async function putMediaRecord(spaceId, mediaId, record) {
  return dbRequest(mediaPath(spaceId, mediaId), {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(record),
  });
}

export async function fetchMediaRecord(spaceId, mediaId) {
  return dbRequest(mediaPath(spaceId, mediaId));
}

/** Nur die Datei-Kennungen im Bereich — ohne die (großen) Inhalte. */
export async function listMediaRecords(spaceId) {
  const result = await dbRequest(mediaPath(spaceId), {}, { shallow: 'true' });
  return result ? Object.keys(result) : [];
}

export async function deleteMediaRecord(spaceId, mediaId) {
  return dbRequest(mediaPath(spaceId, mediaId), { method: 'DELETE' });
}

/* ---------- Bereich am Konto merken (sobald Konten aktiv sind) ---------- */

export async function rememberSpaceForAccount(id) {
  if (!account) return;
  await dbRequest(`${ROOT}/users/${account.uid}/spaceId`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(id),
  }).catch(() => {});
}

export async function spaceOfAccount() {
  if (!account) return null;
  return dbRequest(`${ROOT}/users/${account.uid}/spaceId`).catch(() => null);
}
