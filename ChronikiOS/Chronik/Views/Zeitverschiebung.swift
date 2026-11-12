import SwiftUI

// MEHRERE ZEITSTEMPEL AUF EINMAL VERSCHIEBEN.
//
// Ansage des Nutzers, 09/2026: „beispielsweise um drei Stunden nach hinten."
// Der Fall dahinter ist der Regelfall auf einer Reise — eine Kamera, deren
// Uhr auf der Zeit von zu Hause stand, oder eine Spur aus einer fremden App
// ohne Zonenangabe.
//
// Das Blatt RECHNET VOR, statt zu versprechen: Es nennt die Zahl der
// gewählten Punkte, die Punkte ohne Uhrzeit (an denen sich nichts
// verschieben lässt) und den ersten Punkt mit alter und neuer Zeit.
// Dieselbe Bauweise wie bei jeder Einfuhr dieser App: erst zeigen, dann
// übernehmen.
struct Zeitverschiebung: View {
    @ObservedObject var werk: Reisewerk
    let tagID: UUID
    let punkte: Set<UUID>
    /// Wird nach dem Verschieben aufgerufen — die Liste verlässt dann ihren
    /// Auswahlmodus. Ohne das stünde sie mit einer Auswahl da, die es so
    /// nicht mehr gibt.
    var fertig: () -> Void

    @Environment(\.dismiss) private var schliessen
    @State private var spaeter = true
    @State private var stunden = 3
    @State private var minuten = 0

    private var tag: Reisetag? { werk.reise.tage.first { $0.id == tagID } }
    private var gewaehlte: [Reisepunkt] {
        (tag?.spur ?? []).filter { punkte.contains($0.id) }
    }
    private var ohneZeit: Int { gewaehlte.filter { $0.zeit == nil }.count }
    private var versatz: TimeInterval {
        let betrag = Double(stunden) * 3600 + Double(minuten) * 60
        return spaeter ? betrag : -betrag
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Richtung", selection: $spaeter) {
                        Text("nach hinten").tag(true)
                        Text("nach vorn").tag(false)
                    }
                    .pickerStyle(.segmented)
                    Stepper(value: $stunden, in: 0...23) {
                        LabeledContent("Stunden", value: "\(stunden)")
                    }
                    Stepper(value: $minuten, in: 0...59, step: 5) {
                        LabeledContent("Minuten", value: "\(minuten)")
                    }
                } header: {
                    Text("Um wie viel")
                } footer: {
                    Text("„Nach hinten\u{201C} heißt später am Tag \u{2014} aus 8:15 wird "
                         + "mit drei Stunden 11:15.")
                }

                Section {
                    LabeledContent("Gewählt", value: "\(punkte.count)")
                    if ohneZeit > 0 {
                        // Was NICHT verschoben wird, steht vorher da und
                        // nicht erst hinterher in der Meldung.
                        Label(ohneZeit == 1
                              ? "1 Punkt hat keine Uhrzeit und bleibt unverändert."
                              : "\(ohneZeit) Punkte haben keine Uhrzeit und bleiben unverändert.",
                              systemImage: "clock.badge.questionmark")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    if let probe {
                        LabeledContent("Erster Punkt", value: probe)
                    }
                } header: {
                    Text("Was daraus wird")
                } footer: {
                    Text("Verschoben wird die Uhrzeit AM ORT \u{2014} dieselbe, die in der "
                         + "Liste steht. Punkte, die dabei über Mitternacht rutschen, "
                         + "bleiben an diesem Tag: Der Tag ist der, den du erlebt hast, "
                         + "und nicht das Ergebnis einer Rechnung.\n\nDanach wird die Liste "
                         + "neu nach Zeit geordnet; Punkte ohne Uhrzeit stehen am Ende.")
                }
            }
            .navigationTitle("Zeiten verschieben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verschieben") {
                        werk.meldung = .init(
                            text: werk.zeitenVerschieben(tagID, punkte: punkte, um: versatz))
                        fertig()
                        schliessen()
                    }
                    .disabled(versatz == 0 || punkte.count == ohneZeit)
                }
            }
        }
    }

    // Der erste gewählte Punkt MIT Uhrzeit, vorher und nachher. Eine Probe
    // sagt mehr als eine Zusage: Wer „3 Stunden nach hinten" liest, hat noch
    // nicht geprüft, ob es die richtige Richtung ist.
    private var probe: String? {
        guard let erster = gewaehlte.first(where: { $0.zeit != nil }), let zeit = erster.zeit
        else { return nil }
        let neu = zeit.addingTimeInterval(versatz)
        return "\(Self.uhr.string(from: zeit)) \u{2192} \(Self.uhr.string(from: neu))"
    }

    // Dieselbe feste Zone wie überall: Eine Uhrzeit ist die Wanduhr am Ort.
    private static let uhr: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}
