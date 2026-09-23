import SwiftUI

// DAS SEITENFORMAT WÄHLEN — mit Vorlagen, freiem Maß und Umrechnung.
//
// Ansage des Nutzers, 09/2026: „Ich möchte verschiedene Maßvorlagen für die
// Seiten haben. DIN A4 Hochkant, DIN A4 Breit, DIN A5 dasselbe und
// quadratisch 28 x 28 cm. Ansonsten möchte ich aber auch die Möglichkeit
// haben, eine Seite frei skalieren zu können."
//
// Ein eigener Bildschirm und keine Zeile in der Gestaltung: Das Format ist
// die eine Entscheidung, an der ALLES hängt — Satzspiegel, Blockrahmen,
// Schriftgrößen —, und seit 1.0.27 lässt es sich mit Inhalt wechseln. Das
// gehört nicht hinter einen Auswahlknopf in einer Liste.
struct FormatView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    @State private var breite: String = ""
    @State private var hoehe: String = ""
    @State private var wechsel: Formatwechsel.Vorschau?
    // EIGENE VORLAGEN (ab 1.0.52). Sie liegen in den Voreinstellungen und
    // nicht im Buch — welche Formate ein Druckdienst anbietet, ist keine
    // Eigenschaft dieser einen Reise. Gemerkt werden sie hier als
    // `@State`, weil die Liste sonst bei jedem Zeichnen aus `UserDefaults`
    // gelesen und dekodiert würde.
    @State private var eigene: [Formatvorlagen.Eintrag] = []
    @State private var sichern = false
    @State private var neuerName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Jetzt", value: jetzt.name)
                    LabeledContent("Endformat", value: jetzt.masstext)
                    LabeledContent("Bogen mit Anschnitt", value: bogentext)
                } header: {
                    Text("Dieses Buch")
                } footer: {
                    Text("Das Endformat ist die Seite, wie sie nach dem Schneiden in der Hand liegt. Der Bogen ist das, was im PDF steht — Endformat plus Anschnitt. Beide stehen als TrimBox und BleedBox in der Datei; daran erkennt der Druckdienst, wo geschnitten wird.")
                }

                Section {
                    ForEach(Seitenformat.vorlagen) { vorlage in
                        Button {
                            formatWuenschen(vorlage)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vorlage.name)
                                        .foregroundStyle(.primary)
                                    Text(vorlage.masstext)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Seitenriss(format: vorlage)
                                if vorlage.vorlage == jetzt.vorlage {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Vorlagen")
                } footer: {
                    Text("Die Maße folgen der Formatangabe des jeweiligen Anbieters und sind nicht gemessen — verbindlich ist, was der Druckdienst nennt. Wer ein anderes braucht, tippt es unten ein und sichert es als eigene Vorlage.")
                }

                if !eigene.isEmpty {
                    Section {
                        ForEach(eigene) { eintrag in
                            Button {
                                formatWuenschen(eintrag.format)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(eintrag.name)
                                            .foregroundStyle(.primary)
                                        Text(eintrag.format.masstext)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Seitenriss(format: eintrag.format)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Formatvorlagen.entfernen(eintrag)
                                    eigene = Formatvorlagen.alle
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text("Eigene Vorlagen")
                    } footer: {
                        Text("Gemerkt auf diesem Gerät, nicht im Buch. Angewandt ergeben sie ein freies Maß — das Buch trägt danach die Zahlen und nicht den Namen, damit es sich auch auf einem Gerät öffnen lässt, das diese Vorlage nicht kennt.")
                    }
                }

                Section {
                    HStack {
                        Text("Breite")
                        Spacer()
                        TextField("mm", text: $breite)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("mm").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Höhe")
                        Spacer()
                        TextField("mm", text: $hoehe)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("mm").foregroundStyle(.secondary)
                    }
                    Button("Eigenes Maß übernehmen") {
                        if let eigen = eigenesMass { formatWuenschen(eigen) }
                    }
                    .disabled(eigenesMass == nil)
                    Button {
                        guard let eigen = eigenesMass else { return }
                        neuerName = Formatvorlagen.vorschlag(breite: eigen.breite,
                                                             hoehe: eigen.hoehe)
                        sichern = true
                    } label: {
                        Label("Als eigene Vorlage sichern…", systemImage: "square.and.arrow.down")
                    }
                    .disabled(eigenesMass == nil)
                } header: {
                    Text("Eigenes Maß")
                } footer: {
                    Text(eigenhinweis)
                        .foregroundStyle(eigenesMass == nil && !breite.isEmpty ? .red : .secondary)
                }
            }
            .navigationTitle("Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            .task {
                if breite.isEmpty { breite = zahl(jetzt.breite) }
                if hoehe.isEmpty { hoehe = zahl(jetzt.hoehe) }
                eigene = Formatvorlagen.alle
            }
            .alert("Vorlage sichern", isPresented: $sichern) {
                TextField("Name", text: $neuerName)
                Button("Sichern") {
                    guard let eigen = eigenesMass else { return }
                    let name = neuerName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    Formatvorlagen.sichern(.init(name: name, breite: eigen.breite,
                                                 hoehe: eigen.hoehe))
                    eigene = Formatvorlagen.alle
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Das Maß wird auf diesem Gerät gemerkt und steht danach oben in der Liste. Das Buch selbst ändert sich dadurch nicht \u{2014} dafür ist \u{201E}Eigenes Maß übernehmen\u{201C} da.")
            }
            // ERST ZEIGEN, DANN ÜBERNEHMEN — dieselbe Regel wie bei jeder
            // Einfuhr dieser App. Ein Formatwechsel fasst jeden Block des
            // Buches an; wer ihn auslöst, soll vorher lesen, was passiert.
            .sheet(item: $wechsel) { vorschau in
                Wechselblatt(werk: werk, vorschau: vorschau) { schliessen() }
            }
        }
    }

    private var jetzt: Seitenformat { werk.reise.format }

    private var bogentext: String {
        let b = werk.reise.gestaltung.bogen(jetzt)
        return "\(Druckmass.mmText(b.width, stellen: 0)) × \(Druckmass.mmText(b.height, stellen: 0))"
    }

    private var eigenesMass: Seitenformat? {
        guard let b = zahlAus(breite), let h = zahlAus(hoehe),
              Seitenformat.gueltig(b), Seitenformat.gueltig(h)
        else { return nil }
        return Seitenformat(breite: b, hoehe: h)
    }

    private var eigenhinweis: String {
        let von = Int(Seitenformat.kleinstesMass)
        let bis = Int(Seitenformat.groesstesMass)
        return "Zwischen \(von) und \(bis) mm je Kante. Kleiner bliebe vom Satzspiegel nichts übrig — die Ränder allein wären breiter als die Seite; größer nimmt kein Druckdienst dieser Größenordnung an. Ein Komma ist erlaubt."
    }

    private func zahlAus(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces))
    }

    private func zahl(_ wert: Double) -> String {
        let gerundet = (wert * 10).rounded() / 10
        if abs(gerundet - gerundet.rounded()) < 0.05 { return String(Int(gerundet.rounded())) }
        return String(format: "%.1f", gerundet).replacingOccurrences(of: ".", with: ",")
    }

    private func formatWuenschen(_ neu: Seitenformat) {
        guard neu.millimeter != jetzt.millimeter else {
            // Dasselbe Maß unter einem anderen Namen — nur die Vorlage
            // vermerken, sonst gäbe es eine Umrechnung mit Faktor 1.
            werk.merken()
            werk.reise.format = neu
            return
        }
        wechsel = Formatwechsel.vorschau(reise: werk.reise, auf: neu)
    }
}

