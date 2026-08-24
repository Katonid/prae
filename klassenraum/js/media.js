// Klänge und Videos: Dateien liegen als Datei-Objekte im Gerätespeicher,
// im Klassenraum steht nur ein Verweis darauf.

import { uid } from './util.js';
import { mediaPut, mediaGet, mediaDelete, mediaKeys, getState } from './store.js';

const urls = new Map();

export const MEDIA_LIMIT = 60 * 1024 * 1024; // 60 MB je Datei

export async function saveMediaFile(file) {
  if (!file) throw new Error('Keine Datei');
  if (file.size > MEDIA_LIMIT) throw new Error('ZU_GROSS');
  const id = uid('media');
  await mediaPut(id, {
    blob: file,
    name: file.name || 'Datei',
    type: file.type || '',
    size: file.size,
    savedAt: Date.now(),
  });
  return { id, name: file.name || 'Datei', type: file.type || '', size: file.size };
}

/** Adresse zum Abspielen — für Dateien im Gerät eine kurzlebige Objekt-Adresse. */
export async function mediaUrl(entry) {
  if (!entry) return null;
  if (entry.url) return entry.url;
  if (!entry.mediaId) return null;
  if (urls.has(entry.mediaId)) return urls.get(entry.mediaId);
  const record = await mediaGet(entry.mediaId);
  if (!record || !record.blob) return null;
  const url = URL.createObjectURL(record.blob);
  urls.set(entry.mediaId, url);
  return url;
}

export async function mediaInfo(mediaId) {
  if (!mediaId) return null;
  const record = await mediaGet(mediaId);
  if (!record) return null;
  return { name: record.name, type: record.type, size: record.size };
}

export async function removeMedia(mediaId) {
  if (!mediaId) return;
  if (urls.has(mediaId)) {
    URL.revokeObjectURL(urls.get(mediaId));
    urls.delete(mediaId);
  }
  await mediaDelete(mediaId);
}

export function formatSize(bytes) {
  if (!bytes) return '';
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

/** Dateien wegräumen, auf die kein Element mehr zeigt. */
export async function collectUnusedMedia() {
  try {
    const used = new Set();
    for (const board of getState().boards) {
      for (const widget of board.widgets) {
        const state = widget.state || {};
        if (state.mediaId) used.add(state.mediaId);
        for (const entry of state.entries || []) {
          if (entry.mediaId) used.add(entry.mediaId);
        }
      }
    }
    const keys = await mediaKeys();
    let removed = 0;
    for (const key of keys) {
      if (!used.has(key)) {
        await mediaDelete(key);
        removed += 1;
      }
    }
    return removed;
  } catch (_) {
    return 0;
  }
}

export async function mediaUsage() {
  try {
    const keys = await mediaKeys();
    let total = 0;
    for (const key of keys) {
      const record = await mediaGet(key);
      if (record && record.size) total += record.size;
    }
    return { count: keys.length, bytes: total };
  } catch (_) {
    return { count: 0, bytes: 0 };
  }
}

const AUDIO_ENDINGS = ['mp3', 'm4a', 'aac', 'wav', 'aif', 'aiff', 'caf', 'ogg', 'oga', 'opus', 'flac', 'weba'];
const VIDEO_ENDINGS = ['mp4', 'mov', 'm4v', 'webm', 'mkv', 'avi', 'mpg', 'mpeg'];

/** Passt die Datei zur erwarteten Art? Wird nur für einen Hinweis genutzt. */
export function looksLike(kind, file) {
  const name = String(file && file.name ? file.name : '').toLowerCase();
  const type = String(file && file.type ? file.type : '').toLowerCase();
  const endings = kind === 'video' ? VIDEO_ENDINGS : AUDIO_ENDINGS;
  if (type.startsWith(kind === 'video' ? 'video/' : 'audio/')) return true;
  return endings.some((ending) => name.endsWith(`.${ending}`));
}

/**
 * Dateiauswahl öffnen und die Datei im Gerät ablegen.
 * Bewusst ohne accept-Filter: iPadOS graut sonst Dateien aus, deren Art der
 * Anbieter (iCloud Drive, Netzlaufwerk) nicht mitliefert — genau das ist bei
 * MP3-Dateien passiert. Geprüft wird stattdessen nach der Auswahl.
 */
export function pickMedia() {
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.style.display = 'none';
    document.body.appendChild(input);
    input.addEventListener('change', async () => {
      const file = input.files && input.files[0];
      input.remove();
      if (!file) {
        resolve(null);
        return;
      }
      try {
        const saved = await saveMediaFile(file);
        resolve(Object.assign(saved, { file }));
      } catch (error) {
        resolve({ error: error.message });
      }
    });
    input.click();
  });
}
