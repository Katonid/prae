// Optionale Cloud-Funktionen über die REST-Schnittstellen von Firebase:
// Klassenräume per Code teilen, live folgen und (falls im Projekt aktiviert) Konten.
// Ohne Netz funktioniert die App vollständig lokal — hier scheitern dann nur
// Teilen und Konto, alles andere läuft weiter.

import { shareCode } from './util.js';

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

async function dbRequest(path, options = {}) {
  const url = await dbUrl(path);
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
  await initCloud();
  const path = `${ROOT}/shares/${normalizeCode(code)}`;
  let stopped = false;
  let source = null;
  let poller = null;
  let pending = null;

  const pull = async () => {
    try {
      const payload = await dbRequest(path);
      if (!stopped) handler(payload);
    } catch (_) { /* nächster Versuch später */ }
  };

  const startPolling = () => {
    if (poller || stopped) return;
    poller = setInterval(pull, 8000);
  };

  await pull();

  if (typeof window.EventSource === 'function') {
    try {
      source = new window.EventSource(await dbUrl(path));
      source.addEventListener('put', () => {
        if (pending) clearTimeout(pending);
        pending = setTimeout(pull, 250);
      });
      source.addEventListener('patch', () => {
        if (pending) clearTimeout(pending);
        pending = setTimeout(pull, 250);
      });
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
