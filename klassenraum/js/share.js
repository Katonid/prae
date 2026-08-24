// Teilen & Konto: Klassenräume per Code weitergeben, live folgen, Konto verwalten.

import { h, clear, copyText, debounce } from './util.js';
import {
  getState, getActiveBoard, importBoard, touch, saveNow, on as onStore, replaceState,
} from './store.js';
import {
  initCloud, cloudReady, publishBoard, fetchShare, subscribeShare, removeShare,
  accountsAvailable, signIn, signUp, signOutAccount, onAccountChanged, currentAccount,
  pushBackup, pullBackup,
} from './cloud.js';
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

function shareLink(code) {
  const url = new URL(window.location.href);
  url.hash = '';
  url.search = `?code=${code}`;
  return url.toString();
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
  board.name = payload.board.name || board.name;
  board.background = payload.board.background || board.background;
  board.widgets = Array.isArray(payload.board.widgets) ? payload.board.widgets : [];
  board.drawing = Array.isArray(payload.board.drawing) ? payload.board.drawing : [];
  board.cardStyle = payload.board.cardStyle || board.cardStyle;
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

  const params = new URLSearchParams(window.location.search);
  const code = params.get('code');
  if (code) {
    window.history.replaceState({}, '', window.location.pathname);
    setTimeout(() => openSharePanel(code.toUpperCase()), 400);
  }
}

export function isFollowing() {
  const board = getActiveBoard();
  const entry = board ? shareEntry(board.id) : null;
  return Boolean(entry && entry.follow && entry.code);
}

export function openSharePanel(prefillCode = '') {
  const container = h('div', { class: 'stack' });
  let unsubscribeAccount = null;

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

    /* --- Konto --- */
    container.appendChild(section('Konto', accountBox()));

    container.appendChild(h('p', { class: 'muted small' },
      'Datenschutz: Geteilte Klassenräume liegen unverschlüsselt auf dem Server und sind für jede Person mit dem Code lesbar. '
      + 'Verwende deshalb bitte nur Vornamen oder Kürzel — keine vollständigen Namen oder anderen persönlichen Daten. '
      + 'Klang- und Videodateien vom Gerät werden nicht mitgeschickt; dafür bitte einen Link verwenden. '
      + 'Geschriebenes und Markiertes wird dagegen mitgeteilt.'));
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
    title: 'Teilen & Konto',
    subtitle: 'Klassenräume weitergeben oder übernehmen',
    content: container,
    wide: true,
    onClose: () => {
      if (unsubscribeAccount) unsubscribeAccount();
    },
  });

  render();
  initCloud().then(() => render()).catch(() => {});
  unsubscribeAccount = onAccountChanged(() => render());
  return panel;
}
