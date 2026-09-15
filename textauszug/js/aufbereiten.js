// Aus Zeilen mit Ort wird lesbarer Text.
//
// Was ein PDF an Zeilenumbrüchen mitbringt, ist Satzspiegel, nicht Inhalt: Der
// Umbruch steht dort, wo die Seite zu Ende war. Wer den Text weiterverwendet —
// in den Notizen, in einer Mail —, will Absätze, keine Zeilen von je 78
// Zeichen. Zusammengeführt wird aber nur, wo der Abstand es hergibt: Der
// senkrechte Abstand zwischen zwei Zeilen sagt zuverlässiger, ob ein Absatz
// endet, als jede Regel über Satzzeichen.

const ZIFFERNZEILE = /^[\s[(–—-]*(?:Seite|Blatt|S\.)?\s*\d{1,4}\s*(?:\/\s*\d{1,4}|von\s+\d{1,4})?[\s\])–—-]*$/i;

function schluessel(text) {
  return text.toLowerCase().replace(/\s+/g, ' ').replace(/\d+/g, '#').trim();
}

// Welche Zeilen einer Seite stehen ÜBER oder UNTER dem Satzspiegel?
//
// Nicht „die ersten und letzten zwei" — daran ist diese Prüfung einmal
// gescheitert: In einem Text, der sich inhaltlich wiederholt (Formulare,
// Tabellen, Serienbriefe), sieht echter Inhalt wie eine Kopfzeile aus, und die
// App strich ihn weg. Eine Kopfzeile erkennt man am ABSTAND: Zwischen ihr und
// dem Text klafft eine Lücke, die größer ist als der Zeilenabstand.
// Der Zeilenabstand INNERHALB eines Absatzes: der kleine, häufige Abstand —
// nicht der mittlere. Auf einer kurzen Seite (Überschrift, zwei Absätze,
// Fußzeile) zöge der Mittelwert jede Schwelle zu weit hoch. Deshalb das
// untere Viertel.
function zeilenabstand(zeilen) {
  if (zeilen.length < 3) return null;
  const abstaende = [];
  for (let i = 0; i + 1 < zeilen.length; i++) abstaende.push(zeilen[i].y - zeilen[i + 1].y);
  const sortiert = abstaende.filter((a) => a > 0).sort((a, b) => a - b);
  if (!sortiert.length) return null;
  return sortiert[Math.floor(sortiert.length * 0.25)] || null;
}

function randzeilen(zeilen) {
  if (zeilen.length < 4) return new Set();
  const typisch = zeilenabstand(zeilen) || 1;
  const rand = new Set();

  for (let i = 0; i < 2 && i + 1 < zeilen.length; i++) {
    if (zeilen[i].y - zeilen[i + 1].y > typisch * 1.6) {
      for (let k = 0; k <= i; k++) rand.add(k);
      break;
    }
  }
  for (let i = zeilen.length - 1; i >= Math.max(1, zeilen.length - 2); i--) {
    if (zeilen[i - 1].y - zeilen[i].y > typisch * 1.6) {
      for (let k = i; k < zeilen.length; k++) rand.add(k);
      break;
    }
  }
  // Eine Kopfzeile ist KURZ und nie GRÖSSER als der Fließtext. Das zweite
  // Merkmal ist das wichtigere: Ein Dokument, dessen Seiten je mit einer
  // Kapitelüberschrift beginnen, verlöre sonst genau diese Überschriften —
  // sie stehen am Rand, mit Abstand, und ähneln sich von Seite zu Seite.
  const groessen = zeilen.map((zeile) => zeile.groesse).sort((a, b) => a - b);
  const normalgroesse = groessen[Math.floor(groessen.length / 2)] || 1;
  for (const index of [...rand]) {
    const zeile = zeilen[index];
    if (zeile.text.length > 80 || zeile.groesse > normalgroesse * 1.05) rand.delete(index);
  }
  return rand;
}

