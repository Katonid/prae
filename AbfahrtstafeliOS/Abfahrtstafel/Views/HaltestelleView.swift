import SwiftUI

/// Die Tafel EINER Haltestelle — alles, was dort wegfährt.
///
/// Sie holt ihre Daten selbst und nicht aus `AppModel`: Diese Ansicht wird
/// auch aus der Merkliste heraus geöffnet, wo es gar keinen Bezugspunkt gibt.
/// Eine Ansicht, die nur mit vorher geladenem Zustand funktioniert, ließe sich
/// von dort nicht öffnen.
struct HaltestelleView: View {
    let haltestelle: Haltestelle

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var uhr: Uhrwerk
    @EnvironmentObject private var merkliste: Merkliste

    @State private var abfahrten: [Abfahrt] = []
    @State private var stand: AppModel.Ladestand = .laedt
    @State private var geholtUm: Date?
    @State private var standIstAlt = false

    /// Welche Quellen zu DIESER Tafel beigetragen haben.
    private var quellen: [String] {
        abfahrten.map(\.quelle).filter { !$0.isEmpty }.eindeutig().sorted()
    }

    var body: some View {
        Group {
            switch stand {
            case .laedt where abfahrten.isEmpty:
                ProgressView("Abfahrten werden geholt …")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .fehler(let text, _) where abfahrten.isEmpty:
                Hinweisflaeche(
                    symbol: "wifi.exclamationmark",
                    titel: "Keine Abfahrten",
                    text: text,
                    knopf: "Noch einmal versuchen",
                    tat: { Task { await laden() } }
                )
            default:
                liste
            }
        }
        .navigationTitle(haltestelle.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    merkliste.umschalten(haltestelle)
                } label: {
                    Image(systemName: merkliste.istGemerkt(haltestelle) ? "star.fill" : "star")
                }
                .foregroundStyle(merkliste.istGemerkt(haltestelle) ? .yellow : .accentColor)
                .accessibilityLabel(merkliste.istGemerkt(haltestelle) ? "Merken aufheben" : "Haltestelle merken")
            }
        }
        .task { await laden() }
        // Die Tafel einer einzelnen Haltestelle wird oft lange angesehen —
        // jemand wartet. Sie lädt deshalb von selbst nach, solange sie offen
        // ist.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                await laden()
            }
        }
    }

    private var liste: some View {
        List {
            if case .fehler(let text, _) = stand {
                Section {
                    Meldungsband(text: text)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section {
                ForEach(sichtbare) { abfahrt in
                    let inhalt = AbfahrtsZeile(
                        abfahrt: abfahrt,
                        jetzt: uhr.jetzt,
                        standIstAlt: standIstAlt,
                        zeigtQuelle: quellen.count > 1
                    )
                    // Ohne Fahrtkennung kein Verweis — siehe `hatFahrtlauf`.
                    if abfahrt.hatFahrtlauf {
                        NavigationLink(value: Fahrtwunsch(fahrtId: abfahrt.fahrtId, einstieg: abfahrt.haltestelle)) {
                            inhalt
                        }
                        .lesebreite()
                    } else {
                        inhalt.lesebreite()
                    }
                }
            } header: {
                if let gegend = haltestelle.gegend {
                    Text(gegend)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 3) {
                    if let geholtUm {
                        if standIstAlt {
                            Text("Diese Zeiten sind von \(geholtUm.formatted(date: .omitted, time: .standard)) und zählen nicht weiter — es ist gerade keine Quelle erreichbar.")
                        } else {
                            Text("Zuletzt geholt um \(geholtUm.formatted(date: .omitted, time: .standard)). Die Tafel lädt alle 30 Sekunden nach, solange sie offen ist.")
                        }
                    }
                    if !quellen.isEmpty {
                        Text("Daten: \(quellen.joined(separator: ", ")).")
                    }
                }
                .font(.caption2)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await laden() }
        .overlay {
            if sichtbare.isEmpty {
                Hinweisflaeche(
                    symbol: "moon.zzz",
                    titel: "Von hier fährt gerade nichts",
                    text: "Der Fahrplandienst meldet für diese Haltestelle keine Abfahrten in der nächsten Zeit. Nachts und am Wochenende ist das kein Fehler.",
                    knopf: "Nachsehen",
                    tat: { Task { await laden() } }
                )
                .background(.background)
            }
        }
    }

    private var sichtbare: [Abfahrt] {
        let grenze = Date().addingTimeInterval(-60)
        return abfahrten.filter { $0.tatsaechlich >= grenze }
    }

    private func laden() async {
        if abfahrten.isEmpty { stand = .laedt }
        do {
            // Umkreis 0: Hier geht es um DIESE Haltestelle. Der Umkreis der
            // Tafel „in der Nähe" wäre an dieser Stelle falsch — wer auf eine
            // Haltestelle tippt, will ihre Abfahrten und nicht die der
            // Nachbarstraße.
            let geholt = try await model.dienst.abfahrten(
                ab: haltestelle,
                umkreis: 0,
                zeitpunkt: Date(),
                anzahl: 60
            )
            abfahrten = geholt.sorted { $0.tatsaechlich < $1.tatsaechlich }
            geholtUm = Date()
            standIstAlt = false
            stand = .da
        } catch Fahrplanfehler.veralteterStand(let liegengebliebene, let alter) {
            // Derselbe Weg wie in `AppModel`: Die Zeiten werden gezeigt, aber
            // als alt gekennzeichnet.
            abfahrten = liegengebliebene.sorted { $0.tatsaechlich < $1.tatsaechlich }
            geholtUm = alter
            standIstAlt = true
            stand = .da
        } catch let fehler as Fahrplanfehler {
            guard fehler != .abgebrochen else { return }
            stand = .fehler(text: fehler.localizedDescription, ortswahlHilft: false)
        } catch {
            stand = .fehler(text: error.localizedDescription, ortswahlHilft: false)
        }
    }
}

#Preview {
    NavigationStack {
        HaltestelleView(haltestelle: Musterdienst.marienplatz)
            .environmentObject(AppModel(dienst: Musterdienst()))
            .environmentObject(Uhrwerk())
            .environmentObject(Merkliste())
    }
}
