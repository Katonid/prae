// Klassen: Der Weg von der Lehrkraft zu den Kindern.
//
// Der ganze Ablauf in fünf Sätzen:
//
// 1. Die Lehrkraft meldet sich an und legt eine Klasse an. Dabei entsteht ein
//    sechsstelliger Code.
// 2. Die App zeigt einen QR-Code, der auf genau diese Klasse zeigt. Er kommt
//    an den Beamer oder auf einen Zettel.
// 3. Jedes Kind fotografiert ihn ab, sucht sich einen Benutzernamen und eine
//    vierstellige PIN aus.
// 4. Was die Lehrkraft der Klasse mitgibt — eigene Bereiche und, wenn sie mag,
//    einen Auftrag („Päckchen 2, Stufe Diktat“) —, sehen die Kinder danach in
//    ihrer App.
// 5. Die Sterne der Kinder laufen zurück in die Klassenansicht.
//
// Warum der QR-Code selbst gerechnet wird, steht in qr.js. Warum die PIN nie
// im Klartext irgendwo liegt, in cloud.js.

import { h, leeren, datum } from './util.js';
import { blatt, abschnitt, zeile, schalter, frage, eingabe, ladeplatz, meldung } from './ui.js';
import { qrSvg } from './qr.js';
import { inZwischenablage } from './plattform.js';
import {
  kontenVerfuegbar, anmelden, kontoAnlegen, klartext, regelnPruefen, angemeldet, verwaltungPruefen,
  klasseAnlegen, klasseHolen, klasseLoeschen, klassenDerLehrkraft, klasseAendern,
  klasseWiederEintragen,
  kindAnlegen, kindAnmelden, kindEntfernen, pinNeuSetzen, kindUmbenennen, namensschluessel,
  fortschrittDerKlasse, fortschrittMelden,
  protokollMelden, protokollDerKlasse, protokollLoeschen,
} from './cloud.js';
import {
  eigeneBereiche, bereichSichern, klassen, klasseMerken, klasseVergessen,
  setzeNutzer, nutzer, daten, protokoll,
  setzeSichtbareBereiche,
} from './store.js';
import { BEREICHE } from './woerter.js';
import { RECHTSCHREIBUNG } from './rechtschreibung.js';
import { RECHTSCHREIBUNG1 } from './rechtschreibung1.js';
import { RECHTSCHREIBUNG2 } from './rechtschreibung2.js';
import { RECHTSCHREIBUNG3 } from './rechtschreibung3.js';
import { UEBUNGEN, stufenFuer } from './uebungen/index.js';
import { paketzahl } from './paket.js';
import { bereichswahl } from './bereiche.js';

/** Die Adresse, die im QR-Code steht. */
export function beitrittsadresse(code) {
  const grund = `${window.location.origin}${window.location.pathname}`;
  return `${grund}#/beitreten/${String(code).toUpperCase()}`;
}

/**
 * Der Kasten, der erklärt, warum gerade gar nichts geht.
 *
 * Er steht fest auf dem Blatt und verschwindet nicht nach vier Sekunden: Eine
 * Meldung, die man verpasst hat, ist keine. Und er sagt nicht nur, DASS etwas
 * nicht erlaubt ist, sondern wo der Schalter dafür sitzt — sonst sucht man an
 * der App, während der Fehler in der Firebase-Konsole liegt.
 */
function regelhinweis() {
  return h('div', { class: 'einrichthinweis' },
    h('h3', { class: 'einrichthinweis__titel' }, '🔒 Die Datenbank ist für diese App noch gesperrt'),
    h('p', {},
      'Klassen brauchen Regeln in der Firebase-Konsole, und für den Zweig '
      + '„woerterwerkstatt" fehlen sie noch. Solange das so ist, lässt sich keine Klasse '
      + 'anlegen und kein Kind beitreten. Alles Üben funktioniert trotzdem.'),
    h('ol', { class: 'einrichthinweis__schritte' },
      h('li', {}, 'Firebase-Konsole öffnen → Realtime Database → Reiter „Regeln“.'),
      h('li', {}, 'Den gesamten Inhalt der Datei ', h('code', {}, 'firebase-rules.json'),
        ' aus dem Wurzelverzeichnis des Repos hineinkopieren — sie enthält BEIDE Zweige '
        + 'und nichts sonst (der Regeleditor weist erklärende Zusätze ab).'),
      h('li', {}, 'Auf „Veröffentlichen“ tippen, dann hier neu laden.')),
    h('p', { class: 'einrichthinweis__warnung' },
      'Wichtig: Die Konsole ersetzt beim Veröffentlichen die kompletten Regeln. '
      + 'Wer nur einen Zweig einfügt, sperrt die andere App aus — deshalb stehen beide '
      + 'in derselben Datei.'));
}

/* ---------- Anmeldung der Lehrkraft ---------- */

export function lehrkraftAnmeldung(beiFertig) {
  let modus = 'anmelden';
  const email = h('input', { class: 'feld', type: 'email', autocomplete: 'email', placeholder: 'E-Mail' });
  const passwort = h('input', { class: 'feld', type: 'password', autocomplete: 'current-password', placeholder: 'Passwort' });
  const name = h('input', { class: 'feld', type: 'text', autocomplete: 'name', placeholder: 'Name (erscheint bei den Kindern)' });
  const namenszeile = h('div', { class: 'is-versteckt' }, name);
  const fehler = h('p', { class: 'blatt__fehler', 'aria-live': 'polite' });
  const machen = h('button', { class: 'knopf knopf--voll', type: 'button' }, 'Anmelden');
  const wechseln = h('button', { class: 'knopf knopf--flach', type: 'button' }, 'Noch kein Konto? Eins anlegen');

  wechseln.addEventListener('click', () => {
    modus = modus === 'anmelden' ? 'anlegen' : 'anmelden';
    namenszeile.classList.toggle('is-versteckt', modus !== 'anlegen');
    passwort.autocomplete = modus === 'anlegen' ? 'new-password' : 'current-password';
    machen.textContent = modus === 'anlegen' ? 'Konto anlegen' : 'Anmelden';
    wechseln.textContent = modus === 'anlegen' ? 'Ich habe schon ein Konto' : 'Noch kein Konto? Eins anlegen';
    fehler.textContent = '';
  });

  machen.addEventListener('click', async () => {
    fehler.textContent = '';
    machen.disabled = true;
    try {
      const sitzung = modus === 'anlegen'
        ? await kontoAnlegen(email.value.trim(), passwort.value, name.value.trim())
        : await anmelden(email.value.trim(), passwort.value);
      setzeNutzer({ art: 'lehrkraft', name: sitzung.name || sitzung.email, uid: sitzung.uid });
      dialog.schliessen();
      meldung(`Angemeldet als ${sitzung.name || sitzung.email}.`, 'gut');
      if (beiFertig) beiFertig(sitzung);
    } catch (problem) {
      fehler.textContent = String(problem.message) === 'KONTEN_NICHT_AKTIV'
        ? 'In diesem Firebase-Projekt sind Konten noch nicht freigeschaltet (Authentication → E-Mail/Passwort). Ohne Konto lässt sich alles außer eigenen Bereichen und Klassen nutzen.'
        : klartext(problem);
    } finally {
      machen.disabled = false;
    }
  });

  const dialog = blatt({
    titel: 'Anmeldung für Lehrkräfte',
    inhalt: h('div', {},
      h('p', { class: 'blatt__text' },
        'Zum Üben braucht es keine Anmeldung — die zwanzig Bereiche und alle fünf Stufen laufen ohne Konto. '
        + 'Angemeldet werden eigene Bereiche gesichert, und nur damit lässt sich eine Klasse anlegen.'),
      kontenVerfuegbar() === false
        ? h('p', { class: 'blatt__warnung' }, 'Konten sind in diesem Projekt gerade nicht freigeschaltet.')
        : null,
      email, passwort, namenszeile, fehler,
      h('div', { class: 'blatt__knopfreihe' }, machen, wechseln)),
  });
  return dialog;
}

