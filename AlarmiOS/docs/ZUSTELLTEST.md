# Der Zustellnachweis

Der erste Meilenstein dieses Projekts ist keine Funktion, sondern eine
Messung: **Kommt der Alarm auf einem gesperrten iPad mit aktivem Fokus
binnen zehn Sekunden hörbar an?** Der ganze Ansatz — CloudKit statt eigenem
Server — steht und fällt damit.

## Was hier NICHT geprüft ist

Diese Messung kann nur auf echten Geräten laufen: zwei iPads mit
angemeldeter Apple-ID, in derselben CloudKit-Umgebung, mit einem
signierten Bau. Ein Simulator bekommt keine CloudKit-Pushes, und ein
Bauknecht ohne Signierschlüssel kann sie nicht erzeugen.

**Der Nachweis ist damit offen.** Was übersetzt und geprüft ist: dass die
App und die Erweiterung bauen, dass die Subscriptions mit den richtigen
Optionen angelegt werden, dass der Parser beide Paketformate versteht und
dass die Erweiterung `interruptionLevel` setzt. Ob die Kette auf dem Gerät
die zehn Sekunden hält, sagt erst dieser Test.

## Vorher: einmalig einrichten

1. **CloudKit-Schema.** Beim ersten Lauf legt die App die Record-Typen in
   *Development* selbst an. Danach in der CloudKit-Konsole die Indizes
   setzen und „Deploy Schema Changes to Production" ausführen — welche
   Indizes, steht im README unter „CloudKit einrichten".
2. **Beide iPads in derselben Umgebung.** Über Xcode installiert =
   *Development*, über TestFlight = *Production*. Ein Gerät je Umgebung
   sieht das andere nie. Die App zeigt unter Einstellungen → Dieses Gerät,
   welche gilt.
3. **Beide iPads derselben Gruppe beitreten lassen**, mit verschiedenen
   Kürzeln.
4. Auf beiden die Prüfliste durchgehen, bis sie ganz grün ist.

## Der Ablauf

Gerät A löst aus, Gerät B misst.

**Gerät B vorbereiten:**

* App seit mindestens zwei Stunden geschlossen (aus dem App-Umschalter
  wischen und liegen lassen). Das ist die Bedingung, die den Test hart
  macht: iOS entlädt die App, und der Push muss sie nicht wecken, sondern
  ganz allein über die Erweiterung Lärm machen.
* Einen Fokus einschalten — „Nicht stören" reicht.
* Bildschirm sperren.
* Lautstärke hoch, Lautlos-Schalter auf laut.
* Stoppuhr bereitlegen (ein drittes Gerät oder eine Armbanduhr).

**Gerät A:**

* Alarm auslösen → PROBEALARM → Ort → Countdown ablaufen lassen.
* Die Uhrzeit des Auslösens steht anschließend auf dem Alarm-Bildschirm
  sekundengenau. Sie ist der Nullpunkt der Messung.

**Gemessen wird:** vom Ende des Countdowns auf Gerät A bis zum ersten Ton
auf Gerät B.

## Was zu protokollieren ist

Je Durchgang eine Zeile. Mindestens **zehn Durchgänge**, verteilt über
mehrere Stunden — ein einzelner schneller Push beweist nichts, weil APNs
ein Gerät, das gerade erst etwas bekommen hat, bevorzugt behandelt.

| # | Uhrzeit | Zustand Gerät B | Sekunden bis Ton | Ton? | Anzeige? |
|---|---|---|---|---|---|
| 1 | | gesperrt, Fokus an, App 2 h zu | | | |
| … | | | | | |

Zusätzlich mindestens je zwei Durchgänge in diesen Zuständen:

* Gerät B entsperrt, App im Vordergrund.
* Gerät B entsperrt, App im Hintergrund.
* Gerät B über Nacht liegen gelassen (mindestens 8 Stunden), Stromsparmodus
  an.
* Gerät B in WLAN mit schwachem Empfang.

## Das Urteil

* **Alle Durchgänge unter 10 Sekunden** → der Ansatz trägt. Weitermachen.
* **Einzelne Ausreißer über 10 Sekunden** → notieren, unter welchen
  Umständen. Ein Ausreißer im Stromsparmodus ist etwas anderes als einer im
  Normalbetrieb.
* **Regelmäßig über 10 Sekunden, oder gar nichts** → hier ist Schluss, und
  zwar ausdrücklich: Dann ist CloudKit als Zustellweg für einen Amokalarm
  nicht geeignet. Der Ersatz steht in `docs/BACKEND_MIGRATION.md` unter
  „Der Ersatzweg" — ein winziger eigener APNs-Sender hinter demselben
  Protokoll `AlarmBackend`. Die Oberfläche, der Alarm-Bildschirm, die
  Erweiterung und der Push-Vertrag bleiben dabei unverändert.

## Was bei einem Fehlschlag zuerst zu prüfen ist

Bevor der Ansatz verworfen wird, diese fünf Punkte — in dieser Reihenfolge,
nach Häufigkeit:

1. **Kommt gar nichts?** Prüfliste auf Gerät B. Ohne Apple-ID kommt nichts.
2. **Kommt es leise?** Dann fehlt „zeitkritisch" oder der Lautlos-Schalter
   steht auf stumm. Ohne kritische Hinweise spielt auch ein zeitkritischer
   Alarm bei stummem iPad keinen Ton.
3. **Kommt es ohne Text („AMOKALARM – %@ …")?** Dann lief die Erweiterung
   nicht und der Rückfalltext greift. Prüfen, ob
   `shouldSendMutableContent` gesetzt ist und die Erweiterung wirklich
   mitinstalliert wurde.
4. **Kommt es doppelt?** Zwei Subscriptions mit überlappenden Prädikaten —
   in der CloudKit-Konsole nachsehen und alte Kennungen löschen
   (`SubscriptionID` trägt ein `-v1`, das genau dafür da ist).
5. **Kommt es spät und nur beim Entsperren?** Dann wurde es als stiller Push
   zugestellt. Ein Alarm darf nie `content-available` allein sein.
