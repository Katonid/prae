import SwiftUI

/// Was mit den Daten geschieht — in der App nachlesbar, nicht nur auf einer
/// Webseite.
///
/// Der Text beschreibt den Stand **nach** dem Umbau auf die private
/// iCloud-Datenbank. Wer die Abgleichsschicht später nach Tafelbild
/// zurückholt, nimmt diese Ansicht mit: Sie ist genau dann richtig, wenn
/// nichts mehr in der öffentlichen Datenbank landet.
struct DatenschutzView: View {
    var body: some View {
        List {
            Section {
                Text("Diese App hat keinen Server. Es gibt kein Konto beim "
                     + "Entwickler, keine Werbung, keine Analyse, kein "
                     + "Tracking und keine fremden Dienste im Hintergrund.")
            } header: {
                Text("Kurz gesagt")
            }

            Section {
                zeile("Auf dem Gerät",
                      "Tafeln, Namenslisten, Bilder und Klänge liegen im "
                      + "Ordner der App. Ist der Abgleich ausgeschaltet, "
                      + "verlässt nichts davon dieses Gerät.")
                zeile("In deiner iCloud",
                      "Mit eingeschaltetem Abgleich liegt dasselbe zusätzlich "
                      + "in deiner PRIVATEN iCloud-Datenbank. Sie gehört zu "
                      + "deiner Apple-ID. Der Entwickler dieser App kann "
                      + "nicht hineinsehen — nicht in einzelne Tafeln, nicht "
                      + "in Namen, nicht in Bilder.")
                zeile("Bei einer Freigabe",
                      "Gibst du eine Tafel frei, bleibt sie in deiner iCloud "
                      + "und wird für die eingeladenen Personen sichtbar. "
                      + "Nur für sie. Nimmst du die Freigabe zurück, endet "
                      + "der Zugriff sofort.")
            } header: {
                Text("Wo die Daten liegen")
            } footer: {
                Text("Der Abgleich läuft über Apples CloudKit. Was dort "
                     + "geschieht, verantwortet Apple; auf die Daten in "
                     + "deiner privaten Datenbank hat der Entwickler dieser "
                     + "App keinen Zugriff.")
            }

            Section {
                zeile("Dein Name",
                      "Der Name aus den Einstellungen steht in den Tafeln, "
                      + "damit man sieht, wer eine geteilte Tafel angelegt "
                      + "hat und wer mitmacht. Er ist frei wählbar.")
                zeile("Namen der Kinder",
                      "Die Namenslisten gehören zur Tafel. Wird eine Tafel "
                      + "geteilt, sehen die eingeladenen Personen sie mit. "
                      + "Das ist der Zweck — aber es ist gut, es zu wissen: "
                      + "Namen von Kindern sind personenbezogene Daten. Teile "
                      + "eine Tafel nur mit Menschen, die die Klasse ohnehin "
                      + "unterrichten.")
                zeile("Mikrofon",
                      "Der Lautstärkemesser misst nur den Pegel, unmittelbar "
                      + "auf dem Gerät. Es wird nichts aufgezeichnet und "
                      + "nichts verschickt.")
                zeile("Kamera",
                      "Die Dokumentenkamera zeigt das Bild und hält es auf "
                      + "Wunsch als Standbild fest. Es wandert nur dorthin, "
                      + "wo auch die anderen Bilder liegen.")
            } header: {
                Text("Was erfasst wird")
            }

            Section {
                Text("Löschst du eine Tafel oder eine Liste, bleibt in der "
                     + "iCloud ein leerer Vermerk stehen: die Kennung, das "
                     + "Löschzeichen und der Zeitpunkt — sonst brächten die "
                     + "anderen Geräte sie beim nächsten Abgleich zurück. "
                     + "Inhalt steht darin keiner mehr.\n\n"
                     + "Wer alles loswerden will, schaltet den Abgleich aus "
                     + "und löscht die App. Was in der iCloud liegt, "
                     + "verschwindet mit ihr: in den iOS-Einstellungen unter "
                     + "Apple-ID → iCloud → Speicher verwalten.")
            } header: {
                Text("Löschen")
            }

            Section {
                Text("Videos bleiben dort, wo du sie ausgewählt hast. Die App "
                     + "merkt sich nur ihren Namen und verschickt sie nie.")
            } header: {
                Text("Videos")
            }
        }
        .navigationTitle("Datenschutz")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func zeile(_ titel: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titel).font(Theme.font(16, weight: .semibold))
            Text(text).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