/* ---------- Klassen der Lehrkraft ---------- */

export function klassenVerwalten() {
  const liste = h('div', { class: 'klassenliste' });

  async function zeichnen() {
    leeren(liste).appendChild(ladeplatz('Klassen werden geholt …'));
    // Erst nachsehen, ob die Datenbank überhaupt offensteht. Ohne das ist
    // „keine Klassen vorhanden" nicht von „darf nicht nachsehen" zu
    // unterscheiden — und der Knopf „Neue Klasse" verspricht etwas, das
    // hinterher nicht geht.
    const stand = await regelnPruefen();
    leeren(liste);
    if (stand === 'regeln-fehlen') {
      liste.appendChild(regelhinweis());
      neuknopf.disabled = true;
      return;
    }
    neuknopf.disabled = false;
    if (stand === 'kein-netz') {
      liste.appendChild(h('p', { class: 'blatt__warnung' },
        'Die Datenbank ist gerade nicht erreichbar. Ohne Netz lassen sich Klassen weder anlegen noch ansehen.'));
      return;
    }
    // Zwei Quellen, und beide dürfen lückenhaft sein:
    //
    //   * das Verzeichnis in der Wolke (`users/<uid>/klassen`) — es gilt auf
    //     allen Geräten, kann aber einen Eintrag verloren haben;
    //   * was DIESES Gerät noch weiß — vollständig für die hier angelegten
    //     Klassen, aber eben nur hier.
    //
    // Früher stand hier entweder/oder: Ging die Wolke, zählte nur sie; ging
    // sie nicht, nur das Gerät. Damit verschwand eine Klasse, deren
    // Verzeichniseintrag fehlte, auf jedem anderen Gerät spurlos — und auf
    // dem eigenen sah alles in Ordnung aus. Jetzt wird zusammengeführt und
    // repariert.
    let ausDerWolke = null;
    let stoerung = null;
    try {
      ausDerWolke = await klassenDerLehrkraft();
    } catch (problem) {
      stoerung = problem;
    }

    const nachCode = new Map();
    for (const k of klassen().filter((k2) => k2.rolle === 'lehrkraft')) {
      nachCode.set(k.code, { code: k.code, name: k.name, nurHier: true });
    }
    for (const k of ausDerWolke || []) {
      nachCode.set(k.code, Object.assign({}, nachCode.get(k.code), k, { nurHier: false }));
    }

    // Fehlt ein Eintrag im Verzeichnis, wird er nachgetragen — dann taucht die
    // Klasse beim nächsten Öffnen auch auf dem anderen Gerät auf. Nur wenn das
    // Verzeichnis wirklich gelesen wurde; sonst wüsste man ja nicht, ob etwas
    // fehlt.
    if (ausDerWolke) {
      for (const eintrag of Array.from(nachCode.values()).filter((k) => k.nurHier)) {
        try {
          const ergebnis = await klasseWiederEintragen(eintrag.code);
          if (ergebnis.stand === 'unbekannt') {
            // In der Wolke gelöscht — dann darf sie auch hier weg, sonst
            // führt ein Tipp darauf ins Leere.
            klasseVergessen(eintrag.code);
            nachCode.delete(eintrag.code);
          } else if (ergebnis.stand === 'fremd') {
            nachCode.delete(eintrag.code);
          } else {
            nachCode.set(eintrag.code, Object.assign({}, eintrag, ergebnis.klasse, { nurHier: false }));
          }
        } catch (_) { /* dann bleibt der Eintrag stehen und wird als „nur hier" gezeigt */ }
      }
    }

    const gefunden = Array.from(nachCode.values())
      .sort((a, b) => (b.angelegtAm || 0) - (a.angelegtAm || 0));

    if (stoerung) {
      // Nicht stillschweigend die Geräteliste zeigen: Wer nichts sieht, muss
      // erfahren, ob es keine Klasse gibt oder ob nur nicht nachzusehen war.
      liste.appendChild(h('p', { class: 'blatt__warnung' },
        `Die Klassenliste war nicht abzurufen (${klartext(stoerung)}). Was hier steht, weiß dieses Gerät.`));
    }
    if (!gefunden.length) {
      liste.appendChild(h('p', { class: 'blatt__text' },
        'Noch keine Klasse. Eine Klasse ist nichts weiter als ein Code, mit dem die Kinder in dieselben Bereiche kommen — und über den ihre Sterne zurücklaufen.'));
      return;
    }
    for (const klasse of gefunden) {
      liste.appendChild(h('button', {
        class: 'klassenliste__eintrag', type: 'button',
        onclick: () => klasseZeigen(klasse.code, zeichnen),
      },
        h('span', { class: 'klassenliste__code' }, klasse.code),
        h('span', { class: 'klassenliste__text' },
          h('strong', {}, klasse.name || 'Klasse'),
          h('span', {}, klasse.nurHier
            ? 'nur auf diesem Gerät bekannt'
            : (klasse.angelegtAm ? `angelegt am ${datum(klasse.angelegtAm)}` : ''))),
        h('span', { class: 'bereichsliste__pfeil' }, '›')));
    }
  }

  /**
   * Eine Klasse über ihren Code zurückholen.
   *
   * Der Weg für den Fall, dass eine Klasse auf einem Gerät fehlt: Der Code
   * steht auf dem QR-Zettel und in der Klassenansicht des anderen Geräts.
   * Gehört die Klasse diesem Konto, kommt sie zurück in die Liste — auf
   * diesem Gerät und, weil das Verzeichnis mitgeschrieben wird, auf allen
   * anderen gleich mit.
   */
  async function klasseHolenPerCode() {
    const eingetippt = await eingabe({
      titel: 'Klasse holen',
      text: 'Der sechsstellige Code der Klasse. Du findest ihn auf dem QR-Zettel — '
        + 'oder auf dem Gerät, auf dem die Klasse noch zu sehen ist.',
      platzhalter: 'ABC234',
      pruefung: (wert) => (wert.trim().length >= 4 ? null : 'Der Code hat sechs Zeichen.'),
      ja: 'Holen',
    });
    if (!eingetippt) return;
    const code = eingetippt.trim().toUpperCase();
    try {
      const ergebnis = await klasseWiederEintragen(code);
      if (ergebnis.stand === 'unbekannt') {
        meldung(`Zum Code ${code} gibt es keine Klasse. Vertippt?`, 'warnung', 5000);
        return;
      }
      if (ergebnis.stand === 'fremd') {
        meldung('Diese Klasse gehört nicht zu deinem Konto.', 'warnung', 5000);
        return;
      }
      klasseMerken({ code, name: ergebnis.klasse.name || 'Klasse', rolle: 'lehrkraft' });
      meldung(ergebnis.stand === 'eingetragen'
        ? `„${ergebnis.klasse.name || 'Klasse'}" ist wieder in deiner Liste.`
        : `„${ergebnis.klasse.name || 'Klasse'}" stand schon in deiner Liste.`, 'gut', 5000);
      zeichnen();
    } catch (problem) {
      meldung(klartext(problem), 'warnung', 5000);
    }
  }

  const neuknopf = h('button', {
    class: 'knopf knopf--voll', type: 'button', onclick: () => neueKlasse(zeichnen),
  }, '+ Neue Klasse');

  const holknopf = h('button', {
    class: 'knopf knopf--still', type: 'button', onclick: () => klasseHolenPerCode(),
  }, '↓ Klasse per Code holen');

  // Wozu dieses Konto berechtigt ist, sagt die Datenbank — nicht die App.
  // Die Zeile beantwortet die Frage, die sonst niemand beantworten kann:
  // „Warum sehe ich den Knopf ‚Schule‘ nicht?"
  const rollenzeile = h('p', { class: 'blatt__fussnote' });
  (async () => {
    const ich = angemeldet();
    if (!ich) return;
    const darf = await verwaltungPruefen();
    rollenzeile.textContent = `Angemeldet als ${ich.email || ich.name} · `
      + (darf
        ? 'Schulverwaltung (Knopf „🏫 Schule" in der Kopfzeile)'
        : 'Lehrkraft — eigene Klassen und eigene Bereiche');
  })();

  const dialog = blatt({
    titel: 'Meine Klassen',
    breit: true,
    inhalt: h('div', {}, liste,
      h('div', { class: 'blatt__knopfreihe' }, neuknopf, holknopf),
      rollenzeile),
  });
  zeichnen();
  return dialog;
}

