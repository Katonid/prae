# App-Konfiguration für Jamf School

Damit auf 30 iPads niemand einen Code abtippen muss.

iOS legt eine von der Geräteverwaltung mitgegebene Konfiguration unter
`UserDefaults`-Schlüssel `com.apple.configuration.managed` ab. Die App liest
sie beim Start (`Alarm/Services/ManagedAppConfiguration.swift`); ist ein Code
darin, fragt sie nur noch nach dem Kürzel.

## Wo das eingetragen wird

Jamf School → **Apps** → die App auswählen → Reiter **App-Konfiguration** →
Inhalt einfügen → sichern → auf die Gerätegruppe anwenden.

## Zum Kopieren

```xml
<dict>
    <key>schoolName</key>
    <string>Grundschule Musterstadt</string>
    <key>groupInviteCode</key>
    <string>K7QX2M</string>
    <key>displayNameHint</key>
    <string></string>
</dict>
```

## Die drei Schlüssel

| Schlüssel | Pflicht | Bedeutung |
|---|---|---|
| `schoolName` | nein | Steht auf dem Anmeldebildschirm, damit sichtbar ist, dass die Verwaltung mitgeredet hat. |
| `groupInviteCode` | nein | Der sechsstellige Beitrittscode aus der App (Verwaltung → Beitrittscodes). Das Feld ist danach im Anmeldebildschirm gesperrt. |
| `displayNameHint` | nein | Vorschlag für das Kürzel. Nur sinnvoll, wenn Jamf School je Gerät eine andere Konfiguration ausrollt — sonst leer lassen. |

Alle drei sind Text. Die App schneidet Leerzeichen ab und schreibt den Code
groß; sie **rät nicht**: Eine getippte `0` wird nicht zu einem `O`. Im Code
kommen I, O, 0 und 1 gar nicht vor.

## Je Gerät ein eigenes Kürzel

Wer in Jamf School Variablen einsetzt, kann `displayNameHint` je Gerät
belegen — etwa mit dem Gerätenamen:

```xml
<key>displayNameHint</key>
<string>%DeviceName%</string>
```

Ob eine Variable zur Verfügung steht und wie sie heißt, entscheidet Jamf
School; die App nimmt jeden Text entgegen. Ein Kürzel ist trotzdem besser als
ein Gerätename: In der Rückmeldeliste steht „MÜ" schneller gelesen da als
„iPad-Kollegium-14".

## Was danach zu prüfen ist

1. Ein iPad neu einrichten lassen und die App öffnen: Es darf **nur** noch
   nach dem Kürzel fragen.
2. In der App: Einstellungen → Einsatzbereitschaft. Alle Punkte grün.
3. Selbsttest auslösen und abwarten, bis er hörbar ankommt.

Erst dann gilt das Gerät als eingerichtet — nicht schon, wenn die App
installiert ist.

## Wenn der Code später gewechselt wird

Ein zurückgezogener Code (Verwaltung → Beitrittscodes → „Zurückziehen")
sperrt keine Geräte aus, die bereits beigetreten sind — er verhindert nur
neue Beitritte. Wer den Code in der App-Konfiguration austauscht, muss also
nichts weiter tun; die vorhandenen Geräte laufen weiter.
