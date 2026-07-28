# 💱 CAD USD EUR – native iOS-App

Vollständig eigenständige, native Neuentwicklung der Reise-Währungsrechner-PWA
(jerosch.net/apps/cad) für iPhone und iPad – geschrieben in Swift und SwiftUI,
ohne Web-Anteile und ohne Fremdbibliotheken. Die bestehende PWA bleibt
unverändert.

## Funktionsumfang (wie die PWA)

- **Zwei Länder-Modi:** Kanada (CAD) und USA (USD), umschaltbar über den
  Pillen-Schalter oben; der komplette Seitenhintergrund wechselt mit
  (Kanada-Flaggenbänder bzw. Stars-and-Stripes-Optik)
- **Tageskurs:** Live-Abruf von frankfurter.dev (EZB-Daten) mit
  Plausibilitätsprüfung; ohne Netz wird ehrlich „Offline: Ersatzkurs wird
  verwendet" angezeigt (Ersatzkurse 0,67 bzw. 0,92)
- **Vier verkettete Betragsfelder:** Landeswährung netto, Euro netto,
  Preis inkl. Steuer, Endpreis in Euro inkl. Steuer – jedes Feld ist
  bearbeitbar, alle anderen rechnen sofort mit; deutsche und englische
  Dezimalschreibweise werden toleriert (Komma/Punkt/Tausenderpunkte)
- **Kanada-Steuer:** Ontario (13 % HST) und Quebec (14,975 % = 5 % GST +
  9,975 % QST) per Knopf oder automatisch über den Standort
- **US Sales Tax:** Stadtfeld mit sofortiger Erkennung der voreingestellten
  Städte (Buffalo 8,75 %, Niagara Falls 8 %, Detroit 6 %, Cleveland 8 %),
  vollständige County-Tabelle für den Bundesstaat New York (NY Publication
  718, Stand März 2025 – z. B. Erie 8,75 %, Niagara 8 %, Warren/Glens
  Falls 7 %, New York City 8,875 %), Bundesstaaten-Basissätze für alle
  übrigen Staaten, Online-Ortssuche (Apple Geocoder statt Nominatim) sowie
  manuelles Tax-%-Feld (0–15 %)
- **Standort-Knopf:** bestimmt in Kanada die Provinz, in den USA den
  Steuersatz ortsabhängig (bekannte Stadt → NY-County → Basissatz des
  Bundesstaats); außerhalb von Kanada/USA gibt es einen ehrlichen Hinweis
- **Schnellwerte:** $100 / $500 / $1000 / $3000
- **Merken des Zustands:** Land, Stadt, Provinz, Steuersatz und zuletzt
  bearbeitetes Feld bleiben wie im localStorage der PWA erhalten
  (UserDefaults, gleiche Feldnamen)

## Design

Farben, Verläufe, Karten- und Feld-Layout sind 1:1 aus dem Stylesheet der
PWA übernommen. Das Ahornblatt in Flagge und App-Icon ist das offizielle
elfzackige Blatt der kanadischen Nationalflagge (Kontur aus dem amtlichen
Flaggen-SVG übernommen); alle Flaggen werden ohne Bilddateien direkt
gezeichnet.

## Technik

- Swift/SwiftUI, iOS 17, keine externen Abhängigkeiten
- Standort nur auf Knopfdruck (When-in-Use), Datenminimierung wie gehabt
- Xcode-Projekt: `CadUsdEur.xcodeproj` öffnen, Team wählen, auf das Gerät
  bauen – fertig
