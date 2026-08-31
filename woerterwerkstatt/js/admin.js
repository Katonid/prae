// Schulverwaltung — Lehrkräfte und Klassen der ganzen Schule.
//
// Sichtbar nur für Konten, denen die Datenbankregeln das Verzeichnis aller
// Lehrkräfte öffnen (`verwaltungPruefen` in `cloud.js`). Die App hat davon
// keine eigene Vorstellung: Sie fragt die Datenbank und richtet sich danach.
//
// Was hier geht und was nicht — die Grenze verläuft zwischen Daten und
// Anmeldung, und sie ist keine Bequemlichkeitsfrage:
//
//   * DATEN (Klassen, Kinder, PINs, Profile, Protokolle) liegen in der
//     Realtime Database. Wer die Regeln dafür freigibt, kann alles davon
//     anlegen, ändern und löschen — auch von hier aus.
//   * Die ANMELDUNG einer Lehrkraft liegt in Firebase Authentication. Ein
//     fremdes Konto dort anzulegen geht (`signUp`), eine Mail zum
//     Zurücksetzen zu schicken auch (`sendOobCode`). Ein fremdes Konto zu
//     LÖSCHEN oder seine Adresse zu ändern verlangt dagegen das Admin-SDK
//     mit einem Dienstschlüssel — und der gehört auf einen Server, nicht in
//     eine Web-App, die auf jedem Kindergerät liegt. Dafür führt diese
//     Ansicht in die Firebase-Konsole.
//
// Kinder werden nicht hier verwaltet, sondern in der gewohnten
// Klassenansicht: Die Verwaltung kommt über die Klassenliste in dieselbe
// Ansicht, die auch die Lehrkraft sieht. Zwei Oberflächen für dieselbe
// Aufgabe liefen mit Sicherheit auseinander.

import { h, leeren, datum } from './util.js';
import { blatt, frage, eingabe, meldung, abschnitt, ladeplatz, zeile } from './ui.js';
import {
  angemeldet, alleLehrkraefte, verwaisteKlassen, lehrkraftAnlegen, lehrkraftUmbenennen,
  lehrkraftLoeschen, zugangsmailSenden, verwaltungsrechtSetzen, klasseLoeschen,
  konsolenadresse, klartext,
} from './cloud.js';
import { klasseZeigen } from './klasse.js';

/** Anzeigename einer Lehrkraft — irgendetwas steht immer zur Verfügung. */
function wer(lehrkraft) {
  return lehrkraft.name || lehrkraft.email || lehrkraft.uid;
}

function konsolenknopf(text, bereich = 'authentication/users') {
  const adresse = konsolenadresse(bereich);
  if (!adresse) return null;
  return h('a', {
    class: 'knopf knopf--still knopf--klein', href: adresse,
    target: '_blank', rel: 'noopener noreferrer',
  }, text);
}

/**
 * Die Kennwort-Mail — der einzige Weg zu einem fremden Zugang.
 *
 * Ein Kennwort SETZEN kann die Verwaltung nicht: Das verlangt das Zeichen des
 * betroffenen Kontos, und das hat niemand außer der Lehrkraft selbst. Der Weg
 * über die Mail ist dafür nicht bloß ein Notbehelf — ein Kennwort, das die
 * Verwaltung kennt, ist keines.
 *
 * Was die Kollegin bekommt, steht in der Rückfrage: eine Mail von Firebase mit
 * einem Link, über den sie selbst ein neues Kennwort setzt. Bis dahin gilt das
 * alte weiter; es wird also nichts kaputtgemacht, wenn die Mail liegen bleibt.
 */
async function kennwortmail(email, name = '') {
  const sicher = await frage({
    titel: 'Kennwort-Mail schicken?',
    text: `An ${email} geht eine Mail mit einem Link, über den ${name || 'die Lehrkraft'} `
      + 'selbst ein neues Kennwort setzt. Das bisherige gilt so lange weiter — es geht '
      + 'also nichts verloren, wenn die Mail liegen bleibt. Ein Kennwort direkt zu '
      + 'setzen kann die Verwaltung nicht, und sie sollte es auch nicht können.',
    ja: 'Mail schicken',
  });
  if (!sicher) return false;
  try {
    await zugangsmailSenden(email);
    meldung(`Die Mail ist an ${email} unterwegs. Sag Bescheid, dass sie auch im `
      + 'Spam-Ordner nachsehen soll — der Absender ist Firebase, nicht die Schule.', 'gut', 9000);
    return true;
  } catch (problem) {
    meldung(klartext(problem), 'warnung', 6000);
    return false;
  }
}

