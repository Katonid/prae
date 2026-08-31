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
import { blatt, abschnitt, zeile, frage, eingabe, ladeplatz, meldung } from './ui.js';
import { qrSvg } from './qr.js';
import { inZwischenablage } from './plattform.js';
import {
  kontenVerfuegbar, anmelden, kontoAnlegen, klartext, regelnPruefen,
  klasseAnlegen, klasseHolen, klasseLoeschen, klassenDerLehrkraft, klasseAendern,
  kindAnlegen, kindAnmelden, kindEntfernen, pinNeuSetzen,
  fortschrittDerKlasse, fortschrittMelden,
} from './cloud.js';
import {
  eigeneBereiche, bereichSichern, klassen, klasseMerken, klasseVergessen,
  setzeNutzer, nutzer, daten,
} from './store.js';
import { BEREICHE } from './woerter.js';
import { UEBUNGEN } from './uebungen/index.js';
import { paketzahl } from './paket.js';

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
    let gefunden = [];
    try {
      gefunden = await klassenDerLehrkraft();
    } catch (_) {
      gefunden = klassen();
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
          h('span', {}, klasse.angelegtAm ? `angelegt am ${datum(klasse.angelegtAm)}` : '')),
        h('span', { class: 'bereichsliste__pfeil' }, '›')));
    }
  }

  const neuknopf = h('button', {
    class: 'knopf knopf--voll', type: 'button', onclick: () => neueKlasse(zeichnen),
  }, '+ Neue Klasse');

  const dialog = blatt({
    titel: 'Meine Klassen',
    breit: true,
    inhalt: h('div', {}, liste, h('div', { class: 'blatt__knopfreihe' }, neuknopf)),
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

/** Die Klassenansicht: QR-Code, Auftrag, Kinder und ihre Sterne. */
export function klasseZeigen(code, beiAenderung, frischAngelegt = false) {
  const platz = h('div', {}, ladeplatz('Klasse wird geholt …'));

  const dialog = blatt({
    titel: `Klasse ${code}`,
    breit: true,
    inhalt: platz,
  });

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

    async function kinderZeichnen() {
      let stand = [];
      try {
        stand = await fortschrittDerKlasse(code);
      } catch (_) {
        leeren(kinderplatz).appendChild(h('p', { class: 'blatt__fehler' }, 'Die Liste war nicht erreichbar.'));
        return;
      }
      leeren(kinderplatz);
      if (!stand.length) {
        kinderplatz.appendChild(h('p', { class: 'blatt__text' },
          'Noch niemand beigetreten. Zeig den QR-Code an der Tafel — die Kinder suchen sich dann Namen und PIN selbst aus.'));
        return;
      }
      stand.sort((a, b) => String(a.name).localeCompare(String(b.name), 'de'));
      for (const kind of stand) {
        const summe = Object.values(kind.fortschritt || {}).reduce((s, e) => s + (e.sterne || 0), 0);
        kinderplatz.appendChild(h('div', { class: 'kinderliste__eintrag' },
          h('span', { class: 'kinderliste__name' }, kind.name),
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
    const alleBereiche = BEREICHE.concat(Object.values(klasse.bereiche || {}));
    const bereichswahl = h('select', { class: 'feld' },
      h('option', { value: '' }, '— kein Auftrag —'),
      ...alleBereiche.map((b) => h('option', { value: b.id }, `${b.emoji || '📗'} ${b.name}`)));
    const paketwahl = h('select', { class: 'feld' });
    const stufenwahl = h('select', { class: 'feld' },
      h('option', { value: '' }, 'alle Stufen'),
      ...UEBUNGEN.map((u) => h('option', { value: u.id }, `${u.emoji} Stufe ${u.nummer}: ${u.name}`)));

    function paketeZeichnen() {
      const bereich = alleBereiche.find((b) => b.id === bereichswahl.value);
      leeren(paketwahl);
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
    bereichswahl.addEventListener('change', paketeZeichnen);
    if (klasse.auftrag) {
      bereichswahl.value = klasse.auftrag.bereichId || '';
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
        zeile('Bereich', bereichswahl),
        zeile('Päckchen', paketwahl),
        zeile('Stufe', stufenwahl),
        h('button', {
          class: 'knopf knopf--voll', type: 'button',
          onclick: async () => {
            const auftrag = bereichswahl.value
              ? { bereichId: bereichswahl.value, paket: Number(paketwahl.value || 0), stufe: stufenwahl.value || '' }
              : null;
            try {
              await klasseAendern(code, { auftrag });
              meldung(auftrag ? 'Auftrag gesetzt.' : 'Auftrag entfernt.', 'gut');
            } catch (_) {
              meldung('Das ging gerade nicht.', 'warnung');
            }
          },
        }, 'Auftrag sichern')),
      abschnitt('Kinder', kinderplatz,
        h('button', { class: 'knopf knopf--still knopf--klein', type: 'button', onclick: () => kinderZeichnen() }, '↻ Neu laden')),
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
            await klasseLoeschen(code).catch(() => {});
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
export function beitreten(code, beiFertig) {
  const gross = String(code).toUpperCase();
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

  pinFeld.addEventListener('input', () => { pinFeld.value = pinFeld.value.replace(/\D/g, '').slice(0, 4); });

  klasseHolen(gross)
    .then((klasse) => { klassenname.textContent = `${klasse.name} · Code ${gross}`; uebernehmen(klasse); })
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
    klasseMerken({ code: gross, name: klasse.name, rolle: 'kind', auftrag: klasse.auftrag || null });
  }

  machen.addEventListener('click', async () => {
    fehler.textContent = '';
    const name = nameFeld.value.trim();
    const pin = pinFeld.value.trim();
    if (name.length < 2) { fehler.textContent = 'Schreib deinen Namen (mindestens zwei Buchstaben).'; return; }
    if (!/^\d{4}$/.test(pin)) { fehler.textContent = 'Die PIN sind genau vier Ziffern.'; return; }
    machen.disabled = true;
    try {
      let kind;
      try {
        kind = await kindAnmelden(gross, name, pin);
      } catch (problem) {
        if (String(problem.message) === 'KIND_UNBEKANNT') {
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
    inhalt: h('div', {},
      klassenname,
      h('p', { class: 'blatt__text' },
        'Such dir einen Namen aus und eine PIN aus vier Ziffern. Merk sie dir gut — mit beidem kommst du wieder hinein.'),
      nameFeld, pinFeld, fehler,
      h('div', { class: 'blatt__knopfreihe' }, machen)),
  });
  return dialog;
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
}
