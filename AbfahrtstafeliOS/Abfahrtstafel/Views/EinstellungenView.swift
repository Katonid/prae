import SwiftUI

/// Einstellungen — und die Stelle, an der die App sagt, was sie NICHT weiß.
///
/// Der Abschnitt „Woher die Zahlen kommen" ist kein Beiwerk. Eine App, die
/// fremde Echtzeitdaten zeigt, muss sagen, wessen Daten das sind und wo sie
/// enden; sonst liest jemand eine Verspätung als Zusage. Dieselbe Linie wie in
/// den anderen Apps dieses Repos: lieber eine ehrliche Lücke als ein
/// beruhigender Satz.
struct EinstellungenView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Umkreis", selection: $model.umkreis) {
                        Text("200 m").tag(200)
                        Text("500 m").tag(500)
                        Text("1 km").tag(1000)
                        Text("2 km").tag(2000)
                        Text("3 km").tag(3000)
                    }
                    Picker("Abfahrten je Abfrage", selection: $model.anzahl) {
                        Text("20").tag(20)
                        Text("40").tag(40)
                        Text("80").tag(80)
                    }
                } header: {
                    Text("Was die Tafel zeigt")
                } footer: {
                    Text("Der Umkreis gilt um die nächstgelegene Haltestelle, nicht um den Punkt selbst — so fragt der Fahrplandienst. Auf dem Land kann die nächste Haltestelle weit weg sein; der Kreis liegt dann dort.")
                }
                .onChange(of: model.umkreis) { _, _ in model.laden() }
                .onChange(of: model.anzahl) { _, _ in model.laden() }

                Section {
                    LabeledContent("Dienst", value: model.dienst.quellenname)
                    Link(destination: model.dienst.quellenadresse) {
                        Label("transitous.org", systemImage: "arrow.up.right.square")
                    }
                } header: {
                    Text("Woher die Zahlen kommen")
                } footer: {
                    Text("""
                        Transitous führt die offenen Fahrplandaten der Verkehrsverbünde zusammen — in Deutschland über DELFI, dazu große Teile Europas. Kein Schlüssel, kein Konto, keine Anmeldung.

                        Was das heißt: Echtzeit gibt es nur dort, wo der Verbund sie herausgibt. Steht bei einer Abfahrt „Plan", hat niemand nachgesehen — die App zeigt dann die Fahrplanzeit und behauptet keine Pünktlichkeit. Und auch eine Echtzeitmeldung ist eine Meldung und keine Zusage.
                        """)
                }

                Section {
                    Text("Diese App hat kein Konto, keinen Server und keine Anmeldung. Gemerkte Haltestellen liegen auf dem Gerät.")
                    Text("An den Fahrplandienst geht bei jeder Abfrage die Koordinate, um die es gerade geht — sonst wüsste er nicht, welche Haltestellen gemeint sind. Ein Kennzeichen des Geräts oder der Person wird nicht mitgeschickt.")
                } header: {
                    Text("Was das Gerät verlässt")
                }

                Section {
                    LabeledContent("Fassung", value: fassung)
                } footer: {
                    Text("Fahrpläne sind Auskünfte, keine Zusagen. Wer einen Anschluss erreichen muss, plant einen Puffer ein.")
                }
            }
            .navigationTitle("Einstellungen")
        }
    }

    private var fassung: String {
        let nummer = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let bau = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(nummer) (\(bau))"
    }
}

#Preview {
    EinstellungenView()
        .environmentObject(AppModel(dienst: Musterdienst()))
}