function neueKlasse(beiFertig) {
  const name = h('input', { class: 'feld', type: 'text', placeholder: 'Name der Klasse, z. B. „4b“' });
  const auswahlliste = h('div', { class: 'mitgeben' });
  const gewaehlt = new Set(eigeneBereiche().map((b) => b.id));
  for (const bereich of eigeneBereiche()) {
    const kasten = h('label', { class: 'mitgeben__eintrag' },
      h('input', { type: 'checkbox', checked: true, onchange: (e) => { if (e.target.checked) gewaehlt.add(bereich.id); else gewaehlt.delete(bereich.id); } }),
      h('span', {}, `${bereich.emoji || '📗'} ${bereich.name}`));
    auswahlliste.appendChild(kasten);
  }

  // Ein Platz für den Fehlerfall, MITTEN im Blatt und dauerhaft. Vorher ging
  // die Meldung als Streifen am unteren Rand auf und war nach vier Sekunden
  // weg — wer in dem Moment auf den Knopf sah, bekam sie nie zu Gesicht und
  // erlebte nur, dass „Anlegen" nichts tut.
  const fehlerplatz = h('div', { class: 'is-versteckt' });

  const dialog = blatt({
    titel: 'Neue Klasse',
    inhalt: h('div', {},
      abschnitt('Name', name),
      abschnitt('Eigene Bereiche mitgeben',
        eigeneBereiche().length
          ? auswahlliste
          : h('p', { class: 'blatt__text' }, 'Du hast noch keine eigenen Bereiche. Die zwanzig mitgelieferten haben die Kinder ohnehin — mitgeben musst du nur, was du selbst angelegt hast.')),
      fehlerplatz,
    ),
    fusszeile: [
      h('button', { class: 'knopf knopf--still', type: 'button', onclick: () => dialog.schliessen() }, 'Abbrechen'),
      h('button', {
        class: 'knopf knopf--voll', type: 'button',
        onclick: async (ereignis) => {
          const knopf = ereignis.currentTarget;
          knopf.disabled = true;
          leeren(fehlerplatz).classList.add('is-versteckt');
          try {
            const mit = eigeneBereiche().filter((b) => gewaehlt.has(b.id));
            const klasse = await klasseAnlegen({ name: name.value.trim() || 'Meine Klasse', bereiche: mit });
            klasseMerken({ code: klasse.code, name: klasse.name, rolle: 'lehrkraft' });
            dialog.schliessen();
            if (beiFertig) beiFertig();
            klasseZeigen(klasse.code, beiFertig, true);
          } catch (problem) {
            fehlerplatz.classList.remove('is-versteckt');
            if (String(problem.message) === 'NICHT_ERLAUBT') {
              fehlerplatz.appendChild(regelhinweis());
            } else {
              fehlerplatz.appendChild(h('p', { class: 'blatt__fehler' }, klartext(problem)));
            }
            fehlerplatz.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
            knopf.disabled = false;
          }
        },
      }, 'Anlegen'),
    ],
  });
  return dialog;
}

/* ---------- Was die Kinder geschrieben haben ---------- */

/** Ein Wort als Zeile: wie oft, wie sicher, und was danebenging. */
function wortzeile(wort, mitKind = '') {
  const quote = wort.v ? Math.round((wort.r / wort.v) * 100) : 0;
  const sicher = wort.f === 0;
  return h('div', { class: `wortbefund${sicher ? ' is-sicher' : ''}` },
    h('div', { class: 'wortbefund__kopf' },
      h('strong', { class: 'wortbefund__wort' }, wort.w || wort.wort),
      mitKind ? h('span', { class: 'wortbefund__kind' }, mitKind) : null,
      h('span', { class: 'wortbefund__zahlen' },
        `${wort.r} von ${wort.v} gleich richtig · ${quote} %`)),
    (wort.e && wort.e.length)
      ? h('div', { class: 'wortbefund__eingaben' },
        h('span', { class: 'wortbefund__marke' }, 'geschrieben als'),
        ...wort.e.map((eingabe) => h('span', { class: 'wortbefund__falsch' }, eingabe)))
      : h('span', { class: 'wortbefund__lob' }, sicher ? 'immer richtig' : 'kein Tippfehler festgehalten'),
    wort.s ? h('div', { class: 'wortbefund__stufen' },
      ...UEBUNGEN.filter((u) => wort.s[u.id]).map((u) => h('span', { class: 'wortbefund__stufe' },
        `${u.emoji} ${wort.s[u.id].r}✓ ${wort.s[u.id].f}✗`))) : null);
}

/** Alle Wörter EINES Kindes, die schwersten zuerst. */
function kindprotokoll(kind) {
  const woerter = (kind.woerter || []).slice().sort((a, b) => (b.f - a.f) || (b.z - a.z));
  const schwer = woerter.filter((w) => w.f > 0);
  const sicher = woerter.filter((w) => w.f === 0);
  return blatt({
    titel: kind.name,
    breit: true,
    inhalt: h('div', {},
      h('p', { class: 'blatt__text' },
        `${woerter.length} ${woerter.length === 1 ? 'Wort' : 'Wörter'} bearbeitet`
        + ` · zuletzt am ${kind.aktualisiert ? datum(kind.aktualisiert) : '—'}`),
      schwer.length
        ? abschnitt(`Schwer gefallen (${schwer.length})`, ...schwer.map((w) => wortzeile(w)))
        : h('p', { class: 'blatt__gut' }, 'Kein Wort ging daneben.'),
      sicher.length
        ? abschnitt(`Saß auf Anhieb (${sicher.length})`, ...sicher.map((w) => wortzeile(w)))
        : null),
  });
}

