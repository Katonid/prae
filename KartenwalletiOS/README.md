# 💳 Kartenwallet — native iOS-App

Eigene Karten in die **Apple Wallet** legen: QR-Codes und Barcodes für
Berechtigungen, Mitgliedschaften und Kundenkarten — oder einfach das
**Foto einer Kundenkarte** als sichtbares Bild auf einem Wallet-Pass.

Alles passiert direkt auf dem iPhone: Die App erzeugt vollwertige
`.pkpass`-Dateien (pass.json, Manifest, PKCS#7-Signatur, ZIP) **ohne
Server und ohne externe Bibliotheken** und übergibt sie an den
systemeigenen „Zu Apple Wallet hinzufügen"-Dialog.

## Was die App kann

- **QR-/Barcode-Karten:** Code eintippen, **live mit der Kamera scannen**
  oder aus einem Foto erkennen lassen (QR, Aztec, Code 128, PDF417;
  Handelsformate wie EAN-13 werden automatisch als Code 128 übernommen —
  gleicher Zahlencode, an Kassen in aller Regel lesbar).
- **Foto-Karten:** Foto der physischen Karte auswählen — es erscheint als
  Bild direkt auf dem Wallet-Pass (Streifenbild), optional zusätzlich mit
  Barcode.
- **Gestaltung:** Passfarbe frei wählbar, Name/Zusatz/Kartennummer als
  Felder, Notizen auf der Passrückseite. Text weiß oder schwarz — je
  nachdem, was auf der gewählten Farbe lesbar ist.
- **Darstellung in der Wallet, pro Karte wählbar:** „Einzeln" (eigene
  Kachel, Standard), „Eigener Stapel" (Karten mit demselben Stapel-Namen
  liegen als eine Kachel übereinander — antippen und durchblättern)
  oder „Bei allen anderen" (ein großer Stapel). Technisch:
  Event-Ticket-Layout mit `groupingIdentifier` — eigener Wert pro Karte
  = einzeln, gleicher Wert = gemeinsamer Stapel; Wallet stapelt sonst
  alles mit derselben Pass-Type-ID. Welche Karte ein Stapel als Kachel
  zeigt, entscheidet iOS.
- **Verwalten & Teilen:** Karten bearbeiten (erneutes Hinzufügen ersetzt
  den Pass in der Wallet — gleiche Seriennummer), löschen,
  `.pkpass`-Datei teilen. Geteilte Pässe kann **jeder** direkt in seine
  Wallet legen — Zertifikat und Developer-Konto braucht nur, wer Pässe
  erstellt, nicht wer sie empfängt.
- **Pass-Dateien empfangen:** Die App ist als Öffnen-mit-Ziel für
  `.pkpass` registriert („Öffnen mit Kartenwallet" bzw. Teilen-Menü) und
  hat einen Import-Knopf (+ → „Pass-Datei öffnen") — praktisch, wenn
  eine andere App den Dateityp an sich gerissen hat. Importierte Pässe
  landen direkt im Wallet-Dialog.
- **iPad:** iPads haben keine Apple Wallet — dort erzeugt die App die
  Pass-Datei zum Teilen an ein iPhone, und die Detailansicht zeigt den
  Barcode groß zum direkten Vorzeigen.
- **Datenminimierung:** Karten, Fotos und Zertifikat bleiben auf dem
  Gerät (Zertifikat im Schlüsselbund). Kein Server, kein Konto, keine
  Analyse. Einzige Netzverbindung: das öffentliche
  Apple-WWDR-Zwischenzertifikat wird einmalig von apple.com geladen.

## Einmalige Voraussetzung: Pass-Type-ID-Zertifikat

Apple lässt nur **signierte** Pässe in die Wallet. Jeder Pass muss mit
einem Pass-Type-ID-Zertifikat signiert sein — das ist Apples
Sicherheitsmodell und gilt für jede App. Deshalb einmalig:

1. Mitgliedschaft im **Apple Developer Program** (developer.apple.com,
   99 USD/Jahr — dieselbe, die man auch zum Installieren eigener Apps
   aufs iPhone über ein Jahr hinaus braucht).
2. Auf developer.apple.com unter *Certificates, Identifiers & Profiles →
   Identifiers* eine neue **Pass Type ID** anlegen
   (z. B. `pass.de.familie.kartenwallet`).
3. Für diese Pass Type ID ein **Zertifikat** erstellen (den Certificate
   Signing Request erzeugt die Schlüsselbundverwaltung am Mac:
   *Zertifikatsassistent → Zertifikat einer Zertifizierungsinstanz
   anfordern*).
4. Das Zertifikat am Mac in die Schlüsselbundverwaltung laden, dort
   **Zertifikat samt privatem Schlüssel** markieren und als **.p12** mit
   Passwort exportieren.
5. Die .p12 aufs iPhone bringen (iCloud Drive/AirDrop) und in der App
   unter *Einstellungen → Zertifikat importieren* einlesen.

Die App liest Pass-Type-ID, Team-ID und Organisation automatisch aus dem
Zertifikat — nichts muss abgetippt werden. Ab dann werden alle Pässe
direkt auf dem Gerät signiert.

## Technik

- Swift/SwiftUI, iOS 17, keine externen Abhängigkeiten.
- `PassBuilder` baut pass.json (Store-Card-Layout), Icons und
  Streifenbilder; `manifest.json` mit SHA-1-Hashes.
- `CMSSigner` erzeugt die abgetrennte PKCS#7-Signatur in DER von Hand
  (eigener minimaler ASN.1-Encoder), signiert wird per
  `SecKeyCreateSignature` (RSA-SHA256) mit der Identität aus dem
  Schlüsselbund; das WWDR-Zwischenzertifikat wird mit eingebettet.
- `ZipWriter` schreibt das unkomprimierte ZIP (`.pkpass`).
- Scannen: VisionKit `DataScannerViewController` (live) und Vision
  `VNDetectBarcodesRequest` (aus Fotos).

## Projekt öffnen

`KartenwalletiOS/Kartenwallet.xcodeproj` in Xcode öffnen, Team fürs
Code-Signing wählen, auf dem iPhone ausführen. In den Target-Einstellungen
ist die Wallet-Capability bereits hinterlegt
(`com.apple.developer.pass-type-identifiers`).
