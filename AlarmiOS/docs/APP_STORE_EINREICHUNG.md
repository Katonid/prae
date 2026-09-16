# Schulalarm im App Store einreichen — kostenlos

Ansage des Nutzers 09/2026: Die App soll **kostenlos im öffentlichen App
Store** stehen, nicht mehr nur als Custom App über Apple School Manager.
Beides nebeneinander ist erlaubt; für Dienst-iPads bleibt der Weg über Jamf
School der bequemere (`VERTEILUNG_JAMF_SCHOOL.md`).

Diese Seite ist die Reihenfolge, nicht die Begründung. Warum etwas so ist,
steht im README.

---

## 0. Was der öffentliche Vertrieb ändert — einmal ehrlich

**Der Beitrittscode trägt jetzt allein.** Bis 1.0.34 stand neben ihm, dass
es die App nur auf verwalteten Schul-iPads gab. Das gilt nicht mehr: Jede
Person mit einem iPhone kann die App laden. Wer einen Code hat und eine
Apple-ID besitzt, kommt in die Gruppe — daran hat sich technisch nichts
geändert, aber die zweite Hürde ist weg.

Was bleibt, wirkt **danach** und nicht davor: Die Mitgliederliste nennt zu
jedem Eintrag das Beitrittsdatum und markiert doppelte Kürzel; ein Admin
entfernt einen unerwarteten Eintrag und zieht den Code zurück. Dieser Satz
gehört in die Einweisung des Kollegiums: **Der Beitrittscode ist ein
Schlüssel, kein Merkzettel.**

Wer mehr braucht, braucht einen Server — `BACKEND_MIGRATION.md`.

## 1. Vor dem Hochladen

**Eingereicht wird 1.1.0 (Build 39).** Der Sprung von 1.0.37 ist bewusst
(Ansage des Nutzers, 09/2026) und derselbe Gedanke wie bei Tafelbild 1.4.0:
Was hier in den Laden geht, ist keine achtunddreißigste Nachbesserung, sondern
die erste öffentliche Fassung. Die Stände davor gab es nur im Repo und über
TestFlight — niemand außerhalb hat sie je gesehen. Danach zählt es wie gewohnt
weiter: 1.1.1, 1.1.2 …

- [ ] `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` an allen **vier**
      Stellen im pbxproj gleich und höher als der letzte Upload.
- [ ] Der Bau in GitHub Actions ist grün. **Er beweist nicht, dass sich
      signieren lässt** — er läuft ohne Signierung gegen den Simulator.
- [ ] In Xcode einmal auf ein echtes Gerät bauen: Damit fallen Profil,
      App-Id und Fähigkeiten auf, und nur damit.
- [ ] CloudKit-Konsole: **Deploy Schema Changes to Production**. Ohne das
      fehlen in Production Felder, die es in Development längst gibt.
- [ ] CloudKit-Konsole: **Security Roles → `_icloud` → READ, WRITE und CREATE
      auf allen acht Record-Typen.** Fehlt WRITE auf `Alarm`, kann ein Admin
      nur die eigenen Alarme entwarnen (gemeldet 09/2026) — und das fällt erst
      im Ernstfall auf. Die Tabelle, welches fehlende Häkchen was kostet, steht
      im README unter „Sicherheitsrolle".

## 2. Der Eintrag in App Store Connect

**Von Hand anlegen** (Apps → +), nie über Xcodes „Create App Record":
Xcode schlägt dort den Anzeigenamen vor, und `Schulalarm` ist weltweit
vergeben.

| Feld | Wert |
|---|---|
| Name | `Schulalarm - Der Warnmelder` |
| Untertitel | 30 Zeichen, z. B. `Alarm für das Kollegium` |
| Bundle-Id | `de.dboschule.alarm` |
| Primäre Sprache | Deutsch |
| Kategorie | Bildung (zweite: Dienstprogramme) |
| Preis | **Kostenlos** |

Der Homescreen-Name bleibt „Schulalarm"
(`INFOPLIST_KEY_CFBundleDisplayName`) — Store-Name und Anzeigename sind
getrennte Felder und dürfen auseinandergehen.

## 3. Preis und Verträge

Kostenlos heißt: Es wird **nur** der „Free Apps"-Vertrag gebraucht. Keine
Bankverbindung, keine Steuerformulare, kein Paid-Apps-Agreement. Wenn App
Store Connect in „Vereinbarungen, Steuern und Bankverbindung" nach Bank oder
Steuer fragt, ist der falsche Vertrag ausgewählt.

## 3b. Bildschirmfotos

Ein Bildschirmfoto vom Gerät hat die Auflösung DIESES Geräts — ein iPhone 16
Pro liefert 1206 × 2622. App Store Connect nimmt aber nur eine kurze Liste
fester Maße an und weist alles andere ab. Umgerechnet wird mit

```
python3 scripts/screenshots-aufbereiten.py --ziel iphone-6.9 bild1.png bild2.png …
```

Das Skript behält das Seitenverhältnis, füllt den Rest durch Wiederholen der
Randspalte (bei 1206 × 2622 sind das zwei Pixel links und rechts) und schreibt
**ohne Alphakanal** — Transparenz ist ein Ablehnungsgrund. Ziele: `iphone-6.9`
(1290 × 2796), `iphone-6.5` (1242 × 2688), `ipad-13` (2048 × 2732).

