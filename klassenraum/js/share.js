// Teilen, Abgleich & Konto: Klassenräume per Code weitergeben, live folgen,
// alle Geräte abgleichen und das Konto verwalten.

import { h, clear, copyText, debounce } from './util.js';
import {
  getState, getActiveBoard, importBoard, touch, saveNow, on as onStore, replaceState,
} from './store.js';
import {
  initCloud, cloudReady, publishBoard, fetchShare, subscribeShare, removeShare,
  accountsAvailable, signIn, signUp, signOutAccount, onAccountChanged, currentAccount,
  pushBackup, pullBackup,
} from './cloud.js';
import {
  syncInfo, startSync, joinSync, adoptSpace, spaceFromCookie, linkCode, syncNow, stopSync,
  setAutoSync, onSyncChanged, mediaSyncStatus, syncMediaNow,
} from './sync.js';
import { isFreshStart } from './store.js';
import { openPanel, section, field, button, buttonRow, toggleRow, toast, confirmDialog } from './ui.js';
import { renderBoard } from './board.js';

let applyingRemote = false;
let unsubscribeFollow = null;
let followedCode = null;

function shareEntry(boardId, create = false) {
  const state = getState();
  if (!state.cloud.shares) state.cloud.shares = {};
  if (!state.cloud.shares[boardId] && create) state.cloud.shares[boardId] = {};
  return state.cloud.shares[boardId] || null;
}

function shareLink(code, param = 'code') {
  const url = new URL(window.location.href);
  url.hash = '';
  url.search = `?${param}=${code}`;
  return url.toString();
}

function clockTime(stamp) {
  if (!stamp) return '';
  return new Date(stamp).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
}

const pushSoon = debounce(async () => {
  const board = getActiveBoard();
  if (!board || applyingRemote) return;
  const entry = shareEntry(board.id);
  if (!entry || !entry.code || entry.follow || entry.autoPush === false) return;
  try {
    await publishBoard(board, entry);
    entry.updatedAt = Date.now();
    saveNow();
  } catch (error) {
    console.warn('Teilen fehlgeschlagen', error);
  }
}, 2500);

function applyRemoteBoard(payload) {
  const board = getActiveBoard();
  if (!board || !payload || !payload.board) return;
  applyingRemote = true;
  const remote = payload.board;
  board.name = remote.name || board.name;
  board.background = remote.background || board.background;
  // Neue Stände schicken Seiten; ältere nur widgets/drawing — dann wird
  // daraus eine einzelne Seite.
  const pages = Array.isArray(remote.pages) && remote.pages.length
    ? remote.pages
    : [{
      id: 'p1',
      widgets: Array.isArray(remote.widgets) ? remote.widgets : [],
      drawing: Array.isArray(remote.drawing) ? remote.drawing : [],
    }];
  board.pages = pages;
  board.activePageId = pages.some((page) => page.id === remote.activePageId)
    ? remote.activePageId
    : pages[0].id;
  board.cardStyle = remote.cardStyle || board.cardStyle;
  board.format = remote.format || board.format;
  saveNow();
  renderBoard();
  document.dispatchEvent(new CustomEvent('klassenraum:board-updated'));
  setTimeout(() => { applyingRemote = false; }, 200);
}

async function syncFollow() {
  const board = getActiveBoard();
  const entry = board ? shareEntry(board.id) : null;
  const wanted = entry && entry.follow && entry.code ? entry.code : null;
  if (wanted === followedCode) return;
  if (unsubscribeFollow) {
    unsubscribeFollow();
    unsubscribeFollow = null;
  }
  followedCode = wanted;
  if (!wanted) return;
  try {
    unsubscribeFollow = await subscribeShare(wanted, (payload) => {
      if (payload) applyRemoteBoard(payload);
    });
  } catch (error) {
    console.warn('Live-Verbindung nicht möglich', error);
  }
}

