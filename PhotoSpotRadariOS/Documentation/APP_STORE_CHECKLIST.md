# App-Store- und Release-Checkliste

1. Bundle Identifier, Signing Team und Background-Task-Identifier angleichen.
2. Capability **Background Modes → Background fetch** aktivieren. Der Location-Background-Mode bleibt bewusst aus, weil Significant Changes, Visits und Region Monitoring mit „Immer“-Autorisierung den System-Relaunch verwenden und keine kontinuierlichen Updates laufen.
3. Standortberechtigungen stufenweise erklären: zuerst „Beim Verwenden“, danach mit eigener Erläuterung „Immer“.
4. Mitteilungsberechtigung erst nach einer verständlichen In-App-Erklärung anfragen.
5. Privacy Nutrition Label für präzisen Standort und Netzwerkzugriffe ausfüllen; keine Tracking-Deklaration ohne tatsächliches Tracking.
6. OpenStreetMap-Attribution sowie Lizenz-/Urheberhinweise für Bilder in einer sichtbaren Quellenansicht ergänzen.
7. Echten, identifizierbaren Overpass-User-Agent konfigurieren und öffentliche Instanzen nicht mit großflächigen Abfragen belasten.
8. Auf realen Geräten testen: Fahren, Wandern, schlechter Empfang, Low Power Mode, Background App Refresh aus, Force-Quit und verweigerte Berechtigungen.
9. Instruments verwenden: Energy Log, Network und SwiftData-Store-Wachstum.
10. Benachrichtigungstexte lokalisieren und Datenschutztexte durch Legal Review prüfen lassen.
11. Xcodes Privacy Report erzeugen und `PrivacyInfo.xcprivacy` gegen den tatsächlichen Build sowie App Store Connect abgleichen.