/* ---------- Eine einzelne Lehrkraft ---------- */

function lehrkraftZeigen(lehrkraft, beiAenderung) {
  const platz = h('div', {});

  const zeichnen = () => {
    const klassen = h('div', { class: 'klassenliste' });
    if (!lehrkraft.klassen.length) {
      klassen.appendChild(h('p', { class: 'blatt__text' }, 'Diese Lehrkraft hat noch keine Klasse angelegt.'));
    }
    for (const klasse of lehrkraft.klassen) {
      klassen.appendChild(h('button', {
        class: 'klassenliste__eintrag', type: 'button',
        onclick: () => klasseZeigen(klasse.code, beiAenderung),
      },
        h('span', { class: 'klassenliste__code' }, klasse.code),
        h('span', { class: 'klassenliste__text' },
          h('strong', {}, klasse.name || 'Klasse'),
          h('span', {}, klasse.angelegtAm ? `angelegt am ${datum(klasse.angelegtAm)}` : '')),
        h('span', { class: 'bereichsliste__pfeil' }, '›')));
    }

    leeren(platz).appendChild(h('div', {},
      abschnitt('Konto',
        zeile('Name', h('span', { class: 'blatt__wert' }, lehrkraft.name || '— kein Name —')),
        zeile('E-Mail', h('span', { class: 'blatt__wert' }, lehrkraft.email || '— unbekannt —')),
        zeile('Angelegt', h('span', { class: 'blatt__wert' },
          lehrkraft.angelegtAm ? datum(lehrkraft.angelegtAm) : '— vor der Erfassung —')),
        zeile('Zuletzt angemeldet', h('span', { class: 'blatt__wert' },
          lehrkraft.zuletztAngemeldet ? datum(lehrkraft.zuletztAngemeldet) : '— noch nicht erfasst —')),
        zeile('Eigene Bereiche', h('span', { class: 'blatt__wert' }, String(lehrkraft.bereiche))),
        h('div', { class: 'blatt__knopfreihe' },
          h('button', {
            class: 'knopf knopf--still knopf--klein', type: 'button',
            onclick: async () => {
              const name = await eingabe({
                titel: 'Name ändern',
                text: 'So steht die Lehrkraft in der Verwaltung und über ihren Klassen.',
                wert: lehrkraft.name,
                ja: 'Übernehmen',
              });
              if (!name) return;
              try {
                await lehrkraftUmbenennen(lehrkraft.uid, name);
                lehrkraft.name = name;
                meldung('Name geändert.', 'gut');
                zeichnen();
                if (beiAenderung) beiAenderung();
              } catch (problem) { meldung(klartext(problem), 'warnung', 5000); }
            },
          }, '✏️ Name ändern'),
          h('button', {
            class: 'knopf knopf--voll knopf--klein', type: 'button',
            disabled: !lehrkraft.email,
            onclick: () => kennwortmail(lehrkraft.email, wer(lehrkraft)),
          }, '✉️ Kennwort zurücksetzen')),
        lehrkraft.email
          ? null
          // Ohne hinterlegte Adresse geht es nicht — und dann muss dastehen,
          // warum der Knopf grau ist und was hilft.
          : h('p', { class: 'abschnitt__notiz' },
            'Zu diesem Konto ist keine E-Mail hinterlegt, deshalb lässt sich von hier aus '
            + 'keine Mail schicken. Sie trägt sich nach, sobald die Lehrkraft sich einmal '
            + 'anmeldet — oder du schickst die Mail über „✉️ Kennwort-Mail" in der '
            + 'Übersicht direkt an ihre Adresse.')),

      abschnitt('Rechte',
        h('p', { class: 'blatt__text' },
          lehrkraft.verwaltung
            ? 'Diese Lehrkraft darf die ganze Schule verwalten: alle Klassen, alle Kinder, alle Konten.'
            : 'Diese Lehrkraft sieht nur ihre eigenen Klassen.'),
        lehrkraft.ichSelbst
          ? h('p', { class: 'abschnitt__notiz' },
            'Das eigene Recht lässt sich hier nicht abgeben — sonst stünde man vor der '
            + 'eigenen Tür. Das geht in den Datenbankregeln.')
          : h('div', { class: 'blatt__knopfreihe' },
            h('button', {
              class: 'knopf knopf--still knopf--klein', type: 'button',
              onclick: async () => {
                const an = !lehrkraft.verwaltung;
                if (an) {
                  const sicher = await frage({
                    titel: 'Zur Verwaltung machen?',
                    text: `${wer(lehrkraft)} könnte danach jede Klasse, jedes Kind und jedes `
                      + 'Konto dieser Schule ändern und löschen — auch deins.',
                    ja: 'Recht geben',
                  });
                  if (!sicher) return;
                }
                try {
                  await verwaltungsrechtSetzen(lehrkraft.uid, an, lehrkraft.name || lehrkraft.email);
                  lehrkraft.verwaltung = an;
                  meldung(an ? 'Recht gegeben.' : 'Recht genommen.', 'gut');
                  zeichnen();
                  if (beiAenderung) beiAenderung();
                } catch (problem) { meldung(klartext(problem), 'warnung', 5000); }
              },
            }, lehrkraft.verwaltung ? '🔓 Verwaltungsrecht nehmen' : '🔑 Zur Verwaltung machen'))),

      abschnitt(`Klassen (${lehrkraft.klassen.length})`, klassen),

      abschnitt('Konto löschen',
        h('p', { class: 'blatt__text' },
          'Löscht Profil, eigene Bereiche und alle Klassen dieser Lehrkraft samt Kindern, '
          + 'PINs und Wortprotokollen. Die ANMELDUNG bleibt bestehen: Ein fremdes '
          + 'Firebase-Konto entfernt nur ein Mensch in der Konsole. Bis dahin kann sich '
          + 'die Lehrkraft anmelden — sie fände nur nichts mehr vor.'),
        h('div', { class: 'blatt__knopfreihe' },
          h('button', {
            class: 'knopf knopf--gefahr knopf--klein', type: 'button',
            disabled: lehrkraft.ichSelbst,
            onclick: async () => {
              const anzahl = lehrkraft.klassen.length;
              const sicher = await frage({
                titel: `${wer(lehrkraft)} löschen?`,
                text: anzahl
                  ? `Damit gehen ${anzahl === 1 ? 'eine Klasse' : `${anzahl} Klassen`} samt aller `
                    + 'Kinder, ihrer Sterne und ihrer Wortprotokolle unwiederbringlich verloren.'
                  : 'Diese Lehrkraft hat keine Klassen; es verschwinden Profil und eigene Bereiche.',
                ja: 'Endgültig löschen',
                gefahr: true,
              });
              if (!sicher) return;
              try {
                await lehrkraftLoeschen(lehrkraft.uid, lehrkraft.klassen.map((k) => k.code));
                meldung('Die Daten sind gelöscht. Die Anmeldung entfernst du in der Konsole.', 'gut', 6000);
                dialog.schliessen();
                if (beiAenderung) beiAenderung();
              } catch (problem) { meldung(klartext(problem), 'warnung', 5000); }
            },
          }, '🗑️ Konto und alle Daten löschen'),
          konsolenknopf('↗ Anmeldung in der Konsole entfernen')))));
  };

  const dialog = blatt({ titel: wer(lehrkraft), breit: true, inhalt: platz });
  zeichnen();
  return dialog;
}

