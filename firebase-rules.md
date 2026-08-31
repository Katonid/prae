# Datenbankregeln dieses Firebase-Projekts

Einzufügen ist **`firebase-rules.json`** aus diesem Verzeichnis:

> Firebase-Konsole → **Realtime Database** → Reiter **Regeln** → alles
> markieren, Inhalt hineinkopieren → **Veröffentlichen**

## Warum beide Web-Apps in einer Datei stehen

Die Konsole **ersetzt** beim Veröffentlichen die kompletten Regeln. Wer nur den
Zweig einer App einfügt, sperrt damit die andere aus.

Genau das ist im August 2026 passiert: Als die Wörterwerkstatt dazukam, wurde
ihr Zweig nie eingespielt. Die Datenbank wies dort jeden Lese- und
Schreibversuch mit `401 Permission denied` ab — es ließ sich keine Klasse
anlegen und kein Kind beitreten, während der Klassenraum weiterlief. Deshalb
gibt es jetzt genau **eine** Datei zum Einfügen.

`klassenraum/firebase-rules.json` und `woerterwerkstatt/firebase-rules.json`
sind nur noch Einzelfassungen zum Nachschlagen.

## Warum in der JSON-Datei keine Kommentare stehen

Sie ist zum Kopieren gedacht, und der Regeleditor prüft streng: Er kennt auf
der obersten Ebene nur `rules`, als Regelarten nur `.read`, `.write`,
`.validate` und `.indexOn`, und als deren Werte nur `true`, `false` oder einen
Ausdruck als Text. Ein erklärender Schlüssel oder ein Array darin lässt das
Einfügen mit einem Syntaxfehler scheitern. Die Erklärungen stehen deshalb hier.

## Was die einzelnen Regeln tun

### `klassenraum`

| Zweig | Regel | Warum |
|---|---|---|
| `shares/$code` | offen | Ein geteiltes Board. Der sechsstellige Code IST der Schlüssel. |
| `links/$code` | offen | Kurzer Kopplungscode, läuft nach einer Stunde ab. |
| `spaces/$space` | offen | Abgleichbereich. Die Kennung ist 25 Zeichen lang und nicht zu erraten. |
| `media/$space` | offen | Klänge und Videos, bewusst neben dem Bereich. |
| `users/$uid` | nur man selbst | Konto und Sicherung. |

### `woerterwerkstatt`

| Zweig | Regel | Warum |
|---|---|---|
| `klassen/$code` | offen | Klasse samt Kindern und Sternen. Wer den Code hat (QR-Code), darf mitmachen — das ist der Sinn. PIN-Abdrücke liegen **nicht** hier. |
| `geheim/$code/$kind` | **nicht lesbar**, einmal schreibbar | Der SHA-256-Abdruck aus Code, Name und PIN. Überschreiben darf ihn nur die angemeldete Lehrkraft, der die Klasse gehört (PIN vergessen). `.validate` verlangt 64 Hexzeichen. |
| `anmeldung/$code/$kind` | Schreiben nur bei Übereinstimmung | Der Kniff: Die App schickt den errechneten Abdruck. Die Regel nimmt den Schreibvorgang nur an, wenn er mit dem hinterlegten übereinstimmt. So lässt sich die PIN prüfen, **ohne** dass irgendwer den hinterlegten Abdruck lesen kann. |
| `users/$uid` | nur man selbst | Eigene Bereiche und Klassenliste einer Lehrkraft. |

Ehrlich dazugesagt: Vier Ziffern sind zehntausend Möglichkeiten, und gegen
jemanden, der sie alle durchprobiert, hilft ohne eigenen Server nichts. Es geht
um Rechtschreibfortschritte einer Grundschulklasse.

## Ist es eingespielt? Kurz nachsehen

```
curl -s -o /dev/null -w "%{http_code}\n" \
  "https://praet-113ca-default-rtdb.europe-west1.firebasedatabase.app/woerterwerkstatt/klassen/ZZTEST9.json"
```

`200` = eingespielt. `401` = die Regeln fehlen noch.

Die Wörterwerkstatt prüft das seit 1.0.2 selbst und zeigt in „Meine Klassen“
einen Hinweis mit diesen Schritten, statt einen Knopf anzubieten, der dann
nichts tut.
