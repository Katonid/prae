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
                        Text("120").tag(120)
                        Text("200").tag(200)
                    }
                } header: {
                    Text("Was die Tafel zeigt")
                } footer: {
                    Text("Der Umkreis gilt um die nächstgelegene Haltestelle, nicht um den Punkt selbst — so fragt der Fahrplandienst. Auf dem Land kann die nächste Haltestelle weit weg sein; der Kreis liegt dann dort.\n\nDie Zahl gilt je Abfrage. In einer Innenstadt kauft eine höhere vor allem mehr Busse und Trams: Gemessen decken vierzig Abfahrten dort rund drei Minuten ab. Züge, Fernbusse und Fähren werden davon nicht knapper — sie haben seit 1.1.10 eine eigene Abfrage und damit ihr eigenes Zeitfenster.")
                }
                .onChange(of: model.umkreis) { _, _ in model.laden() }
                .onChange(of: model.anzahl) { _, _ in model.laden() }

                Section {
                    LabeledContent("1. Transitous", value: "Deutschland, Österreich, Schweiz")
                    LabeledContent("2. Verkehrsverbund vor Ort", value: "wo einer antwortet")
                    LabeledContent("Betriebsmeldungen", value: "nur vom Verbund")
                    LabeledContent("3. Zwischenspeicher", value: "ohne Netz")
                    Link(destination: model.dienst.quellenadresse) {
                        Label("transitous.org", systemImage: "arrow.up.right.square")
                    }
                } header: {
                    Text("Woher die Zahlen kommen")
                } footer: {
                    Text("""
                        Die App fragt der Reihe nach. Transitous führt die offenen Fahrplandaten der Verkehrsverbünde zusammen — Deutschland, Österreich, die Schweiz und große Teile Europas; kein Schlüssel, kein Konto. Das ist die Quelle für alles: Haltestellen, Abfahrten, Zwischenhalte und die Strecke auf der Karte.

                        Antwortet sie nicht, fragt die App den Verkehrsverbund vor Ort — geprüft sind MVV, VRR, VVS, DING, VRN, VVO und efa-bw sowie opendata.ch für die Schweiz. Wo keiner davon zuständig ist, geht es ohne zweite Quelle weiter; die erste deckt die Gegend trotzdem ab. Antwortet auch die nicht, zeigt die App den zuletzt geholten Stand.

                        Was das heißt: Echtzeit gibt es nur dort, wo der Verbund sie herausgibt — in Deutschland und der Schweiz fast überall, in Österreich je nach Gegend. Steht bei einer Abfahrt „Plan", hat niemand nachgesehen; die App zeigt dann die Fahrplanzeit und behauptet keine Pünktlichkeit. Und auch eine Echtzeitmeldung ist eine Meldung und keine Zusage.

                        Zeiten aus dem Zwischenspeicher sind immer als solche gekennzeichnet, mit Uhrzeit, und ihre Minutenziffern zählen nicht weiter. Eine alte Tafel, die weiterzählt, sähe richtig aus und wäre es nicht.

                        Zeilen ohne Pfeil lassen sich nicht öffnen: Die Schnittstellen der Verbünde geben eine Abfahrtstafel heraus, aber keinen Fahrtlauf mit Zwischenhalten.

                        Betriebsmeldungen — Umleitung, Sperrung, verlegte Haltestelle — kommen AUSSCHLIESSLICH vom Verbund vor Ort. Die Quelle der Abfahrtszeiten führt keine einzige; sie kennt Verspätung und Ausfall, aber nicht den Grund und nicht die Folgen. Wo kein Verbund zuständig ist, steht hier deshalb nichts — und das heißt NICHT, dass alles planmäßig fährt, sondern dass niemand nachgesehen hat.
                        """)
                }

                Section {
                    NavigationLink {
                        ZugaengeView()
                    } label: {
                        Label("Eigene Zugänge", systemImage: "key")
                    }
                } header: {
                    Text("Schlüssel, die Ihnen gehören")
                } footer: {
                    Text("Manche Fahrplandienste antworten nur mit einem Zugangsschlüssel. Ein Schlüssel, der in einer App mitgeliefert wird, ist keiner — einer, den Sie selbst holen, schon. Hier lässt er sich eintragen; er liegt dann in Ihrem Schlüsselbund und verlässt das Gerät nur in seine eigene Abfrage.")
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
        .environmentObject(Standortdienst())
}
