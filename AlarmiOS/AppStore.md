# Schulalarm im App Store Connect

Die App geht **nicht** in den öffentlichen App Store. Sie wird als **Custom
App** über Apple School Manager an eine einzelne Schule verteilt. Was
trotzdem in App Store Connect ausgefüllt werden muss:

## Der App-Eintrag wird VON HAND angelegt

**Nicht über Xcodes „Create App Record"** im Distribute-Ablauf. Xcode schlägt
dort den Anzeigenamen vor, und `Schulalarm` ist im App Store bereits vergeben
— der Versuch endet mit „App Record Creation failed due to request containing
an attribute already in use" (gemeldet 09/2026, derselbe Fehler wie zuvor bei
Anstoß). App-Namen sind bei Apple **weltweit eindeutig, auch für Custom
Apps**, die nie im öffentlichen Laden auftauchen.

Also: App Store Connect → Meine Apps → **+** → Neue App, mit einem freien
Namen. Steht der Eintrag, lädt „Distribute App" über die Bundle-Id in ihn
hinein und fragt nicht mehr nach einem Namen. Der fertige Archiv-Eintrag muss
dafür **nicht** neu gebaut werden.

* **Name im Store:** `Schulalarm - Der Warnmelder` (27 Zeichen, Grenze 30) —
  vergeben 09/2026, nachdem `Schulalarm` allein abgelehnt wurde. Ob ein Name
  frei ist, sagt erst das Feld in App Store Connect — nicht raten, eintippen.
* **Untertitel:** `Alarm für das Kollegium` (23 Zeichen, Grenze 30)
* **Bundle-ID:** `de.dboschule.alarm` (aus der Liste wählen)
* **Primärsprache:** Deutsch
* **SKU:** frei wählbar, z. B. `dboschule-alarm-001`
* **Primäre Kategorie:** Bildung
* **Vertrieb:** Custom App — Organisation über die Organisations-ID aus
  Apple School Manager freischalten (ASM → Einstellungen →
  Registrierungsinformationen).

**Auf dem Homescreen heißt die App weiterhin `Schulalarm`**
(`INFOPLIST_KEY_CFBundleDisplayName`). Store-Name und Anzeigename sind
getrennte Felder und dürfen auseinandergehen; iOS schneidet unter dem Symbol
ohnehin nach rund zwölf Zeichen ab. Am Projekt ändert der Store-Name nichts —
Ordner, Ziel, Bundle-Id und iCloud-Container bleiben, wie sie sind.

## Altersfreigabe

4+. Kein nutzergenerierter Inhalt im Sinne der Fragebögen (der Chat läuft
innerhalb eines geschlossenen Kollegiums von 30 Personen und ist an einen
laufenden Alarm gebunden), keine Werbung, keine Käufe.

## Export-Compliance

`ITSAppUsesNonExemptEncryption = NO` steht in beiden Info.plists und als
Build-Einstellung. App Store Connect fragt deshalb bei keinem Build nach.

## Datenschutzangaben (App Privacy)

| Datenart | Verknüpft | Tracking | Zweck |
|---|---|---|---|
| Nutzer-ID (iCloud-Kennung) | ja | nein | App-Funktionalität |
| Andere Nutzerinhalte (Kürzel, Rückmeldungen, Nachrichten) | ja | nein | App-Funktionalität |

Nichts weiter. Kein Standort, keine Kontakte, keine Kennungen für Werbung,
keine Nutzungsdaten, keine Diagnose. Deckungsgleich mit
`Alarm/PrivacyInfo.xcprivacy`.

## Review-Hinweise

Vollständiger Text in `docs/APP_REVIEW_NOTES.md`. **Vor dem Einreichen den
Testcode einsetzen** — in der App unter Verwaltung → Beitrittscodes einen
frischen Code mit der Notiz „App Review" erzeugen und ihn nach der Prüfung
zurückziehen.

## Vor jedem Upload

1. `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` an allen **vier**
   Stellen im pbxproj um eins heben (App Debug+Release, Erweiterung
   Debug+Release). Beide Ziele müssen dieselbe Nummer tragen, sonst weist
   App Store Connect das Paket ab.
2. Bau in GitHub Actions abwarten, bis er grün ist.
3. Archivieren und hochladen.
