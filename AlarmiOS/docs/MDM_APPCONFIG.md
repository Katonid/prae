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

## „Die App soll im Alarmfall vorne sein"

Das ist der häufigste Wunsch, und die ehrliche Antwort steht zuerst:

**Keine iOS-App kann sich selbst in den Vordergrund holen.** Es gibt dafür
keine Schnittstelle — nicht mit kritischen Hinweisen, nicht mit einer
Custom-App-Verteilung, nicht über das MDM. Ein Push kann eine App weder
starten noch nach vorn bringen. Was auf dem Bildschirm liegt, entscheidet die
Person am Gerät; das ist eine Grundentscheidung von iOS und keine fehlende
Berechtigung.

Was tatsächlich nach vorn kommt, ist die **Mitteilung**: zeitkritisch, mit
eigenem Ton, auf dem Sperrbildschirm, mit den Rückmeldeknöpfen darin. Ein Tipp
öffnet die App direkt auf dem Alarm-Bildschirm.

Zwei Stellschrauben liegen beim MDM, und beide gehören ins
Konfigurationsprofil, nicht in die App:

1. **Mitteilungen vorschreiben.** Ein `com.apple.notificationsettings`-Payload
   für `de.dboschule.alarm` mit erlaubten Mitteilungen, Ton an, Sperrbildschirm
   an, Vorschau nach Vorgabe des Krisenteams, `CriticalAlertEnabled` sobald
   Apple die Berechtigung erteilt hat. Damit kann niemand die Mitteilungen
   versehentlich abschalten — und genau das ist der wahrscheinlichste Grund
   für ein stummes iPad.
2. **Fokus-Ausnahme und Lautlos** bleiben Sache des Geräts. Ohne kritische
   Hinweise bleibt ein stumm geschaltetes iPad stumm; das ist der Grund für
   den Antrag in `CRITICAL_ALERTS_ANTRAG.md`.

**Einzel-App-Modus (Single App Mode)** ist der einzige Weg, ein iPad dauerhaft
auf diese App festzunageln. Das ergibt Sinn für ein festes Gerät — Sekretariat,
Lehrerzimmer, Hausmeisterei —, das sonst nichts tut. Für das Arbeits-iPad einer
Lehrkraft ergibt es keinen Sinn: Es wird den ganzen Tag für Unterricht
gebraucht, und ein Gerät, das nichts anderes kann, liegt am Ende im Schrank —
und ein iPad im Schrank ist im Ernstfall genau so nützlich wie gar keins.
