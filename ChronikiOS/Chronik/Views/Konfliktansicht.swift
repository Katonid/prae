import SwiftUI

// ZWEI FASSUNGEN NEBENEINANDER (ab 1.0.102).
//
// Gemeldet 09/2026: „Ich weiß nicht, von welchem Gerät und von wann diese
// unterschiedlichen Fassungen sind. Deshalb kann ich auch nicht
// beurteilen, welches die aktuelle ist, die ich behalten will."
//
// Bis 1.0.101 stand in den Einstellungen der nackte Dateiname und daneben
// zwei Knöpfe. Hier steht jetzt, was in beiden Dateien steht — und zwar
// GEGENEINANDER: Wann sie gesichert wurden (mit Sekunden), auf welchem
// Gerät, wie viele Tage, Fotos, Seiten und Zeichen sie tragen, und was
// davon sich unterscheidet.
//
// **Was die App nicht weiß, sagt sie.** Den Gerätenamen vermerkt sie erst
// seit 1.0.102; in jeder älteren Datei steht er nicht, und nachtragen
// lässt er sich nicht. Ein geratenes Gerät wäre bei dieser Entscheidung
// die teuerste Auskunft überhaupt.
struct Konfliktansicht: View {
    let befund: Konfliktbefund
    var nehmen: () -> Void
    var verwerfen: () -> Void

    @Environment(\.dismiss) private var schliessen
    @State private var fragtVerwerfen = false

    var body: some View {
        Form {
            wennUnlesbar
            standabschnitt("Diese Fassung", befund.beiseite, beiseite: true)
            standabschnitt("Im Regal \u{2014} sie gilt gerade", befund.geltend, beiseite: false)
            unterschied
            geraetehinweis
            taten
            herkunft
        }
        .navigationTitle(befund.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Diese Fassung verwerfen?",
                            isPresented: $fragtVerwerfen, titleVisibility: .visible) {
            Button("Verwerfen", role: .destructive) {
                verwerfen()
                schliessen()
            }
            Button("Behalten", role: .cancel) { }
        } message: {
            Text("Sie wird gelöscht und ist danach weg. Die Fassung im Regal bleibt, "
                 + "wie sie ist.")
        }
    }

    // MARK: - Die beiden Stände

    @ViewBuilder
    private func standabschnitt(_ titel: String, _ stand: Konfliktstand?,
                                beiseite: Bool) -> some View {
        Section {
            if let stand {
                LabeledContent("Gesichert am", value: Konfliktbefund.zeit(stand.geaendert))
                LabeledContent("Gesichert auf") {
                    Text(stand.geraet ?? "nicht vermerkt")
                        .foregroundStyle(stand.geraet == nil ? Color.secondary : Color.primary)
                }
                LabeledContent("Tage", value: "\(stand.tage)")
                LabeledContent("Fotos", value: "\(stand.fotos)")
                LabeledContent("Seiten", value: "\(stand.seiten)")
                LabeledContent("Tagebuchtext", value: "\(stand.zeichen) Zeichen")
                if stand.name != befund.name {
                    LabeledContent("Heißt", value: stand.name)
                }
            } else if beiseite {
                Text("Diese Datei lässt sich nicht lesen.")
                    .foregroundStyle(.orange)
            } else {
                Text("Es gibt sie nicht mehr \u{2014} das Buch ist nicht im Regal.")
                    .foregroundStyle(.orange)
            }
        } header: {
            Text(titel)
        }
    }

    @ViewBuilder
    private var wennUnlesbar: some View {
        if befund.beiseite == nil {
            Section {
                Text("Die beiseitegelegte Datei ist nicht zu lesen. Was in ihr steht, "
                     + "lässt sich hier nicht zeigen \u{2014} verworfen wird sie deshalb "
                     + "trotzdem nicht von selbst.")
                .font(.footnote)
            }
        }
    }

