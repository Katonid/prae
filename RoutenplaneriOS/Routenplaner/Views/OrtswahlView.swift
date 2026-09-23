import SwiftUI
import MapKit

/// Welches Feld gerade gewählt wird. Der WUNSCH trägt das Ziel — kein
/// Schalter daneben (Lehre aus Abfahrtstafel 1.0.9: `.sheet(item:)`).
enum Ortsfeld: String, Identifiable {
    case start, ziel
    var id: String { rawValue }
    var titel: String { self == .start ? "Start" : "Ziel" }
}

struct OrtswahlView: View {
    let feld: Ortsfeld
    let waehlen: (Ort) -> Void

    @EnvironmentObject private var standort: Standort
    @Environment(\.dismiss) private var schliessen
    @StateObject private var suche = Ortssuche()
    @State private var loest = false
    @State private var fehler: String?
    @FocusState private var fokus: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        if let p = standort.punkt {
                            waehlen(Ort(name: "Mein Standort", punkt: p))
                            schliessen()
                        } else {
                            standort.anfragen()
                            fehler = standort.abgelehnt
                                ? "Die Ortung ist abgelehnt. Sie lässt sich in den Einstellungen unter Datenschutz → Ortungsdienste erlauben — oder den Ort einfach suchen."
                                : "Der Standort ist noch nicht bekannt. Einen Augenblick warten und noch einmal tippen."
                        }
                    } label: {
                        Label("Mein Standort", systemImage: "location.fill")
                    }
                }
                if let fehler {
                    Section { Text(fehler).foregroundStyle(.red) }
                }
                if let f = suche.fehler, !suche.eingabe.isEmpty {
                    Section { Text("Suche: \(f)").foregroundStyle(.secondary) }
                }
                Section {
                    ForEach(suche.vorschlaege, id: \.self) { v in
                        Button {
                            aufloesen(v)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.title).foregroundStyle(.primary)
                                if !v.subtitle.isEmpty {
                                    Text(v.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(loest)
                    }
                } footer: {
                    if suche.eingabe.isEmpty {
                        Text("Adresse, Ort, Campingplatz oder Sehenswürdigkeit eintippen.")
                    }
                }
            }
            .overlay { if loest { ProgressView() } }
            .searchable(text: $suche.eingabe, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "\(feld.titel) suchen")
            .navigationTitle(feld.titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
            }
            .onAppear { suche.naehe(standort.punkt) }
        }
    }

    private func aufloesen(_ v: MKLocalSearchCompletion) {
        loest = true
        fehler = nil
        Task {
            do {
                let ort = try await Ortssuche.aufloesen(v)
                waehlen(ort)
                schliessen()
            } catch {
                fehler = error.localizedDescription
            }
            loest = false
        }
    }
}