// Ein kleiner Riss des Formats — er sagt in einem Blick, was drei Zahlen
// nicht sagen: ob es hoch, quer oder quadratisch ist.
private struct Seitenriss: View {
    let format: Seitenformat

    var body: some View {
        let hoehe: Double = 26
        let breite = hoehe * max(format.verhaeltnis, 0.3)
        Rectangle()
            .strokeBorder(Color.secondary, lineWidth: 1)
            .frame(width: min(breite, 40), height: hoehe)
            .accessibilityHidden(true)
    }
}

// MARK: - Das Blatt, das vor der Umrechnung steht

private struct Wechselblatt: View {
    @ObservedObject var werk: Reisewerk
    let vorschau: Formatwechsel.Vorschau
    let fertig: () -> Void
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Von", value: "\(vorschau.alt.name) · \(vorschau.alt.masstext)")
                    LabeledContent("Auf", value: "\(vorschau.neu.name) · \(vorschau.neu.masstext)")
                    LabeledContent("Faktor", value: vorschau.prozent + " %")
                } header: {
                    Text("Der Wechsel")
                }

                Section {
                    LabeledContent("Blöcke", value: "\(vorschau.bloecke)")
                    LabeledContent("Fließtext",
                                   value: "\(pt(vorschau.fliesstextAlt)) → \(pt(vorschau.fliesstextNeu))")
                } header: {
                    Text("Was mitgerechnet wird")
                } footer: {
                    Text("Mitskaliert wird alles, was eine Länge ist: die Rahmen aller Blöcke, die Ränder, die Schriftgrößen, Innenabstände und Linienbreiten. Nicht mitskaliert wird der Anschnitt — drei Millimeter sind drei Millimeter, egal wie groß die Seite ist; wer ihn mitschrumpfte, bekäme beim Schneiden einen weißen Faden. Der Ausschnitt eines Fotos bleibt ebenfalls, denn er ist ein Anteil am Bild und keine Länge.")
                }

                if !vorschau.aehnlich {
                    Section {
                        Label("Die beiden Formate haben ein anderes Seitenverhältnis.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("Gerechnet wird mit dem kleineren der beiden Verhältnisse, damit kein Block über die Seite hinausläuft. Der Satz wird dadurch nicht falsch, aber an einer Kante bleibt mehr Luft als vorher. A4 und A5 haben dasselbe Verhältnis — dort geht die Umrechnung ohne Rest auf.")
                    }
                }

                Section {
                    Button("Format wechseln und Inhalt mitrechnen") {
                        werk.merken()
                        Formatwechsel.umrechnen(&werk.reise, auf: vorschau.neu)

                        schliessen()
                        fertig()
                    }
                    Button("Nur das Format wechseln, Inhalt lassen") {
                        werk.merken()
                        werk.reise.format = vorschau.neu

                        schliessen()
                        fertig()
                    }
                } footer: {
                    Text("\u{201E}Inhalt lassen\u{201C} ist der Weg, wenn danach ohnehin alles neu angeordnet werden soll — die Blöcke behalten dann ihre Maße und stehen auf der neuen Seite an ihrer alten Stelle. Beides lässt sich mit \u{201E}Widerrufen\u{201C} zurücknehmen.")
                }
            }
            .navigationTitle("Format wechseln")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
            }
        }
    }

    private func pt(_ wert: Double) -> String {
        String(format: "%.1f pt", wert).replacingOccurrences(of: ".", with: ",")
    }
}

extension Formatwechsel.Vorschau: Identifiable {
    var id: String { alt.id + "-" + neu.id }
}
