# 📧 Mailsortierer für Synology DiskStation

Eine kleine, selbst gehostete App für den **Synology Container Manager**, die
Mails aus mehreren Mailkonten per IMAP abruft, nach frei konfigurierbaren
Regeln sortiert und auf Wunsch Abwesenheitsnotizen verschickt.

**Typischer Anwendungsfall:** Während des Urlaubs sollen Mails bestimmter
Absender automatisch in einen Ordner „Nach-dem-Urlaub" verschoben werden, und
der Absender erhält eine Abwesenheitsnotiz – konfigurierbar für beliebig viele
Mailkonten und Absenderadressen.

## Funktionen

- **Mehrere Mailkonten** (IMAP zum Abrufen, SMTP zum Versenden der Notizen)
- **Filterregeln pro Konto:** Absenderadresse (exakt oder mit Platzhalter wie
  `*@firma.de`) → Zielordner. Der Zielordner wird bei Bedarf automatisch im
  Postfach angelegt.
- **Abwesenheitsnotiz pro Regel:** Betreff und Text frei konfigurierbar.
  Eine Sperrfrist (Standard: 7 Tage) verhindert, dass derselbe Absender bei
  jeder Mail erneut eine Notiz erhält. Automatische Mails (Newsletter,
  Mailinglisten, `noreply@…`) erhalten grundsätzlich keine Antwort.
- **Webinterface** (deutsch) zum Verwalten von Konten, Regeln und
  Einstellungen, inklusive Verbindungstest und Aktivitätsprotokoll.
- **Regelmäßiger Abruf** im einstellbaren Intervall (Standard: 5 Minuten)
  plus Button „Jetzt prüfen".
- Die Mails werden **direkt auf dem Mailserver** verschoben (IMAP MOVE) –
  Handy und andere Mailprogramme sehen die Sortierung also ebenfalls.

## Installation auf der Synology DiskStation

Voraussetzung: DSM 7.2 oder neuer mit installiertem Paket **Container Manager**.

1. Den kompletten Ordner `mail-filter` auf die DiskStation kopieren, z. B.
   über File Station in den freigegebenen Ordner `docker`
   (also `docker/mail-filter`).
2. **Container Manager** öffnen → **Projekt** → **Erstellen**.
3. Als Projektpfad den Ordner `docker/mail-filter` wählen. Der Container
   Manager erkennt die vorhandene `docker-compose.yml` automatisch –
   „Vorhandene docker-compose.yml verwenden" auswählen.
4. Vor dem Start in der angezeigten `docker-compose.yml` das
   `ADMIN_PASSWORD` ändern (und bei Bedarf den Port `8385` anpassen).
5. Projekt erstellen und starten. Beim ersten Start baut die DiskStation das
   Container-Image selbst – das dauert ein paar Minuten.
6. Das Webinterface ist danach erreichbar unter:
   `http://<IP-der-DiskStation>:8385`
   (Anmeldung mit `admin` und dem gesetzten `ADMIN_PASSWORD`.)

Alle Einstellungen liegen in `mail-filter/data/mailsortierer.db` und bleiben
bei Updates und Neustarts des Containers erhalten.

## Einrichtung

1. **Konten** → „Konto hinzufügen": IMAP-Zugangsdaten des Mailkontos
   eintragen (z. B. `imap.gmx.net`, Port 993, SSL/TLS). Für
   Abwesenheitsnotizen zusätzlich den SMTP-Server angeben (z. B.
   `mail.gmx.net`, Port 587, STARTTLS). Mit „Verbindung testen" prüfen.
   - Bei vielen Anbietern (GMX, Web.de, Gmail, …) muss IMAP im Mailkonto
     erst freigeschaltet werden; Gmail und andere verlangen ein
     **App-Passwort** statt des normalen Passworts.
2. **Regeln** → „Regel hinzufügen": Konto wählen, Absender-Muster und
   Zielordner eintragen. Optional „Abwesenheitsnotiz an den Absender senden"
   aktivieren und Betreff/Text der Notiz eingeben.
3. **Einstellungen:** Abrufintervall und Sperrfrist für Notizen anpassen.
4. Im **Protokoll** ist nachvollziehbar, welche Mails verschoben und welche
   Notizen versendet wurden.

## Funktionsweise

- Die App prüft zyklisch den **Posteingang** jedes aktiven Kontos (nur
  Kopfzeilen, Inhalte werden nicht gelesen) und wendet die Regeln der Reihe
  nach an – die erste passende Regel gewinnt.
- Bei einem Treffer wird ggf. zuerst die Abwesenheitsnotiz versendet und die
  Mail anschließend in den Zielordner verschoben. Der Gelesen-Status bleibt
  unverändert.
- Nicht passende Mails bleiben unangetastet im Posteingang.

## Hinweise zur Sicherheit

- Die Mail-Passwörter werden unverschlüsselt in der SQLite-Datenbank im
  `data`-Ordner gespeichert. Den Ordner daher nur für berechtigte
  DSM-Benutzer freigeben.
- Die App ist für den Betrieb im **Heimnetz** gedacht. Wer sie über das
  Internet erreichbar machen will, sollte sie hinter den Reverse-Proxy der
  DiskStation mit HTTPS legen.
- `ADMIN_PASSWORD` unbedingt setzen – ohne Passwort ist das Webinterface
  ungeschützt (die App schreibt dann eine Warnung ins Protokoll).

## Technik

- Python 3.12, [FastAPI](https://fastapi.tiangolo.com/) und
  [imap-tools](https://github.com/ikvk/imap_tools)
- SQLite für Konfiguration und Protokolle (im Volume `/data`)
- Frontend: statisches HTML/CSS/JavaScript ohne Build-Schritt
