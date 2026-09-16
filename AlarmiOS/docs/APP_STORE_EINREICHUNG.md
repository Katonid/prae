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

## 4. Was in die Formulare gehört

**Datenschutz-URL (Pflicht):**
`https://katonid.github.io/prae/schulalarm/datenschutz.html`

**Support-URL (Pflicht):**
`https://katonid.github.io/prae/schulalarm/support.html`

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