// Zeilen, die auf den meisten Seiten am Rand gleich lauten, sind Kopf- und
// Fußzeilen. Einzeln betrachtet sähe jede aus wie Inhalt.
function wiederholteFinden(seiten) {
  const zaehler = new Map();
  for (const seite of seiten) {
    const rand = randzeilen(seite.zeilen);
    const gesehen = new Set();
    for (const index of rand) {
      const k = schluessel(seite.zeilen[index].text);
      if (!k || k.length < 2 || gesehen.has(k)) continue;
      gesehen.add(k);
      zaehler.set(k, (zaehler.get(k) || 0) + 1);
    }
  }
  const grenze = Math.max(2, Math.ceil(seiten.length * 0.6));
  const wiederholt = new Set();
  for (const [k, anzahl] of zaehler) {
    if (anzahl >= grenze) wiederholt.add(k);
  }
  return wiederholt;
}

function kopfUndFussWeg(seiten) {
  const wiederholt = wiederholteFinden(seiten);
  let entfernt = 0;
  const sauber = seiten.map((seite) => {
    const rand = randzeilen(seite.zeilen);
    const zeilen = seite.zeilen.filter((zeile, index) => {
      if (!rand.has(index)) return true;
      // Eine reine Seitenzahl steht auf jeder Seite anders da und fiele dem
      // Vergleich nie auf — sie wird an ihrer Gestalt erkannt.
      if (ZIFFERNZEILE.test(zeile.text)) { entfernt++; return false; }
      if (wiederholt.has(schluessel(zeile.text))) { entfernt++; return false; }
      return true;
    });
    return { ...seite, zeilen };
  });
  return { seiten: sauber, entfernt };
}

// Endet die Zeile mit einem Trennstrich, gehört das Wort zusammen — außer der
// Strich gehört dazu („E-Mail", „Nord-Süd"). Als Regel: Geht es klein weiter,
// war es eine Trennung.
function trennungAufloesen(links, rechts) {
  if (!/[\p{Ll}\p{Lu}]-$/u.test(links)) return null;
  if (!/^[\p{Ll}]/u.test(rechts)) return null;
  return links.slice(0, -1) + rechts;
}

// Zeilen einer Seite zu Absätzen bündeln: Der senkrechte Abstand entscheidet.
function absaetzeBauen(zeilen, zusammenfuehren) {
  const stuecke = [];
  let laufend = '';
  let vorige = null;
  // Der rechte Rand des Satzspiegels. Eine Zeile, die deutlich davor endet,
  // ist das Ende eines Absatzes — so entsteht Flattersatz, und genau daran
  // erkennt man einen Zeilenumbruch, der KEINER Fortsetzung dient. Ohne das
  // wachsen Aufzählungen und Grußformeln zu einem Klumpen zusammen.
  const randRechts = zeilen.reduce((groesster, zeile) => Math.max(groesster, zeile.bis || 0), 0);
  // Womit der senkrechte Abstand verglichen wird, entscheidet alles: Ein
  // Kinderbuch setzt 16 Punkt Schrift mit 37 Punkt Zeilenabstand. An der
  // Schriftgröße gemessen wäre dort JEDE Zeile ein neuer Absatz (gefunden
  // 09/2026 an „Caesar und Zombie"). Gemessen wird deshalb am Zeilenabstand
  // der Seite selbst; nur wenn der nicht zu ermitteln ist, zählt die Schrift.
  const abstandSeite = zeilenabstand(zeilen);

  let groesste = 0;
  const schliessen = () => {
    if (laufend.trim()) stuecke.push({ text: laufend.trim(), groesse: groesste });
    laufend = '';
    groesste = 0;
  };

  for (const zeile of zeilen) {
    const text = zeile.text;
    if (!text) continue;
    let neuerAbsatz = vorige === null;
    if (vorige) {
      const abstand = vorige.y - zeile.y;
      const zeilenhoehe = Math.max(vorige.groesse, zeile.groesse, 1);
      const schwelle = abstandSeite ? abstandSeite * 1.45 : zeilenhoehe * 1.55;
      // Deutlich mehr Luft als zwischen zwei Zeilen desselben Absatzes:
      // neuer Absatz. Eine größere Schrift ebenfalls.
      if (abstand > schwelle) neuerAbsatz = true;
      if (zeile.groesse > vorige.groesse * 1.25) neuerAbsatz = true;
      if (!zusammenfuehren) neuerAbsatz = true;
      // Aufzählungen bleiben eigene Zeilen.
      if (/^[-•·*•–]\s|^\d{1,2}[.)]\s/.test(text)) neuerAbsatz = true;
      if (vorige.aufzaehlung && zusammenfuehren && !neuerAbsatz) {
        neuerAbsatz = abstand > (abstandSeite ? abstandSeite * 1.15 : zeilenhoehe * 1.2);
      }
    }

    // Ein Trennstrich am Zeilenende wiegt schwerer als jede Randregel: Das
    // Wort ist mitten entzwei und gehört zusammen.
    const verbunden = neuerAbsatz || !vorige ? null : trennungAufloesen(laufend, text);
    if (verbunden === null && vorige && zusammenfuehren && !neuerAbsatz) {
      // Etwa ein halbes Wort Luft am rechten Rand: Darunter ist es Flattersatz
      // innerhalb eines Absatzes, darüber hat der Absatz aufgehört. Gemessen
      // an drei Sorten PDF — enger gefasst zerfiel ein Absatz in seine Zeilen.
      const luecke = randRechts - (vorige.bis || 0);
      if (luecke > Math.max(4, vorige.groesse * 3.4)) neuerAbsatz = true;
    }

    if (verbunden !== null) {
      laufend = verbunden;
    } else if (neuerAbsatz) {
      schliessen();
      laufend = text;
    } else {
      laufend += ' ' + text;
    }
    groesste = Math.max(groesste, zeile.groesse);
    vorige = { ...zeile, aufzaehlung: /^[-•·*•–]\s|^\d{1,2}[.)]\s/.test(text) };
  }
  schliessen();
  return stuecke;
}

