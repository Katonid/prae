// Farbschemata: bestimmen Akzentfarben, Verläufe und Leuchten der Oberfläche.
// Alles läuft über CSS-Eigenschaften, damit jedes Element automatisch folgt.

export const SCHEMES = [
  { id: 'indigo', label: 'Indigo', from: '#6366f1', mid: '#a855f7', to: '#ec4899', glow: '99, 102, 241' },
  { id: 'ozean', label: 'Ozean', from: '#0ea5e9', mid: '#06b6d4', to: '#14b8a6', glow: '14, 165, 233' },
  { id: 'wald', label: 'Wald', from: '#16a34a', mid: '#0d9488', to: '#65a30d', glow: '22, 163, 74' },
  { id: 'sonne', label: 'Sonne', from: '#f59e0b', mid: '#f97316', to: '#e11d48', glow: '245, 158, 11' },
  { id: 'schiefer', label: 'Schiefer', from: '#475569', mid: '#334155', to: '#1e293b', glow: '71, 85, 105' },
  { id: 'kreide', label: 'Kreide', from: '#7c8ba1', mid: '#8b9bb4', to: '#a3b1c6', glow: '124, 139, 161' },
];

export function scheme(board) {
  const id = (board && board.accent) || 'indigo';
  return SCHEMES.find((entry) => entry.id === id) || SCHEMES[0];
}

/** Farben für SVG-Verläufe (Timer-Ring, Sekundenzeiger). */
export function accentPair(board) {
  const entry = scheme(board);
  const plain = board && board.gradient === false;
  return { from: entry.from, to: plain ? entry.from : entry.to };
}

export function applyScheme(board) {
  const entry = scheme(board);
  const plain = board && board.gradient === false;
  const style = document.body.style;
  style.setProperty('--accent', entry.from);
  style.setProperty('--accent-2', entry.mid);
  style.setProperty('--accent-3', entry.to);
  style.setProperty('--accent-grad', plain
    ? entry.from
    : `linear-gradient(135deg, ${entry.from} 0%, ${entry.mid} 55%, ${entry.to} 100%)`);
  style.setProperty('--accent-glow', `0 14px 34px -12px rgba(${entry.glow}, 0.85)`);
  style.setProperty('--accent-soft-bg', `rgba(${entry.glow}, 0.12)`);
}
