import SwiftUI

// WIE DIE KARTEN IM GANZEN BUCH AUSSEHEN (ab 1.0.79).
//
// Frage des Nutzers, 09/2026: „Gibt es eigentlich irgendwo eine Möglichkeit,
// eine globale Einstellung für die Reisepunkte zu treffen? Im vorliegenden
// Fall möchte ich beispielsweise einstellen können, dass überall nur die
// Spur angezeigt wird und nicht die Punkte."
//
// **Es gab sie — und ich habe sie in 1.0.77 selbst versteckt.** Sie lag
// unter „Ränder, Karte, Seitenzahlen…", und genau dieser Menüpunkt wurde
// umbenannt in „Ränder und Druckzugaben…", weil er nach seinem Inhalt
// heißen sollte. Dahinter liegen tatsächlich Anschnitt, Sicherheitsabstand
// und Bundsteg — aber eben auch das Kartenbild, und dessen Name ist mit der
// Umbenennung aus dem Menü verschwunden. Dreizehnte Auflage von „es war da,
// man fand es nicht", und die erste, die aus einer Verbesserung entstanden
// ist.
//
// **Merke: Wer einen Sammelbildschirm nach einem TEIL seines Inhalts
// benennt, macht den anderen Teil unsichtbar.** Die Karten bekommen deshalb
// einen eigenen Menüpunkt — wie „Fotos…" (1.0.10) und „Textfelder…"
// (1.0.12), und aus demselben Grund: Es ist eine Wirkung, die für alle
// gilt, und sie wird dort gesucht, wo die Frage entsteht.
//
// **Kein zweiter Bildschirm für dieselbe Sache:** Gezeigt wird dieselbe
// `KartenbildWahl`, die auch im Inspektor für Tag und einzelne Karte steht,
// und dieselbe Einstellung, die in der Gestaltung lag. Zwei Fassungen
// liefen auseinander — die Regel seit 1.0.10.
struct KartenstilView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                KartenbildWahl(titel: "Kartenbild", bild: $werk.reise.kartenbild)

                Section {
                    ColorPicker("Akzentfarbe", selection: Binding(
                        get: { werk.reise.akzent.farbe },
                        set: { werk.reise.akzent = Farbwert($0) }
                    ))
                    VStack(alignment: .leading) {
                        LabeledContent("Breite der Karte",
                                       value: "\(Int(werk.reise.gestaltung.kartenanteil * 100)) %")
                        Slider(value: $werk.reise.gestaltung.kartenanteil, in: 0.2...0.6)
                    }
                } header: {
                    Text("Karte im Satz")
                } footer: {
                    // Die Akzentfarbe steht hier, weil die Linie der Spur
                    // sie trägt — und sie gibt es nur EINMAL: Ein zweites
                    // Feld „Linienfarbe" gab es in 1.0.0 und lief
                    // unweigerlich auseinander.
                    Text("Die Akzentfarbe zeichnet die Spur auf der Karte, solange unter „Linienfarben“ nichts anderes gewählt ist; sie gilt im ganzen Buch und nicht nur hier.")
                }

                // RAND UND SCHATTEN ALLER KARTEN (ab 1.0.119, Frage des
                // Nutzers 09/2026: „Kann ich global an den Karten einen Rand
                // einstellen?"). Dieselben Felder wie bei den Fotos.
                Section {
                    VStack(alignment: .leading) {
                        LabeledContent("Linie ringsum",
                                       value: String(format: "%.1f pt", werk.reise.gestaltung.kartenrandbreite)
                                           .replacingOccurrences(of: ".", with: ","))
                        Slider(value: $werk.reise.gestaltung.kartenrandbreite, in: 0...6, step: 0.5)
                    }
                    ColorPicker("Farbe der Linie", selection: Binding(
                        get: { (werk.reise.gestaltung.kartenrandfarbe ?? .leise).farbe },
                        set: { werk.reise.gestaltung.kartenrandfarbe = Farbwert($0) }
                    ), supportsOpacity: false)
                    Picker("Schatten", selection: Binding(
                        get: { werk.reise.gestaltung.kartenschatten },
                        set: { werk.reise.gestaltung.kartenschatten = $0 }
                    )) {
                        Text("Wie die Fotos (\(werk.reise.gestaltung.fotoschatten.name))")
                            .tag(Schattenart?.none)
                        ForEach(Schattenart.allCases) { art in
                            Text(art.name).tag(Schattenart?.some(art))
                        }
                    }
                    Button("Abweichungen einzelner Karten aufheben") {
                        werk.kartenwirkungVereinheitlichen()
                    }
                } header: {
                    Text("Rand und Schatten aller Karten")
                } footer: {
                    Text("Die Linie liegt innen an der Kante der Karte. Eine einzelne Karte darf abweichen \u{2014} im Inspektor (Pinsel), wenn sie gewählt ist. Karten, die vor dieser Fassung gesetzt wurden, tragen den Schatten des Stils fest in sich; \u{201E}Abweichungen aufheben\u{201C} lässt sie wieder dieser Einstellung folgen.")
                }

                // DIE FARBEN DER LINIEN (ab 1.0.114, Ansage des Nutzers
                // 09/2026 in Fernweh: „Insgesamt möchte ich die Farben auf
                // der Karte einstellen können und auch dies soll …an
                // Fotobuch übergeben werden."). Die Reisespur folgt weiter
                // der Akzentfarbe — die Regel von oben —, bis jemand
                // ausdrücklich eine eigene wählt; „wie Akzentfarbe" führt
                // zurück. Wanderungen und Autofahrten sind andere Linien.
                Section {
                    Toggle("Reisespur wie Akzentfarbe", isOn: Binding(
                        get: { werk.reise.linienfarben?.reisespur == nil },
                        set: { gleich in
                            var neu = werk.reise.linienfarben ?? Linienfarben()
                            neu.reisespur = gleich ? nil : werk.reise.akzent
                            werk.reise.linienfarben = neu
                        }
                    ))
                    if werk.reise.linienfarben?.reisespur != nil {
                        ColorPicker("Reisespur", selection: farbe(\.reisespur, vorgabe: werk.reise.akzent),
                                    supportsOpacity: false)
                    }
                    ColorPicker("Wanderungen", selection: farbe(\.wanderung, vorgabe: Linienfarben.wanderVorgabe),
                                supportsOpacity: false)
                    ColorPicker("Autofahrten", selection: farbe(\.fahrt, vorgabe: Linienfarben.fahrtVorgabe),
                                supportsOpacity: false)
                    if werk.reise.linienfarben != nil {
                        Button("Vorgaben wiederherstellen") { werk.reise.linienfarben = nil }
                    }
                } header: {
                    Text("Linienfarben")
                } footer: {
                    Text("Wanderungen und Autofahrten kommen aus Fernweh und stehen auf der Karte in ihrer eigenen Farbe. Die Farben aus Fernweh werden beim Einlesen übernommen, solange hier keine eigenen gewählt sind.")
                }

                // DIE EBENEN (ab 1.0.124, wie in Fernweh 1.0.38/1.0.39):
                // Reihenfolge, Ein/Aus je Linienart, zurücktretende
                // Reisespur. Angezeigt OBEN zuerst — so liegt es auf der
                // Karte; gespeichert wird unten zuerst (Vertrag).
                Section {
                    let oben = Array(werk.reise.ebenen.geltendeFolge.reversed())
                    ForEach(Array(oben.enumerated()), id: \.element) { stelle, art in
                        HStack(spacing: 12) {
                            Button { ebeneVerschieben(stelle, um: -1) } label: {
                                Image(systemName: "chevron.up")
                            }
                            .disabled(stelle == 0)
                            .accessibilityLabel("\(Kartenebenen.name(art)) nach oben")
                            Button { ebeneVerschieben(stelle, um: 1) } label: {
                                Image(systemName: "chevron.down")
                            }
                            .disabled(stelle == oben.count - 1)
                            .accessibilityLabel("\(Kartenebenen.name(art)) nach unten")
                            Toggle(Kartenebenen.name(art), isOn: Binding(
                                get: { werk.reise.ebenen.zeigt(art) },
                                set: { an in
                                    ebenenAendern { ebenen in
                                        var aus = ebenen.ausgeblendet ?? []
                                        aus.removeAll { $0 == art }
                                        if !an { aus.append(art) }
                                        ebenen.ausgeblendet = aus.isEmpty ? nil : aus
                                    }
                                }
                            ))
                        }
                        // Mehrere Knöpfe in einer Zeile: ohne `.borderless`
                        // löste ein Tipp auf die Zeile alle zugleich aus.
                        .buttonStyle(.borderless)
                    }
                    Toggle("Reisespur tritt zurück", isOn: Binding(
                        get: { werk.reise.ebenen.zuruecknehmen },
                        set: { an in ebenenAendern { $0.reisespurZuruecknehmen = an } }
                    ))
                    if werk.reise.kartenebenen != nil {
                        Button("Vorgaben wiederherstellen") { werk.reise.kartenebenen = nil }
                    }
                } header: {
                    Text("Linien auf der Karte")
                } footer: {
                    Text("Oben steht, was auf der Karte oben liegt. Ausgeblendete Linien bleiben im Buch und lassen sich hier wieder einschalten. \u{201E}Reisespur tritt zurück\u{201C} zeichnet die Reisespur während einer Autofahrt oder Wanderung dünn und blass \u{2014} das geht nur, wo ihre Punkte dort noch da sind (Übernahme aus Fernweh ab 1.0.38). Beim Einlesen aus Fernweh kommt all das mit, solange hier nichts gewählt ist.")
                }

                Section {
                    Text("Was hier steht, gilt für ALLE Karten. Ein einzelner Tag und eine einzelne Karte dürfen davon abweichen — das steht im Inspektor (Pinsel) unter \u{201E}Karte\u{201C}, wenn eine Karte gewählt ist. Was dort nicht ausdrücklich gesetzt ist, folgt weiter dieser Einstellung.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Wofür das gilt")
                }
            }
            .navigationTitle("Karten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }

    private func ebenenAendern(_ aendern: (inout Kartenebenen) -> Void) {
        var neu = werk.reise.kartenebenen ?? Kartenebenen()
        aendern(&neu)
        werk.reise.kartenebenen = neu
    }

    // `stelle` zählt von OBEN; gespeichert wird von unten.
    private func ebeneVerschieben(_ stelle: Int, um schritt: Int) {
        var oben = Array(werk.reise.ebenen.geltendeFolge.reversed())
        let ziel = stelle + schritt
        guard oben.indices.contains(stelle), oben.indices.contains(ziel) else { return }
        oben.swapAt(stelle, ziel)
        ebenenAendern { $0.folge = Array(oben.reversed()) }
    }

    private func farbe(_ weg: WritableKeyPath<Linienfarben, Farbwert?>, vorgabe: Farbwert) -> Binding<Color> {
        Binding(
            get: { (werk.reise.linienfarben?[keyPath: weg] ?? vorgabe).farbe },
            set: { neu in
                var farben = werk.reise.linienfarben ?? Linienfarben()
                farben[keyPath: weg] = Farbwert(neu)
                werk.reise.linienfarben = farben
            }
        )
    }
}