/**
 * Die Wörter der ganzen Klasse, nach Fehlern sortiert.
 *
 * Das ist die Ansicht, für die das Protokoll überhaupt da ist: Sie sagt
 * einer Lehrkraft in fünf Sekunden, welche Wörter am Montag noch einmal an
 * die Tafel gehören — und wie die Klasse sie schreibt.
 */
function klassenprotokoll(code, kinder) {
  const nachWort = new Map();
  for (const kind of kinder) {
    for (const wort of kind.woerter || []) {
      const schluessel = `${wort.b}|${wort.w}`;
      const stand = nachWort.get(schluessel) || { w: wort.w, b: wort.b, v: 0, r: 0, f: 0, z: 0, e: [], kinder: new Set() };
      stand.v += wort.v || 0;
      stand.r += wort.r || 0;
      stand.f += wort.f || 0;
      stand.z = Math.max(stand.z, wort.z || 0);
      if (wort.f > 0) stand.kinder.add(kind.name);
      for (const eingabe of wort.e || []) if (!stand.e.includes(eingabe)) stand.e.push(eingabe);
      nachWort.set(schluessel, stand);
    }
  }
  const alle = Array.from(nachWort.values());
  const schwer = alle.filter((w) => w.f > 0).sort((a, b) => (b.f - a.f) || (b.kinder.size - a.kinder.size));

  return blatt({
    titel: 'Was der Klasse schwerfällt',
    breit: true,
    inhalt: h('div', {},
      h('p', { class: 'blatt__text' },
        kinder.length
          ? `${alle.length} verschiedene Wörter von ${kinder.length} ${kinder.length === 1 ? 'Kind' : 'Kindern'}.`
            + ' Die schwersten zuerst.'
          : 'Noch hat niemand geübt.'),
      ...schwer.slice(0, 60).map((wort) => wortzeile(
        { w: wort.w, v: wort.v, r: wort.r, f: wort.f, e: wort.e.slice(0, 8) },
        `${wort.kinder.size} ${wort.kinder.size === 1 ? 'Kind' : 'Kinder'}`,
      )),
      (!schwer.length && alle.length)
        ? h('p', { class: 'blatt__gut' }, 'Kein einziges Wort ging daneben.')
        : null),
  });
}