export function initSharing() {
  onStore('change', () => pushSoon());
  onStore('board-switch', () => syncFollow());
  syncFollow();

  // Konto und Gerät zeigen auf verschiedene Abgleich-Bereiche: nachfragen,
  // ob dieses Gerät in den Bereich des Kontos wechseln soll.
  onStore('sync-space-conflict', async (payload) => {
    if (!payload || !payload.remembered) return;
    const ok = await confirmDialog('Anderen Abgleich-Bereich übernehmen?',
      'Dein Konto ist mit einem anderen Abgleich-Bereich verbunden als dieses Gerät — deshalb gleichen die Geräte '
      + 'aneinander vorbei. Soll dieses Gerät dem Bereich des Kontos beitreten? Die Tafeln dieses Geräts werden dabei zusammengeführt.',
      'Beitreten');
    if (!ok) return;
    try {
      await adoptSpace(payload.remembered, { keepLocal: true });
      renderBoard();
      toast('Mit dem Bereich deines Kontos verbunden — Tafeln werden abgeglichen.', 'success');
    } catch (error) {
      toast('Wechseln nicht möglich — Internetverbindung prüfen.', 'warn');
    }
  });

  const params = new URLSearchParams(window.location.search);
  const code = params.get('code');
  const syncParam = params.get('sync');
  const raumParam = params.get('raum');
  if (code || syncParam) {
    window.history.replaceState({}, '', window.location.pathname);
    setTimeout(() => openSharePanel(code ? code.toUpperCase() : '', syncParam ? syncParam.toUpperCase() : ''), 400);
    return;
  }
  if (raumParam && /^s[a-z0-9]{8,}$/.test(raumParam)) {
    window.history.replaceState({}, '', window.location.pathname);
    reconnectSpace(raumParam, 'link');
    return;
  }
  // Speicher geleert (z. B. Whiteboard im Kiosk-Betrieb), aber das Cookie hat
  // überlebt: still wieder mit dem gemerkten Klassenraum verbinden.
  const cookieSpace = spaceFromCookie();
  if (cookieSpace && isFreshStart() && !syncInfo().active) {
    reconnectSpace(cookieSpace, 'cookie');
  }
}

/** Gerät wieder mit einem gemerkten Abgleich-Bereich verbinden („angemeldet bleiben"). */
async function reconnectSpace(spaceId, quelle) {
  const info = syncInfo();
  if (info.active) {
    if (info.spaceId !== spaceId && quelle === 'link') {
      toast('Dieses Gerät gleicht bereits einen anderen Klassenraum ab — der Tafel-Link wurde nicht übernommen.', 'warn');
    }
    return;
  }
  try {
    if (isFreshStart()) {
      // Nichts Eigenes auf dem Gerät — den Stand des Bereichs übernehmen,
      // ohne eine frische Beispieltafel in den Bereich zu drücken.
      await adoptSpace(spaceId, { keepLocal: false });
      renderBoard();
      toast('Wieder mit deinem Klassenraum verbunden.', 'success');
      return;
    }
    if (quelle !== 'link') return;
    const ok = await confirmDialog('Mit dem gespeicherten Klassenraum verbinden?',
      'Die Tafeln dieses Geräts werden mit dem Klassenraum zusammengeführt und danach abgeglichen.', 'Verbinden');
    if (!ok) return;
    await adoptSpace(spaceId, { keepLocal: true });
    renderBoard();
    toast('Mit dem Klassenraum verbunden.', 'success');
  } catch (error) {
    toast('Verbinden nicht möglich — Internetverbindung prüfen.', 'warn');
  }
}

export function isFollowing() {
  const board = getActiveBoard();
  const entry = board ? shareEntry(board.id) : null;
  return Boolean(entry && entry.follow && entry.code);
}

