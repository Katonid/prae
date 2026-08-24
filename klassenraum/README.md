# Klassenraum — digitale Tafel für den Unterricht

Eine freie Web-App als Ersatz für kostenpflichtige Tafel-Dienste. Sie läuft ohne
Installation im Browser, ist für iPad und interaktive Tafeln gemacht und
funktioniert auch am Telefon.

**Adresse:** https://katonid.github.io/prae/klassenraum/

## Was die App kann

| Element | Beschreibung |
| --- | --- |
| **Zufälliger Name** | Zieht Namen aus einer Liste — mit oder ohne Zurücklegen. Gezogene Namen lassen sich einzeln zurücklegen, löschen oder von Hand als gezogen markieren. Der gezogene Name kann **schrittweise aufgedeckt** werden, damit die Klasse mitraten kann. |
| **Timer / Stoppuhr** | Voreinstellungen von 1 bis 45 Minuten, ±1 Minute, Signalton am Ende. |
| **Uhr** | Analog (mit Ziffernblatt zum Ablesen üben) oder digital, mit Datum. |
| **Ampel** | Drei Lichter, antippen oder doppeltippen zum Weiterschalten, mit eigenen Beschriftungen. |
| **Tagesablauf** | Checkliste mit Fortschrittsbalken, Punkte abhaken, sortieren, schnell erfassen. |
| **Text** | Doppeltippen zum Schreiben, Schriftgröße passt sich automatisch an. |
| **Bild** | Bild vom Gerät, wird beim Einfügen verkleinert. |
| **Lautstärke** | Misst über das Mikrofon die Lautstärke im Raum, mit einstellbarer Grenze und optionalem Signalton. Beim ersten Start fragt das Gerät nach der Erlaubnis; wird sie verweigert, erklärt die Karte den Weg zurück. |
| **Arbeitssymbol** | Einzel-, Partner-, Gruppenarbeit, Stillarbeit, Melden, Zuhören, Aufräumen. |

Dazu kommen: **mehrere Klassenräume** (eine eigene Tafel pro Klasse), **Namenslisten**,
die in allen Klassenräumen verfügbar sind, ein **Präsentationsmodus** ohne Bedienleisten
und die Möglichkeit, alles **als Datei zu sichern**.

## Aussehen

* **Bewegte Hintergründe** („Nordlicht“, „Sonnenaufgang“, „Waldgrün“, „Beere“, „Tafelgrün“,
  „Kreide hell“) mit langsam wandernden Farbschleiern — dazu einfarbige Hintergründe,
  Farbverläufe oder ein eigenes Bild.
* **Drei Kartenstile:** Glas (durchscheinend), Hell (maximaler Kontrast) und Dunkel
  (abends angenehm) — pro Klassenraum einstellbar.
* Karten mit weichem Schlagschatten, Namen im Farbverlauf, Konfetti beim Ziehen,
  glühende Ampellichter und ein Timer-Ring mit Farbverlauf.
* Wer in den Systemeinstellungen „Bewegung reduzieren“ aktiviert hat, bekommt die
  ruhige Variante ohne Animationen.

## Zwei Ansichten

Oben rechts schaltet **„Fertig“** in die **Unterrichtsansicht**: Elementleiste,
Auswahlrahmen, Zahnräder und Eingabefelder verschwinden, die Tafel lässt sich aber
weiter bedienen (Namen ziehen, Ampel schalten, Timer starten, Punkte abhaken).
Verschieben, Einstellen und Löschen sind dort gesperrt — ein Kind kann also nichts
versehentlich verstellen. **„Bearbeiten“** schaltet zurück. Die zuletzt gewählte
Ansicht wird gemerkt.

## Namen aufdecken

Damit die Klasse raten kann, erscheint der gezogene Name nicht sofort. Jeder Tipp auf
die Karte deckt einen Schritt auf; das Augensymbol zeigt sofort alles. Vier Arten
stehen zur Wahl:

| Art | Wirkung |
| --- | --- |
| **Mosaik** (Vorgabe) | Ein feines Raster aus 280 Kacheln verschwindet nach und nach — zwölf Tipps bis zum ganzen Namen. |
| **Unschärfe** | Zuerst nur ein Farbnebel, mit jedem Tipp schärfer — zehn Tipps. Die Stärke richtet sich nach der Schriftgröße, damit auch große Namen wirklich unlesbar sind. |
| **Buchstaben** | Ein Buchstabe nach dem anderen erscheint, der Rest bleibt als Punkt stehen — wie beim Ratespiel. |
| **Sofort** | Ohne Spannung: der Name steht direkt da. |

Ebenfalls einstellbar: ob die **Liste der bereits gezogenen Namen** nie, nur beim
Bearbeiten (Vorgabe) oder immer sichtbar ist. In der Unterrichtsansicht bleibt sie
damit verborgen — und der gerade gezogene Name taucht dort erst auf, wenn er
aufgedeckt ist.