/* ---------- Neue Lehrkraft ---------- */

async function neueLehrkraft(beiFertig) {
  const email = h('input', {
    class: 'feld', type: 'email', placeholder: 'name@schule.de',
    autocomplete: 'off', autocapitalize: 'none', spellcheck: 'false',
  });
  const name = h('input', { class: 'feld', type: 'text', placeholder: 'Anrede und Name', autocomplete: 'off' });
  const wort = h('input', {
    class: 'feld', type: 'text', placeholder: 'mindestens sechs Zeichen',
    autocomplete: 'off', autocapitalize: 'none', spellcheck: 'false',
  });
  const fehler = h('p', { class: 'blatt__fehler', 'aria-live': 'polite' });

  const anlegen = async () => {
    fehler.textContent = '';
    if (!email.value.trim()) { fehler.textContent = 'Ohne E-Mail geht es nicht — sie ist die Anmeldung.'; email.focus(); return; }
    if (wort.value.trim().length < 6) { fehler.textContent = 'Das erste Kennwort braucht mindestens sechs Zeichen.'; wort.focus(); return; }
    knopf.disabled = true;
    try {
      const neu = await lehrkraftAnlegen(email.value.trim(), wort.value.trim(), name.value.trim());
      dialog.schliessen();
      meldung(`${neu.name || neu.email} ist angelegt.`, 'gut', 4000);
      if (beiFertig) beiFertig();
    } catch (problem) {
      fehler.textContent = klartext(problem);
      knopf.disabled = false;
    }
  };

  const knopf = h('button', { class: 'knopf knopf--voll', type: 'button', onclick: anlegen }, 'Anlegen');
  wort.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); anlegen(); } });

  const dialog = blatt({
    titel: 'Neue Lehrkraft',
    inhalt: h('div', {},
      h('p', { class: 'blatt__text' },
        'Das Konto entsteht sofort und ist damit anmeldbar. Gib das erste Kennwort '
        + 'persönlich weiter und lass es ändern — die Verwaltung sollte es danach nicht '
        + 'mehr kennen.'),
      zeile('E-Mail', email),
      zeile('Name', name),
      zeile('Erstes Kennwort', wort),
      fehler),
    fusszeile: [
      h('button', { class: 'knopf knopf--still', type: 'button', onclick: () => dialog.schliessen() }, 'Abbrechen'),
      knopf,
    ],
  });
  email.focus();
  return dialog;
}