export function aufbereiten(seitenRoh, einstellungen = {}) {
  const {
    kopfzeilen = true,
    absaetze = true,
    seitenmarken = false,
  } = einstellungen;

  let seiten = seitenRoh;
  let entfernt = 0;
  if (kopfzeilen && seiten.length >= 2) {
    const ergebnis = kopfUndFussWeg(seiten);
    seiten = ergebnis.seiten;
    entfernt = ergebnis.entfernt;
  }

  // Die übliche Schriftgröße des ganzen Dokuments — der Maßstab, an dem sich
  // eine Überschrift erkennen lässt. Gemessen über ALLE Seiten: Auf einer
  // einzelnen Seite kann die Überschrift die Mehrheit stellen.
  const allegroessen = [];
  for (const seite of seiten) {
    for (const zeile of seite.zeilen) allegroessen.push(zeile.groesse);
  }
  allegroessen.sort((a, b) => a - b);
  const normalgroesse = allegroessen[Math.floor(allegroessen.length / 2)] || 1;

  const bloecke = [];
  let leereSeiten = 0;
  for (const seite of seiten) {
    const stuecke = absaetzeBauen(seite.zeilen, absaetze);
    if (!stuecke.length) leereSeiten++;
    if (seitenmarken) bloecke.push({ text: `--- Seite ${seite.nummer} ---`, marke: true });
    for (const stueck of stuecke) {
      // Größer gesetzt und kurz: eine Überschrift. Beides muss zutreffen —
      // ein langer Absatz in großer Schrift ist ein Vorspann, keine Zeile
      // fürs Inhaltsverzeichnis.
      const groesser = stueck.groesse > normalgroesse * 1.15;
      const kurz = stueck.text.length <= 120;
      bloecke.push({
        text: stueck.text,
        ueberschrift: groesser && kurz,
        ebene: stueck.groesse > normalgroesse * 1.45 ? 1 : 2,
      });
    }
  }

  const text = bloecke.map((block) => block.text).join('\n\n')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();

  return { text, bloecke, entfernt, leereSeiten };
}
