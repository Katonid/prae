# Wörterwerkstatt als native iOS-App

Die App ist heute eine Web-App (`woerterwerkstatt/`). Dieses Papier hält fest,
was schon jetzt dafür getan ist, dass daraus eine iOS-App werden kann — und
was dann noch zu tun wäre. Es ist **kein Beschluss**, sondern eine
Wegbeschreibung, damit die Entscheidung später eine Entscheidung bleibt und
kein Neuanfang.

## Warum die Frage überhaupt aufkommt

Drei Dinge kann eine Web-App auf einem iPad nicht oder nur halb:

1. **Auf dem Homescreen aussehen wie eine App.** Über „Zum Home-Bildschirm“
   geht das schon (die App bringt Manifest und Icons mit), aber die Kinder
   müssen den Weg gezeigt bekommen, und ein Schul-iPad im geführten Zugriff
   lässt ihn oft gar nicht zu.
2. **Über das MDM der Schule verteilt werden.** Das geht nur mit einer App aus
   dem App Store oder Apple School Manager. Für viele Schulen ist genau das der
   Unterschied zwischen „benutzen wir“ und „benutzen wir nicht“. (Halb stimmt
   das nicht — ein MDM kann auch einen Web Clip verteilen. Siehe den nächsten
   Abschnitt.)
3. **Verlässlich vorlesen.** `speechSynthesis` gibt es in Safari, aber die
   Stimmenauswahl ist unberechenbar und die erste Ausgabe braucht eine
   Berührung. `AVSpeechSynthesizer` ist verlässlich.

Alles andere — Offline-Betrieb, Fortschritt, Klassen per QR-Code — funktioniert
im Browser bereits vollständig.

## Wenn die Kinder nur eine schulische Apple-ID haben

Nachgesehen 08/2026 auf Frage des Nutzers. **Kurz: Ja, der Umbau ist möglich —
die schulische Apple-ID verbietet nichts. Sie legt aber den Verteilweg fest,
und der entscheidet hier mehr als der Quelltext.**

### Was eine schulische Apple-ID kann und was nicht

Eine schulische Apple-ID („Managed Apple Account“ aus dem Apple School
Manager) ist kein gewöhnliches Apple-Konto:

* **Kein Laden aus dem App Store.** Der Handel ist abgeschaltet — ein Kind
  kann sich eine App nicht selbst holen, auch keine kostenlose.
* **Apps kommen von der Schule**, über „Apps und Bücher“ im Apple School
  Manager und ein MDM. Zugewiesen wird entweder an das **Gerät** — dann
  braucht das iPad überhaupt keine Apple-ID — oder an das Konto.
* **TestFlight geht seit 10/2025 mit schulischen Apple-IDs, aber nicht für
  die Rolle „Schüler“.** Ein Kind kann also keine Testfassung bekommen.
* Die Schule darf private Apple-IDs auf ihren Geräten ganz sperren.

Die App wird auf einem Kinder-iPad also genau dann sichtbar, wenn die Schule
sie verteilt — nie, weil ein Kind sie sich holt.

### Die Wörterwerkstatt selbst verlangt keine Apple-ID

Am Quelltext geprüft (08/2026): kein iCloud, kein „Anmelden mit Apple“, kein
Kauf in der App, kein Game Center — nichts davon steht irgendwo im Ordner.
Die Kinder melden sich mit **Klassencode, Namen und vierstelliger PIN** an
(`js/cloud.js`); gespeichert wird örtlich (IndexedDB) und in der
Firebase-Datenbank. Die einzigen fremden Adressen im ganzen Ordner gehören
Firebase. Nach außen spricht die App über Google, nie über Apple.

Es gibt damit **keine Stelle, an der eine schulische Apple-ID etwas
verhindert**, was die App tut. Sie ist an genau zwei Stellen wichtig: beim
Installieren und beim Testen.

### Die eigentliche Bedingung: Hat die Schule ein MDM?

Ohne MDM und Apple School Manager kommt eine native App auf ein verwaltetes
iPad **gar nicht** — es gibt keinen zweiten Weg. Dann ist die heutige Web-App
nicht der bequemere, sondern der einzige. Diese Frage gehört vor die erste
Zeile Swift.

