// Namenslisten: einmal anlegen, in jedem Klassenraum verwendbar.

import { h, clear, parseNames, uid } from './util.js';
import { icon } from './icons.js';
import { getState, addList, updateList, removeList } from './store.js';
import { openPanel, section, field, button, buttonRow, confirmDialog, toast } from './ui.js';

export function openListsPanel(initialListId = null) {
  const container = h('div', { class: 'stack' });
  let editingId = initialListId;

  function renderOverview() {
    clear(container);
    const lists = getState().lists;
    const rows = h('div', { class: 'stack' });
    if (!lists.length) {
      rows.appendChild(h('p', { class: 'muted small' }, 'Noch keine Liste angelegt.'));
    }
    for (const list of lists) {
      rows.appendChild(h('div', { class: 'list-row' },
        h('button', {
          class: 'list-row__main',
          onclick: () => {
            editingId = list.id;
            renderEditor();
          },
        },
        h('strong', null, list.name),
        h('small', { class: 'muted' }, `${list.names.length} Namen · ${list.names.slice(0, 3).join(', ')}${list.names.length > 3 ? ' …' : ''}`)),
        h('button', {
          class: 'icon-button', title: 'Duplizieren',
          onclick: () => {
            addList(`${list.name} (Kopie)`, list.names.slice());
            renderOverview();
          },
          html: icon('copy', 18),
        }),
        h('button', {
          class: 'icon-button icon-button--danger', title: 'Löschen',
          onclick: async () => {
            const ok = await confirmDialog('Liste löschen?', `„${list.name}“ wird dauerhaft entfernt.`);
            if (!ok) return;
            removeList(list.id);
            renderOverview();
          },
          html: icon('trash', 18),
        })));
    }

    container.append(
      section('Meine Listen', rows),
      buttonRow(button('Neue Liste', {
        icon: 'plus', primary: true,
        onClick: () => {
          const list = addList('Neue Klasse', []);
          editingId = list.id;
          renderEditor();
        },
      })),
      h('p', { class: 'muted small' },
        'Tipp: Listen gelten für alle Klassenräume. Im Element „Zufälliger Name“ wählst du, welche Liste dort genutzt wird.'));
  }

  function renderEditor() {
    const list = getState().lists.find((entry) => entry.id === editingId);
    if (!list) {
      renderOverview();
      return;
    }
    clear(container);
    const nameInput = h('input', {
      class: 'input', type: 'text', value: list.name,
      oninput: (event) => updateList(list.id, { name: event.target.value }),
    });
    const area = h('textarea', {
      class: 'input input--area', rows: 14, placeholder: 'Ein Name pro Zeile',
      value: list.names.join('\n'),
    });
    const counter = h('p', { class: 'muted small' }, `${list.names.length} Namen`);
    area.addEventListener('input', () => {
      const names = parseNames(area.value);
      // Wer aus der Liste verschwindet, verschwindet auch aus den Pausierten
      // und verliert sein Merkmal.
      const paused = (list.paused || []).filter((name) => names.includes(name));
      const old = (getState().lists.find((entry) => entry.id === editingId) || {}).marks || {};
      const marks = {};
      for (const name of names) {
        if (old[name]) marks[name] = old[name];
      }
      updateList(list.id, { names, paused, marks });
      counter.textContent = `${names.length} Namen`;
      renderPause();
      renderMarks();
    });

    // Pausierte Namen (z. B. krank) bleiben in der Liste, werden aber nicht gezogen.
    const pauseBox = h('div', { class: 'stack' });
    function renderPause() {
      clear(pauseBox);
      const current = getState().lists.find((entry) => entry.id === editingId);
      if (!current || !current.names.length) {
        pauseBox.appendChild(h('p', { class: 'muted small' }, 'Erst Namen eintragen — dann lässt sich hier pausieren.'));
        return;
      }
      const paused = current.paused || [];
      pauseBox.append(
        h('p', { class: 'muted small' },
          paused.length
            ? `${paused.length} Name(n) pausiert — sie werden nicht gezogen. Tippen schaltet um.`
            : 'Antippen pausiert einen Namen (z. B. bei Krankheit) — er wird dann nicht gezogen.'),
        h('div', { class: 'chips' }, current.names.map((name) => h('button', {
          class: 'chip-name' + (paused.includes(name) ? ' is-paused' : ''),
          title: paused.includes(name) ? 'Wieder mitziehen' : 'Pausieren (wird nicht gezogen)',
          onclick: () => {
            const next = paused.includes(name)
              ? paused.filter((entry) => entry !== name)
              : paused.concat(name);
            updateList(current.id, { paused: next });
            renderPause();
          },
        }, h('span', null, name)))));
    }
    renderPause();

    // Merkmale je Name (z. B. „J“/„M“) — beim Gruppen-Auslosen wird nach
    // Möglichkeit aus jedem Merkmal gemischt (ein Junge + ein Mädchen usw.).
    const marksBox = h('div', { class: 'stack' });
    function renderMarks() {
      clear(marksBox);
      const current = getState().lists.find((entry) => entry.id === editingId);
      if (!current || !current.names.length) {
        marksBox.appendChild(h('p', { class: 'muted small' }, 'Erst Namen eintragen — dann lassen sich hier Merkmale vergeben.'));
        return;
      }
      const marks = current.marks || {};
      const values = Array.from(new Set(Object.values(marks).filter(Boolean)));
      marksBox.append(
        h('p', { class: 'muted small' },
          'Kurzes Merkmal je Name, z. B. „J“ und „M“ — beim Auslosen von Gruppen wird dann nach Möglichkeit '
          + 'aus jedem Merkmal gemischt (ein Junge und ein Mädchen pro Gruppe). Auch eigene Merkmale sind möglich, '
          + 'etwa Lesestufen „A“/„B“/„C“. Leer lassen = ohne Merkmal.'),
        h('div', { class: 'marks-grid' }, current.names.map((name) => {
          const input = h('input', {
            class: 'input input--mark', type: 'text', maxlength: '6',
            value: marks[name] || '', placeholder: '—',
            oninput: (event) => {
              const fresh = getState().lists.find((entry) => entry.id === editingId);
              if (!fresh) return;
              const next = Object.assign({}, fresh.marks || {});
              const value = event.target.value.trim();
              if (value) next[name] = value;
              else delete next[name];
              updateList(fresh.id, { marks: next });
            },
          });
          return h('label', { class: 'marks-row' }, h('span', { class: 'marks-row__name' }, name), input);
        })),
        values.length > 1
          ? h('p', { class: 'muted small' }, `Vergebene Merkmale: ${values.join(', ')}`)
          : null);
    }
    renderMarks();

    container.append(
      buttonRow(button('Zurück zur Übersicht', {
        icon: 'back', ghost: true, small: true,
        onClick: () => {
          editingId = null;
          renderOverview();
        },
      })),
      section('Name der Liste', field('z. B. Klasse 4a', nameInput)),
      section('Namen', area, counter),
      section('Pausieren', pauseBox),
      section('Merkmale (für Gruppen)', marksBox),
      buttonRow(
        button('Alphabetisch sortieren', {
          icon: 'layers', small: true,
          onClick: () => {
            const names = parseNames(area.value).sort((a, b) => a.localeCompare(b, 'de'));
            updateList(list.id, { names });
            area.value = names.join('\n');
            counter.textContent = `${names.length} Namen`;
            renderPause();
            renderMarks();
          },
        }),
        button('Doppelte entfernen', {
          icon: 'check', small: true,
          onClick: () => {
            const names = Array.from(new Set(parseNames(area.value)));
            updateList(list.id, { names, paused: (list.paused || []).filter((name) => names.includes(name)) });
            area.value = names.join('\n');
            counter.textContent = `${names.length} Namen`;
            renderPause();
            renderMarks();
            toast('Doppelte Einträge entfernt.', 'success');
          },
        }),
        button('Nummern 1–30', {
          icon: 'plus', small: true,
          onClick: () => {
            const names = Array.from({ length: 30 }, (_, index) => String(index + 1));
            updateList(list.id, { names, paused: [], marks: {} });
            area.value = names.join('\n');
            counter.textContent = `${names.length} Namen`;
            renderPause();
            renderMarks();
          },
        })));
  }

  const panel = openPanel({
    title: 'Namenslisten',
    subtitle: 'Klassenlisten für die Zufallsauswahl',
    content: container,
    wide: true,
  });

  if (editingId) renderEditor();
  else renderOverview();
  return panel;
}

export function makeListFromNames(name, names) {
  return { id: uid('list'), name, names };
}
