// Wiederverwendbare Oberflächen-Bausteine: Panel (Seitenleiste), Dialoge, Hinweise.

import { h, clear } from './util.js';
import { icon } from './icons.js';

let panelHost = null;
let panelCloser = null;

function ensureHosts() {
  if (!panelHost) panelHost = document.getElementById('panel-root');
}

export function openPanel({ title, subtitle, content, onClose, wide = false }) {
  ensureHosts();
  closePanel();
  const body = h('div', { class: 'panel__body' });
  const panel = h('div', { class: 'panel' + (wide ? ' panel--wide' : ''), role: 'dialog', 'aria-label': title },
    h('div', { class: 'panel__head' },
      h('div', null,
        h('h2', null, title),
        subtitle ? h('p', { class: 'panel__subtitle' }, subtitle) : null),
      h('button', { class: 'icon-button', title: 'Schließen', onclick: () => closePanel(), html: icon('close', 20) })),
    body);
  const backdrop = h('div', { class: 'panel-backdrop', onclick: () => closePanel() });
  panelHost.appendChild(backdrop);
  panelHost.appendChild(panel);
  if (content) body.appendChild(content);
  requestAnimationFrame(() => panel.classList.add('is-open'));
  panelCloser = () => {
    panel.remove();
    backdrop.remove();
    panelCloser = null;
    if (onClose) onClose();
  };
  return { panel, body, setContent: (node) => { clear(body); body.appendChild(node); } };
}

export function closePanel() {
  if (panelCloser) panelCloser();
}

export function isPanelOpen() {
  return Boolean(panelCloser);
}

export function modal({ title, content, actions = [], onClose }) {
  const host = document.getElementById('modal-root');
  const box = h('div', { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-label': title });
  const wrap = h('div', { class: 'modal-backdrop' }, box);
  const close = () => {
    wrap.remove();
    if (onClose) onClose();
  };
  box.appendChild(h('div', { class: 'modal__head' },
    h('h2', null, title),
    h('button', { class: 'icon-button', title: 'Schließen', onclick: close, html: icon('close', 20) })));
  const body = h('div', { class: 'modal__body' });
  if (content) body.appendChild(content);
  box.appendChild(body);
  if (actions.length) {
    box.appendChild(h('div', { class: 'modal__actions' }, actions.map((action) => h('button', {
      class: 'button' + (action.primary ? ' button--primary' : '') + (action.danger ? ' button--danger' : ''),
      onclick: () => {
        const result = action.onClick ? action.onClick() : true;
        if (result !== false) close();
      },
    }, action.label))));
  }
  wrap.addEventListener('click', (event) => {
    if (event.target === wrap) close();
  });
  host.appendChild(wrap);
  return { close, body };
}

export function confirmDialog(title, message, confirmLabel = 'Löschen') {
  return new Promise((resolve) => {
    modal({
      title,
      content: h('p', { class: 'muted' }, message),
      actions: [
        { label: 'Abbrechen', onClick: () => resolve(false) },
        { label: confirmLabel, danger: true, primary: true, onClick: () => resolve(true) },
      ],
      onClose: () => resolve(false),
    });
  });
}

export function promptDialog(title, label, value = '', confirmLabel = 'Speichern') {
  return new Promise((resolve) => {
    const input = h('input', { class: 'input', type: 'text', value });
    let settled = false;
    const done = (result) => {
      if (settled) return;
      settled = true;
      resolve(result);
    };
    const dialog = modal({
      title,
      content: h('label', { class: 'field' }, h('span', null, label), input),
      actions: [
        { label: 'Abbrechen', onClick: () => done(null) },
        { label: confirmLabel, primary: true, onClick: () => done(input.value.trim() || null) },
      ],
      onClose: () => done(null),
    });
    input.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') {
        done(input.value.trim() || null);
        dialog.close();
      }
    });
    setTimeout(() => input.focus(), 50);
  });
}

let toastTimer = null;

export function toast(message, tone = 'info') {
  const host = document.getElementById('toast-root');
  clear(host);
  const box = h('div', { class: `toast toast--${tone}` }, message);
  host.appendChild(box);
  requestAnimationFrame(() => box.classList.add('is-open'));
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    box.classList.remove('is-open');
    setTimeout(() => box.remove(), 250);
  }, 3200);
}

export function section(title, ...children) {
  return h('section', { class: 'stack-section' },
    title ? h('h3', { class: 'stack-section__title' }, title) : null,
    ...children);
}

export function field(label, control, hint) {
  return h('label', { class: 'field' },
    h('span', null, label),
    control,
    hint ? h('small', { class: 'muted' }, hint) : null);
}

export function toggleRow(label, checked, onChange, hint) {
  const input = h('input', { type: 'checkbox', checked, onchange: (event) => onChange(event.target.checked) });
  return h('label', { class: 'toggle-row' },
    h('span', null, h('strong', null, label), hint ? h('small', { class: 'muted' }, hint) : null),
    h('span', { class: 'switch' }, input, h('span', { class: 'switch__track' })));
}

export function buttonRow(...buttons) {
  return h('div', { class: 'button-row' }, ...buttons);
}

export function button(label, options = {}) {
  const el = h('button', {
    class: ['button', options.primary ? 'button--primary' : '', options.danger ? 'button--danger' : '',
      options.ghost ? 'button--ghost' : '', options.small ? 'button--small' : '', options.full ? 'button--full' : '']
      .filter(Boolean).join(' '),
    type: 'button',
    title: options.title || '',
    onclick: options.onClick,
  });
  if (options.disabled) el.disabled = true;
  if (options.icon) el.insertAdjacentHTML('afterbegin', icon(options.icon, options.small ? 16 : 18));
  if (label) el.appendChild(h('span', null, label));
  return el;
}

export function colorSwatches(colors, current, onPick) {
  return h('div', { class: 'swatches' }, colors.map((color) => h('button', {
    class: 'swatch' + (color === current ? ' is-active' : ''),
    style: { background: color },
    title: color,
    onclick: () => onPick(color),
  })));
}