Hat die Schule ein MDM, folgt daraus zugleich das Gegenargument: Dann kann sie
auch einen **Web Clip** verteilen (Nutzlast `com.apple.webClip.managed`,
Anzeige „Vollbild“). Das bringt ohne jeden Umbau ein Symbol auf dem
Homescreen, ohne Browserleiste, über dasselbe MDM verteilt — ohne App Store,
ohne Apple-ID, ohne Prüfung durch Apple, sofort. Die Punkte 1 und 2 aus
„Warum die Frage überhaupt aufkommt“ sind damit erledigt, und beide waren die
Hauptgründe.

### Was der Umbau dann noch bringt

Bleiben die Gründe, die ein Web Clip nicht abdeckt:

* **Vorlesen.** Ein Web Clip ist Safari, also bleibt es bei
  `speechSynthesis` samt unberechenbarer Stimmenwahl. Die Diktatstufe steht
  und fällt damit — das ist das stärkste verbliebene Argument.
* **Safari-Sperren.** Wo die Schule Safari abschaltet oder einen
  Inhaltsfilter setzt, fällt der Web Clip mit aus. Eine eigene App mit
  `WKWebView` ist davon unberührt. (Den Netzfilter umgeht sie nicht: Die
  Firebase-Adresse muss durch, sonst gibt es keine Klassen.)
* **Speicher, den niemand wegräumt.** Safari räumt den Speicher von Seiten
  auf, die sieben Tage nicht benutzt wurden; für vom Homescreen gestartete
  Web-Apps soll das nicht gelten. Darauf verlassen möchte man sich bei sechs
  Wochen Sommerferien nicht. Im Bündel einer App stellt sich die Frage nicht.
* **QR-Scanner** für den Klassenbeitritt (siehe unten, Punkt 1).

### Was beim App-Store-Weg zusätzlich zu tun ist

1. **Verfügbarkeit für Apple School Manager anhaken.** Ohne diese Freigabe
   des Entwicklers taucht die App in „Apps und Bücher“ nicht auf — auch eine
   kostenlose nicht. Die Schule kann sie dann nicht beziehen, obwohl sie im
   App Store steht.
2. **Oder als „Custom App“** nur für diese eine Schule (Organisations-Kennung
   aus deren Apple School Manager). Nicht öffentlich gelistet, aber von Apple
   genauso geprüft — Richtlinie 4.2 gilt dort ebenso.
3. **Nicht die Kinder-Kategorie wählen**, sondern „Bildung“ mit Altersfreigabe
   4+. Die Kinder-Kategorie verbietet, personenbezogene Daten an Dritte zu
   geben — und genau das ist Firebase. Wer sie einmal gewählt hat, muss ihre
   Regeln auch in allen künftigen Fassungen einhalten.
4. **Datenschutz.** Namen, Sterne und das Wortprotokoll von Kindern liegen bei
   Google. Für die Schule heißt das ein Auftragsverarbeitungsvertrag — das
   gilt schon heute für die Web-App, fällt beim App Store aber jemandem auf.
5. **Testen ohne Kinder.** Der Nutzer selbst und Lehrkräfte können per
   TestFlight prüfen, Kinder nicht. Was in die Klasse geht, muss vorher
   woanders fertig geprüft sein.

### Empfehlung in dieser Reihenfolge

1. Bei der Schule fragen, ob sie MDM und Apple School Manager hat. **Nein →
   die Web-App bleibt, und der Umbau erübrigt sich**, denn eine App käme auf
   die Geräte nicht drauf.
2. **Ja → zuerst einen Web Clip verteilen lassen.** Kostet nichts, dauert eine
   Viertelstunde und bringt Homescreen-Symbol und Verteilung sofort.
3. Erst wenn danach noch etwas fehlt — verlässliches Vorlesen, ein Scanner,
   oder Safari ist gesperrt —, lohnt Weg A. Die schulische Apple-ID ist dann
   kein Hindernis mehr, sondern nur noch der Grund, warum gerätebasiert
   zugewiesen wird.

## Was heute schon dafür getan ist

### Eine einzige Brücke zur Plattform

`woerterwerkstatt/js/plattform.js` ist die **einzige** Datei, in der etwas
steht, das nicht reines HTML ist:

| Funktion | Web-Weg heute | nativer Weg später |
|---|---|---|
| `sprich(text, {tempo})` | `speechSynthesis` | `AVSpeechSynthesizer` |
| `schweig()` | `speechSynthesis.cancel()` | `stopSpeaking(at:)` |
| `haptik(art)` | `navigator.vibrate` (auf iOS wirkungslos) | `UIImpactFeedbackGenerator` |
| `inZwischenablage(text)` | `navigator.clipboard` | `UIPasteboard` |
| `bleibWach(an)` | `navigator.wakeLock` | `UIApplication.isIdleTimerDisabled` |
| `vollbild(an)` | `requestFullscreen` | entfällt (die App IST Vollbild) |
| `nativ()` / `alsApp()` | `display-mode: standalone` | meldet `true` |

