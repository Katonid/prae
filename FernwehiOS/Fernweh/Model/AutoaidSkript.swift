import Foundation

// DAS SCRIPTABLE-SKRIPT „autoaid → GPX" (ab 1.0.38, Ansage des Nutzers
// 11/2026: „damit wir das nicht wieder vergessen, leg bitte einen kurzen
// Hinweistext in der App an, an der Stelle, wo man GPX-Daten einer
// Autofahrt importieren möchte").
//
// So kamen die Autofahrten der Osterreise mit ECHTEM Streckenverlauf in die
// App: autoaid gibt im Fahrtenbuch nur eine CSV (eine Zeile je Fahrt, ohne
// Punkte). Das Skript läuft in der App „Scriptable", meldet sich mit dem
// autoaid-Konto an (OAuth, nur der Refresh-Token liegt im Schlüsselbund),
// holt je Fahrt der CSV die GPS-Punkte (`/events?eventType=POSITION`, sonst
// die gespeicherte Polyline) und schreibt eine GPX-Datei — eine Spur je
// Fahrt, Name „TT.MM.JJJJ HH:MM–HH:MM · Start → Ziel". Die liest
// `Fahrtenimport` wie jede andere GPX-Datei.
//
// Fassung 1.1 (10.11.2026) liest auch den DEUTSCHEN autoaid-Export
// („Fahrten-ID", „Startdatum", Monate „Okt"); 1.0 kannte nur den englischen.
// Das Skript stammt vom Nutzer; ändert autoaid seine Schnittstelle, wird
// HIER nachgezogen. Die App kopiert es nur in die Zwischenablage — sie selbst
// spricht autoaid nicht an.
enum AutoaidSkript {
    static let fassung = "1.1"

