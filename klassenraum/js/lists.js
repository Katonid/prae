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
      updateList(list.id, { names });
      counter.textContent = `${names.length} Namen`;
    });

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
      buttonRow(
        button('Alphabetisch sortieren', {
          icon: 'layers', small: true,
          onClick: () => {
            const names = parseNames(area.value).sort((a, b) => a.localeCompare(b, 'de'));
            updateList(list.id, { names });
            area.value = names.join('\n');
            counter.textContent = `${names.length} Namen`;
          },
        }),
        button('Doppelte entfernen', {
          icon: 'check', small: true,
          onClick: () => {
            const names = Array.from(new Set(parseNames(area.value)));
            updateList(list.id, { names });
            area.value = names.join('\n');
            counter.textContent = `${names.length} Namen`;
            toast('Doppelte Einträge entfernt.', 'success');
          },
        }),
        button('Nummern 1–30', {
          icon: 'plus', small: true,
          onClick: () => {
            const names = Array.from({ length: 30 }, (_, index) => String(index + 1));
            updateList(list.id, { names });
            area.value = names.join('\n');
            counter.textContent = `${names.length} Namen`;
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
