# Kontaktwandler

Wandelt eine Excel-Tabelle mit **Namen** und **E-Mail-Adressen** in eine
**LDIF-Datei** um — das Format, mit dem Thunderbird (und viele andere
Adressbücher und Verzeichnisdienste) Kontakte einliest.

Adresse: https://katonid.github.io/prae/kontaktwandler/

## Was hineingeht

| Vorname | Nachname | E-Mail |
| --- | --- | --- |
| Anna | Müller | anna.mueller@example.org |
| Jörg | Weiß | j.weiss@example.org |

- **.xlsx** (jedes Blatt wählbar), **.csv** (Semikolon, Komma oder Tabulator;
  UTF-8 oder Windows-1252) — oder Zellen aus Excel kopieren und einfügen.
- Die Spalten werden an der Überschrift erkannt (Vorname, Nachname, Name,
  E-Mail, E-Mail 2, Telefon, Handy, Firma, Bemerkung …) und lassen sich in
  der Oberfläche umstellen. Ohne Überschrift wird die E-Mail-Spalte am Inhalt
  erkannt.
- Eine einzige Namensspalte mit `Müller, Anna` ergibt Vor- und Nachname.
- Zwei Adressen in einer Zelle oder zwei Mailspalten ergeben einen Kontakt
  mit zweiter Adresse (`mozillaSecondEmail`).
- Zeilen ohne gültige Adresse und doppelte Adressen werden **nicht still
  verschluckt**, sondern unter „Nicht übernommen" aufgelistet.

## Was herauskommt

Je Kontakt ein Eintrag wie in Thunderbirds eigener Ausgabe:

```
dn: cn=John Smith\, Jr.,mail=john@example.com
objectclass: top
objectclass: person
objectclass: organizationalPerson
objectclass: inetOrgPerson
objectclass: mozillaAbPersonAlpha
givenName: John
sn: Smith, Jr.
cn: John Smith, Jr.
mail: john@example.com
```

Werte mit Umlauten stehen Base64-verschlüsselt (`sn:: TcO8bGxlcg==`), so
verlangt es RFC 2849. Auf Wunsch kommt am Ende eine **Verteilerliste**
(`groupOfNames`) mit allen Kontakten dazu.

## Ins Adressbuch

- **Thunderbird:** Extras → Importieren → Adressbücher → Datei → LDIF.
- **Mac (Kontakte):** Ablage → Importieren.

## Aufbau

Statische Web-App ohne Bauschritt und ohne fremde Bibliothek.

| Datei | Aufgabe |
| --- | --- |
| `js/zip.js`, `js/xml.js`, `js/xlsx.js` | xlsx-Leser, übernommen aus dem Terminkonverter |
| `js/kontakte.js` | Spalten erkennen, Zeilen zu Kontakten |
| `js/ldif.js` | LDIF schreiben (Base64, DN-Maskierung, Falten) |
| `js/app.js` | Oberfläche |
| `sw.js`, `manifest.webmanifest`, `icons/` | installierbar und offline |
| `scripts/generate-icons.py` | rechnet die Icons |
| `scripts/einzeldatei.py` | baut `einzeldatei.html` (alles in einer Datei, für `file://`) |