export function openSharePanel(prefillCode = '', prefillSyncCode = '') {
  const container = h('div', { class: 'stack' });
  let unsubscribeAccount = null;
  let unsubscribeSync = null;
  // Zuletzt erzeugter Kopplungscode, damit er im Panel stehen bleibt.
  let pendingLink = null;
  // Beim Verbinden: eigene Tafeln mitnehmen oder nur den anderen Stand übernehmen?
  let keepLocal = true;

  function render() {
    clear(container);
    const board = getActiveBoard();
    const entry = shareEntry(board.id);

    /* --- eigenen Klassenraum teilen --- */
    const shareBox = h('div', { class: 'stack' });
    if (entry && entry.code && !entry.follow) {
      shareBox.append(
        h('div', { class: 'code-display' },
          h('span', { class: 'code-display__label' }, 'Teilen-Code'),
          h('strong', { class: 'code-display__code' }, entry.code)),
        buttonRow(
          button('Code kopieren', {
            icon: 'copy', small: true,
            onClick: async () => {
              await copyText(entry.code);
              toast('Code kopiert.', 'success');
            },
          }),
          button('Link kopieren', {
            icon: 'share', small: true,
            onClick: async () => {
              await copyText(shareLink(entry.code));
              toast('Link kopiert.', 'success');
            },
          })),
        toggleRow('Änderungen automatisch senden', entry.autoPush !== false, (value) => {
          entry.autoPush = value;
          touch({ board: false });
          if (value) pushSoon();
        }, 'Andere sehen deine Änderungen dann beim nächsten Laden bzw. live.'),
        buttonRow(
          button('Jetzt senden', {
            icon: 'upload', primary: true, small: true,
            onClick: async () => {
              try {
                const result = await publishBoard(board, entry);
                Object.assign(entry, result);
                saveNow();
                toast('Klassenraum aktualisiert.', 'success');
              } catch (error) {
                toast('Senden nicht möglich — Internetverbindung prüfen.', 'warn');
              }
            },
          }),
          button('Freigabe beenden', {
            icon: 'trash', ghost: true, small: true,
            onClick: async () => {
              const ok = await confirmDialog('Freigabe beenden?',
                'Der Code funktioniert danach nicht mehr. Dein Klassenraum bleibt auf diesem Gerät erhalten.', 'Beenden');
              if (!ok) return;
              try {
                await removeShare(entry.code);
              } catch (_) { /* egal */ }
              delete getState().cloud.shares[board.id];
              saveNow();
              render();
              toast('Freigabe beendet.', 'success');
            },
          })));
    } else if (entry && entry.follow) {
      shareBox.append(
        h('p', { class: 'muted small' }, `Dieser Klassenraum folgt live dem Code ${entry.code}. Änderungen der teilenden Person erscheinen automatisch.`),
        buttonRow(button('Folgen beenden (Kopie behalten)', {
          icon: 'close', small: true,
          onClick: () => {
            delete getState().cloud.shares[board.id];
            saveNow();
            syncFollow();
            render();
          },
        })));
    } else {
      shareBox.append(
        h('p', { class: 'muted small' },
          'Erzeugt einen kurzen Code. Wer ihn eingibt, kann diesen Klassenraum laden — z. B. die interaktive Tafel im Klassenzimmer oder Kolleginnen und Kollegen.'),
        button('Teilen-Code erstellen', {
          icon: 'share', primary: true, full: true,
          onClick: async () => {
            try {
              const created = await publishBoard(board, {});
              getState().cloud.shares[board.id] = Object.assign({ autoPush: true, follow: false }, created);
              saveNow();
              render();
              toast('Code erstellt.', 'success');
            } catch (error) {
              toast('Keine Verbindung — Teilen braucht Internet.', 'warn');
            }
          },
        }));
    }
    container.appendChild(section(`Klassenraum „${board.name}“ teilen`, shareBox));

    /* --- fremden Klassenraum öffnen --- */
    const codeInput = h('input', {
      class: 'input input--code', type: 'text', maxlength: '8', placeholder: 'z. B. K7M3QA',
      value: prefillCode || '',
      oninput: (event) => { event.target.value = event.target.value.toUpperCase(); },
    });
    const load = async (follow) => {
      const value = codeInput.value.trim().toUpperCase();
      if (value.length < 4) {
        toast('Bitte den vollständigen Code eingeben.', 'warn');
        return;
      }
      try {
        const payload = await fetchShare(value);
        if (!payload || !payload.board) {
          toast('Zu diesem Code wurde nichts gefunden.', 'warn');
          return;
        }
        const incoming = JSON.parse(JSON.stringify(payload.board));
        if (!follow) {
          const taken = getState().boards.some((entry) => entry.name === incoming.name);
          if (taken) incoming.name = `${incoming.name} (Kopie)`;
        }
        const created = importBoard(incoming);
        if (follow) {
          getState().cloud.shares[created.id] = { code: value, follow: true, autoPush: false };
        }
        saveNow();
        renderBoard();
        syncFollow();
        render();
        toast(follow ? 'Klassenraum geladen — folgt jetzt live.' : 'Kopie geladen.', 'success');
      } catch (error) {
        toast('Laden nicht möglich — Internetverbindung prüfen.', 'warn');
      }
    };
    container.appendChild(section('Geteilten Klassenraum öffnen',
      field('Code eingeben', codeInput),
      buttonRow(
        button('Als eigene Kopie laden', { icon: 'download', primary: true, small: true, onClick: () => load(false) }),
        button('Live folgen', { icon: 'layers', small: true, onClick: () => load(true) })),
      h('p', { class: 'muted small' },
        '„Kopie“ gehört danach dir und kann frei verändert werden. „Live folgen“ übernimmt jede Änderung der teilenden Person.')));

    /* --- Abgleich zwischen Geräten --- */
    container.appendChild(section('Abgleich zwischen Geräten', syncBox()));

    /* --- Konto --- */
    container.appendChild(section('Konto', accountBox()));

    container.appendChild(h('p', { class: 'muted small' },
      'Datenschutz: Geteilte und abgeglichene Klassenräume liegen unverschlüsselt auf dem Server. '
      + 'Geteiltes ist für jede Person mit dem Code lesbar; der Abgleich hängt an einer langen, zufälligen Kennung, die nur deine Geräte kennen. '
      + 'Verwende deshalb bitte nur Vornamen oder Kürzel — keine vollständigen Namen oder anderen persönlichen Daten. '
      + 'Beim Teilen per Code werden Klang- und Videodateien nicht mitgeschickt (dafür einen Link verwenden); '
      + 'beim Abgleich der eigenen Geräte wandern sie mit. '
      + 'Geschriebenes und Markiertes wird dagegen mitgeteilt.'));
  }

  function statusText(info) {
    if (!info.active) return 'Nicht eingerichtet.';
    if (info.status === 'busy') return 'Wird abgeglichen …';
    if (info.status === 'error') return `${info.error || 'Kein Netz'} — wird nachgeholt, sobald wieder Verbindung besteht.`;
    const time = clockTime(info.lastSyncAt);
    return time ? `Verbunden — zuletzt abgeglichen um ${time} Uhr.` : 'Verbunden.';
  }

  /**
   * Stand der Klang-/Videodateien im Abgleich — mit einem Knopf, der sie
   * gezielt überträgt und ehrlich sagt, woran es hakt (z. B. Datenbankregeln
   * ohne den Zweig „media").
   */
  function mediaBox() {
    const line = h('p', { class: 'muted small' }, 'Dateien: wird geprüft …');
    mediaSyncStatus().then((status) => {
      if (!status.total) {
        line.textContent = 'Keine Klang- oder Videodateien in den Tafeln.';
        return;
      }
      line.textContent = status.open
        ? `Dateien: ${status.open} von ${status.total} noch nicht auf allen Geräten.`
        : `Dateien: alle ${status.total} übertragen.`;
    }).catch(() => {
      line.textContent = '';
    });
    return h('div', { class: 'stack' }, line,
      buttonRow(button('Dateien jetzt übertragen', {
        icon: 'upload', small: true,
        onClick: async () => {
          const result = await syncMediaNow();
          if (result.error) {
            toast(result.rulesProblem
              ? 'Der Server lehnt die Dateien ab — bitte die aktuellen Datenbankregeln (firebase-rules.json) in der Firebase-Konsole einspielen.'
              : `Dateien nur teilweise übertragen (${result.sent} gesendet, ${result.pulled} geholt) — Internetverbindung prüfen.`, 'warn');
          } else {
            toast(`Dateien abgeglichen — ${result.sent} gesendet, ${result.pulled} geholt.`, 'success');
          }
          render();
        },
      })));
  }

  function linkBox() {
    if (!pendingLink) return null;
    return h('div', { class: 'stack' },
      h('div', { class: 'code-display' },
        h('span', { class: 'code-display__label' }, 'Kopplungscode (eine Stunde gültig)'),
        h('strong', { class: 'code-display__code' }, pendingLink.code)),
      buttonRow(
        button('Code kopieren', {
          icon: 'copy', small: true,
          onClick: async () => {
            await copyText(pendingLink.code);
            toast('Code kopiert.', 'success');
          },
        }),
        button('Link kopieren', {
          icon: 'share', small: true,
          onClick: async () => {
            await copyText(shareLink(pendingLink.code, 'sync'));
            toast('Link kopiert.', 'success');
          },
        })),
      h('p', { class: 'muted small' },
        'Auf dem anderen Gerät die App öffnen → „Teilen“ → „Gerät verbinden“ und den Code eingeben. '
        + 'Der Link macht dasselbe in einem Schritt.'));
  }

  function syncBox() {
    const box = h('div', { class: 'stack' });
    const info = syncInfo();

    if (!info.active) {
      const joinInput = h('input', {
        class: 'input input--code', type: 'text', maxlength: '8', placeholder: 'z. B. R4TK9B',
        value: prefillSyncCode || '',
        oninput: (event) => { event.target.value = event.target.value.toUpperCase(); },
      });
      box.append(
        h('p', { class: 'muted small' },
          'Hält alle Tafeln und Namenslisten auf allen Geräten gleich — iPad, Rechner und die Tafel im Klassenzimmer. '
          + 'Änderungen wandern automatisch hin und her; ohne Netz wird beim nächsten Mal nachgeholt.'),
        button('Abgleich einrichten', {
          icon: 'upload', primary: true, full: true,
          onClick: async () => {
            try {
              await startSync();
              pendingLink = await linkCode();
              render();
              toast('Abgleich eingerichtet.', 'success');
            } catch (error) {
              toast('Einrichten nicht möglich — Internetverbindung prüfen.', 'warn');
            }
          },
        }),
        field('Code vom anderen Gerät', joinInput),
        // Bewusst ohne render(): Ein Neuaufbau würde den eingetippten Code leeren.
        toggleRow('Tafeln dieses Geräts mitnehmen', keepLocal, (value) => {
          keepLocal = value;
        }, 'Aus: Dieses Gerät übernimmt nur die Tafeln und Listen des anderen Geräts — gut für ein frisches Gerät.'),
        buttonRow(button('Gerät verbinden', {
          icon: 'download', small: true,
          onClick: async () => {
            const value = joinInput.value.trim().toUpperCase();
            if (value.length < 4) {
              toast('Bitte den vollständigen Code eingeben.', 'warn');
              return;
            }
            try {
              await joinSync(value, { keepLocal });
              renderBoard();
              render();
              toast('Gerät verbunden — Tafeln werden abgeglichen.', 'success');
            } catch (error) {
              const message = error && error.message === 'CODE_ABGELAUFEN'
                ? 'Der Code ist abgelaufen — auf dem ersten Gerät einen neuen erzeugen.'
                : error && error.message === 'CODE_UNBEKANNT'
                  ? 'Zu diesem Code wurde nichts gefunden.'
                  : 'Verbinden nicht möglich — Internetverbindung prüfen.';
              toast(message, 'warn');
            }
          },
        })),
        h('p', { class: 'muted small' },
          'Auch Klang- und Videodateien wandern mit (bis 60 MB je Datei).'));
      return box;
    }

    // append(null) würde „null" als Text einfügen — deshalb erst filtern.
    const kennung = info.spaceId ? `${info.spaceId.slice(0, 8)}…${info.spaceId.slice(-4)}` : '—';
    box.append(...[
      h('p', { class: `sync-status is-${info.status}` }, statusText(info)),
      // Zum Vergleichen zwischen den Geräten: Nur Geräte mit derselben Kennung
      // gleichen miteinander ab — alles andere sind getrennte Bereiche.
      h('p', { class: 'muted small' },
        `Bereichskennung: ${kennung} — auf allen Geräten muss hier dieselbe Kennung stehen. `
        + 'Steht woanders eine andere, gleichen die Geräte aneinander vorbei: Dann dort unten den Tafel-Link '
        + 'dieses Geräts öffnen (oder per Code verbinden).'),
      toggleRow('Automatisch abgleichen', info.auto, (value) => {
        setAutoSync(value);
        render();
      }, 'Aus: Es wird nur beim Tippen auf „Jetzt abgleichen“ gesendet und geholt.'),
      buttonRow(
        button('Jetzt abgleichen', {
          icon: 'reset', primary: true, small: true,
          onClick: async () => {
            const ok = await syncNow();
            render();
            toast(ok ? 'Abgeglichen.' : 'Abgleich nicht möglich — Internetverbindung prüfen.', ok ? 'success' : 'warn');
          },
        }),
        button('Weiteres Gerät verbinden', {
          icon: 'share', small: true,
          onClick: async () => {
            try {
              pendingLink = await linkCode();
              render();
            } catch (error) {
              toast('Code konnte nicht erzeugt werden.', 'warn');
            }
          },
        })),
      mediaBox(),
      linkBox(),
      buttonRow(button('Tafel-Link kopieren (angemeldet bleiben)', {
        icon: 'copy', small: true,
        onClick: async () => {
          await copyText(shareLink(info.spaceId, 'raum'));
          toast('Tafel-Link kopiert.', 'success');
        },
      })),
      h('p', { class: 'muted small' },
        'Für Geräte, die ihren Speicher regelmäßig leeren (z. B. Whiteboards im Klassenzimmer): '
        + 'Den Tafel-Link dort als Lesezeichen oder Web-App speichern — beim Öffnen verbindet sich die Tafel von selbst wieder '
        + 'und holt alle Inhalte aus dem Abgleich. Der Link läuft nicht ab; bitte nur auf eigenen Geräten verwenden.'),
      buttonRow(button('Abgleich auf diesem Gerät beenden', {
        icon: 'close', ghost: true, small: true,
        onClick: async () => {
          const ok = await confirmDialog('Abgleich beenden?',
            'Dieses Gerät wird nicht mehr abgeglichen. Alle Tafeln bleiben hier erhalten; die anderen Geräte gleichen weiter ab.', 'Beenden');
          if (!ok) return;
          await stopSync();
          pendingLink = null;
          render();
          toast('Abgleich beendet.', 'success');
        },
      })),
    ].filter(Boolean));
    return box;
  }

  function accountBox() {
    const box = h('div', { class: 'stack' });
    const account = currentAccount();
    if (account) {
      box.append(
        h('p', null, h('strong', null, account.name || account.email), h('br'), h('small', { class: 'muted' }, account.email)),
        buttonRow(
          button('Sicherung hochladen', {
            icon: 'upload', small: true,
            onClick: async () => {
              try {
                await pushBackup(getState());
                toast('Alle Klassenräume gesichert.', 'success');
              } catch (error) {
                toast('Sicherung fehlgeschlagen.', 'warn');
              }
            },
          }),
          button('Sicherung laden', {
            icon: 'download', small: true,
            onClick: async () => {
              const ok = await confirmDialog('Sicherung laden?',
                'Die Klassenräume auf diesem Gerät werden durch die Sicherung ersetzt.', 'Laden');
              if (!ok) return;
              try {
                const backup = await pullBackup();
                if (!backup) {
                  toast('Es liegt noch keine Sicherung vor.', 'warn');
                  return;
                }
                const state = getState();
                replaceState(Object.assign({}, state, { boards: backup.boards, lists: backup.lists || state.lists }));
                renderBoard();
                toast('Sicherung geladen.', 'success');
              } catch (error) {
                toast('Laden fehlgeschlagen.', 'warn');
              }
            },
          }),
          button('Abmelden', { icon: 'close', ghost: true, small: true, onClick: () => signOutAccount() })));
      return box;
    }

    if (!cloudReady()) {
      box.appendChild(h('div', { class: 'note' },
        h('strong', null, 'Gerade keine Verbindung zum Server.'),
        h('p', { class: 'muted small' },
          'Alle Klassenräume auf diesem Gerät funktionieren weiter. Für Teilen und Konto wird Internet gebraucht.')));
      return box;
    }

    if (accountsAvailable() === false) {
      box.appendChild(h('div', { class: 'note' },
        h('strong', null, 'Konten sind für dieses Projekt noch nicht freigeschaltet.'),
        h('p', { class: 'muted small' },
          'Teilen per Code funktioniert trotzdem. Wer Konten nutzen möchte, aktiviert in der Firebase-Konsole unter '
          + '„Authentication → Anmeldemethode“ den Anbieter „E-Mail/Passwort“ — danach erscheint hier automatisch die Anmeldung.')));
      return box;
    }

    const emailInput = h('input', { class: 'input', type: 'email', placeholder: 'name@schule.de', autocomplete: 'email' });
    const passwordInput = h('input', { class: 'input', type: 'password', placeholder: 'Passwort', autocomplete: 'current-password' });
    const nameInput = h('input', { class: 'input', type: 'text', placeholder: 'Anzeigename (optional)' });
    const status = h('p', { class: 'muted small' });

    const run = async (action) => {
      status.textContent = 'Einen Moment …';
      try {
        if (action === 'signup') await signUp(emailInput.value.trim(), passwordInput.value, nameInput.value.trim());
        else await signIn(emailInput.value.trim(), passwordInput.value);
        status.textContent = '';
        render();
      } catch (error) {
        status.textContent = error.message === 'KONTEN_NICHT_AKTIV'
          ? 'Konten sind in diesem Firebase-Projekt noch nicht aktiviert (Authentication → E-Mail/Passwort).'
          : error.message;
      }
    };

    box.append(
      field('E-Mail', emailInput),
      field('Passwort', passwordInput),
      field('Name', nameInput),
      buttonRow(
        button('Anmelden', { primary: true, small: true, onClick: () => run('signin') }),
        button('Konto anlegen', { small: true, onClick: () => run('signup') })),
      status,
      h('p', { class: 'muted small' }, 'Mit Konto kannst du alle Klassenräume sichern und auf einem anderen Gerät wieder laden.'));
    return box;
  }

  const panel = openPanel({
    title: 'Teilen & Abgleich',
    subtitle: 'Klassenräume weitergeben, übernehmen und Geräte abgleichen',
    content: container,
    wide: true,
    onClose: () => {
      if (unsubscribeAccount) unsubscribeAccount();
      if (unsubscribeSync) unsubscribeSync();
    },
  });

  render();
  initCloud().then(() => render()).catch(() => {});
  unsubscribeAccount = onAccountChanged(() => render());
  let firstSyncCall = true;
  unsubscribeSync = onSyncChanged(() => {
    // Der erste Aufruf kommt sofort beim Anmelden — dann steht die Anzeige schon.
    if (firstSyncCall) {
      firstSyncCall = false;
      return;
    }
    render();
  });
  return panel;
}