    static let text = #"""
// autoaid → GPX für iPhone/iPad (Scriptable)
// Version 1.1
//
// 1.1: liest auch den DEUTSCHEN autoaid-Export (Spalten „Fahrten-ID“,
//      „Startdatum“, „Startadresse“ …, Monate „Okt“, „Mai“, „Dez“, „Mär“).
//      1.0 kannte nur den englischen („Trip ID“, „Start date“ …) und brach
//      sonst mit „Die Spalte ‚Trip ID‘ fehlt“ ab. Österreichische
//      Postleitzahlen (4 Ziffern) werden im Ortsnamen erkannt.
//
// Benötigt die kostenlose App "Scriptable".
// Die autoaid-Zugangsdaten werden NICHT als Passwort gespeichert.
// Nach der ersten Anmeldung wird nur der OAuth-Refresh-Token
// sicher im iOS-Schlüsselbund (Keychain) gespeichert.
//
// Ablauf:
// 1. Beim ersten Start: autoaid-CSV aus "Dateien" auswählen.
// 2. Einmal bei autoaid anmelden.
// 3. Einzelne Fahrt auswählen ODER einen Zeitraum von/bis wählen.
// 4. Einzelne Fahrt oder alle Fahrten des Zeitraums als GPX speichern.
//
// Die importierte CSV wird lokal in Scriptable gespeichert (nicht in iCloud).

const OAUTH_URL = "https://oauth.autoaid.de";
const API_BASE = "https://api-production.autoaid.de/cc/v3.0";
const CLIENT_ID = "connectedCarApi";

const KEY_EMAIL = "autoaid-gpx.email";
const KEY_REFRESH = "autoaid-gpx.refresh-token";
const CACHE_FILE = "autoaid_trips.csv";

const localFM = FileManager.local();
const cachePath = localFM.joinPath(localFM.documentsDirectory(), CACHE_FILE);

// Deutsche Spaltennamen → die englischen, mit denen das Skript arbeitet.
const HEADER_DE = {
  "Fahrten-ID": "Trip ID",
  "Startdatum": "Start date",
  "Enddatum": "End date",
  "Start-Zeit": "Start time",
  "End-Zeit": "End time",
  "Startadresse": "Start address",
  "Zieladresse": "End address",
  "Typ": "Type",
  "Start-Kilometerstand": "Start mileage",
  "End-Kilometerstand": "End mileage",
  "Wegstrecke": "Distance",
  "Zeitdauer": "Duration",
  "Fahrer/in": "Driver",
  "Zweck der Fahrt": "Purpose of trip",
  "Kontaktperson": "Contact person"
};

// ---------- Hilfsfunktionen ----------

function escapeXML(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function safeFilename(s) {
  return String(s)
    .replace(/[<>:"/\\|?*\u0000-\u001f]/g, "-")
    .replace(/\s+/g, "_")
    .replace(/_+/g, "_")
    .slice(0, 150);
}

function shortPlace(address) {
  if (!address) return "";
  const parts = String(address).split(",").map(x => x.trim()).filter(Boolean);
  const last = parts[parts.length - 1] || "";
  const m = last.match(/\b\d{4,5}\s+(.+)$/);
  return m ? m[1].trim() : last;
}

function pad2(n) {
  return String(n).padStart(2, "0");
}

// Englische UND deutsche Monatskürzel (erste drei Buchstaben, klein).
const MONTHS = {
  jan: 1, feb: 2, mar: 3, apr: 4, may: 5, jun: 6,
  jul: 7, aug: 8, sep: 9, oct: 10, nov: 11, dec: 12,
  "mär": 3, mrz: 3, mai: 5, okt: 10, dez: 12
};

// „1 Nov 2026“, „31 Okt 2026“, „1. März 2026“ → [Tag, Monat, Jahr]
function splitAutoaidDate(dateStr) {
  const m = String(dateStr || "").trim().match(/^(\d{1,2})\.?\s+([A-Za-zÄÖÜäöü]{3,})\.?\s+(\d{4})$/);
  if (!m) return null;
  const month = MONTHS[m[2].slice(0, 3).toLowerCase()];
  if (!month) return null;
  return [Number(m[1]), month, Number(m[3])];
}

function parseAutoaidDate(dateStr, timeStr = "00:00") {
  const d = splitAutoaidDate(dateStr);
  if (!d) return 0;
  const tm = String(timeStr || "00:00").match(/^(\d{1,2}):(\d{2})/);
  const hh = tm ? Number(tm[1]) : 0;
  const mm = tm ? Number(tm[2]) : 0;
  return new Date(d[2], d[1] - 1, d[0], hh, mm).getTime();
}

function isoDateFromAutoaid(dateStr) {
  const d = splitAutoaidDate(dateStr);
  if (!d) return safeFilename(dateStr || "Fahrt");
  return `${d[2]}-${pad2(d[1])}-${pad2(d[0])}`;
}

function displayDate(dateStr) {
  const d = splitAutoaidDate(dateStr);
  if (!d) return dateStr || "";
  return `${pad2(d[0])}.${pad2(d[1])}.${d[2]}`;
}

function normalizeSearch(q) {
  let s = String(q || "").trim();
  // Deutsche numerische Datumsformate in autoaid-Format ergänzen:
  const dm = s.match(/^(\d{1,2})[.\-/](\d{1,2})(?:[.\-/](\d{2}|\d{4}))?\.?$/);
  if (dm) {
    let y = dm[3];
    if (!y) y = String(new Date().getFullYear());
    if (y.length === 2) y = "20" + y;
    const mi = Number(dm[2]) - 1;
    if (mi >= 0 && mi < 12) {
      // Als TT.MM.JJJJ — so steht es (über displayDate) im Suchtext,
      // gleich ob die CSV deutsch oder englisch ist.
      return `${pad2(Number(dm[1]))}.${pad2(mi + 1)}.${y}`;
    }
  }
  return s.toLowerCase();
}

function tripLabel(row) {
  const d = displayDate(row["Start date"]);
  const t = row["Start time"] || "";
  const from = shortPlace(row["Start address"]);
  const to = shortPlace(row["End address"]);
  const dist = row["Distance"] || "";
  return `${d} ${t} · ${from} → ${to}${dist ? " · " + dist : ""}`;
}

function tripName(row) {
  return `${displayDate(row["Start date"])} ${row["Start time"] || ""}–${row["End time"] || ""} · ${shortPlace(row["Start address"])} → ${shortPlace(row["End address"])}`;
}

function tripFilename(row) {
  const date = isoDateFromAutoaid(row["Start date"]);
  const time = String(row["Start time"] || "").replace(":", "-");
  const from = shortPlace(row["Start address"]);
  const to = shortPlace(row["End address"]);
  const id = String(row["Trip ID"] || "").slice(0, 8);
  return safeFilename(`${date}_${time}_${from}-${to}_${id}`) + ".gpx";
}

// Solider CSV-Parser mit Unterstützung für Anführungszeichen und Zeilenumbrüche in Feldern.
function parseCSV(text) {
  text = String(text || "").replace(/^﻿/, "");
  const rows = [];
  let row = [];
  let field = "";
  let quoted = false;

  for (let i = 0; i < text.length; i++) {
    const ch = text[i];

    if (quoted) {
      if (ch === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          quoted = false;
        }
      } else {
        field += ch;
      }
    } else {
      if (ch === '"') {
        quoted = true;
      } else if (ch === ",") {
        row.push(field);
        field = "";
      } else if (ch === "\n") {
        row.push(field.replace(/\r$/, ""));
        rows.push(row);
        row = [];
        field = "";
      } else {
        field += ch;
      }
    }
  }

  if (field.length || row.length) {
    row.push(field.replace(/\r$/, ""));
    rows.push(row);
  }

  if (!rows.length) return [];
  const headers = rows[0].map(h => {
    const t = h.trim();
    return HEADER_DE[t] || t;
  });
  return rows.slice(1)
    .filter(r => r.some(v => String(v).trim() !== ""))
    .map(r => {
      const obj = {};
      headers.forEach((h, idx) => obj[h] = r[idx] ?? "");
      return obj;
    });
}

async function info(title, message) {
  const a = new Alert();
  a.title = title;
  a.message = message;
  a.addAction("OK");
  await a.presentAlert();
}

async function confirm(title, message, ok = "Ja", cancel = "Abbrechen") {
  const a = new Alert();
  a.title = title;
  a.message = message;
  a.addAction(ok);
  a.addCancelAction(cancel);
  return await a.presentAlert() === 0;
}

async function importCSV() {
  const path = await DocumentPicker.openFile();
  if (!path) return false;

  let txt;
  try {
    txt = FileManager.local().readString(path);
  } catch (e) {
    try {
      txt = FileManager.iCloud().readString(path);
    } catch (e2) {
      throw new Error("Die ausgewählte CSV konnte nicht gelesen werden.");
    }
  }

  const rows = parseCSV(txt);
  if (!rows.length || !Object.prototype.hasOwnProperty.call(rows[0], "Trip ID")) {
    throw new Error("Die Datei sieht nicht wie ein autoaid-Fahrtenexport aus. Die Spalte „Trip ID“ bzw. „Fahrten-ID“ fehlt.");
  }

  localFM.writeString(cachePath, txt);
  await info("CSV übernommen", `${rows.length} Fahrten wurden lokal in Scriptable gespeichert.`);
  return true;
}

function loadTrips() {
  if (!localFM.fileExists(cachePath)) return [];
  const txt = localFM.readString(cachePath);
  const rows = parseCSV(txt);
  return rows
    .filter(r => String(r["Trip ID"] || "").trim())
    .sort((a, b) => parseAutoaidDate(b["Start date"], b["Start time"]) - parseAutoaidDate(a["Start date"], a["Start time"]));
}

async function promptLogin() {
  const a = new Alert();
  a.title = "Bei autoaid anmelden";
  a.message = "Das Passwort wird nicht gespeichert. Danach wird nur der OAuth-Refresh-Token sicher im iOS-Schlüsselbund abgelegt.";
  a.addTextField("E-Mail-Adresse", Keychain.contains(KEY_EMAIL) ? Keychain.get(KEY_EMAIL) : "");
  a.addSecureTextField("Passwort", "");
  a.addAction("Anmelden");
  a.addCancelAction("Abbrechen");

  const idx = await a.presentAlert();
  if (idx < 0) return null;

  const email = a.textFieldValue(0).trim();
  const password = a.textFieldValue(1);
  if (!email || !password) throw new Error("E-Mail-Adresse und Passwort werden benötigt.");

  const tok = await oauth({
    grant_type: "password",
    username: email,
    password: password,
    client_id: CLIENT_ID
  });

  if (!tok.access_token) throw new Error("autoaid hat kein Access-Token geliefert.");
  Keychain.set(KEY_EMAIL, email);
  if (tok.refresh_token) Keychain.set(KEY_REFRESH, tok.refresh_token);
  return tok.access_token;
}

async function oauth(fields) {
  const req = new Request(OAUTH_URL);
  req.method = "POST";
  req.timeoutInterval = 45;
  req.headers = { "Accept": "application/json" };

  for (const [k, v] of Object.entries(fields)) {
    req.addParameterToMultipart(k, String(v));
  }

  let raw;
  try {
    raw = await req.loadString();
  } catch (e) {
    const status = req.response ? req.response.statusCode : null;
    throw new Error(status ? `autoaid-Anmeldung fehlgeschlagen (HTTP ${status}).` : `Netzwerkfehler bei der autoaid-Anmeldung: ${e}`);
  }

  let obj;
  try {
    obj = JSON.parse(raw);
  } catch (_) {
    throw new Error("autoaid hat bei der Anmeldung eine unerwartete Antwort geliefert.");
  }

  const status = req.response ? req.response.statusCode : 200;
  if (status < 200 || status >= 300) {
    const msg = obj.error_description || obj.error || `HTTP ${status}`;
    throw new Error(`autoaid-Anmeldung fehlgeschlagen: ${msg}`);
  }
  return obj;
}

async function getAccessToken() {
  if (Keychain.contains(KEY_REFRESH)) {
    const refresh = Keychain.get(KEY_REFRESH);
    try {
      const tok = await oauth({
        grant_type: "refresh_token",
        refresh_token: refresh,
        client_id: CLIENT_ID
      });
      if (tok.access_token) {
        if (tok.refresh_token) Keychain.set(KEY_REFRESH, tok.refresh_token);
        return tok.access_token;
      }
    } catch (e) {
      // Refresh ungültig/abgelaufen: neu anmelden.
      Keychain.remove(KEY_REFRESH);
    }
  }
  return await promptLogin();
}

async function apiGET(path, token, params = {}) {
  const qs = Object.entries(params)
    .filter(([,v]) => v !== undefined && v !== null && v !== "")
    .map(([k,v]) => encodeURIComponent(k) + "=" + encodeURIComponent(String(v)))
    .join("&");

  const req = new Request(API_BASE + path + (qs ? "?" + qs : ""));
  req.method = "GET";
  req.timeoutInterval = 60;
  req.headers = {
    "Authorization": "Bearer " + token,
    "Accept": "application/json",
    "Accept-Language": "de"
  };

  let raw;
  try {
    raw = await req.loadString();
  } catch (e) {
    const status = req.response ? req.response.statusCode : null;
    if (status === 401 || status === 403) {
      throw new Error("Die autoaid-Anmeldung wurde abgelehnt. Bitte im Menü „Anmeldung zurücksetzen“ wählen und erneut anmelden.");
    }
    throw new Error(status ? `autoaid-API: HTTP ${status}` : `Netzwerkfehler: ${e}`);
  }

  const status = req.response ? req.response.statusCode : 200;
  let obj;
  try {
    obj = JSON.parse(raw);
  } catch (_) {
    throw new Error("autoaid hat eine unerwartete API-Antwort geliefert.");
  }
  if (status < 200 || status >= 300) {
    throw new Error(`autoaid-API: HTTP ${status}`);
  }
  return obj;
}

async function fetchPositionEvents(tripId, token) {
  const result = await apiGET("/events", token, {
    tripId: tripId,
    eventType: "POSITION",
    maxResults: 10000
  });

  let events = [];
  if (Array.isArray(result)) events = result;
  else if (result && typeof result === "object") {
    events = result.events || result.items || result.results || result.data || [];
  }

  const points = [];
  for (const ev of events) {
    if (!ev || typeof ev !== "object") continue;
    const type = String(ev.event_type ?? ev.eventType ?? "POSITION").toUpperCase();
    if (type !== "POSITION") continue;

    let lat = null, lon = null;
    const value = ev.value;

    if (typeof value === "string") {
      const m = value.match(/POINT\s*\(\s*([-+]?\d+(?:\.\d+)?)\s+([-+]?\d+(?:\.\d+)?)\s*\)/i);
      if (m) {
        lon = Number(m[1]);
        lat = Number(m[2]);
      }
    } else if (value && typeof value === "object") {
      lat = Number(value.lat ?? value.latitude);
      lon = Number(value.lon ?? value.lng ?? value.longitude);
    }

    if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
      lat = Number(ev.lat ?? ev.latitude);
      lon = Number(ev.lon ?? ev.lng ?? ev.longitude);
    }

    const time = ev.recorded_timestamp ?? ev.recordedTimestamp ?? null;
    if (Number.isFinite(lat) && Number.isFinite(lon)) {
      points.push({ lat, lon, time });
    }
  }

  points.sort((a,b) => String(a.time || "").localeCompare(String(b.time || "")));

  const deduped = [];
  const seen = new Set();
  for (const p of points) {
    const k = `${p.lat.toFixed(7)}|${p.lon.toFixed(7)}|${p.time || ""}`;
    if (!seen.has(k)) {
      seen.add(k);
      deduped.push(p);
    }
  }
  return deduped;
}

function decodePolyline(str) {
  const coords = [];
  let index = 0, lat = 0, lng = 0;

  while (index < str.length) {
    let result = 0, shift = 0, b;
    do {
      b = str.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20 && index <= str.length);
    lat += (result & 1) ? ~(result >> 1) : (result >> 1);

    result = 0; shift = 0;
    do {
      b = str.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20 && index <= str.length);
    lng += (result & 1) ? ~(result >> 1) : (result >> 1);

    coords.push({ lat: lat / 1e5, lon: lng / 1e5, time: null });
  }
  return coords;
}

async function fetchPolylineFallback(tripId, token) {
  let trip = null;
  let lastError = null;

  for (const path of [`/trips/${encodeURIComponent(tripId)}`, `/trip/${encodeURIComponent(tripId)}`]) {
    try {
      trip = await apiGET(path, token);
      break;
    } catch (e) {
      lastError = e;
    }
  }

  if (!trip) {
    if (lastError) throw lastError;
    return [];
  }

  let aggs = trip.aggregations || [];
  for (const key of ["trip", "data", "result"]) {
    if (!aggs.length && trip[key] && Array.isArray(trip[key].aggregations)) {
      aggs = trip[key].aggregations;
    }
  }

  const poly = aggs.find(a =>
    String(a.eventType ?? a.event_type ?? "").toUpperCase() === "POSITION" &&
    String(a.aggregationType ?? a.aggregation_type ?? "").toUpperCase() === "POLYLINE"
  );

  return (poly && typeof poly.value === "string") ? decodePolyline(poly.value) : [];
}

function makeTrackXML(points, row, usedFallback, indent = "  ") {
  const name = tripName(row);
  const desc = `autoaid Trip ID: ${row["Trip ID"]}; ${row["Start address"] || ""} → ${row["End address"] || ""}` +
    (usedFallback ? "; Track aus autoaid-POLYLINE (ohne Punkt-Zeitstempel)" : "");

  const p1 = indent + "  ";
  const p2 = indent + "    ";
  const p3 = indent + "      ";

  const trkpts = points.map(p => {
    let s = `${p3}<trkpt lat="${p.lat.toFixed(7)}" lon="${p.lon.toFixed(7)}">`;
    if (p.time) s += `\n${p3}  <time>${escapeXML(p.time)}</time>\n${p3}`;
    s += `</trkpt>`;
    return s;
  }).join("\n");

  return `${indent}<trk>
${p1}<name>${escapeXML(name)}</name>
${p1}<desc>${escapeXML(desc)}</desc>
${p1}<trkseg>
${trkpts}
${p1}</trkseg>
${indent}</trk>`;
}

function makeGPX(points, row, usedFallback) {
  const name = tripName(row);
  return `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="autoaid GPX Export for Scriptable"
     xmlns="http://www.topografix.com/GPX/1/1"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
  <metadata>
    <name>${escapeXML(name)}</name>
  </metadata>
${makeTrackXML(points, row, usedFallback, "  ")}
</gpx>`;
}

function formatDateDE(date) {
  return `${pad2(date.getDate())}.${pad2(date.getMonth() + 1)}.${date.getFullYear()}`;
}

function formatDateISO(date) {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

function startOfDay(date) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function endOfDay(date) {
  const d = new Date(date);
  d.setHours(23, 59, 59, 999);
  return d;
}

function tripStartDate(row) {
  const ts = parseAutoaidDate(row["Start date"], row["Start time"]);
  return ts ? new Date(ts) : null;
}

function makeMultiGPX(converted, fromDate, toDate) {
  const title = `autoaid-Fahrten ${formatDateDE(fromDate)} bis ${formatDateDE(toDate)}`;
  const tracks = converted
    .map(item => makeTrackXML(item.points, item.row, item.usedFallback, "  "))
    .join("\n");

  return `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="autoaid GPX Export for Scriptable"
     xmlns="http://www.topografix.com/GPX/1/1"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
  <metadata>
    <name>${escapeXML(title)}</name>
    <desc>${converted.length} getrennte autoaid-Fahrten, gemeinsam in einer GPX-Datei</desc>
  </metadata>
${tracks}
</gpx>`;
}

async function chooseFromRows(rows, title, message) {
  if (!rows.length) return null;

  // Action Sheets mit sehr vielen Einträgen werden unhandlich.
  // Daher jeweils höchstens 25 Treffer anzeigen.
  const shown = rows.slice(0, 25);
  const a = new Alert();
  a.title = title;
  a.message = message || "";
  shown.forEach(r => a.addAction(tripLabel(r)));
  a.addCancelAction("Abbrechen");
  const idx = await a.presentSheet();
  return idx >= 0 ? shown[idx] : null;
}

async function searchTrip(trips) {
  while (true) {
    const a = new Alert();
    a.title = "Fahrt suchen";
    a.message = "Suche nach Datum (z. B. 25.09.2026), Uhrzeit, Ort, Adresse, Strecke oder Trip-ID.";
    a.addTextField("Suchbegriff", "");
    a.addAction("Suchen");
    a.addCancelAction("Abbrechen");
    const idx = await a.presentAlert();
    if (idx < 0) return null;

    const raw = a.textFieldValue(0).trim();
    if (!raw) continue;
    const q = normalizeSearch(raw);

    const matches = trips.filter(row => {
      const hay = [
        row["Start date"], row["End date"], displayDate(row["Start date"]),
        row["Start time"], row["End time"],
        row["Start address"], row["End address"], row["Distance"],
        row["Duration"], row["Trip ID"], row["Purpose of trip"], row["Contact person"]
      ].join(" ").toLowerCase();
      return hay.includes(q) || hay.includes(raw.toLowerCase());
    });

    if (!matches.length) {
      await info("Keine Fahrt gefunden", `Für „${raw}“ wurde keine Fahrt gefunden.`);
      continue;
    }

    if (matches.length > 25) {
      const narrow = await confirm(
        `${matches.length} Treffer`,
        "Das sind zu viele Fahrten für eine übersichtliche Auswahl. Suche bitte etwas genauer, z. B. zusätzlich nach einem Ort oder einer Uhrzeit.",
        "Suche verfeinern",
        "Abbrechen"
      );
      if (narrow) continue;
      return null;
    }

    return await chooseFromRows(matches, `${matches.length} Treffer`, `Suche: ${raw}`);
  }
}

async function chooseDateRange(trips) {
  const validDates = trips
    .map(tripStartDate)
    .filter(d => d && !Number.isNaN(d.getTime()))
    .sort((a, b) => a - b);

  if (!validDates.length) {
    throw new Error("In der CSV konnten keine gültigen Fahrtdaten erkannt werden.");
  }

  const earliest = startOfDay(validDates[0]);
  const latest = startOfDay(validDates[validDates.length - 1]);

  const fromPicker = new DatePicker();
  fromPicker.minimumDate = earliest;
  fromPicker.maximumDate = latest;
  fromPicker.initialDate = latest;
  const fromDate = startOfDay(await fromPicker.pickDate());

  const toPicker = new DatePicker();
  toPicker.minimumDate = fromDate;
  toPicker.maximumDate = latest;
  toPicker.initialDate = latest < fromDate ? fromDate : latest;
  const toDate = endOfDay(await toPicker.pickDate());

  const matches = trips
    .filter(row => {
      const d = tripStartDate(row);
      return d && d >= fromDate && d <= toDate;
    })
    .sort((a, b) => parseAutoaidDate(a["Start date"], a["Start time"]) - parseAutoaidDate(b["Start date"], b["Start time"]));

  if (!matches.length) {
    await info(
      "Keine Fahrten",
      `Zwischen ${formatDateDE(fromDate)} und ${formatDateDE(toDate)} wurden keine Fahrten gefunden.`
    );
    return null;
  }

  const preview = matches.slice(0, 4).map(r => "• " + tripLabel(r)).join("\n");
  const more = matches.length > 4 ? `\n… und ${matches.length - 4} weitere Fahrt(en)` : "";

  const ok = await confirm(
    `${matches.length} Fahrt${matches.length === 1 ? "" : "en"} gefunden`,
    `${formatDateDE(fromDate)} bis ${formatDateDE(toDate)}\n\n${preview}${more}\n\nAlle Fahrten werden als getrennte Tracks in EINER gemeinsamen GPX-Datei gespeichert.`,
    "Gesammelt exportieren",
    "Abbrechen"
  );

  if (!ok) return null;
  return { fromDate, toDate, rows: matches };
}

async function exportDateRange(trips) {
  const selection = await chooseDateRange(trips);
  if (!selection) return;

  const token = await getAccessToken();
  if (!token) return;

  const converted = [];
  const failed = [];
  let fallbackCount = 0;
  let pointCount = 0;

  for (let i = 0; i < selection.rows.length; i++) {
    const row = selection.rows[i];
    const tripId = String(row["Trip ID"] || "").trim();

    try {
      if (!tripId) throw new Error("Trip ID fehlt");

      let points = await fetchPositionEvents(tripId, token);
      let usedFallback = false;

      if (!points.length) {
        points = await fetchPolylineFallback(tripId, token);
        usedFallback = points.length > 0;
      }

      if (!points.length) {
        throw new Error("Keine POSITION-Daten oder Polyline");
      }

      converted.push({ row, points, usedFallback });
      pointCount += points.length;
      if (usedFallback) fallbackCount++;
    } catch (e) {
      failed.push({
        row,
        reason: String(e && e.message ? e.message : e)
      });
    }
  }

  if (!converted.length) {
    const first = failed[0];
    throw new Error(
      "Keine der ausgewählten Fahrten konnte exportiert werden." +
      (first ? `\n\nErster Fehler: ${tripLabel(first.row)}\n${first.reason}` : "")
    );
  }

  const gpx = makeMultiGPX(converted, selection.fromDate, selection.toDate);
  const filename =
    `autoaid_${formatDateISO(selection.fromDate)}_bis_${formatDateISO(selection.toDate)}` +
    `_${converted.length}_Fahrten.gpx`;

  await DocumentPicker.exportString(gpx, filename);

  let msg = `${converted.length} Fahrt${converted.length === 1 ? "" : "en"} wurden in einer gemeinsamen GPX-Datei gespeichert.\n\n` +
            `${pointCount} Trackpunkte insgesamt.`;

  if (fallbackCount) {
    msg += `\n${fallbackCount} Fahrt${fallbackCount === 1 ? "" : "en"} wurde${fallbackCount === 1 ? "" : "n"} aus der autoaid-Polyline erzeugt und hat daher keine Zeitstempel an den einzelnen Trackpunkten.`;
  }

  if (failed.length) {
    msg += `\n\n${failed.length} Fahrt${failed.length === 1 ? "" : "en"} konnte${failed.length === 1 ? "" : "n"} nicht abgerufen werden und wurde${failed.length === 1 ? "" : "n"} ausgelassen.`;
    const firstFailures = failed.slice(0, 3).map(f => "• " + tripLabel(f.row)).join("\n");
    msg += `\n${firstFailures}`;
    if (failed.length > 3) msg += `\n… und ${failed.length - 3} weitere`;
  }

  await info("Sammel-GPX erstellt", msg);
}

async function resetLogin() {
  if (Keychain.contains(KEY_REFRESH)) Keychain.remove(KEY_REFRESH);
  if (Keychain.contains(KEY_EMAIL)) Keychain.remove(KEY_EMAIL);
  await info("Anmeldung zurückgesetzt", "Beim nächsten GPX-Export wirst du erneut nach deinen autoaid-Zugangsdaten gefragt.");
}

async function chooseTrip(trips) {
  while (true) {
    const recent = trips.slice(0, 10);
    const a = new Alert();
    a.title = "autoaid → GPX";
    a.message = `${trips.length} Fahrten geladen. Wähle eine der letzten Fahrten oder suche.`;

    recent.forEach(r => a.addAction(tripLabel(r)));
    a.addAction("📅 Zeitraum gesammelt exportieren …");
    a.addAction("🔎 Ältere Fahrt suchen …");
    a.addAction("↻ Neue CSV einlesen …");
    a.addAction("🔐 Anmeldung zurücksetzen");
    a.addCancelAction("Beenden");

    const idx = await a.presentSheet();
    if (idx < 0) return null;

    if (idx < recent.length) return recent[idx];

    const special = idx - recent.length;
    if (special === 0) {
      return { __range: true };
    } else if (special === 1) {
      const row = await searchTrip(trips);
      if (row) return row;
    } else if (special === 2) {
      const ok = await importCSV();
      if (ok) return { __reload: true };
    } else if (special === 3) {
      await resetLogin();
    }
  }
}

async function exportTrip(row) {
  const tripId = String(row["Trip ID"] || "").trim();
  if (!tripId) throw new Error("Diese Fahrt hat keine Trip ID.");

  const token = await getAccessToken();
  if (!token) return;

  let points = await fetchPositionEvents(tripId, token);
  let usedFallback = false;

  if (!points.length) {
    points = await fetchPolylineFallback(tripId, token);
    usedFallback = points.length > 0;
  }

  if (!points.length) {
    throw new Error("Für diese Fahrt wurden weder POSITION-Ereignisse noch eine gespeicherte Polyline gefunden.");
  }

  const gpx = makeGPX(points, row, usedFallback);
  const filename = tripFilename(row);

  await DocumentPicker.exportString(gpx, filename);

  const note = usedFallback
    ? `${points.length} Trackpunkte exportiert. autoaid lieferte für diese Fahrt keine einzelnen POSITION-Ereignisse; deshalb wurde die gespeicherte Polyline verwendet. Die einzelnen Trackpunkte haben daher keine Zeitstempel.`
    : `${points.length} GPS-Punkte mit den von autoaid gelieferten Zeitstempeln exportiert.`;

  await info("GPX erstellt", note);
}

// ---------- Hauptprogramm ----------

async function main() {
  try {
    if (!localFM.fileExists(cachePath)) {
      const start = new Alert();
      start.title = "autoaid → GPX einrichten";
      start.message = "Wähle zunächst deinen normalen Fahrten-CSV-Export von autoaid aus. Er wird nur lokal in Scriptable gespeichert.";
      start.addAction("CSV auswählen");
      start.addCancelAction("Abbrechen");
      if (await start.presentAlert() < 0) return;

      const ok = await importCSV();
      if (!ok) return;
    }

    while (true) {
      const trips = loadTrips();
      if (!trips.length) throw new Error("In der gespeicherten CSV wurden keine Fahrten gefunden.");

      const chosen = await chooseTrip(trips);
      if (!chosen) break;
      if (chosen.__reload) continue;

      if (chosen.__range) {
        await exportDateRange(trips);
        break;
      }

      await exportTrip(chosen);
      break;
    }
  } catch (e) {
    await info("Fehler", String(e && e.message ? e.message : e));
  }
}

await main();
Script.complete();
"""#
}