/** Die Klassenansicht: QR-Code, Auftrag, Kinder und ihre Sterne. */
export function klasseZeigen(code, beiAenderung, frischAngelegt = false) {
  const platz = h('div', {}, ladeplatz('Klasse wird geholt …'));

  const dialog = blatt({
    titel: `Klasse ${code}`,
    breit: true,
    inhalt: platz,
  });

  let bereichsuhr = null;

  (async () => {
    let klasse;
    try {
      klasse = await klasseHolen(code);
    } catch (problem) {
      leeren(platz).appendChild(String(problem.message) === 'NICHT_ERLAUBT'
        ? regelhinweis()
        : h('p', { class: 'blatt__fehler' }, klartext(problem)));
      return;
    }
    const adresse = beitrittsadresse(code);
    const qr = h('div', { class: 'qr-kasten' });
    try {
      qr.appendChild(qrSvg(adresse, { stufe: 'M' }));
    } catch (_) {
      qr.appendChild(h('p', { class: 'blatt__fehler' }, 'Der QR-Code ließ sich nicht erzeugen.'));
    }

    const kinderplatz = h('div', { class: 'kinderliste' }, ladeplatz('Kinder werden geholt …'));
    let protokolle = [];
    let protokollsperre = null;
    const protokollhinweis = h('div', { class: 'is-versteckt' });

    /**
     * Sagt, warum unter den Namen keine Wörter stehen.
     *
     * Drei Gründe sehen auf dem Bildschirm gleich aus und sind völlig
     * verschieden: Die Regeln lassen das Nachsehen nicht zu; das Mitschreiben
     * ist für diese Klasse abgeschaltet; es hat noch niemand geübt. Nur der
     * erste ist ein Fehler — und ausgerechnet der sah bis 1.5.1 aus wie „noch
     * nichts da".
     */
    function protokollhinweisZeichnen() {
      leeren(protokollhinweis).classList.add('is-versteckt');
      if (protokollsperre && String(protokollsperre.message) === 'NICHT_ERLAUBT') {
        protokollhinweis.classList.remove('is-versteckt');
        protokollhinweis.appendChild(h('div', { class: 'einrichthinweis' },
          h('h3', { class: 'einrichthinweis__titel' }, '📋 Die Wortprotokolle sind noch nicht lesbar'),
          h('p', {},
            'Die Kinder schreiben mit — nur das Nachsehen weist die Datenbank ab. Bis zur '
            + 'Fassung 1.5.0 stand die Leseerlaubnis im Zweig „protokoll" nur am einzelnen '
            + 'Kind; diese Ansicht liest aber die ganze Klasse auf einmal. Es geht nichts '
            + 'verloren: Was schon geübt wurde, erscheint, sobald die Regeln neu '
            + 'eingespielt sind.'),
          h('ol', { class: 'einrichthinweis__schritte' },
            h('li', {}, 'Firebase-Konsole → Realtime Database → Reiter „Regeln“.'),
            h('li', {}, 'Den gesamten Inhalt von ', h('code', {}, 'firebase-rules.json'),
              ' aus dem Wurzelverzeichnis des Repos einsetzen (Fassung 1.5.0 oder neuer).'),
            h('li', {}, 'Veröffentlichen, dann hier „↻ Neu laden“.'))));
        return;
      }
      if (klasse.protokoll === false) {
        protokollhinweis.classList.remove('is-versteckt');
        protokollhinweis.appendChild(h('p', { class: 'abschnitt__notiz' },
          'Das Mitschreiben ist für diese Klasse abgeschaltet (weiter unten). Solange das so '
          + 'ist, kommen keine neuen Wörter dazu.'));
        return;
      }
      if (!protokolle.length) {
        protokollhinweis.classList.remove('is-versteckt');
        protokollhinweis.appendChild(h('p', { class: 'abschnitt__notiz' },
          'Noch keine Wörter. Sie kommen an, sobald ein Kind ein Päckchen zu Ende gebracht '
          + 'hat — bei laufender Übung wird noch nichts gemeldet.'));
      }
    }

    async function kinderZeichnen() {
      let stand = [];
      try {
        stand = await fortschrittDerKlasse(code);
      } catch (_) {
        leeren(kinderplatz).appendChild(h('p', { class: 'blatt__fehler' }, 'Die Liste war nicht erreichbar.'));
        return;
      }
      // Das Wortprotokoll liegt in einem eigenen Zweig, den nur die Lehrkraft
      // lesen darf. Scheitert das, bleibt die Kinderliste stehen — die Sterne
      // hängen nicht daran. Der GRUND wird aber gesagt: Bis 1.5.0 stand die
      // Leseerlaubnis nur am einzelnen Kind, nicht am Klassencode, und die
      // Klassenansicht liest den ganzen Code auf einmal. Ergebnis: Die Kinder
      // schrieben brav mit, die Lehrkraft bekam den Zweig nie zu sehen — und
      // die App schwieg dazu (gemeldet 08/2026).
      try {
        protokolle = await protokollDerKlasse(code);
        protokollsperre = null;
      } catch (problem) {
        protokolle = [];
        protokollsperre = problem;
      }
      protokollhinweisZeichnen();
      const protokollNach = new Map(protokolle.map((p) => [p.schluessel, p]));

      leeren(kinderplatz);
      if (!stand.length) {
        kinderplatz.appendChild(h('p', { class: 'blatt__text' },
          'Noch niemand beigetreten. Zeig den QR-Code an der Tafel — die Kinder suchen sich dann Namen und PIN selbst aus.'));
        return;
      }
      stand.sort((a, b) => String(a.name).localeCompare(String(b.name), 'de'));
      for (const kind of stand) {
        const summe = Object.values(kind.fortschritt || {}).reduce((s, e) => s + (e.sterne || 0), 0);
        const eigenes = protokollNach.get(kind.schluessel);
        const schwer = eigenes ? (eigenes.woerter || []).filter((w) => w.f > 0).length : 0;
        kinderplatz.appendChild(h('div', { class: 'kinderliste__eintrag' },
          eigenes
            ? h('button', {
              class: 'kinderliste__name kinderliste__name--klickbar', type: 'button',
              title: 'Zeigen, welche Wörter dieses Kind bearbeitet hat',
              onclick: () => kindprotokoll(eigenes),
            }, kind.name, h('span', { class: 'kinderliste__woerter' },
              `${(eigenes.woerter || []).length} ${(eigenes.woerter || []).length === 1 ? 'Wort' : 'Wörter'}`
              + (schwer ? ` · ${schwer} schwer` : '')))
            : h('span', { class: 'kinderliste__name' }, kind.name),
          h('span', { class: 'kinderliste__sterne' }, `${summe} ★`),
          h('span', { class: 'kinderliste__zeit' }, kind.zuletzt ? datum(kind.zuletzt) : ''),
          h('button', {
            class: 'knopf knopf--flach knopf--klein', type: 'button', title: 'Neue PIN vergeben',
            onclick: async () => {
              const neue = await eingabe({
                titel: `Neue PIN für ${kind.name}`,
                text: 'Vier Ziffern. Sag sie dem Kind — nachsehen kannst du sie später nicht mehr, gespeichert wird nur ein Abdruck.',
                platzhalter: '••••', art: 'zahl',
                pruefung: (wert) => (/^\d{4}$/.test(wert) ? null : 'Genau vier Ziffern, bitte.'),
              });
              if (!neue) return;
              try {
                await pinNeuSetzen(code, kind.schluessel, neue);
                meldung(`${kind.name} hat jetzt die PIN ${neue}.`, 'gut', 6000);
              } catch (problem) {
                meldung(String(problem.message) === 'NICHT_ERLAUBT'
                  ? 'Das darf nur, wem die Klasse gehört — und nur, wenn die Datenbankregeln eingespielt sind.'
                  : klartext(problem), 'warnung', 5000);
              }
            },
          }, 'PIN'),
          h('button', {
            class: 'knopf knopf--flach knopf--klein', type: 'button', title: 'Kind umbenennen',
            onclick: async () => {
              const neuerName = await eingabe({
                titel: `${kind.name} umbenennen`,
                text: 'Der Name ist zugleich die Anmeldung — und er steckt im PIN-Abdruck. '
                  + 'Wird er wirklich ein anderer, braucht das Kind darum eine neue PIN. '
                  + 'Sterne und Wortprotokoll kommen mit.',
                wert: kind.name, ja: 'Weiter',
              });
              if (!neuerName || neuerName === kind.name) return;
              const gleich = namensschluessel(neuerName) === kind.schluessel;
              const neuePin = gleich ? '0000' : await eingabe({
                titel: `Neue PIN für ${neuerName}`,
                text: 'Vier Ziffern. Sag sie dem Kind — nachsehen lässt sie sich später nicht.',
                platzhalter: '••••', art: 'zahl',
                pruefung: (wert) => (/^\d{4}$/.test(wert) ? null : 'Genau vier Ziffern, bitte.'),
              });
              if (!neuePin) return;
              try {
                await kindUmbenennen(code, kind.schluessel, neuerName, neuePin);
                meldung(gleich
                  ? `Heißt jetzt ${neuerName}. Die PIN bleibt.`
                  : `${neuerName} meldet sich ab jetzt mit der PIN ${neuePin} an.`, 'gut', 6000);
                kinderZeichnen();
              } catch (problem) {
                meldung(String(problem.message) === 'NAME_VERGEBEN'
                  ? 'Diesen Namen gibt es in der Klasse schon.'
                  : klartext(problem), 'warnung', 5000);
              }
            },
          }, '✏️'),
          h('button', {
            class: 'knopf knopf--flach knopf--klein', type: 'button', title: 'Kind entfernen',
            onclick: async () => {
              const ja = await frage({ titel: 'Kind entfernen?', text: `${kind.name} verliert den Zugang zu dieser Klasse. Die Sterne auf dem eigenen Gerät bleiben.`, ja: 'Entfernen', gefahr: true });
              if (!ja) return;
              await kindEntfernen(code, kind.schluessel).catch(() => {});
              kinderZeichnen();
            },
          }, '✕')));
      }
    }

    /* Auftrag: „Diese Woche Päckchen 2, Stufe Diktat“ — freiwillig. */
    // Nicht `bereichswahl` nennen: So heißt das eingeführte Blatt aus
    // `bereiche.js`, und ein gleichnamiges Feld verdeckt es im ganzen Block —
    // der Knopf „Bereiche für die Klasse" weiter unten rief dann ein
    // <select> auf.
    const gruppen = [
      ['Eigene Bereiche', Object.values(klasse.bereiche || {})],
      ['Themenbereiche', BEREICHE],
      ['Rechtschreibung — 1. Schuljahr', RECHTSCHREIBUNG1],
      ['Rechtschreibung — 2. Schuljahr', RECHTSCHREIBUNG2],
      ['Rechtschreibung — 3. Schuljahr', RECHTSCHREIBUNG3],
      ['Rechtschreibung — 4. Schuljahr', RECHTSCHREIBUNG],
    ].filter(([, liste]) => liste.length);
    const alleBereiche = gruppen.flatMap(([, liste]) => liste);
    const bereichsfeld = h('select', { class: 'feld' },
      h('option', { value: '' }, '— kein Auftrag —'),
      ...gruppen.map(([name, liste]) => h('optgroup', { label: name },
        ...liste.map((b) => h('option', { value: b.id }, `${b.emoji || '📗'} ${b.name}`)))));
    const paketwahl = h('select', { class: 'feld' });
    const stufenwahl = h('select', { class: 'feld' });

    function paketeZeichnen() {
      const bereich = alleBereiche.find((b) => b.id === bereichsfeld.value);
      leeren(paketwahl);
      leeren(stufenwahl);
      stufenwahl.appendChild(h('option', { value: '' }, 'alle Stufen'));
      // Nur die Stufen, die dieser Bereich wirklich übt — die Blöcke der
      // 1. Klasse haben keine Wortart-Stufe, und ein Auftrag dorthin liefe
      // ins Leere.
      stufenFuer(bereich).forEach((u, stelle) => {
        stufenwahl.appendChild(h('option', { value: u.id }, `${u.emoji} Stufe ${stelle + 1}: ${u.name}`));
      });
      if (!bereich) {
        // Ein leerer Wähler sieht aus wie ein Fehler. Lieber sagt er, worauf
        // er wartet.
        paketwahl.appendChild(h('option', {}, 'erst einen Bereich wählen'));
        paketwahl.disabled = true;
        return;
      }
      paketwahl.disabled = false;
      for (let i = 0; i < paketzahl(bereich); i += 1) {
        paketwahl.appendChild(h('option', { value: String(i) }, `Päckchen ${i + 1}`));
      }
    }
    bereichsfeld.addEventListener('change', paketeZeichnen);
    if (klasse.auftrag) {
      bereichsfeld.value = klasse.auftrag.bereichId || '';
      paketeZeichnen();
      paketwahl.value = String(klasse.auftrag.paket || 0);
      stufenwahl.value = klasse.auftrag.stufe || '';
    } else {
      paketeZeichnen();
    }

    leeren(platz).appendChild(h('div', {},
      frischAngelegt ? h('p', { class: 'blatt__gut' }, 'Die Klasse steht. Jetzt den QR-Code zeigen.') : null,
      abschnitt('Beitreten',
        h('div', { class: 'beitritt' },
          qr,
          h('div', { class: 'beitritt__text' },
            h('p', {}, 'Die Kinder scannen den Code mit der Kamera — oder tippen ihn ab:'),
            h('div', { class: 'beitritt__code' }, code),
            h('p', { class: 'beitritt__adresse' }, adresse),
            h('div', { class: 'blatt__knopfreihe' },
              h('button', {
                class: 'knopf knopf--still knopf--klein', type: 'button',
                onclick: async () => meldung(await inZwischenablage(adresse) ? 'Link kopiert.' : 'Kopieren ging nicht — der Link steht oben.', 'info'),
              }, 'Link kopieren'),
              h('button', {
                class: 'knopf knopf--still knopf--klein', type: 'button',
                onclick: () => qrDrucken(code, klasse.name, adresse),
              }, 'Groß zeigen & drucken'))))),
      abschnitt('Auftrag für diese Woche',
        h('p', { class: 'blatt__text' }, 'Was hier steht, sehen die Kinder beim Öffnen ganz oben. Alles andere lässt sich trotzdem weiter üben.'),
        zeile('Bereich', bereichsfeld),
        zeile('Päckchen', paketwahl),
        zeile('Stufe', stufenwahl),
        h('button', {
          class: 'knopf knopf--voll', type: 'button',
          onclick: async () => {
            const auftrag = bereichsfeld.value
              ? { bereichId: bereichsfeld.value, paket: Number(paketwahl.value || 0), stufe: stufenwahl.value || '' }
              : null;
            try {
              await klasseAendern(code, { auftrag });
              meldung(auftrag ? 'Auftrag gesetzt.' : 'Auftrag entfernt.', 'gut');
            } catch (_) {
              meldung('Das ging gerade nicht.', 'warnung');
            }
          },
        }, 'Auftrag sichern')),
      abschnitt('Kinder', kinderplatz, protokollhinweis,
        h('div', { class: 'blatt__knopfreihe' },
          h('button', {
            class: 'knopf knopf--voll knopf--klein', type: 'button',
            onclick: () => (protokolle.length
              ? klassenprotokoll(code, protokolle)
              : meldung('Noch keine Wörter zum Nachsehen.', 'info')),
          }, '📋 Was der Klasse schwerfällt'),
          h('button', { class: 'knopf knopf--still knopf--klein', type: 'button', onclick: () => kinderZeichnen() }, '↻ Neu laden'))),
      abschnitt('Bereiche für die Klasse',
        h('p', { class: 'blatt__text' },
          'Welche Bereiche die Kinder sehen. Deine Auswahl wird auf ihre Geräte übernommen, '
          + 'sobald sie die App öffnen — auch die Rechtschreibblöcke, die von Haus aus ausgeblendet sind.'),
        h('div', { class: 'blatt__knopfreihe' },
          h('button', {
            class: 'knopf knopf--voll', type: 'button',
            onclick: () => bereichswahl({
              titel: `Bereiche für ${klasse.name}`,
              hinweis: 'Was du hier anhakst, sehen die Kinder dieser Klasse. Es gilt zugleich für dein eigenes Gerät.',
              beiWahl: (auswahl) => {
                // Nicht bei jedem Haken schreiben — sonst geht bei „Alle an"
                // ein Schwall Anfragen los. Erst wenn es kurz ruhig ist.
                clearTimeout(bereichsuhr);
                bereichsuhr = setTimeout(() => {
                  klasseAendern(code, { bereicheAn: auswahl })
                    .then(() => { klasse.bereicheAn = auswahl; })
                    .catch((problem) => meldung(klartext(problem), 'warnung', 5000));
                }, 700);
              },
            }),
          }, '📚 Bereiche wählen'))),

      abschnitt('Anmeldung der Kinder',
        zeile('Auch ohne PIN anmelden',
          schalter(klasse.ohnePin === true, async (an) => {
            try {
              await klasseAendern(code, { ohnePin: an });
              klasse.ohnePin = an;
              meldung(an
                ? 'Kinder kommen jetzt mit Name und Klassencode hinein.'
                : 'Für die Anmeldung braucht es wieder die PIN.', 'gut', 5000);
            } catch (problem) {
              meldung(klartext(problem), 'warnung', 5000);
            }
          }),
          'Praktisch, wenn PINs vergessen werden. Dann kann sich aber jedes Kind, das den Klassencode hat, als jedes andere anmelden.'),
        h('p', { class: 'abschnitt__notiz' },
          'Eine vergessene PIN lässt sich auch einzeln neu vergeben — der Knopf „PIN" steht bei jedem Kind.')),

      abschnitt('Wörter und Fehler mitschreiben',
        zeile('Mitschreiben',
          schalter(klasse.protokoll !== false, async (an) => {
            try {
              await klasseAendern(code, { protokoll: an });
              klasse.protokoll = an;
              meldung(an
                ? 'Die Kinder schreiben ihre Wörter jetzt mit.'
                : 'Es wird nichts mehr mitgeschrieben. Bereits Gemeldetes bleibt, bis du es löschst.', 'gut', 5000);
            } catch (problem) {
              meldung(klartext(problem), 'warnung', 5000);
            }
          }),
          'Welche Wörter die Kinder bearbeitet haben und wie sie sie geschrieben haben. Lesen kannst nur du — die Kinder sehen die Fehler der anderen nicht.'),
        h('p', { class: 'abschnitt__notiz' },
          'Das sind Leistungsdaten einzelner Kinder. Sie liegen so lange in der Datenbank, bis du sie löschst.'),
        h('button', {
          class: 'knopf knopf--gefahr knopf--klein', type: 'button',
          onclick: async () => {
            const ja = await frage({
              titel: 'Alle Wörter und Fehler löschen?',
              text: 'Das Protokoll der ganzen Klasse wird entfernt. Die Sterne bleiben.',
              ja: 'Löschen', gefahr: true,
            });
            if (!ja) return;
            try {
              await protokollLoeschen(code);
              protokolle = [];
              meldung('Protokoll gelöscht.', 'gut');
              kinderZeichnen();
            } catch (problem) {
              meldung(klartext(problem), 'warnung', 5000);
            }
          },
        }, 'Protokoll der Klasse löschen')),
      abschnitt('Klasse',
        h('button', {
          class: 'knopf knopf--gefahr', type: 'button',
          onclick: async () => {
            const ja = await frage({
              titel: 'Klasse löschen?',
              text: 'Der Code wird ungültig, und alle Kinder verlieren den Zugang. Was auf ihren Geräten liegt, bleibt.',
              ja: 'Löschen', gefahr: true,
            });
            if (!ja) return;
            // Der Besitzer wird mitgegeben: Öffnet die Schulverwaltung eine
            // fremde Klasse, muss sie aus DEREN Liste verschwinden, nicht aus
            // der eigenen.
            await klasseLoeschen(code, klasse.besitzer).catch(() => {});
            klasseVergessen(code);
            dialog.schliessen();
            if (beiAenderung) beiAenderung();
          },
        }, 'Klasse löschen')),
    ));
    kinderZeichnen();
  })();

  return dialog;
}

