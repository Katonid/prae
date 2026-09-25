import SwiftUI
import CoreData

/// Die Suche über alle Einträge (ab 1.0.11). Jeder Treffer nennt sein
/// Tagebuch, den Tag, die Tageszeit und — wenn es eine gibt — die Reise; ein
/// Tipp öffnet den Eintrag. Die Regeln stehen in `Suche.swift`.
struct SuchView: View {
    @FetchRequest(fetchRequest: TagebuchView.alleEintraege()) private var eintraege: FetchedResults<Eintrag>
    @ObservedObject private var buecherei = Buecherei.shared
    @Environment(\.dismiss) private var schliessen

    @State private var anfrage = ""
    /// `nil` = alle Tagebücher, "" = nur Einträge ohne Tagebuch.
    @State private var nurTagebuch: String?
    @State private var treffer: [Suche.Treffer] = []
    @State private var woerter: [String] = []

    struct Tagesgruppe: Identifiable {
        let schluessel: String
        let tag: Date
        let treffer: [Suche.Treffer]
        var id: String { schluessel }
    }

    var body: some View {
        NavigationStack {
            List {
                if woerter.isEmpty {
                    anleitung
                } else if treffer.isEmpty {
                    ContentUnavailableView.search(text: anfrage)
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        EmptyView()
                    } footer: {
                        Text(zusammenfassung)
                    }
                    ForEach(gruppen) { g in
                        Section(Tag.text(g.tag, "EEEE, d. MMMM yyyy", zone: .current)) {
                            ForEach(g.treffer) { t in
                                NavigationLink {
                                    EintragView(eintrag: t.eintrag, palette: t.eintrag.reise?.palette ?? .meer)
                                } label: {
                                    TrefferZeile(treffer: t, woerter: woerter)
                                }
                            }
                        }
                    }
                }
                if buecherei.schloesser.keys.contains(where: { buecherei.istGesperrt($0) }) {
                    Section {
                        EmptyView()
                    } footer: {
                        Label("Gesperrte Tagebücher werden nicht durchsucht. Öffne sie vorher, wenn sie dabei sein sollen.",
                              systemImage: "lock.fill")
                    }
                }
            }
            .navigationTitle("Suche")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $anfrage, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Begriff, Ort, Person …")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
                ToolbarItem(placement: .topBarLeading) { tagebuchWahl }
            }
            // Kurz warten, bis das Tippen ruht: Der Lauf geht über alle
            // Einträge, und bei jedem Buchstaben neu zu suchen wäre Arbeit
            // für eine Liste, die gleich wieder verworfen wird.
            .task(id: "\(anfrage)|\(nurTagebuch ?? "∗")|\(buecherei.offen.sorted().joined(separator: ","))|\(eintraege.count)") {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                suchen()
            }
        }
    }

    // MARK: - Teile

    private var anleitung: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Wonach suchst du?", systemImage: "magnifyingglass")
                .font(.headline)
            Text("Gesucht wird in Titeln, Texten, Orten und in den Namen der Schreibenden — in allen Tagebüchern und Reisen. Groß- und Kleinschreibung zählt nicht. Mehrere Wörter müssen alle vorkommen; in Anführungszeichen („alter Hafen“) wird genau diese Folge gesucht.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var tagebuchWahl: some View {
        Menu {
            Button { nurTagebuch = nil } label: {
                Label("Alle Tagebücher", systemImage: nurTagebuch == nil ? "checkmark" : "books.vertical")
            }
            ForEach(tagebuchNamen, id: \.self) { n in
                Button { nurTagebuch = n } label: {
                    Label(n, systemImage: nurTagebuch == n ? "checkmark"
                          : (buecherei.istGesperrt(n) ? "lock.fill" : "book.closed.fill"))
                }
            }
            Button { nurTagebuch = "" } label: {
                Label("Ohne Tagebuch", systemImage: nurTagebuch == "" ? "checkmark" : "minus.circle")
            }
        } label: {
            Label(nurTagebuch.map { $0.isEmpty ? "Ohne Tagebuch" : $0 } ?? "Alle",
                  systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(.titleAndIcon)
        }
    }

    private var tagebuchNamen: [String] {
        Set(eintraege.compactMap(\.tagebuchName)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var zusammenfassung: String {
        let n = treffer.count
        var s = n == 1 ? "1 Eintrag" : "\(n) Einträge"
        let tage = gruppen.count
        s += tage == 1 ? " an 1 Tag" : " an \(tage) Tagen"
        if let t = nurTagebuch { s += t.isEmpty ? " · nur ohne Tagebuch" : " · nur in „\(t)“" }
        return s
    }

    /// Neueste zuerst — wer sucht, sucht meist etwas Jüngeres.
    private var gruppen: [Tagesgruppe] {
        var jeTag: [String: (Date, [Suche.Treffer])] = [:]
        for t in treffer {
            guard let s = t.eintrag.tagSchluessel, let d = t.eintrag.tagDatum else { continue }
            jeTag[s, default: (d, [])].1.append(t)
        }
        return jeTag.map { Tagesgruppe(schluessel: $0.key, tag: $0.value.0,
                                       treffer: $0.value.1.sorted { ($0.eintrag.datum ?? .distantPast) < ($1.eintrag.datum ?? .distantPast) }) }
            .sorted { $0.tag > $1.tag }
    }

    private func suchen() {
        let w = Suche.woerter(anfrage)
        let auswahl: [Eintrag]
        if let t = nurTagebuch {
            auswahl = eintraege.filter { ($0.tagebuchName ?? "") == t }
        } else {
            auswahl = Array(eintraege)
        }
        treffer = Suche.suchen(w, in: auswahl) { buecherei.istGesperrt($0) }
        woerter = w
    }
}

/// Ein Treffer: Tagebuch, Tageszeit, Reise, Titel und der Ausschnitt mit
/// den Fundstellen.
private struct TrefferZeile: View {
    @ObservedObject var eintrag: Eintrag
    let stelle: Suche.Fundstelle
    let ausschnitt: String?
    let woerter: [String]
    @ObservedObject private var buecherei = Buecherei.shared

    init(treffer: Suche.Treffer, woerter: [String]) {
        eintrag = treffer.eintrag
        stelle = treffer.stelle
        ausschnitt = treffer.ausschnitt
        self.woerter = woerter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                if let buch = eintrag.tagebuchName {
                    Label(buch, systemImage: "book.closed.fill")
                        .fontWeight(.semibold)
                        .foregroundStyle(buecherei.buchfarbe(buch).farbe)
                        .lineLimit(1)
                } else {
                    Label("Ohne Tagebuch", systemImage: "minus.circle")
                        .foregroundStyle(.secondary)
                }
                if let abschnitt = Tagesabschnitt.von(eintrag) {
                    Label("\(abschnitt.rawValue) · \(eintrag.uhrzeitText)", systemImage: abschnitt.symbol)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .font(.caption)
            Text(Suche.hervorgehoben(eintrag.anzeigeTitel, woerter))
                .font(.headline)
            if let ausschnitt {
                Text(Suche.hervorgehoben(ausschnitt, woerter))
                    .font(.callout)
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .lineLimit(4)
                if stelle != .text {
                    Text("Gefunden in: \(stelle.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let reise = eintrag.reise {
                Label(reise.anzeigeTitel, systemImage: "suitcase.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(reise.palette.haupt)
            }
        }
        .padding(.vertical, 4)
    }
}