**Weil die App auch auf dem iPad läuft, verlangt App Store Connect BEIDE
Sätze.** Ein reiner iPhone-Satz reicht nicht; das fällt erst beim Einreichen
auf, wenn schon alles andere steht. Also am iPad dieselben Bildschirme
aufnehmen und mit `--ziel ipad-13` umrechnen.

Was gezeigt wird, entscheidet der Inhalt und nicht die Vollständigkeit: der
Startbildschirm, die Auswahl der Alarmart, der Countdown, der Alarmbildschirm.
**Im Bild steht „Testschule"** und kein echter Schulname — dieselbe
Datensparsamkeit wie in der App.

## 4. Was in die Formulare gehört

**Datenschutz-URL (Pflicht):**
`https://katonid.github.io/prae/schulalarm/datenschutz.html`

**Support-URL (Pflicht):**
`https://katonid.github.io/prae/schulalarm/support.html`

**Nutzungsbedingungen (freiwillig, hier aber sinnvoll):**
`https://katonid.github.io/prae/schulalarm/nutzungsbedingungen.html`

**Lizenzvereinbarung: Apples Standard stehen lassen.** App Store Connect →
App-Informationen → Lizenzvereinbarung. Der Standardtext (Apples „Licensed
Application End User License Agreement") schließt Gewährleistung bereits so weit
aus, wie das jeweilige Recht es zulässt, und der Anbieter ist darin der
Lizenzgeber. Eine **eigene** Vereinbarung muss Apples Mindestanforderungen
erfüllen und wird mitgeprüft — sie ist eine zusätzliche Fehlerquelle für einen
Gewinn, den die Nutzungsbedingungen daneben schon bringen.

**Verfügbarkeit auf Deutschland begrenzen** (Preis und Verfügbarkeit →
Verfügbarkeit). Die App ist deutschsprachig und auf deutsche Schulen
zugeschnitten; ein Angebot in den USA bringt keinen Nutzen und holt eine
Rechtsordnung ins Haus, in der Produkthaftung und Sammelklagen anders laufen.
Später erweitern geht mit zwei Tipps, zurücknehmen ist mühsam.

**Altersfreigabe:** überall „Nicht vorhanden"/„Keine". Die App zeigt keine
anstößigen Inhalte, kein Glücksspiel, keine Werbung. Ergebnis: 4+.

**App-Datenschutz („Nutrition Label"):** was die App wirklich sammelt —
Kennung (die iCloud-Kennung), Benutzerinhalte (Nachrichten im Alarm) und
Diagnose-nahe Angaben (Gerätemodell, App-Fassung, Berechtigungsstand),
jeweils **mit der Identität verknüpft** und **nicht** für Tracking. Kein
Standort, keine Kontakte, keine Werbekennung. Die Liste steht auch in
`PrivacyInfo.xcprivacy`; die beiden dürfen nicht auseinandergehen.

**Anmerkungen für die Prüfung:** der vollständige Text aus
`APP_REVIEW_NOTES.md`. Ein Testkonto wird **nicht** gebraucht — der Prüfer
richtet seine eigene Schule ein.

## 5. Die zwei Stellen, an denen so eine App abgewiesen wird

1. **„Das ist eine Firmen-App."** Apple verweist Apps, die erkennbar nur
   einer einzelnen Einrichtung nützen, auf die Custom Apps. Gegenmittel ist
   kein Trick, sondern die Wahrheit an der richtigen Stelle: Jede Schule
   richtet sich ihre eigene ein, es gibt nichts Gemeinsames zwischen ihnen.
   Genau damit beginnen die Review-Notizen und die Beschreibung.
2. **Von Nutzern eingestellter Inhalt.** Im Alarm schreibt das Kollegium
   einander Nachrichten. Apple verlangt dafür einen Weg zu melden, einen,
   jemanden loszuwerden, und eine erreichbare Adresse. Alle drei gibt es:
   Einstellungen → „Unangemessene Inhalte melden", Verwaltung → Mitglieder →
   „Entfernen" samt Zurückziehen des Codes, und die Support-Adresse.

Dazu kommen zwei Fragen, die erfahrungsgemäß gestellt werden:

- **Kritische Hinweise.** Bewilligt am 08.09.2026 für `de.dboschule.alarm`.
  Ein Satz genügt: Sie sind das, was einen Amokalarm auf einem
  stummgeschalteten iPad hörbar macht, und die App fällt ohne die Erlaubnis
  sauber auf `.timeSensitive` zurück.
- **„Ersetzt das den Notruf?"** Nein, und die App sagt es selbst — auf dem
  Alarm-Bildschirm und in den Einstellungen.

## 6. Hochladen und einreichen

1. Xcode → Product → Archive (Ziel „Any iOS Device").
2. Distribute App → App Store Connect → Upload.
3. In App Store Connect den Build der Fassung zuordnen.
4. Export-Compliance wird **nicht** gefragt:
   `ITSAppUsesNonExemptEncryption = NO` steht im Projekt. Fragt sie doch
   jemand, ist der Schlüssel verloren gegangen.
5. „Zur Prüfung einreichen".

## 7. Nach der Freigabe

- Der Link zum Laden gehört in die Einweisung des Kollegiums, der
  **Beitrittscode nicht in dieselbe Mail** — zwei Wege, zwei Nachrichten.
- Ein TestFlight-Bau läuft nach 90 Tagen ab, eine Fassung aus dem Laden
  nicht. Für den Dauerbetrieb also den Laden nehmen.
- **Offen bleibt der Zustellnachweis** auf zwei echten Geräten
  (`ZUSTELLTEST.md`). Eine Freigabe durch Apple ist keine Messung.
