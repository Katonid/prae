import SwiftUI

// SCHRIFTEN PRÜFEN — eine Probe, keine Erklärung (ab 1.0.43).
//
// Zweimal gemeldet, dass selbst installierte Schriften nicht auftauchen,
// und zweimal von hier aus geantwortet, ohne etwas messen zu können: Auf
// diesem Rechner gibt es kein iPad und keine selbst installierte Schrift.
// Nach der ersten Erklärung, die nicht geholfen hat, wird nicht ein
// zweites Mal geraten — die App sagt selbst, was sie vorfindet.
//
// Gezeigt wird, was gezählt werden kann: was das System als dauerhaft
// angemeldet meldet, wie viele Familien dieser Prozess danach kennt, was
// über den Wähler gewählt wurde und ob es sich wiederfinden lässt, dazu
// das Protokoll der letzten Starts. Ohne Deutung und kopierbar — eine
// Messung, die man abschreiben oder abfotografieren muss, kommt verkürzt
// an. Dieselbe Bauweise wie „Zustellung prüfen" bei Schulalarm.
struct Schriftenprobe: View {
    @State private var text = ""
    @State private var kopiert = false

    var body: some View {
        List {
            Section {
                Text(text.isEmpty ? "Wird gemessen \u{2026}" : text)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            } header: {
                Text("Befund")
            } footer: {
                Text("Diese Zahlen sind gemessen, nicht angenommen. Ganz oben steht, was dieser Bau überhaupt darf \u{2014} gelesen aus dem eingebetteten Bereitstellungsprofil; fehlt das Schriftenrecht dort, sagen die Zahlen darunter nichts über das Gerät aus. Wenn ein Profil das Recht BEWILLIGT, steht die Zeichenkette dabei: Die gehört gemeldet, dann kann sie in die Entitlements-Datei.")
            }

            Section {
                Button {
                    UIPasteboard.general.string = text
                    kopiert = true
                } label: {
                    Label("Befund kopieren", systemImage: "doc.on.doc")
                }
                if kopiert {
                    Text("Der Befund liegt in der Zwischenablage.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button {
                    // Noch einmal anmelden und danach neu messen. Der
                    // Rückruf kommt erst, wenn die Anmeldung abgeschlossen
                    // ist; einen Augenblick später zu messen wäre dieselbe
                    // zu frühe Frage, die 1.0.41 gestellt hat.
                    Geraeteschriften.beimStartAnmelden()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        messen()
                    }
                } label: {
                    Label("Noch einmal beim System nachfragen",
                          systemImage: "arrow.clockwise")
                }
            } footer: {
                Text("Das Nachfragen meldet dieselben Schriften noch einmal für diese App an und misst danach. Es ändert nichts am Gerät \u{2014} installiert oder entfernt wird hier nichts.")
            }
        }
        .navigationTitle("Schriften prüfen")
        .navigationBarTitleDisplayMode(.inline)
        // Gemessen wird beim Öffnen und nicht im Körper: Der Lauf geht über
        // alle Familien des Geräts, und ein Körper läuft bei jedem
        // Neuzeichnen (die Lehre aus 1.0.15).
        .task { messen() }
    }

    private func messen() {
        text = Geraeteschriften.probe()
        kopiert = false
    }
}
