# Verteilung: Apple School Manager und Jamf School

Für die Jamf-Administration. Ziel: Die App liegt auf den Dienst-iPads des
Kollegiums, sie installiert sich von selbst, sie darf Mitteilungen zeigen,
und sie kennt ihren Beitrittscode, bevor sie das erste Mal geöffnet wird.

Der Weg ist die **Custom App** — nur für die eigene Organisation sichtbar,
nicht im öffentlichen App Store zu finden. Unlisted App Distribution ist der
Rückfall, falls Custom App an der Organisation scheitert.

## 1. In App Store Connect

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
