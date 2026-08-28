# Schriften

Dieselben Schriften wie in der Web-App „Klassenraum". Alle vier haben
ein „einstöckiges" a und g — ein rundes a mit Strich, so wie Kinder es
in der Grundschule schreiben lernen. Die Systemschrift des Geräts zeigt
dagegen das gedruckte a mit Bogen, das Leseanfänger verwirrt.

| Schrift   | Herkunft                                  | Lizenz |
|-----------|-------------------------------------------|--------|
| Lexend    | https://fonts.google.com/specimen/Lexend    | SIL Open Font License 1.1 |
| Andika    | https://fonts.google.com/specimen/Andika    | SIL Open Font License 1.1 |
| Quicksand | https://fonts.google.com/specimen/Quicksand | SIL Open Font License 1.1 |
| Poppins   | https://fonts.google.com/specimen/Poppins   | SIL Open Font License 1.1 |

Die Dateien liegen im App-Bündel und werden nie nachgeladen — die App
läuft vollständig ohne Netz.

**Nicht von Hand pflegen:** Der Arbeitsablauf
`.github/workflows/tafelbild-schriften.yml` holt sie. Kommt eine
Schrift dazu, gehört sie dort hinein, in `KlassenraumiOS/Config/Info.plist`
(`UIAppFonts`) und in `KlassenraumiOS/Klassenraum/Views/Schriften.swift`.
