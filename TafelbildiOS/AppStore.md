# Tafelbild im App Store — was einzutragen ist

Diese Datei ist eine Arbeitsliste für die Abgabe in App Store Connect. Alles,
was im Repo erledigt werden kann, ist erledigt; hier steht, was von Hand
einzutragen ist — samt fertiger Texte zum Kopieren.

## Im Repo schon vorhanden

| Punkt | Wo |
|---|---|
| App-Symbol (1024 px, ohne Alphakanal) | `Tafelbild/Assets.xcassets/AppIcon.appiconset` |
| Alternative Symbolfarben | `Tafelbild/Symbole/` |
| Verwendungszwecke für Kamera, Mikrofon, Fotos | `Config/Info.plist` |
| Keine Exportbeschränkung (`ITSAppUsesNonExemptEncryption = NO`) | `Config/Info.plist` + Bauzieleinstellung |
| **Datenschutzmanifest** | `Tafelbild/PrivacyInfo.xcprivacy` |
| Datenschutzerklärung im Netz | `docs/tafelbild/datenschutz.html` |
| Support-Seite im Netz | `docs/tafelbild/support.html` |

Adressen nach dem nächsten Merge:

* Datenschutz: `https://katonid.github.io/prae/tafelbild/datenschutz.html`
* Support: `https://katonid.github.io/prae/tafelbild/support.html`

## Noch zu prüfen

* **Kontaktadresse.** In den beiden Seiten steht `tafelbild@apps.dblern.de` —
  gebildet nach dem Vorbild der Soundboard-Seiten. Wenn diese Adresse nicht
  existiert oder eine andere gewünscht ist, in `docs/tafelbild/*.html`
  ändern; App Store Connect verlangt dieselbe Adresse noch einmal als
  Support-Kontakt.

## In App Store Connect einzutragen

### Grunddaten

* **Name:** Tafelbild
* **Untertitel (max. 30 Zeichen):** `Die Tafel für den Unterricht`
* **Kategorie:** Bildung (zweitrangig: Produktivität)
* **Altersfreigabe:** 4+ — keine der Fragen trifft zu
* **Preis:** kostenlos
* **Sprache:** Deutsch

### Beschreibung

```
Tafelbild macht aus dem iPad eine Tafel für den Unterricht: Zufallsname,
Timer, Uhr, Ampel, Lautstärkemesser, Tagesablauf, Text, Bild, Klänge,
Arbeitssymbole, Video und Dokumentenkamera — frei anzuordnen auf mehreren
Seiten je Tafel.

WAS DRIN IST

• Zufälliger Name — zieht aus deiner Klassenliste, ohne Wiederholung oder
  mit. Der Name lässt sich Stück für Stück aufdecken, damit die Klasse
  mitraten darf.
• Timer und Stoppuhr — ein Tipp startet, ein Doppeltipp setzt zurück.
  Wahlweise als Ring mit Zahl oder als ablaufende Scheibe auf einem
  Ziffernblatt, für die niemand die Uhr lesen können muss.
• Uhr — analog mit Lernziffernblatt oder digital, wahlweise mit Datum.
• Ampel und Arbeitssymbole — zeigen groß, was gerade gilt.
• Lautstärkemesser — misst den Pegel im Raum, mit Schwellen für Stillarbeit,
  Partner- und Gruppenarbeit. Aufgezeichnet wird nichts.
• Tagesablauf zum Abhaken, Textfelder, Bilder, Klangfelder, Video.
• Dokumentenkamera — Heft unter das iPad legen, Bild einfrieren, mit dem
  Stift hineinschreiben.
• Handschrift über allem, mit Apple Pencil oder Finger.
• Beamer und Fernseher zeigen nur die Tafel — nicht den iPad-Bildschirm.
  Bedienleiste, Menüs und die Mitteilungen anderer Apps bleiben beim
  Lehrertisch.

FÜR DEN ALLTAG GEBAUT

Mehrere Tafeln, mehrere Seiten je Tafel — eine je Stunde oder je Fach.
Das Format der Tafel passt sich dem Beamer an: 16:10, 16:9 oder 4:3.
Hintergründe, Farbverläufe mit eigenen Farben, Schriften mit dem runden a
der Grundschulschrift. Alles lässt sich so groß stellen, dass es aus der
letzten Reihe zu lesen ist.

GEMEINSAM ARBEITEN

Eine Tafel lässt sich per Einladungscode teilen. Inhalte gehören danach
allen — Namenslisten samt gezogener Namen, Texte, Tagesablauf. Anordnung,
Farben und ausgeblendete Elemente bleiben bei jeder Person persönlich.
Zwischen den eigenen Geräten gleicht sich alles ab.

DATENSCHUTZ

Kein Konto beim Entwickler, keine Werbung, kein Tracking, keine Analyse.
Alles liegt auf dem Gerät und im eigenen iCloud-Bereich. Der
Lautstärkemesser rechnet nur einen Pegel aus; die Kamera nimmt nur auf, was
selbst eingefroren wird.
```

