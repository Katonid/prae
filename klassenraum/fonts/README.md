# Schriften

Alle Schriften liegen als `woff2` im Repo und werden von der App selbst
ausgeliefert — **nicht** von Google-Servern nachgeladen. Sonst würde der
Offline-Betrieb brechen, und jedes Öffnen der Tafel würde eine Anfrage an einen
fremden Server schicken.

Ausgewählt wurden ausschließlich Schriften mit **einstöckigem „a" und „g"**
(rundes a mit Strich), so wie Kinder in der Grundschule schreiben lernen —
aber ohne handschriftlichen Einschlag.

| Schrift | Fassung | Lizenz | Quelle |
| --- | --- | --- | --- |
| **Lexend** | variabel 100–900 | SIL Open Font License 1.1 | <https://fonts.google.com/specimen/Lexend> |
| **Quicksand** | variabel 300–700 | SIL Open Font License 1.1 | <https://fonts.google.com/specimen/Quicksand> |
| **Andika** | 400 und 700 | SIL Open Font License 1.1 | <https://fonts.google.com/specimen/Andika> |
| **Poppins** | 400 und 700 | SIL Open Font License 1.1 | <https://fonts.google.com/specimen/Poppins> |

Je Schrift liegen zwei Ausschnitte bereit: `latin` (deutsche Umlaute, ß,
Akzente) und `latin-ext` (z. B. ć, ş, ğ, ł für Namen aus anderen Sprachen).
Der Browser lädt nur, was er wirklich braucht.

Die Einbindung steht in `../css/fonts.css`, die Auswahl in `../js/fonts.js`.
Der Lizenztext der SIL Open Font License 1.1 steht unter
<https://openfontlicense.org/>.
