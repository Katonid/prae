// Kleinkram, den der xlsx- und der docx-Leser teilen.

// Wandelt XML-Entitäten zurück in Zeichen.
export function entziffere(text) {
  return text.replace(/&(#x?[0-9a-fA-F]+|amp|lt|gt|quot|apos);/g, (ganz, kern) => {
    if (kern === 'amp') return '&';
    if (kern === 'lt') return '<';
    if (kern === 'gt') return '>';
    if (kern === 'quot') return '"';
    if (kern === 'apos') return "'";
    const nummer = kern[1] === 'x' || kern[1] === 'X'
      ? parseInt(kern.slice(2), 16)
      : parseInt(kern.slice(1), 10);
    return Number.isFinite(nummer) ? String.fromCodePoint(nummer) : ganz;
  });
}

export function alsText(dateien, pfad) {
  const daten = dateien.get(pfad);
  return daten ? new TextDecoder('utf-8').decode(daten) : null;
}
