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
                    NavigationLink {
                        SchriftwahlView(auswahl: Binding(
                            get: { werk.reise.typografie.flieText.familie },
                            set: { neu in
                                werk.merken()
                                werk.reise.typografie.familieUeberall(neu)
                            }
                        ), titel: "Schrift überall")
                    } label: {
                        LabeledContent("Schriftart überall",
                                       value: werk.reise.typografie.flieText.familie.vollerName)
                    }
                    // ZWEI ZUGÄNGE ZU DERSELBEN SEITE (ab 1.0.43). Wer
                    // eine selbst installierte Schrift sucht, sucht sie
                    // nicht hinter „Schriftart überall" — dort steht der
                    // Name der gerade gewählten Schrift, und das liest sich
                    // wie eine Auswahlliste. Dieselbe Lehre wie beim
                    // Fotostil in 1.0.10: Der Menüpunkt muss sagen, was
                    // dahinterliegt.
                    NavigationLink {
                        SchriftwahlView(auswahl: Binding(
                            get: { werk.reise.typografie.flieText.familie },
                            set: { neu in
                                werk.merken()
                                werk.reise.typografie.familieUeberall(neu)
                            }
                        ), titel: "Schrift überall")
                    } label: {
                        Label("Selbst installierte Schriften\u{2026}",
                              systemImage: "textformat")
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
                    Text("Zur Wahl steht, was dieses Gerät wirklich hergibt — eine Schrift, die dann doch die Systemschrift zeichnet, wäre eine Auskunft, die nicht stimmt. Eine selbst installierte Schrift ist dieser App nicht von selbst bekannt; der Abschnitt ganz oben in der Schriftwahl holt sie und sagt, was dabei herauskam.")
                }

                Picker("Wofür", selection: $rolle) {
                    ForEach(Schriftrolle.allCases) { rolle in
                        Text(rolle.kurzname).tag(rolle)
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
            NavigationLink {
                SchriftwahlView(auswahl: bild.familie, titel: rolle.name)
            } label: {
                LabeledContent("Schriftart", value: bild.wrappedValue.familie.vollerName)
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
            trennungshinweise
            ableitungshinweis
        }
    }

    // DIE ZWEITE ÜBERSCHRIFT WIRD ABGELEITET, SOLANGE NIEMAND SIE
    // EINSTELLT — und das steht da, statt dass man es merkt.
    //
    // Solange sie abgeleitet ist, folgt sie der Überschrift: Wer die
    // Buchschrift oder den Stil wechselt, bekommt sie passend mit.
    // Der erste Griff an einen der Regler oben löst sie heraus; ab da ist
    // sie eine eigene Einstellung. Dieselbe Regel wie bei einer
    // `Schriftabweichung`, und derselbe Weg zurück.
    @ViewBuilder
    private var ableitungshinweis: some View {
        if rolle == .unterueberschrift {
            if werk.reise.typografie.unterueberschrift == nil {
                Label("Abgeleitet aus der Überschrift — dieselbe Schrift, gut halb so groß, kursiv. Sobald du hier etwas änderst, steht sie für sich und folgt der Überschrift nicht mehr.",
                      systemImage: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    werk.merken()
                    werk.reise.typografie.unterueberschrift = nil
                } label: {
                    Label("Wieder aus der Überschrift ableiten",
                          systemImage: "arrow.uturn.backward")
                }
            }
        }
    }

    // WAS DER SCHALTER WIRKLICH TUT — und wo er nichts tut.
    //
    // Bis 1.0.39 stand hier nur die erste Zeile, und sie verschwand, sobald
    // man die Trennung einschaltete. Getrennt wurde trotzdem nie (siehe
    // `Model/Silbentrennung.swift`): Die App nahm die Warnung zurück und
    // ließ die Löcher stehen. Ein Hinweis, der das Gegenteil dessen sagt,
    // was gilt, ist schlimmer als keiner.
    @ViewBuilder
    private var trennungshinweise: some View {
        if bild.wrappedValue.ausrichtung == .blocksatz, !bild.wrappedValue.trennung {
            Label("Blocksatz ohne Silbentrennung reißt Löcher in die Zeilen.",
                  systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        if bild.wrappedValue.trennung, !Silbentrennung.verfuegbar {
            Label("Dieses Gerät hat kein deutsches Trennwörterbuch — es wird nichts getrennt.",
                  systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        if bild.wrappedValue.trennung, bild.wrappedValue.versalien {
            Label("In Großbuchstaben wird nicht getrennt.",
                  systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if bild.wrappedValue.trennung, Silbentrennung.verfuegbar,
           !bild.wrappedValue.versalien
        {
            Label("Die Trennstellen kommen aus dem Wörterbuch des Geräts, nicht aus dieser App.",
                  systemImage: "text.book.closed")
                .font(.caption)
                .foregroundStyle(.secondary)
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
        case .unterueberschrift: return "Lissabon — Alfama"
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
