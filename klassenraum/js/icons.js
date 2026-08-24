// Schlichte Strich-Icons (currentColor), damit die App ohne externe Dateien auskommt.

const paths = {
  randomizer: '<path d="M3 6h4l10 12h4"/><path d="M3 18h4L17 6h4"/><path d="M18 3l3 3-3 3"/><path d="M18 15l3 3-3 3"/>',
  timer: '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 2.5"/><path d="M9 2h6"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  traffic: '<rect x="7" y="2" width="10" height="20" rx="5"/><circle cx="12" cy="7" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="12" cy="17" r="1.6"/>',
  checklist: '<path d="M4 6l2 2 3.5-3.5"/><path d="M4 14l2 2 3.5-3.5"/><path d="M13 6h7"/><path d="M13 15h7"/>',
  text: '<path d="M5 6V4h14v2"/><path d="M12 4v16"/><path d="M9 20h6"/>',
  image: '<rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="8.5" cy="9.5" r="1.8"/><path d="M4 17l5-5 4 4 3-2.5L20 17"/>',
  noise: '<path d="M11 5L6 9H3v6h3l5 4z"/><path d="M15.5 8.5a5 5 0 0 1 0 7"/><path d="M18.5 5.5a9 9 0 0 1 0 13"/>',
  symbols: '<circle cx="8" cy="8" r="3"/><circle cx="17" cy="9" r="2.4"/><path d="M3 19c0-3 2.2-5 5-5s5 2 5 5"/><path d="M14 19c0-2.2 1.4-4 3.2-4S21 16.8 21 19"/>',
  dice: '<rect x="3" y="3" width="18" height="18" rx="4"/><circle cx="8.5" cy="8.5" r="1.3"/><circle cx="15.5" cy="15.5" r="1.3"/><circle cx="12" cy="12" r="1.3"/>',
  home: '<path d="M4 11l8-7 8 7"/><path d="M6 10v10h12V10"/>',
  plus: '<path d="M12 5v14"/><path d="M5 12h14"/>',
  trash: '<path d="M4 7h16"/><path d="M9 7V5h6v2"/><path d="M6 7l1 13h10l1-13"/>',
  gear: '<circle cx="12" cy="12" r="3.2"/><path d="M12 2.5l1.4 2.6 2.9-.5 .6 2.9 2.6 1.4-1.6 2.5 1.6 2.5-2.6 1.4-.6 2.9-2.9-.5L12 21.5l-1.4-2.6-2.9.5-.6-2.9-2.6-1.4L6.1 12 4.5 9.5l2.6-1.4.6-2.9 2.9.5z"/>',
  dots: '<circle cx="12" cy="5" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="12" cy="19" r="1.4"/>',
  expand: '<path d="M4 9V4h5"/><path d="M20 15v5h-5"/><path d="M15 4h5v5"/><path d="M9 20H4v-5"/>',
  collapse: '<path d="M9 4v5H4"/><path d="M15 20v-5h5"/><path d="M20 9h-5V4"/><path d="M4 15h5v5"/>',
  share: '<circle cx="18" cy="5" r="2.5"/><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="19" r="2.5"/><path d="M8.2 10.8l7.6-4.3"/><path d="M8.2 13.2l7.6 4.3"/>',
  user: '<circle cx="12" cy="8" r="3.6"/><path d="M4 20c0-4 3.6-6.4 8-6.4S20 16 20 20"/>',
  close: '<path d="M6 6l12 12"/><path d="M18 6L6 18"/>',
  lock: '<rect x="5" y="10" width="14" height="10" rx="2.5"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
  unlock: '<rect x="5" y="10" width="14" height="10" rx="2.5"/><path d="M8 10V7a4 4 0 0 1 7.5-1.8"/>',
  copy: '<rect x="9" y="9" width="11" height="11" rx="2.5"/><path d="M15 6.5V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h.5"/>',
  layers: '<path d="M12 3l9 5-9 5-9-5z"/><path d="M3 13l9 5 9-5"/>',
  paint: '<path d="M5 12V6a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v3H9"/><rect x="3" y="12" width="8" height="5" rx="1.5"/><path d="M7 17v2a2 2 0 0 0 2 2h0a2 2 0 0 0 2-2v-2"/>',
  play: '<path d="M8 5l11 7-11 7z"/>',
  pause: '<path d="M9 5v14"/><path d="M15 5v14"/>',
  reset: '<path d="M4 12a8 8 0 1 0 2.5-5.8"/><path d="M4 4v5h5"/>',
  chevron: '<path d="M7 10l5 5 5-5"/>',
  back: '<path d="M15 5l-7 7 7 7"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7"/>',
  eye: '<path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  sparkle: '<path d="M12 3l1.8 4.7L18.5 9.5 13.8 11.3 12 16l-1.8-4.7L5.5 9.5l4.7-1.8z"/><path d="M18 15l.9 2.3 2.3.9-2.3.9L18 21.4l-.9-2.3-2.3-.9 2.3-.9z"/>',
  download: '<path d="M12 4v11"/><path d="M8 12l4 4 4-4"/><path d="M5 20h14"/>',
  upload: '<path d="M12 20V9"/><path d="M8 12l4-4 4 4"/><path d="M5 4h14"/>',
};

export function icon(name, size = 22) {
  const body = paths[name] || paths.dots;
  return `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${body}</svg>`;
}

export function iconEl(name, size = 22) {
  const span = document.createElement('span');
  span.className = 'icon';
  span.innerHTML = icon(name, size);
  return span;
}