Jede Funktion prüft zuerst, ob sich unter `window.wwBruecke` eine native Hülle
gemeldet hat, und nimmt sonst den Web-Weg. Eine Hülle muss also nur ein Objekt
mit diesen Namen bereitstellen — an der übrigen App ändert sich **keine Zeile**.

Dass jede Funktion still nichts tut, wenn beides fehlt, ist Absicht: Ein
fehlender Klang darf nie eine Übung anhalten.

### Nichts wird nachgeladen

Keine CDN, kein Framework, keine fremde Bibliothek. Schriften liegen als woff2
im Ordner, der QR-Code wird selbst gerechnet, die Klänge werden im Gerät
erzeugt (Web Audio), die Wortbilder sind selbst gezeichnetes SVG. In einer
Hülle mit `WKWebView` und lokalen Dateien fehlt damit nichts — was nachgeladen
werden müsste, wäre genau das, was in einem Bündel nie ankommt.

### Keine gebauten Dateien

Kein npm, kein Bundler, kein Übersetzungsschritt. Der Ordner
`woerterwerkstatt/` lässt sich unverändert als Ressourcenordner in ein
Xcode-Ziel legen.

### Relative Pfade und ein Wegweiser über die Raute

Alle Pfade sind relativ (`./js/…`), und der Wegweiser läuft über
`window.location.hash`. Beides funktioniert auch, wenn die App nicht unter
`/prae/woerterwerkstatt/` liegt, sondern aus einem Bündel geladen wird.

Eine Ausnahme, die beim Umzug anzufassen ist: `js/cloud.js` lädt
`../firebase-config.js` aus dem Wurzelverzeichnis des Repos. In einer Hülle
muss diese Datei ins Bündel und der Pfad angepasst werden — eine Zeile.

### Sichere Ränder und Standalone-Verhalten

`viewport-fit=cover` und `env(safe-area-inset-*)` an Kopfleiste, Bühne, Blättern
und Meldungen. `apple-mobile-web-app-capable`, ein `apple-touch-icon` und ein
Manifest liegen bei. Die App sieht auf dem Homescreen schon heute richtig aus.

### Speicher, der einen Umzug übersteht

Gespeichert wird in IndexedDB, mit `localStorage` als Rückfall — beides gibt es
in `WKWebView`. Der Zustand wird beim Lesen **zusammengeführt** statt ersetzt
(`store.js`, `zusammen()`): Eine neue Fassung mit zusätzlichen Einstellungen
verliert die alten Werte nicht.

Wichtig für den Umzug: Der Speicher hängt an der Herkunft (Origin). Wer von
`https://katonid.github.io` in eine Hülle mit lokalen Dateien zieht, nimmt den
Fortschritt **nicht** mit. Was dagegen hilft, steht unten unter „Wenn es so
weit ist“.

## Zwei Wege, wenn es so weit ist

### Weg A — Hülle um die Web-App (`WKWebView`)

Ein Xcode-Ziel, ein `WKWebView`, der Ordner `woerterwerkstatt/` als
Ressourcenordner, geladen über `loadFileURL(_:allowingReadAccessTo:)`. Dazu
eine Klasse, die `window.wwBruecke` bereitstellt (siehe Tabelle oben) — über
`WKUserContentController.add(_:name:)` und ein kleines Skript, das beim
Dokumentstart eingespielt wird.

* **Dauer:** überschaubar. Die Brücke ist der Hauptteil, und die ist klein.
* **Vorteil:** eine Quelle für Web und App. Was in der Web-App verbessert wird,
  ist in der iOS-App enthalten.
* **Nachteil:** Apple lehnt Apps ab, die nichts als eine Webseite sind
  (Richtlinie 4.2). Die Brücke muss also wirklich etwas beitragen — Vorlesen
  mit `AVSpeechSynthesizer`, Haptik, Bildschirm wach halten, und am besten
  Kamera-Beitritt (siehe unten). Das ist zu schaffen, aber es ist eine Hürde,
  die man kennen sollte, bevor man anfängt.

### Weg B — Neubau in SwiftUI

