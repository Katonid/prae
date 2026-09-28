// Ein schlichter Schlüssel-Wert-Speicher auf IndexedDB — für die zuletzt
// geladenen OSM-Zellen, damit sie auch ohne Netz auf der Karte stehen.
// Jeder Zugriff darf scheitern (privates Fenster, voller Speicher): Dann
// läuft die App eben ohne Gedächtnis weiter.

const NAME = 'container-finder';
const ABLAGE = 'zellen';
let verbindung = null;

function oeffnen() {
  if (verbindung) return verbindung;
  verbindung = new Promise((fertig, fehler) => {
    const anfrage = indexedDB.open(NAME, 1);
    anfrage.onupgradeneeded = () => anfrage.result.createObjectStore(ABLAGE);
    anfrage.onsuccess = () => fertig(anfrage.result);
    anfrage.onerror = () => fehler(anfrage.error);
  }).catch((f) => { verbindung = null; throw f; });
  return verbindung;
}

async function vorgang(modus, arbeit) {
  const db = await oeffnen();
  return new Promise((fertig, fehler) => {
    const tx = db.transaction(ABLAGE, modus);
    const ergebnis = arbeit(tx.objectStore(ABLAGE));
    tx.oncomplete = () => fertig(ergebnis && 'result' in ergebnis ? ergebnis.result : undefined);
    tx.onerror = () => fehler(tx.error);
    tx.onabort = () => fehler(tx.error);
  });
}

export async function lesen(schluessel) {
  try { return await vorgang('readonly', (s) => s.get(schluessel)); } catch { return undefined; }
}

export async function schreiben(schluessel, wert) {
  try { await vorgang('readwrite', (s) => s.put(wert, schluessel)); } catch { /* ohne Gedächtnis */ }
}

// Alte Zellen wegräumen, damit der Speicher nicht endlos wächst.
export async function aufraeumen(behalten = 150) {
  try {
    const db = await oeffnen();
    const alle = await new Promise((fertig, fehler) => {
      const liste = [];
      const tx = db.transaction(ABLAGE, 'readonly');
      tx.objectStore(ABLAGE).openCursor().onsuccess = (e) => {
        const zeiger = e.target.result;
        if (!zeiger) return;
        liste.push([zeiger.key, zeiger.value?.zeit || 0]);
        zeiger.continue();
      };
      tx.oncomplete = () => fertig(liste);
      tx.onerror = () => fehler(tx.error);
    });
    if (alle.length <= behalten) return;
    alle.sort((a, b) => b[1] - a[1]);
    await vorgang('readwrite', (s) => { for (const [k] of alle.slice(behalten)) s.delete(k); });
  } catch { /* egal */ }
}
