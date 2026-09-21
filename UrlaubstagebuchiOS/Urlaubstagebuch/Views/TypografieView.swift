import SwiftUI

// Die Schrift des ganzen Buches.
//
// Was hier steht, gilt überall — außer dort, wo jemand an einer einzelnen
// Stelle etwas anderes gewählt hat. Diese Reihenfolge ist der Kern: Erst
// die Regel, dann die Ausnahme. Wer das Buch später von Serifen auf eine
// Groteske umstellt, will nicht siebzig Textblöcke einzeln nachziehen.
struct TypografieView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen
    @State private var rolle: Schriftrolle = .flieText

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Schriftart überall", selection: Binding(
                        get: { werk.reise.typografie.flieText.familie },
                        set: { neu in
                            werk.merken()
                            werk.reise.typografie.familieUeberall(neu)
                        }
                    )) {
                        ForEach(Schriftfamilie.vorhandene) { familie in
                            Text(familie.name).tag(familie)
                        }
                    }
                    HStack {
                        Text("Alle Größen")
                        Spacer()
                        Button("kleiner") {
                            werk.merken()
                            werk.reise.typografie.groessenSkalieren(0.92)
                        }
                        .buttonStyle(.bordered)
                        Button("größer") {
                            werk.merken()
                            werk.reise.typografie.groessenSkalieren(1.09)
                        }
                        .buttonStyle(.bordered)
                    }
                } header: {
                    Text("Für das ganze Buch")
                } footer: {
                    Text("Nur die Schriftfamilien, die dieses Gerät wirklich mitbringt, stehen zur Wahl — eine, die dann doch die Systemschrift zeichnet, wäre eine Auskunft, die nicht stimmt.")
                }

                Picker("Wofür", selection: $rolle) {
                    ForEach(Schriftrolle.allCases) { rolle in
                        Text(rolle.name).tag(rolle)
                    }
                }
                .pickerStyle(.segmented)

                schriftAbschnitt

                Section {
                    probe
                } header: {
                    Text("Probe")
                } footer: {
                    Text("Die Probe ist mit demselben Setzer gezeichnet, der die Seite und das PDF setzt — was hier steht, steht so auch im Buch.")
                }
            }
            .navigationTitle("Schrift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        // Eine andere Schriftgröße heißt eine andere
                        // Textmenge je Seite. Die unberührten Tage werden
                        // deshalb neu gesetzt; die von Hand gearbeiteten
                        // bleiben, wie sie sind.
                        werk.alleNeuAnordnen(nurUnberuehrte: true)
                        schliessen()
                    }
                }
            }
        }
    }

    private var bild: Binding<Schriftbild> {
        Binding(
            get: { werk.reise.typografie[rolle] },
            set: { werk.reise.typografie[rolle] = $0 }
        )
    }

    private var schriftAbschnitt: some View {
        Section(rolle.name) {
            Picker("Schriftart", selection: bild.familie) {
                ForEach(Schriftfamilie.vorhandene) { familie in
                    Text(familie.name).tag(familie)
                }
            }
            Stepper(value: bild.groesse, in: 4...80, step: 0.5) {
                LabeledContent("Größe", value: String(format: "%.1f pt", bild.wrappedValue.groesse))
            }
            Picker("Ausrichtung", selection: bild.ausrichtung) {
                ForEach(Ausrichtung.allCases) { art in
                    Label(art.name, systemImage: art.symbol).tag(art)
                }
            }
            .pickerStyle(.menu)
            Toggle("Fett", isOn: bild.fett)
            Toggle("Kursiv", isOn: bild.kursiv)
            Toggle("Großbuchstaben", isOn: bild.versalien)
            Toggle("Silben trennen", isOn: bild.trennung)
            VStack(alignment: .leading) {
                LabeledContent("Zeilenabstand",
                               value: String(format: "%.2f", bild.wrappedValue.zeilenabstand))
                Slider(value: bild.zeilenabstand, in: 0.9...2.6)
            }
            VStack(alignment: .leading) {
                LabeledContent("Absatzabstand",
                               value: String(format: "%.0f pt", bild.wrappedValue.absatzabstand))
                Slider(value: bild.absatzabstand, in: 0...30)
            }
            VStack(alignment: .leading) {
                LabeledContent("Sperrung", value: String(format: "%.1f", bild.wrappedValue.sperrung))
                Slider(value: bild.sperrung, in: -1...6)
            }
            ColorPicker("Farbe", selection: Binding(
                get: { bild.wrappedValue.farbe.farbe },
                set: { bild.wrappedValue.farbe = Farbwert($0) }
            ))
            if bild.wrappedValue.ausrichtung == .blocksatz, !bild.wrappedValue.trennung {
                // Blocksatz ohne Trennung reißt Löcher in die Zeilen. Getrennt
                // wird hier nicht von uns, sondern von Apples deutschem
                // Wörterbuch — eine selbst gebaute Trennung wäre verboten,
                // die deutsche ist nicht ableitbar.
                Label("Blocksatz ohne Silbentrennung reißt Löcher in die Zeilen.",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var probe: some View {
        Textkasten(text: probetext, bild: bild.wrappedValue)
            .frame(height: probehoehe)
            .padding(.vertical, 4)
    }

    private var probetext: String {
        switch rolle {
        case .titel: return "Über den Pass nach Süden"
        case .datum: return Tagesdatum(Date()).lang
        case .bildunterschrift: return "Blick vom Hafen zurück auf die Altstadt"
        case .flieText:
            return "Am Morgen lag noch Nebel über dem Tal. Wir sind früh los, weil die Straße über den Pass am Nachmittag voll wird, und haben unterwegs an einer Quelle gehalten. Die letzten Kehren waren steil genug, dass niemand mehr geredet hat."
        }
    }

    private var probehoehe: CGFloat {
        let breite: CGFloat = 320
        return max(Textmass.hoehe(probetext, bild: bild.wrappedValue, breite: breite), 30)
    }
}
