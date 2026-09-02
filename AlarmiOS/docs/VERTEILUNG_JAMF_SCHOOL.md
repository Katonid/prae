# Verteilung: Apple School Manager und Jamf School

Für die Jamf-Administration. Ziel: Die App liegt auf den Dienst-iPads des
Kollegiums, sie installiert sich von selbst, sie darf Mitteilungen zeigen,
und sie kennt ihren Beitrittscode, bevor sie das erste Mal geöffnet wird.

Der Weg ist die **Custom App** — nur für die eigene Organisation sichtbar,
nicht im öffentlichen App Store zu finden. Unlisted App Distribution ist der
Rückfall, falls Custom App an der Organisation scheitert.

## 1. In App Store Connect

* Den App-Eintrag **von Hand** anlegen (Meine Apps → +), nicht über Xcodes
  „Create App Record": Xcode schlägt dort den Anzeigenamen vor, und
  `Schulalarm` ist vergeben. App-Namen sind weltweit eindeutig, auch für
  Custom Apps. Einzelheiten samt freier Namensvorschläge in `../AppStore.md`.
* Die App als **Custom App** anlegen (Vertrieb: „Custom App", nicht
  „öffentlicher App Store").
* Unter *Preise und Verfügbarkeit* die Organisation freischalten, die die App
  beziehen darf. Dafür wird die **Organisations-ID aus Apple School Manager**
  gebraucht (ASM → Einstellungen → Registrierungsinformationen).
* Zum Prüfen einreichen. Die Review-Hinweise stehen in
  `docs/APP_REVIEW_NOTES.md` — vor allem der Satz, dass die App keinen Notruf
  ersetzt, und ein Testcode für die Prüfung.

## 2. In Apple School Manager

* **Apps und Bücher** → die App suchen (sie erscheint erst, wenn Apple sie
  freigegeben hat).
* Die benötigte Zahl an Lizenzen erwerben — auch bei kostenlosen Apps muss
  eine Menge zugewiesen werden. **Ein paar Lizenzen mehr als iPads**: Ein
  Ersatzgerät mitten im Schuljahr soll nicht an einer Lizenz scheitern.
* Als Standort denjenigen wählen, mit dem Jamf School verbunden ist.

## 3. In Jamf School

### 3.1 Synchronisieren

**Apps** → **Apps und Bücher** → Synchronisierung anstoßen. Die App
erscheint mit der erworbenen Lizenzzahl.

### 3.2 Zuweisen

Der Gerätegruppe der Lehrkräfte zuweisen, mit **automatischer Installation**
(nicht „auf Anfrage"). Eine Alarm-App, die erst installiert wird, wenn jemand
sie sucht, ist im Ernstfall nicht da.

Ebenfalls einschalten: **automatische App-Updates**. Eine Fassung, die auf
zwei Dritteln der Geräte alt ist, macht die Fehlersuche unmöglich.

### 3.3 App-Konfiguration einfügen

**Apps** → App → **App-Konfiguration**. Inhalt und Erklärung stehen in
`docs/MDM_APPCONFIG.md`. Damit kennt die App den Beitrittscode und fragt beim
ersten Start nur noch nach dem Kürzel.

### 3.4 Mitteilungen per Konfigurationsprofil vorab erlauben

Das ist der wichtigste Schritt dieser Liste. Ohne ihn muss jede Lehrkraft die
Rückfrage selbst richtig beantworten, und die eine, die auf „Nicht erlauben"
tippt, hat ein iPad, das im Ernstfall schweigt.

**Profile** → neues Profil → Nutzlast **Mitteilungen** (Notifications) →
Bundle-ID `de.dboschule.alarm`:

| Einstellung | Wert | Warum |
|---|---|---|
| Mitteilungen | erlaubt | sonst gar nichts |
| Töne | erlaubt | eine lautlose Mitteilung ist im Alarmfall keine |
| Auf dem Sperrbildschirm | anzeigen | der Normalfall im Unterricht |
| In der Mitteilungszentrale | anzeigen | zum Nachsehen |
| Banner-Stil | **dauerhaft** | ein temporäres Banner verschwindet nach Sekunden |
| Vorschauen | „immer" oder „ohne Entsperren" | siehe Kasten unten |
| Kritische Hinweise | nur, wenn Apple das Entitlement bewilligt hat | siehe README |

> **Vorschauen und der Beamer.** Hängt am iPad ein Beamer oder Apple TV, so
> spiegelt iOS das System-Banner mit — auch bevor jemand die App öffnet. Die
> App selbst zeigt auf dem zweiten Bildschirm ein neutrales Bild, aber auf
> das Banner davor hat sie keinen Zugriff. Ob die Vorschau den Alarmtext
> zeigen soll oder nur „Schulalarm", ist deshalb eine Entscheidung des
> Krisenteams und wird hier eingestellt, nicht in der App.

### 3.5 Fokus-Ausnahme

Ein aktiver Fokus („Nicht stören", „Unterricht") hält gewöhnliche
Mitteilungen zurück. Die App sendet zeitkritisch (`.timeSensitive`) und
kommt damit durch — **sofern die Lehrkraft „Zeitkritische Mitteilungen" für
diese App nicht abgeschaltet hat.** Das lässt sich per Profil nicht sicher
erzwingen und steht deshalb in der Prüfliste der App, die jedes Gerät bei
jedem Start neu prüft.

## 3b. Vorher: der Probelauf über TestFlight

Bevor die App als Custom App durch die volle Prüfung geht, gehört sie in die
Hände des Kollegiums. Der Weg dafür ist eine **externe TestFlight-Gruppe** —
und der klappt auch dann, wenn die schulischen Apple-IDs keine Mail empfangen
können.

### Zwei Apple-IDs, und sie dürfen verschieden sein

Auf einem iPhone oder iPad sind zwei Konten getrennt einstellbar, und das ist
hier die Rettung:

| Wofür | Wo | Woran es hängt |
|---|---|---|
| **iCloud** | Einstellungen → ganz oben | **Schulalarm.** Die App erkennt jede Lehrkraft an ihrem iCloud-Konto; daran hängen Mitgliedschaft, Rolle und Rückmeldungen. |
| **Medien & Käufe** | Einstellungen → App Store | **TestFlight.** Nur die Installation. |

Eine schulische Apple-ID für iCloud und eine andere für Medien & Käufe ist
also eine gültige Aufteilung — und oft die einzige, die geht.

**Ohne angemeldetes iCloud-Konto läuft Schulalarm überhaupt nicht.** Kein
Konto, kein Abonnement, kein Push; die App sagt das auf ihrem ersten
Bildschirm. Das gilt auf jedem Verteilweg, auch bei gerätebasierter Zuweisung
über Jamf, die die App sonst ganz ohne Apple-ID installiert. Wer die Geräte
vorbereitet, prüft deshalb zuerst das iCloud-Konto und erst danach alles
andere.

### Der öffentliche Link — keine Einladungsmail nötig

Eine externe Gruppe kann in App Store Connect einen **öffentlichen Link**
bekommen:

```
https://testflight.apple.com/join/AB3XK9QP
```

Die acht Zeichen am Ende sind der Code, und **genau der lässt sich in der
TestFlight-App unter „Code einlösen" eintippen.** Damit braucht niemand eine
Einladungsmail. Praktisch für eine Konferenz: aus dem Link einen QR-Code
machen und an die Wand werfen.

Zwei Bedingungen:

* Den öffentlichen Link gibt es **nur für externe** Gruppen. Interne Tester
  müssten Benutzer des App-Store-Connect-Kontos werden — für ein Kollegium der
  falsche Weg.
* Er wird erst nutzbar, **wenn die Beta App Review durch ist**. Gruppe und Link
  lassen sich vorher anlegen, aber es installiert sich nichts, bevor Apple den
  Bau freigegeben hat. Den Termin im Kollegium also **nach** der Freigabe
  ansetzen, nicht davor.

### Was vorher zu prüfen ist

**Ob eine Managed Apple ID aus Apple School Manager TestFlight benutzen darf,
hängt von Rolle und ASM-Einstellungen ab.** Das entscheidet ein Versuch an
EINEM Dienst-iPad, nicht eine Vermutung: TestFlight öffnen und sehen, ob sich
ein Code eingeben lässt. Erst danach dreißig Leute einladen.

Klappt es dort nicht, bleibt für die Dienstgeräte der Custom-App-Weg aus
Abschnitt 1 bis 3; die privaten Geräte der Kolleginnen laufen weiter über den
TestFlight-Link. Beide Wege nebeneinander sind unproblematisch — es ist
dieselbe App und dieselbe Gruppe.

### TestFlight ist der Probelauf, nicht der Betrieb

**Ein TestFlight-Bau läuft nach 90 Tagen ab.** Für den Pilotbetrieb ist das in
Ordnung. Für den Dauerbetrieb einer Alarm-App ist es das nicht: Eine
abgelaufene App ist eine stumme App, und das fällt an dem Tag auf, an dem es
darauf ankommt. Sobald der Zustelltest steht, gehört die App auf den
Custom-App-Weg — dort gibt es kein Ablaufdatum und keine Einlöserei.

## 4. Die Reihenfolge auf dem Gerät

1. iPad ist in Jamf School registriert und in der Gerätegruppe.
2. Profil mit den Mitteilungsrechten ist aufgespielt.
3. App wird automatisch installiert.
4. Lehrkraft öffnet sie, gibt ihr Kürzel ein.
5. Prüfliste durchgehen, Selbsttest auslösen, **auf den Ton warten**.

Schritt 5 ist nicht Kosmetik. Er ist der einzige Beweis, dass die Kette aus
Apple-ID, Berechtigung, Fokus und Netz an diesem Gerät wirklich hält.

## 5. Wenn ein Gerät stumm bleibt

In dieser Reihenfolge prüfen — die Liste ist nach Häufigkeit sortiert:

1. **Keine Apple-ID angemeldet.** Ohne sie kommt gar nichts an. Die App sagt
   das in der Prüfliste im Klartext.
2. **Mitteilungen nicht erlaubt** oder Ton abgeschaltet.
3. **Zeitkritische Mitteilungen abgeschaltet** — dann hält jeder Fokus den
   Alarm zurück.
4. **Lautlos-Schalter.** Ohne die Berechtigung „kritische Hinweise" spielt
   auch eine zeitkritische Mitteilung bei stummem iPad keinen Ton.
5. **Falsche CloudKit-Umgebung.** Über Xcode installiert läuft die App gegen
   *Development*, über TestFlight und Custom App gegen *Production*. Wer ein
   Testgerät per Xcode bespielt hat, sieht die Alarme der anderen nicht.

Die Geräteübersicht in der App (Verwaltung → Geräte) zeigt zu jedem iPad,
was es zuletzt über sich gemeldet hat — und färbt rot, was seit 48 Stunden
schweigt.