/** Den QR-Code groß in einem eigenen Fenster — zum Zeigen und zum Drucken. */
function qrDrucken(code, name, adresse) {
  const fenster = window.open('', '_blank');
  if (!fenster) { meldung('Das Fenster wurde blockiert.', 'warnung'); return; }
  let svg = '';
  try {
    svg = qrSvg(adresse, { stufe: 'M' }).outerHTML;
  } catch (_) { svg = ''; }
  fenster.document.write(`<!DOCTYPE html><html lang="de"><head><meta charset="utf-8">
<title>Beitreten: ${name || 'Klasse'}</title>
<style>
  body{font-family:system-ui,sans-serif;margin:0;display:flex;flex-direction:column;
       align-items:center;justify-content:center;min-height:100vh;gap:18px;color:#0f172a}
  svg{width:min(70vmin,520px);height:auto}
  h1{margin:0;font-size:clamp(24px,4vw,40px)}
  .code{font-size:clamp(36px,7vw,72px);letter-spacing:.18em;font-weight:800}
  p{margin:0;color:#475569;font-size:16px;word-break:break-all;text-align:center;max-width:40ch}
  @media print{body{min-height:auto;padding:24px}}
</style></head><body>
<h1>${name || 'Wörterwerkstatt'}</h1>
${svg}
<div class="code">${code}</div>
<p>${adresse}</p>
</body></html>`);
  fenster.document.close();
}

