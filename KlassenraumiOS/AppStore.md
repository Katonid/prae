# Klassenraum und der App Store — kurz: nein

**Diese App wird niemals zur Prüfung eingereicht.** Zwei fast gleiche Apps
desselben Entwicklers gelten nach Apples Regel 4.3 als Dublette und werden
abgelehnt. Klassenraum lebt ausschließlich in **TestFlight bei internen
Testern**; dafür findet keine Prüfung statt.

Hier stand einmal die vollständige Abgabeliste — mitkopiert aus Tafelbild,
als der Ordner angelegt wurde. Sie ist entfernt, weil sie zu einer Abgabe
anleitete, die es nicht geben darf, und weil ihre Texte den alten Stand
beschrieben (Einladungscode, öffentlicher iCloud-Bereich). Die gültige Liste
für die veröffentlichte App steht in `TafelbildiOS/AppStore.md`.

## Was für TestFlight nötig ist

| Punkt | Wo |
|---|---|
| App-ID `de.familie.klassenraum` mit iCloud + Push | Developer-Portal, von Hand |
| iCloud-Bereich `iCloud.de.familie.tafelbild` | `Config/Klassenraum.entitlements` — **derselbe wie Tafelbild, mit Absicht** |
| Keine Exportbeschränkung (`ITSAppUsesNonExemptEncryption = NO`) | `Config/Info.plist` + Bauzieleinstellung |
| Datenschutzmanifest | `Klassenraum/PrivacyInfo.xcprivacy` |
| Build-Nummer | vergibt die Bauphase „Build-Nummer setzen" automatisch |

In App Store Connect braucht es dafür nur einen App-Eintrag und die internen
Tester. **Keine Bildschirmfotos, keine Beschreibung, keine Altersfreigabe,
keine Einreichung** — all das verlangt erst die Prüfung.

Hochladen: In Xcode das Ziel auf „Any iOS Device", `Product → Archive`,
im Organizer „Distribute App" → „App Store Connect" → „Upload". Danach in
App Store Connect unter **TestFlight** freigeben, nicht unter „App Store".

## Für den Rückbau nach Tafelbild aufbewahrt

Wenn die Abgleichsschicht von hier zurückwandert, ändern sich in Tafelbild
vier Angaben. Sie stehen hier, damit sie nicht verlorengehen:

**1. App-Datenschutz in App Store Connect.** Auf „Erfasst diese App Daten?"
lautet die Antwort dann **„Nein"** — und zwar zu Recht. Begründung, falls die
Prüfung nachfragt:

> Die App hat keinen Server und kein Nutzerkonto. Der Abgleich läuft über
> CloudKit in die **private** Datenbank der Nutzerin, die an ihre Apple-ID
> gebunden ist; der Entwickler hat darauf keinen Zugriff und erhält keine
> Kopie. Eine geteilte Tafel bleibt in der privaten iCloud derjenigen, die
> sie geteilt hat, und ist nur für die eingeladenen Personen sichtbar
> (`CKShare`). Kamera und Mikrofon werden ausschließlich auf dem Gerät
> ausgewertet; aufgezeichnet wird nichts.

Solange Tafelbild in die **öffentliche** Datenbank schreibt, ist diese
Antwort falsch — dort kann der Entwickler jeden Datensatz einsehen, und das
gilt nach Apples Maßstab als Erfassung.

**2. `TafelbildiOS/Tafelbild/PrivacyInfo.xcprivacy`.** Dort steht
`NSPrivacyCollectedDataTypes` leer. Das wird beim Rückbau richtig; bis dahin
widerspricht es dem tatsächlichen Verhalten. Die ausführliche Begründung
steht im Kopf von `Klassenraum/PrivacyInfo.xcprivacy`.

**3. `docs/tafelbild/datenschutz.html`.** Die Seite beschreibt heute bewusst
den Stand der veröffentlichten App: öffentliche Datenbank, Einsicht durch den
Entwickler, gelöschte Datensätze bleiben stehen. **Nicht vorab ändern** —
sonst stünde dort etwas Falscheres als jetzt. Beim Rückbau wird daraus:
private Datenbank, keine Einsicht, Freigabe über einen Link statt über einen
Code.

**4. Der Werbetext.** Der Abschnitt „Gemeinsam arbeiten" in
`TafelbildiOS/AppStore.md` spricht vom Einladungscode. Nach dem Rückbau heißt
es dort: Eine Tafel lässt sich über einen Einladungslink freigeben, die
Freigabe lässt sich zurücknehmen, und wer eine vorbereitete Tafel bekommt,
kann sie als eigene übernehmen.
