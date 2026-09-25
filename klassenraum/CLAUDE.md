# Projekt Klassenraum (Web-App)

> Ausgelagert aus der `CLAUDE.md` im Wurzelverzeichnis (09/2026). Die
> übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen weiterhin dort und gelten hier genauso.


- Code: `klassenraum/` — statische Web-App ohne Build-Schritt (ES-Module,
  kein Framework), wird vom bestehenden GitHub-Pages-Workflow mit
  ausgeliefert: https://katonid.github.io/prae/klassenraum/
- GitHub Pages läuft für dieses Repo über „GitHub Actions" (Workflow
  `pages.yml`). Der Workflow spiegelt `docs/` zusätzlich an die Wurzel,
  damit die alten Adressen `/soundboard/` (App-Store-Links) und
  `/flightmate-ai/` gültig bleiben — diese Zeile nicht entfernen.
- Ersetzt den kostenpflichtigen Dienst „Classroomscreen“: Zufallsnamen,
  Timer/Stoppuhr, Uhr, Ampel, Tagesablauf, Text, Bild, Lautstärkemesser,
  Arbeitssymbole — frei verschiebbar auf einer Tafelfläche.
- Alles liegt lokal (IndexedDB). Es geht nur dann etwas ins Netz, wenn ein
  Teilen-Code erstellt oder ein Konto genutzt wird.
- Cloud läuft über die REST-Schnittstellen von Firebase (Realtime Database
  + Identity Toolkit) mit `firebase-config.js` aus dem Wurzelverzeichnis —
  kein SDK laden, das bricht den Offline-Betrieb.
- Drei Cloud-Wege, die nicht vermischt werden dürfen: **Teilen** (ein Board
  unter `klassenraum/shares/<CODE>`), **Abgleich** (alle Boards und Listen als
  Einzeldatensätze unter `klassenraum/spaces/<Kennung>`, Klang-/Videodateien
  base64-kodiert unter `klassenraum/media/<Kennung>/<Datei-Id>` — bewusst
  NEBEN dem Bereich, damit der volle Bereichsabruf sie nicht mitlädt;
  `js/sync.js`) und **Konto/Sicherung** (`klassenraum/users/<uid>`). Der Abgleich führt pro
  Datensatz nach Zeitstempel zusammen („neuer gewinnt") und schickt
  Löschvermerke mit; die letzte verbliebene Tafel wird nie gelöscht.
- `klassenraum/firebase-rules.json` enthält die empfohlenen Datenbankregeln
  (kein Auflisten von `shares`/`spaces`/`links`). Sie müssen in der
  Firebase-Konsole eingefügt werden — Standard ist offen.
- Konten brauchen eine einmalige Freischaltung in der Firebase-Konsole
  (Authentication → E-Mail/Passwort). Ohne sie zeigt die App einen Hinweis;
  Teilen per Code funktioniert trotzdem.
- Die App-Icons erzeugt `klassenraum/scripts/generate-icons.py` — nicht von
  Hand bearbeiten.
- Schriften liegen als woff2 in `klassenraum/fonts/` und werden über
  `css/fonts.css` eingebunden — **nie** von Google-Servern nachladen (bricht
  Offline-Betrieb). Ausgewählt sind nur Schriften mit einstöckigem a/g
  (Grundschulform); Vorgabe ist Lexend, Auswahl in `js/fonts.js`.