/* ---------- Die Seite der Kinder ---------- */

/**
 * Beitreten oder anmelden. Ein Kind, das den Code zum ersten Mal scannt,
 * legt sich an; danach meldet es sich mit denselben zwei Angaben wieder an.
 * Es gibt bewusst KEINE zwei Knöpfe „Neu“ und „Anmelden“ — ein Kind weiß
 * nicht immer, was von beidem es gerade ist. Die App probiert die Anmeldung
 * und bietet das Anlegen erst an, wenn es den Namen noch nicht gibt.
 */
export function beitreten(code, beiFertig, beimSchliessen = null) {
  const gross = String(code).toUpperCase();
  // Ob diese Klasse die Anmeldung ohne PIN erlaubt, steht in der Klasse und
  // ist erst nach dem Laden bekannt. Bis dahin gilt: PIN nötig.
  let ohnePin = false;
  const nameFeld = h('input', {
    class: 'feld feld--gross', type: 'text', placeholder: 'Dein Name',
    autocomplete: 'username', autocapitalize: 'words', spellcheck: 'false',
  });
  const pinFeld = h('input', {
    class: 'feld feld--gross feld--pin', type: 'password', inputmode: 'numeric',
    pattern: '[0-9]*', maxlength: 4, placeholder: '••••', autocomplete: 'current-password',
  });
  const fehler = h('p', { class: 'blatt__fehler', 'aria-live': 'polite' });
  const machen = h('button', { class: 'knopf knopf--voll knopf--gross', type: 'button' }, 'Los geht’s');
  const klassenname = h('p', { class: 'blatt__text' }, `Klassencode ${gross}`);
  const pinhinweis = h('p', { class: 'blatt__text is-versteckt' },
    'Wenn du schon einmal hier warst, darfst du die PIN auch weglassen.');

  pinFeld.addEventListener('input', () => { pinFeld.value = pinFeld.value.replace(/\D/g, '').slice(0, 4); });

  klasseHolen(gross)
    .then((klasse) => {
      klassenname.textContent = `${klasse.name} · Code ${gross}`;
      ohnePin = klasse.ohnePin === true;
      if (ohnePin) {
        pinFeld.placeholder = '•••• (darfst du weglassen)';
        pinhinweis.classList.remove('is-versteckt');
      }
      uebernehmen(klasse);
    })
    .catch((problem) => {
      // Eine gesperrte Datenbank sieht von hier aus wie ein falscher Code —
      // und ein Kind, das daraufhin seinen Code sechsmal neu abtippt, sucht an
      // der falschen Stelle.
      const grund = String(problem.message);
      fehler.textContent = grund === 'KLASSE_UNBEKANNT'
        ? 'Diesen Klassencode gibt es nicht (mehr). Stimmen alle sechs Zeichen?'
        : (grund === 'NICHT_ERLAUBT'
          ? 'Das Mitmachen ist gerade nicht eingerichtet. Sag deiner Lehrerin oder deinem Lehrer Bescheid.'
          : klartext(problem));
      machen.disabled = true;
    });

  /** Die Bereiche, die die Lehrkraft der Klasse mitgegeben hat, ins Gerät holen. */
  function uebernehmen(klasse) {
    for (const bereich of Object.values(klasse.bereiche || {})) {
      bereichSichern(Object.assign({}, bereich, { ausKlasse: gross }));
    }
    if (klasse.bereicheAn) setzeSichtbareBereiche(klasse.bereicheAn);
    klasseMerken({
      code: gross, name: klasse.name, rolle: 'kind',
      auftrag: klasse.auftrag || null,
      protokoll: klasse.protokoll !== false,
      ohnePin: klasse.ohnePin === true,
    });
  }

  machen.addEventListener('click', async () => {
    fehler.textContent = '';
    const name = nameFeld.value.trim();
    const pin = pinFeld.value.trim();
    if (name.length < 2) { fehler.textContent = 'Schreib deinen Namen (mindestens zwei Buchstaben).'; return; }
    // Ohne PIN geht es nur, wenn die Lehrkraft es erlaubt hat UND das Kind
    // schon angelegt ist. Beim ERSTEN Mal braucht es immer eine PIN — sonst
    // hätte das Kind später keine, die man ihm sagen könnte.
    if (!/^\d{4}$/.test(pin) && !(ohnePin && pin === '')) {
      fehler.textContent = ohnePin
        ? 'Die PIN sind genau vier Ziffern — oder lass sie ganz leer.'
        : 'Die PIN sind genau vier Ziffern.';
      return;
    }
    machen.disabled = true;
    try {
      let kind;
      try {
        kind = await kindAnmelden(gross, name, pin, ohnePin);
      } catch (problem) {
        if (String(problem.message) === 'KIND_UNBEKANNT') {
          if (!/^\d{4}$/.test(pin)) {
            throw new Error('Dich gibt es hier noch nicht. Zum ersten Mal brauchst du eine PIN aus vier Ziffern.');
          }
          kind = await kindAnlegen(gross, name, pin);
          meldung('Willkommen! Merk dir deinen Namen und deine PIN.', 'gut', 5000);
        } else {
          throw problem;
        }
      }
      setzeNutzer({ art: 'kind', name: kind.name, schluessel: kind.schluessel, klasse: gross });
      dialog.schliessen();
      if (beiFertig) beiFertig(kind);
    } catch (problem) {
      const text = String(problem.message);
      fehler.textContent = text === 'PIN_FALSCH'
        ? 'Die PIN stimmt nicht. Frag deine Lehrerin oder deinen Lehrer — sie können eine neue vergeben.'
        : (text === 'NAME_VERGEBEN'
          ? 'Diesen Namen hat schon jemand. Nimm einen anderen — zum Beispiel mit deinem Anfangsbuchstaben hinten dran.'
          : (text === 'KEINE_VERBINDUNG' ? 'Keine Verbindung. Bist du im WLAN?' : text));
      machen.disabled = false;
    }
  });

  const dialog = blatt({
    titel: 'Mitmachen',
    // Der Wegweiser merkt sich, für welchen Code ein Blatt offen ist, und muss
    // erfahren, wenn es wieder zu ist — sonst ließe sich derselbe Code danach
    // nie wieder öffnen.
    beimSchliessen,
    inhalt: h('div', {},
      klassenname,
      h('p', { class: 'blatt__text' },
        'Such dir einen Namen aus und eine PIN aus vier Ziffern. Merk sie dir gut — mit beidem kommst du wieder hinein.'),
      nameFeld, pinFeld, pinhinweis, fehler,
      h('div', { class: 'blatt__knopfreihe' }, machen)),
  });
  return dialog;
}