    // MARK: - Der Unterschied

    @ViewBuilder
    private var unterschied: some View {
        if !befund.unterschiede.isEmpty {
            Section {
                ForEach(befund.unterschiede, id: \.self) { zeile in
                    Label {
                        Text(zeile)
                    } icon: {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
            } header: {
                Text("Unterschied")
            } footer: {
                Text("Gezählt wird, was sich zählen lässt. Welche Fassung die richtige "
                     + "ist, sagt keine Zahl \u{2014} das weiß nur, wer an dem Tag "
                     + "daran gearbeitet hat.")
            }
        }
    }

    @ViewBuilder
    private var geraetehinweis: some View {
        if befund.beiseite?.geraet == nil || befund.geltend?.geraet == nil {
            Section {
                Text("Auf welchem Gerät eine Fassung entstanden ist, vermerkt die App "
                     + "erst seit Fassung 1.0.102. Wo oben \u{201E}nicht vermerkt\u{201C} "
                     + "steht, wurde die Datei vorher geschrieben \u{2014} nachtragen "
                     + "lässt sich das nicht. Ab jetzt steht es in jedem Buch; den Namen "
                     + "dieses Geräts setzt du in den Einstellungen unter "
                     + "\u{201E}Abgleich\u{201C}.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Entscheiden

    @ViewBuilder
    private var taten: some View {
        Section {
            Button {
                nehmen()
                schliessen()
            } label: {
                Label("Diese Fassung nehmen", systemImage: "arrow.uturn.backward")
            }
            .disabled(befund.beiseite == nil)
            Button(role: .destructive) {
                fragtVerwerfen = true
            } label: {
                Label("Diese Fassung verwerfen", systemImage: "trash")
            }
        } footer: {
            Text("\u{201E}Nehmen\u{201C} tauscht die beiden: Diese Fassung kommt ins "
                 + "Regal, und die bisherige wird ihrerseits beiseitegelegt und steht "
                 + "danach hier \u{2014} es geht also nichts verloren, und der Tausch "
                 + "lässt sich zurücknehmen. Die Fotos bleiben in beiden Fällen "
                 + "unberührt: Beide Fassungen teilen sich denselben Bilderordner.")
        }
    }

    @ViewBuilder
    private var herkunft: some View {
        Section {
            if let bemerkt = befund.bemerkt {
                LabeledContent("Konflikt bemerkt", value: Konfliktbefund.zeit(bemerkt))
            }
            Text(befund.ort.lastPathComponent)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        } header: {
            Text("Woher sie kommt")
        } footer: {
            Text("Zwei Geräte haben dasselbe Buch geändert, ohne sich dazwischen zu "
                 + "sehen. Die App hat die jüngere Fassung ins Regal gestellt und die "
                 + "andere liegen gelassen \u{2014} entschieden hat sie allein nach der "
                 + "Uhrzeit, nicht nach dem Inhalt.")
        }
    }
}

// Die Zeile in den Einstellungen: so viel, dass man nicht tippen MUSS, um
// das Wichtigste zu sehen — und ein Weg hinein für alles andere.
struct Konfliktzeile: View {
    let befund: Konfliktbefund

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(befund.name)
                .font(.body)
            if let beiseite = befund.beiseite {
                zeile("Liegt hier", beiseite)
            } else {
                Text("Nicht lesbar")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let geltend = befund.geltend {
                zeile("Im Regal", geltend)
            }
        }
    }

    private func zeile(_ wort: String, _ stand: Konfliktstand) -> some View {
        // Zusammengesetzt wird VOR dem Körper: Eine `+`-Kette mit
        // Interpolation darin ist genau das, woran der Typprüfer in 1.0.38
        // aufgegeben hat.
        var text = wort + ": " + Konfliktbefund.zeit(stand.geaendert)
        text += " \u{00B7} " + (stand.geraet ?? "Gerät nicht vermerkt")
        return Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