### Schlagwörter (max. 100 Zeichen, mit Komma getrennt)

```
Unterricht,Schule,Grundschule,Tafel,Timer,Zufallsname,Lautstärke,Klasse,Lehrer,Ampel,Tagesablauf
```

### Neue Funktionen (bei der ersten Fassung)

```
Erste Fassung.
```

### Bildschirmfotos

App Store Connect nimmt nur Bilder an, deren Pixelmaße auf den Punkt
stimmen — und das Feld sagt genau, welche es will:

| Feld | Erlaubte Maße | Simulator |
|---|---|---|
| iPhone 6,9" | 1320 × 2868 oder 1290 × 2796 (auch quer) | iPhone 17/16 Pro Max |
| iPhone 6,7" | 1290 × 2796 (auch quer) | iPhone 15 Pro Max |
| iPhone 6,5" | 1284 × 2778 oder 1242 × 2688 (auch quer) | iPhone 14 Plus, 13/12 Pro Max |
| iPad 13" | 2064 × 2752 oder 2048 × 2732 (auch quer) | iPad Pro 13", iPad Air 13" |

Verlangt wird nur die jeweils größte iPhone- und iPad-Größe; die kleineren
rechnet Apple daraus ab. Ein Satz iPhone-Bilder und ein Satz iPad-Bilder
reichen also.

**Die Bilder werden von Hand gemacht — auf dem Gerät.** Es gab einmal
einen Arbeitsablauf, der sie im Simulator erzeugen sollte. Er ist wieder
entfernt: Er hat nie ein brauchbares Bild geliefert, und die Aufnahmen, auf
die es ankommt, kann ein Simulator ohnehin nicht zeigen — die
Dokumentenkamera hat er nicht, den Beamer auch nicht.

So geht es:

1. Auf dem iPad eine Tafel schön einrichten (Zufallsname mit gezogenem
   Namen, Timer, Uhr, Tagesablauf …).
2. Bildschirmfoto machen — beim iPad ohne Knopf: Ein-/Aus-Taste und
   Lauter-Taste kurz zusammen.
3. Dasselbe auf dem iPhone, oder die iPad-Bilder für beide Felder nehmen,
   solange die Maße stimmen.

Apple nimmt auch Simulatoraufnahmen an (`⌘S` im Simulator), falls ein
Gerät der geforderten Größe gerade fehlt.

### Angaben zum Datenschutz („App Privacy")

Auf die Frage „Erfasst diese App Daten?" lautet die Antwort:

> **Nein, wir erfassen keine Daten aus dieser App.**

Begründung, falls die Prüfung nachfragt: Kamera-, Mikrofon- und
Fotozugriffe finden ausschließlich auf dem Gerät statt. Der Abgleich läuft
über CloudKit im Container der App; die Datensätze sind an die iCloud-Kennung
der Nutzerin gebunden, der Entwickler hat keinen Zugriff darauf und erhält
keine Kopie. Ein Konto beim Entwickler gibt es nicht.

### Export-Compliance

`ITSAppUsesNonExemptEncryption = NO` steht in der Info.plist — die Frage
entfällt bei jedem Upload.

### Prüfhinweise für Apple („App Review Information")

```
Die App braucht kein Konto. Beim ersten Start steht eine Beispieltafel
bereit; alle Funktionen sind sofort erreichbar.

Kamera: Element „Dokumentenkamera" aus der Leiste unten (Bearbeiten →
Dokumentenkamera). Zeigt das Livebild, ein Tipp friert es ein.

Mikrofon: Element „Lautstärke". Misst nur den Pegel, nimmt nichts auf.

iCloud: Der Abgleich läuft über CloudKit im öffentlichen Bereich des
eigenen Containers, ohne Nutzerkonto beim Entwickler. Er lässt sich in den
Einstellungen abschalten.
```

## Vor dem Hochladen prüfen

1. In Xcode das Ziel auf „Any iOS Device" stellen, `Product → Archive`.
2. Im Organizer „Distribute App" → „App Store Connect".
3. Version und Build: `MARKETING_VERSION` steht im Projekt, die Build-Nummer
   vergibt die Bauphase „Build-Nummer setzen" automatisch.
4. Nach dem Upload in App Store Connect die oben genannten Felder füllen und
   zur Prüfung einreichen.