/**
 * Anmelden ohne QR-Code: Klassencode abtippen.
 *
 * Ein Kind auf einem frischen Gerät hatte bisher keinen Weg hinein — es
 * brauchte den Link. Der ist aber weg, sobald der Beamer aus ist oder das
 * Tablet gewechselt wurde. Hier tippt es die sechs Zeichen ab und landet im
 * gewohnten Blatt.
 */
export function anmeldenMitCode(beiFertig) {
  const codefeld = h('input', {
    class: 'feld feld--gross feld--code', type: 'text', placeholder: 'ABC234',
    autocomplete: 'off', autocapitalize: 'characters', spellcheck: 'false', maxlength: 6,
  });
  const fehler = h('p', { class: 'blatt__fehler', 'aria-live': 'polite' });
  // Kleinbuchstaben und Leerzeichen geradeziehen — mehr nicht. Der
  // Klassencode kennt weder I noch O noch 0 oder 1 (siehe `beitrittscode` in
  // util.js), gerade damit es hier nichts zu raten gibt. Wer eines davon
  // tippt, hat sich verlesen, und das muss die App sagen statt es
  // stillschweigend in ein anderes Zeichen zu verwandeln.
  codefeld.addEventListener('input', () => {
    codefeld.value = codefeld.value.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 6);
  });

  const weiter = () => {
    const code = codefeld.value.trim().toUpperCase();
    if (code.length !== 6) { fehler.textContent = 'Der Klassencode hat genau sechs Zeichen.'; return; }
    dialog.schliessen();
    window.location.hash = `#/beitreten/${code}`;
    if (beiFertig) beiFertig(code);
  };
  codefeld.addEventListener('keydown', (ereignis) => {
    if (ereignis.key === 'Enter') { ereignis.preventDefault(); weiter(); }
  });

  const dialog = blatt({
    titel: 'Mitmachen',
    inhalt: h('div', {},
      h('p', { class: 'blatt__text' },
        'Tipp den Klassencode ein — die sechs Zeichen stehen unter dem QR-Code an der Tafel. '
        + 'Danach kommen dein Name und deine PIN.'),
      codefeld, fehler,
      h('div', { class: 'blatt__knopfreihe' },
        h('button', { class: 'knopf knopf--voll knopf--gross', type: 'button', onclick: weiter }, 'Weiter'))),
  });
  return dialog;
}

/**
 * Was die Lehrkraft an der Klasse geändert hat, auf dieses Gerät holen:
 * Auftrag der Woche, freigeschaltete Bereiche, mitgegebene eigene Bereiche.
 *
 * Läuft beim Start im Hintergrund. Scheitert es (kein Netz), bleibt alles so,
 * wie es war — geübt wird ohnehin ohne Netz.
 */
export async function klasseAuffrischen() {
  const wer = nutzer();
  if (!wer || wer.art !== 'kind' || !wer.klasse) return;
  let klasse;
  try {
    klasse = await klasseHolen(wer.klasse);
  } catch (_) {
    return;
  }
  for (const bereich of Object.values(klasse.bereiche || {})) {
    bereichSichern(Object.assign({}, bereich, { ausKlasse: klasse.code }));
  }
  if (klasse.bereicheAn) setzeSichtbareBereiche(klasse.bereicheAn);
  klasseMerken({
    code: klasse.code, name: klasse.name, rolle: 'kind',
    auftrag: klasse.auftrag || null,
    protokoll: klasse.protokoll !== false,
    ohnePin: klasse.ohnePin === true,
  });
}

/**
 * Sterne des Kindes an die Klasse melden. Absichtlich nur die Sterne — was ein
 * Kind falsch getippt hat, bleibt auf seinem Gerät.
 */
export async function fortschrittHochladen() {
  const angemeldetesKind = nutzer();
  if (!angemeldetesKind || angemeldetesKind.art !== 'kind' || !angemeldetesKind.klasse) return;
  const knapp = {};
  for (const [schluessel, stand] of Object.entries(daten().fortschritt || {})) {
    if (stand && stand.sterne) knapp[schluessel.replace(/[.#$/[\]]/g, '_')] = { sterne: stand.sterne, zuletzt: stand.zuletzt || 0 };
  }
  await fortschrittMelden(angemeldetesKind.klasse, angemeldetesKind.schluessel, knapp).catch(() => {});

  // Das Wortprotokoll nur, wenn die Lehrkraft es für diese Klasse zulässt.
  // Der Merker kommt beim Beitreten und bei jedem Öffnen mit; fehlt er (alte
  // Klasse), gilt es als erlaubt — die Lehrkraft hat den Schalter.
  const klasse = klassen().find((k) => k.code === angemeldetesKind.klasse);
  if (klasse && klasse.protokoll === false) return;
  await protokollMelden(
    angemeldetesKind.klasse,
    angemeldetesKind.schluessel,
    angemeldetesKind.name,
    protokoll(),
  ).catch(() => {});
}
