/**
 * Lightweight opening_hours evaluation for the most common OSM patterns:
 *   "24/7", "Mo-Fr 08:00-18:00", "Mo-Sa 09:00-20:00; Su 10:00-16:00",
 *   "Mo,We,Fr 10:00-18:00", "08:00-20:00", "Mo-Su 06:00-22:00", "off"/"closed".
 * Anything it cannot parse yields `undefined` (status "unknown") – the raw
 * string is still shown to the user, we never guess.
 */

const DAYS = ['su', 'mo', 'tu', 'we', 'th', 'fr', 'sa'];

interface Interval {
  days: Set<number>; // 0=Sunday .. 6=Saturday
  from: number; // minutes since midnight
  to: number;
  closed?: boolean;
}

function parseDays(spec: string): Set<number> | null {
  const days = new Set<number>();
  for (const part of spec.split(',')) {
    const range = part.trim().toLowerCase();
    if (!range) continue;
    const m = range.match(/^([a-z]{2})(?:\s*-\s*([a-z]{2}))?$/);
    if (!m) return null;
    const a = DAYS.indexOf(m[1]);
    if (a < 0) return null;
    if (m[2]) {
      const b = DAYS.indexOf(m[2]);
      if (b < 0) return null;
      for (let i = a; ; i = (i + 1) % 7) {
        days.add(i);
        if (i === b) break;
      }
    } else {
      days.add(a);
    }
  }
  return days.size ? days : null;
}

function parseRule(rule: string): Interval[] | null {
  const r = rule.trim();
  if (!r) return [];
  const lower = r.toLowerCase();
  if (lower === '24/7') return [{ days: new Set([0, 1, 2, 3, 4, 5, 6]), from: 0, to: 1440 }];

  // Optional day spec followed by time span(s), or "off"
  const m = r.match(/^([A-Za-z ,\-]+?)?\s*((?:\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2}\s*,?\s*)+|off|closed)$/);
  if (!m) return null;
  const daySpec = m[1]?.trim();
  const days = daySpec ? parseDays(daySpec) : new Set([0, 1, 2, 3, 4, 5, 6]);
  if (!days) return null;
  const timesPart = m[2].toLowerCase();
  if (timesPart === 'off' || timesPart === 'closed') {
    return [{ days, from: 0, to: 0, closed: true }];
  }
  const intervals: Interval[] = [];
  for (const t of timesPart.split(',')) {
    const tm = t.trim().match(/^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$/);
    if (!tm) return null;
    const from = parseInt(tm[1]) * 60 + parseInt(tm[2]);
    let to = parseInt(tm[3]) * 60 + parseInt(tm[4]);
    if (to === 0) to = 1440;
    intervals.push({ days, from, to });
  }
  return intervals;
}

/** Returns true/false when confidently determinable, otherwise undefined. */
export function isOpenNow(raw: string | undefined, now = new Date()): boolean | undefined {
  if (!raw) return undefined;
  const rules = raw.split(';');
  const intervals: Interval[] = [];
  for (const rule of rules) {
    const parsed = parseRule(rule);
    if (parsed === null) return undefined; // unparseable → unknown
    intervals.push(...parsed);
  }
  if (!intervals.length) return undefined;

  const day = now.getDay();
  const minutes = now.getHours() * 60 + now.getMinutes();
  const prevDay = (day + 6) % 7;

  let open = false;
  let matchedToday = false;
  for (const iv of intervals) {
    if (iv.days.has(day)) {
      matchedToday = true;
      if (iv.closed) {
        open = false; // later rules override earlier ones in opening_hours
        continue;
      }
      if (iv.to > iv.from) {
        if (minutes >= iv.from && minutes < iv.to) open = true;
      } else if (iv.to < iv.from) {
        // overnight span starting today
        if (minutes >= iv.from) open = true;
      }
    }
    // overnight span from the previous day reaching into today
    if (iv.days.has(prevDay) && !iv.closed && iv.to < iv.from && minutes < iv.to) {
      open = true;
      matchedToday = true;
    }
  }
  return matchedToday ? open : false;
}
