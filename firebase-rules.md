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

Nachgesehen wird das vor jedem Einfügen — das Skript prüft zugleich, dass die
Einzelfassungen zum Zweig in der Gesamtdatei passen:

```
python3 woerterwerkstatt/scripts/regeln-pruefen.py
```

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
| `klassen/$code` | offen; **auflisten** nur die Verwaltung | Klasse samt Kindern und Sternen. Wer den Code hat (QR-Code), darf mitmachen — das ist der Sinn. PIN-Abdrücke liegen **nicht** hier. Die Liste ALLER Codes bekommt nur die Schulverwaltung; sie braucht sie, um Klassen ohne Lehrkraft zu finden. |
| `geheim/$code` | **nicht lesbar**, schreiben nur Besitzerin oder Verwaltung | Der SHA-256-Abdruck aus Code, Name und PIN. Am `$code` hängt die Erlaubnis, damit eine ganze Klasse in einem Zug wegzuräumen ist; darunter darf jedes Kind seinen eigenen Eintrag EINMAL anlegen (`!data.exists()`). `.validate` verlangt 64 Hexzeichen. |
| `anmeldung/$code/$kind` | Schreiben nur bei Übereinstimmung | Der Kniff: Die App schickt den errechneten Abdruck. Die Regel nimmt den Schreibvorgang nur an, wenn er mit dem hinterlegten übereinstimmt. So lässt sich die PIN prüfen, **ohne** dass irgendwer den hinterlegten Abdruck lesen kann. |
| `protokoll/$code/$kind` | **schreiben alle, lesen nur Lehrkraft oder Verwaltung** | Welche Wörter ein Kind bearbeitet hat und wie es sie geschrieben hat. Bewusst NICHT unter `klassen/` — dort darf lesen, wer den Code hat, und das sind alle Kinder der Klasse. Was ein Kind falsch geschrieben hat, geht seine Mitschüler nichts an. |
| `users/$uid` | man selbst — oder die Verwaltung | Eigene Bereiche und Klassenliste einer Lehrkraft. |
| `admins/$uid` | jeder liest den EIGENEN Eintrag, schreiben nur die Verwaltung | Wer die Schule verwalten darf. |

#### Das Löschen einer Klasse hat eine Reihenfolge

`geheim/$code` fragt nach `klassen/$code/besitzer`. Ist die Klasse zuerst
gelöscht, gibt es keinen Besitzer mehr — und die PIN-Abdrücke bleiben für
immer liegen, unlesbar und unlöschbar. Deshalb räumt `klasseLoeschen` erst
`geheim`, `anmeldung` und `protokoll` weg und dann die Klasse.

Bis 1.4.0 tat es das nicht: Beim Löschen einer Klasse blieben alle drei
Nebenzweige stehen, und „Protokoll der ganzen Klasse löschen“ scheiterte
stillschweigend, weil `.write` nur am `$kind` stand, nicht am `$code`.

### Schulverwaltung

Ein Konto darf die ganze Schule verwalten, wenn eines von beidem zutrifft:

* Seine **E-Mail** steht in den Regeln (`jerosch@dbo.schulen-bochum.nrw`).
  Das ist der Einstieg — ohne ihn gäbe es ein Henne-Ei-Problem: Der erste
  Eintrag in `admins` ließe sich von niemandem schreiben.
* Oder seine **Kennung** steht unter `admins/<uid>`. Diese Einträge vergibt
  die Verwaltung in der App selbst (Schulverwaltung → Lehrkraft → „Zur
  Verwaltung machen“).

Die App fragt nicht nach einer Adresse und kennt keine Liste. Sie **probiert**:
Wer `woerterwerkstatt/users` auflisten darf, ist Verwaltung, und nur dann
erscheint der Knopf „🏫 Schule“. Damit stehen die Rechte an genau einer Stelle
— dieser Datei —, und eine weitere Verwaltung braucht keine neue Fassung der
App.

Eine weitere Adresse fest eintragen geht, indem der Vergleich verdoppelt wird:

```
auth.token.email === 'erste@schule.de' || auth.token.email === 'zweite@schule.de'
```

Zwei Dinge dazu, ehrlich gesagt:

* Die Regel prüft die Adresse, **nicht** ob sie bestätigt ist. Wer sich zuerst
  mit ihr anmeldet, bekommt das Recht. Da das Konto längst besteht, ist das
  hier ungefährlich — bei einer neu eingetragenen Adresse aber sollte man sich
  sofort selbst damit anmelden.
* Ein Verwaltungskonto kann alles: jede Klasse, jedes Kind, jedes Profil. Es
  gehört nicht auf ein Gerät, das im Klassenraum offen herumsteht.

#### Was auch die Verwaltung nicht kann

**Ein fremdes Firebase-Konto löschen oder seine E-Mail ändern.** Dafür gibt es
nur zwei Wege: das Admin-SDK mit einem Dienstschlüssel auf einem Server — den
gäbe es in einer Web-App auf jedem Kindergerät mit, also nein — oder einen
Menschen in der Firebase-Konsole. Die App löscht deshalb alle **Daten** einer
Lehrkraft (Profil, Bereiche, Klassen, Kinder, PINs, Protokolle) und führt
danach in die Konsole, wo die Anmeldung selbst zu entfernen ist.

Was sie kann: ein Konto **anlegen** (`signUp`) und eine **Mail zum Zurücksetzen
des Kennworts** schicken (`sendOobCode`). Ein Kennwort direkt zu setzen geht
nicht — und wäre auch keins mehr, wenn die Verwaltung es kennt.

Ehrlich dazugesagt: Vier Ziffern sind zehntausend Möglichkeiten, und gegen
jemanden, der sie alle durchprobiert, hilft ohne eigenen Server nichts. Es geht
um Rechtschreibfortschritte einer Grundschulklasse.

Zum Zweig `protokoll` gehört ein zweiter ehrlicher Satz: Das sind
**Leistungsdaten einzelner, namentlich genannter Kinder**. Sie liegen in der
Datenbank, bis die Lehrkraft sie löscht (Knopf in der Klassenansicht), und das
Mitschreiben lässt sich je Klasse abschalten. Wer eine Klasse löscht, sollte
das Protokoll gleich mitlöschen.

## Ist es eingespielt? Kurz nachsehen

```
curl -s -o /dev/null -w "%{http_code}\n" \
  "https://praet-113ca-default-rtdb.europe-west1.firebasedatabase.app/woerterwerkstatt/klassen/ZZTEST9.json"
```

`200` = eingespielt. `401` = die Regeln fehlen noch.

Die Wörterwerkstatt prüft das seit 1.0.2 selbst und zeigt in „Meine Klassen“
einen Hinweis mit diesen Schritten, statt einen Knopf anzubieten, der dann
nichts tut.