Die Daten (`js/woerter.js`) nach JSON wandeln und die Oberfläche neu bauen.

* **Vorteil:** echte Systemoberfläche, keine Richtlinienfrage, bessere
  Tastaturbehandlung.
* **Nachteil:** zwei Fassungen, die auseinanderlaufen. Jede neue Übungsart
  müsste zweimal gebaut werden.

**Empfehlung:** Weg A, sobald es einen Grund gibt (MDM-Verteilung, verlässliche
Sprachausgabe) — und dann mit einer Brücke, die genug beiträgt, um Richtlinie
4.2 standzuhalten. Weg B nur, wenn die App eigenständig weiterwachsen soll.

## Was in beiden Fällen zu tun ist

1. **Kamera für den Klassen-Beitritt.** Heute scannen die Kinder den QR-Code
   mit der Kamera-App des iPads, die dann Safari öffnet. In einer nativen App
   gehört ein eigener Scanner hinein (`AVCaptureSession` mit
   `AVMetadataMachineReadableCodeObject`) — das ist zugleich das stärkste
   Argument gegen Richtlinie 4.2. Der Code steht schon fertig in der Adresse
   (`#/beitreten/ABC234`), es fehlt nur der Weg von der Kamera dorthin.
2. **`ITSAppUsesNonExemptEncryption = NO`** setzen, als Build-Einstellung
   `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` oder in der `Info.plist`.
   Ohne das fragt App Store Connect bei **jedem** TestFlight-Build nach der
   Export-Compliance. (Steht so auch in der `CLAUDE.md` des Repos, für alle
   iOS-Apps hier.)
3. **`DEVELOPMENT_LANGUAGE = de`** plus `CFBundleDevelopmentRegion` und
   `CFBundleLocalizations` in der `Info.plist`. Ohne das hält iOS die App für
   englisch und zeigt alles Systemeigene — Teilen-Blatt, Dateiwähler,
   „Abbrechen“/„Fertig“ — auf Englisch. (In Tafelbild einmal teuer gelernt.)
4. **`NSCameraUsageDescription`**, sobald der Scanner drin ist.
5. **Datenschutz.** Die App verarbeitet Namen von Kindern und ihre
   Übungsfortschritte. Für den App Store braucht es die Datenschutzangaben und
   eine erreichbare Datenschutzerklärung — wie bei Tafelbild unter
   `docs/tafelbild/datenschutz.html`. Was gemeldet wird, ist knapp gehalten
   (nur Sterne je Päckchen, nie einzelne Eingaben) — das ist beim Ausfüllen der
   Angaben die halbe Miete.
6. **Umzug des Fortschritts.** Wer die App schon im Browser genutzt hat, findet
   in der nativen Hülle einen leeren Speicher (andere Herkunft). Zwei
   Möglichkeiten: Beim ersten Start die Web-Fassung im `WKWebView` unter der
   alten Adresse laden und den Zustand einmal überspielen — oder, viel
   einfacher, das Kind meldet sich mit Name und PIN an und holt sich seinen
   Stand aus der Klasse. Dafür ist der Fortschritt in der Klasse schon
   vorgesehen; es fehlt nur das Zurückholen.
7. **Bau in GitHub Actions eintragen.** Die App-Liste steht in
   `.github/scripts/welche-apps.py` und in den `options` von
   `.github/workflows/ios-apps-build.yml` — an beiden Stellen.

## Was NICHT zu tun ist

* **Kein Framework nachrüsten**, „weil man es dann leichter portieren kann“.
  Das Gegenteil ist der Fall: Jede Abhängigkeit ist eine Datei mehr, die im
  Bündel landen und dort funktionieren muss.
* **Die Brücke nicht umgehen.** Wer irgendwo direkt `speechSynthesis` oder
  `navigator.vibrate` aufruft, verschiebt die Portierungsarbeit von einer Datei
  auf alle. `js/plattform.js` ist die einzige Stelle — das ist der ganze Trick.
* **Nicht auf `alert`, `confirm` oder `prompt` bauen.** In `WKWebView` müssen
  sie von der Hülle beantwortet werden, sonst passiert schlicht nichts, ohne
  jede Fehlermeldung. Die App benutzt durchweg eigene Blätter — `frage()` für
  Ja/Nein und `eingabe()` für eine Eingabe, beide in `js/ui.js`. Im ganzen
  Ordner steht kein einziges `prompt()`; das soll so bleiben.