## Bedienung in Kürze

* **Element hinzufügen:** unten in der Leiste antippen (nur beim Bearbeiten).
* **Bedienen:** Ein Tipp auf die Karte löst die Hauptfunktion aus — Zufälliger Name zieht
  den nächsten Namen, die Ampel schaltet weiter, das Arbeitssymbol wechselt, die Uhr springt
  zwischen analog und digital, die Lautstärkemessung startet.
* **Verschieben:** Element anfassen und ziehen; an den Ecken ziehen ändert die Größe.
  (Beim Ziehen wird nichts ausgelöst.)
* **Einstellen:** Element antippen → Zahnrad in der kleinen Leiste darüber.
* **Sperren:** Schloss-Symbol in derselben Leiste — verhindert versehentliches Verschieben an der interaktiven Tafel.
* **Am Telefon** schaltet die App automatisch auf eine Listenansicht um (im Menü umschaltbar).
* **Auf den Homescreen legen:** in Safari „Teilen“ → „Zum Home-Bildschirm“. Danach startet die App im Vollbild und funktioniert auch offline.

## Teilen und Konten

Ein Klassenraum lässt sich unter „Teilen“ mit einem **sechsstelligen Code**
weitergeben. Andere geben den Code ein und wählen:

* **Als eigene Kopie laden** — die Kopie gehört danach der anderen Person.
* **Live folgen** — jede Änderung der teilenden Person erscheint automatisch,
  z. B. auf der interaktiven Tafel im Klassenzimmer.

**Konten** (E-Mail und Passwort) sichern alle Klassenräume und laden sie auf
einem anderen Gerät wieder. Sie brauchen eine einmalige Freischaltung im
Firebase-Projekt: *Firebase-Konsole → Authentication → Anmeldemethode →
E-Mail/Passwort aktivieren*. Solange das nicht geschehen ist, zeigt die App
einen Hinweis; Teilen per Code funktioniert unabhängig davon.

## Aktualisierungen

Die App prüft bei jedem Öffnen, ob auf dem Server eine neue Fassung liegt, lädt sie
und startet sich einmal automatisch neu („Neue Fassung geladen"). Im Menü unter
**Über** steht die laufende Fassung, daneben der Knopf **„Nach Aktualisierung
suchen"** — falls ein Gerät doch einmal auf einem alten Stand hängen bleibt.

## Datenschutz

* Alle Klassenräume, Listen und Bilder liegen **auf dem Gerät** (IndexedDB) und
  werden nicht automatisch übertragen.
* Erst beim Erstellen eines Teilen-Codes wird der betreffende Klassenraum auf den
  Server geschrieben. Dort liegt er **unverschlüsselt** und ist für jede Person
  mit dem Code lesbar — deshalb bitte nur **Vornamen oder Kürzel** verwenden.
* Der Lautstärkemesser berechnet nur den Pegel. Es wird **nichts aufgenommen,
  gespeichert oder gesendet**.
* Ohne Teilen und ohne Konto stellt die App keine Verbindung ins Netz her.

## Technik

Statische Web-App ohne Build-Schritt (ES-Module, kein Framework). Sie wird über
den GitHub-Pages-Workflow des Repos mit ausgeliefert.

```
klassenraum/
  index.html            Grundgerüst
  css/app.css           Oberfläche
  js/app.js             Start, Bedienleisten, Klassenraum-Verwaltung
  js/board.js           Tafelfläche: verschieben, Größe ändern, auswählen
  js/store.js           Zustand und Speicherung (IndexedDB, Fallback localStorage)
  js/widgets/*.js       die einzelnen Elemente
  js/lists.js           Namenslisten
  js/share.js           Teilen-Oberfläche und Live-Abgleich
  js/cloud.js           Firebase-REST (Teilen, Konten, Sicherung)
  js/ui.js, js/util.js, js/icons.js
  sw.js                 Offline-Betrieb
  scripts/generate-icons.py   erzeugt die App-Icons
```

Die Zugangsdaten kommen aus `../firebase-config.js` im Repo-Wurzelverzeichnis.
Für die Cloud-Funktionen wird die REST-Schnittstelle der Realtime Database
genutzt (Live-Abgleich über den Ereignisstrom, sonst regelmäßiges Nachfragen);
es wird kein zusätzliches SDK geladen.

### Lokal ausprobieren

```bash
npx http-server -p 8765 .      # im Repo-Wurzelverzeichnis
# dann http://127.0.0.1:8765/klassenraum/ öffnen
```

### Empfohlene Datenbankregeln

Die Freigaben liegen unter `klassenraum/`. Passende Regeln für die Realtime
Database, falls sie später verschärft werden sollen:

```json
{
  "rules": {
    "klassenraum": {
      "shares": { ".read": true, ".write": true },
      "users": {
        "$uid": { ".read": "$uid === auth.uid", ".write": "$uid === auth.uid" }
      }
    }
  }
}
```