/* ---------- Die Verwaltung selbst ---------- */

export function schulverwaltung() {
  const platz = h('div', {});

  async function zeichnen() {
    leeren(platz).appendChild(ladeplatz('Schule wird geholt …'));
    let lehrkraefte = [];
    let verwaist = [];
    try {
      lehrkraefte = await alleLehrkraefte();
      verwaist = await verwaisteKlassen(lehrkraefte).catch(() => []);
    } catch (problem) {
      leeren(platz).appendChild(h('p', { class: 'blatt__warnung' }, klartext(problem)));
      return;
    }

    const ich = angemeldet();
    const liste = h('div', { class: 'klassenliste' });
    for (const lehrkraft of lehrkraefte) {
      liste.appendChild(h('button', {
        class: 'klassenliste__eintrag', type: 'button',
        onclick: () => lehrkraftZeigen(lehrkraft, zeichnen),
      },
        h('span', { class: 'bereichsliste__emoji' }, lehrkraft.verwaltung ? '🔑' : '👩‍🏫'),
        h('span', { class: 'klassenliste__text' },
          h('strong', {}, wer(lehrkraft) + (lehrkraft.ichSelbst ? ' (du)' : '')),
          h('span', {}, `${lehrkraft.email || 'ohne E-Mail'} · `
            + `${lehrkraft.klassen.length === 1 ? '1 Klasse' : `${lehrkraft.klassen.length} Klassen`}`
            + (lehrkraft.verwaltung ? ' · Verwaltung' : ''))),
        h('span', { class: 'bereichsliste__pfeil' }, '›')));
    }

    const alleKlassen = lehrkraefte.flatMap((l) => l.klassen.map((k) => Object.assign({}, k, { besitzer: l })));
    alleKlassen.sort((a, b) => (a.name || '').localeCompare(b.name || '', 'de'));
    const klassenliste = h('div', { class: 'klassenliste' });
    for (const klasse of alleKlassen) {
      klassenliste.appendChild(h('button', {
        class: 'klassenliste__eintrag', type: 'button',
        onclick: () => klasseZeigen(klasse.code, zeichnen),
      },
        h('span', { class: 'klassenliste__code' }, klasse.code),
        h('span', { class: 'klassenliste__text' },
          h('strong', {}, klasse.name || 'Klasse'),
          h('span', {}, wer(klasse.besitzer))),
        h('span', { class: 'bereichsliste__pfeil' }, '›')));
    }

    // Verwaiste Klassen: Codes ohne Lehrkraft. Über die Liste oben wären sie
    // nicht zu finden — und niemand käme je wieder an sie heran.
    const verwaistliste = h('div', { class: 'klassenliste' });
    for (const code of verwaist) {
      verwaistliste.appendChild(h('div', { class: 'verwaistliste__eintrag' },
        h('span', { class: 'klassenliste__code' }, code),
        h('span', { class: 'kinderliste__name' }, 'ohne Lehrkraft'),
        h('button', {
          class: 'knopf knopf--still knopf--klein', type: 'button',
          onclick: () => klasseZeigen(code, zeichnen),
        }, 'Ansehen'),
        h('button', {
          class: 'knopf knopf--gefahr knopf--klein', type: 'button',
          onclick: async () => {
            const sicher = await frage({
              titel: `Klasse ${code} löschen?`,
              text: 'Kinder, Sterne, PINs und Wortprotokoll dieser Klasse sind danach weg.',
              ja: 'Löschen', gefahr: true,
            });
            if (!sicher) return;
            try { await klasseLoeschen(code); meldung('Gelöscht.', 'gut'); zeichnen(); }
            catch (problem) { meldung(klartext(problem), 'warnung', 5000); }
          },
        }, 'Löschen')));
    }

    leeren(platz).appendChild(h('div', {},
      h('p', { class: 'blatt__text' },
        `${lehrkraefte.length === 1 ? 'Eine Lehrkraft' : `${lehrkraefte.length} Lehrkräfte`}, `
        + `${alleKlassen.length === 1 ? 'eine Klasse' : `${alleKlassen.length} Klassen`}. `
        + 'Kinder, PINs und Wortprotokolle stehen in der jeweiligen Klasse — dort, wo sie '
        + 'auch die Lehrkraft findet.'),

      abschnitt('Lehrkräfte', liste,
        h('p', { class: 'abschnitt__notiz' },
          'Ein Tipp auf einen Namen öffnet das Konto — dort lässt sich umbenennen, das '
          + 'Kennwort zurücksetzen und das Verwaltungsrecht vergeben.'),
        h('div', { class: 'blatt__knopfreihe' },
          h('button', {
            class: 'knopf knopf--voll', type: 'button', onclick: () => neueLehrkraft(zeichnen),
          }, '+ Neue Lehrkraft'),
          // Der Weg für den Fall, dass zu einem Konto keine Adresse im
          // Verzeichnis steht — dann ist der Knopf im Konto grau, die Kollegin
          // hat aber trotzdem eine Mailadresse.
          h('button', {
            class: 'knopf knopf--still', type: 'button',
            onclick: async () => {
              const adresse = await eingabe({
                titel: 'Kennwort-Mail schicken',
                text: 'Die E-Mail-Adresse, mit der sich die Kollegin anmeldet. Gibt es zu '
                  + 'dieser Adresse kein Konto, sagt es die App.',
                platzhalter: 'name@schule.de',
                pruefung: (wert) => (/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(wert) ? null : 'Das sieht nicht nach einer E-Mail-Adresse aus.'),
                ja: 'Weiter',
              });
              if (!adresse) return;
              await kennwortmail(adresse);
            },
          }, '✉️ Kennwort-Mail'))),

      abschnitt('Alle Klassen',
        h('p', { class: 'abschnitt__notiz' },
          'Ein Tipp öffnet die gewohnte Klassenansicht: Kinder anlegen, umbenennen, '
          + 'PIN neu vergeben, entfernen — und den QR-Code zeigen.'),
        alleKlassen.length ? klassenliste
          : h('p', { class: 'blatt__text' }, 'Noch keine Klasse an dieser Schule.')),

      verwaist.length
        ? abschnitt(`Klassen ohne Lehrkraft (${verwaist.length})`,
          h('p', { class: 'abschnitt__notiz' },
            'Diese Codes gehören zu keinem Konto mehr — meist, weil eine Anmeldung in der '
            + 'Firebase-Konsole entfernt wurde, ohne die Klassen mitzunehmen.'),
          verwaistliste)
        : null,

      abschnitt('Diese Anmeldung',
        zeile('Konto', h('span', { class: 'blatt__wert' }, (ich && ich.email) || '—')),
        zeile('Kennung', h('span', { class: 'blatt__wert blatt__wert--klein' }, (ich && ich.uid) || '—')),
        h('p', { class: 'abschnitt__notiz' },
          'Wer verwalten darf, steht in den Datenbankregeln — nicht in der App. Weitere '
          + 'Verwaltungen vergibst du oben bei der jeweiligen Lehrkraft; die erste steht '
          + 'in den Regeln selbst.'),
        h('div', { class: 'blatt__knopfreihe' },
          konsolenknopf('↗ Anmeldungen in der Konsole'),
          konsolenknopf('↗ Regeln in der Konsole', 'database/rules')))));
  }

  const dialog = blatt({ titel: '🏫 Schulverwaltung', breit: true, inhalt: platz });
  zeichnen();
  return dialog;
}
