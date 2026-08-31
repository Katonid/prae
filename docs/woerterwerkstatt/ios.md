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
   Unterschied zwischen „benutzen wir“ und „benutzen wir nicht“.
3. **Verlässlich vorlesen.** `speechSynthesis` gibt es in Safari, aber die
   Stimmenauswahl ist unberechenbar und die erste Ausgabe braucht eine
   Berührung. `AVSpeechSynthesizer` ist verlässlich.

Alles andere — Offline-Betrieb, Fortschritt, Klassen per QR-Code — funktioniert
im Browser bereits vollständig.

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
