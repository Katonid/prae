# Der Push-Vertrag

Dies ist die Schnittstelle, an der die Zustellung hängt. Wer diese App auf
eine andere Gegenstelle umstellt — Firebase, ein eigener APNs-Server, später
FCM für Android —, muss genau dieses Paket erzeugen. Alles andere in der App
bleibt dann unverändert.

Gelesen wird der Vertrag an einer einzigen Stelle:
`Shared/PushPayloadParser.swift`. Die Schlüsselnamen stehen in
`Shared/PushContract.swift`.

## Das neutrale Format

Die eigenen Felder stehen **auf oberster Ebene** von `userInfo`, neben `aps`.
Das ist die einzige Stelle, auf die sich APNs, FCM und ein
selbstgeschriebener Sender gleichermaßen einigen.

```json
{
  "aps": {
    "alert": { "title": "AMOKALARM – Aula", "body": "Ausgelöst von MÜ um 09:14" },
    "sound": "alarm.caf",
    "mutable-content": 1,
    "category": "ALARM",
    "interruption-level": "time-sensitive"
  },
  "event": "alarm",
  "alarmId": "0F3C1A7E-…",
  "type": "amok",
  "status": "active",
  "location": "Aula",
  "triggeredByName": "MÜ",
  "createdAt": "2026-09-01T09:14:02Z",
  "instruction": "Tür verschließen, Fenster meiden …",
  "groupId": "abc123",
  "targetUserId": null
}
```

### Felder

| Schlüssel | Pflicht | Werte |
|---|---|---|
| `event` | ja | `alarm`, `allClear`, `ping`, `selfTest` |
| `alarmId` | ja, außer bei `ping` | Kennung des Alarms, stabil über alle Pushes desselben Alarms |
| `type` | ja, außer bei `ping` | `amok`, `fire`, `medical`, `test` |
| `status` | nein | `active`, `cleared` |
| `location` | nein | Freitext |
| `triggeredByName` | nein | Kürzel, kein voller Name |
| `createdAt` | nein | **ISO 8601 als Text**, siehe unten |
| `instruction` | nein | Handlungstext, gekürzt auf 180 Zeichen |
| `groupId` | nein | Kennung der Gruppe |
| `targetUserId` | nein | gesetzt = nur dieses Gerät ist gemeint |
| `pingId` | nein | nur bei `ping` |

### Warum `createdAt` Text ist

Weil eine Zahl zwei Lesarten hat. CloudKit kodiert ein `Date`-Feld im Push
als nackte Zahl, und ob die ab 1970 oder ab Apples Bezugsdatum 2001 zählt,
steht nirgends verlässlich. Ein falscher Nullpunkt macht aus jedem Alarm
einen 31 Jahre alten — und die App **schaltet alte Alarme leise**
(`PushAsset.staleAfter`, drei Minuten). Der Fehler wäre also nicht sichtbar
falsch, sondern still stumm.

Der Leser nimmt trotzdem beide Zahlen an und rät den Nullpunkt an der
Größenordnung. Ein neuer Sender soll nicht daran scheitern; schreiben soll
er aber Text.

### Die drei `aps`-Felder, die zählen

* `"mutable-content": 1` — **ohne dies läuft die Notification Service
  Extension nicht**, und ohne die Erweiterung bleibt der Alarm auf
  `.active`: ein aktiver Fokus hält ihn zurück. Das ist der wichtigste
  Schlüssel im ganzen Paket.
* `"sound"` — `alarm.caf` oder `allclear.caf`. Beide liegen im App-Bündel
  **und** in der Erweiterung.
* `apns-collapse-id` (HTTP-Kopfzeile) auf die `alarmId` — sonst stapeln sich
  mehrere Zustellungen desselben Alarms als mehrere Banner.

Die Erweiterung setzt `interruptionLevel` selbst; das `aps`-Feld
`interruption-level` ist nur die Absicherung für den Fall, dass sie nicht
zum Zug kommt.

## Der stille Ping

```json
{ "aps": { "content-available": 1 }, "event": "ping", "groupId": "abc123" }
```

Kein `alert`, kein `sound`. Das Gerät schreibt daraufhin seinen
`DeviceStatus` fort. **Ein Alarm darf nie so aussehen** — stille Pushes
werden von iOS gedrosselt und im Stromsparmodus gar nicht zugestellt.

## Das CloudKit-Format

CloudKit baut sein Paket selbst; beeinflussen lässt sich nur, welche
Record-Felder mitreisen (`desiredKeys` der Subscription). Der Parser
versteht es zusätzlich:

```json
{
  "aps": { "…": "…" },
  "ck": {
    "qry": {
      "sid": "alarm-created-v1",
      "fo": 1,
      "rid": "0F3C1A7E-…",
      "af": { "type": "amok", "status": "active", "location": "Aula",
              "triggeredByName": "MÜ", "createdAt": "2026-09-01T09:14:02Z",
              "instructionShort": "Tür verschließen …", "headline": "AMOKALARM",
              "targetUser": "*", "groupRef": "abc123" }
    }
  }
}
```

* `sid` ist die Kennung der Subscription und entscheidet, was gemeint ist
  (`SubscriptionID` in `Shared/PushContract.swift`).
* `rid` ist der Name des Datensatzes und damit die `alarmId`.
* `af` sind die `desiredKeys`.

Die Erweiterung schreibt dieses Paket ins neutrale Format um
(`PushPayloadParser.normalized`) und setzt `normalized: true`. Die App
bekommt danach nie wieder ein `ck` zu sehen.

## Was ein neuer Sender liefern muss

1. Das neutrale Format oben, mit `mutable-content`.
2. Einen `apns-collapse-id`-Kopf je Alarm.
3. Für Android: dieselben Schlüssel als FCM-`data`-Nachricht mit
   `priority: high`. Die Ton- und Dringlichkeitsfrage ist dort eine andere
   (Notification Channels statt `interruptionLevel`) — die Datenfelder
   bleiben dieselben.

## Was sich nie ändern darf

`alarmId` und `type` sind die einzigen Pflichtfelder, weil eine Meldung ohne
sie nicht anzeigbar ist. **Jedes andere Feld darf fehlen** — und der Push
wird trotzdem gezeigt. Ein Alarm, den die App verwirft, weil eine Ortsangabe
fehlte, ist der schlimmste denkbare Fehler dieser App.
