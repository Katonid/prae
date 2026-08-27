import SwiftUI

/// Der Liveticker: oben die Spiele, die gerade laufen, darunter die
/// Meldungen in zeitlicher Reihenfolge.
struct Tickersicht: View {
    @EnvironmentObject private var daten: Datenhaltung
    @State private var filter: Liga?

    var body: some View {
        NavigationStack {
            Group {
                if daten.einsatzbereit {
                    inhalt
                } else {
                    Willkommenssicht()
                }
            }
            .navigationTitle("Liveticker")
            .navigationDestination(for: Spiel.self) { spiel in
                Spielsicht(spiel: spiel)
            }
            .toolbar { werkzeuge }
        }
    }

    // MARK: Inhalt

    private var inhalt: some View {
        List {
            if let fehler = daten.tickerFehler {
                Hinweiszeile(text: fehler, ernst: true)
            }
            if daten.beispielmodus {
                Hinweiszeile(text: "Beispieldaten — keine echten Ergebnisse.", ernst: false)
            }

            laufendeSpiele
            weitereSpiele
            meldungen
        }
        .listStyle(.insetGrouped)
        .refreshable { await daten.tickerAktualisieren() }
        .task { await daten.tickerBeobachten() }
        .overlay(alignment: .bottom) { fusszeile }
    }

    private var gefilterteSpiele: [Spiel] {
        guard let filter else { return daten.liveSpiele }
        return daten.liveSpiele.filter { $0.liga == filter }
    }

    private var gefilterteMeldungen: [Tickermeldung] {
        guard let filter else { return daten.ticker }
        return daten.ticker.filter { $0.liga == filter }
    }

    @ViewBuilder
    private var laufendeSpiele: some View {
        let laufend = gefilterteSpiele.filter { $0.status.laeuftGerade }
        if !laufend.isEmpty {
            Section {
                ForEach(laufend) { spiel in
                    NavigationLink(value: spiel) {
                        Spielzeile(spiel: spiel, ligaZeigen: true)
                    }
                }
            } header: {
                Label("Jetzt live", systemImage: "dot.radiowaves.left.and.right")
            }
        }
    }

    @ViewBuilder
    private var weitereSpiele: some View {
        let weitere = gefilterteSpiele.filter { !$0.status.laeuftGerade }
        if !weitere.isEmpty {
            Section("Heute") {
                ForEach(weitere) { spiel in
                    NavigationLink(value: spiel) {
                        Spielzeile(spiel: spiel, ligaZeigen: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var meldungen: some View {
        let liste = gefilterteMeldungen
        Section("Meldungen") {
            if liste.isEmpty {
                Text(daten.tickerLaeuft ? "Wird geladen …" : "Noch keine Meldungen. Sobald ein Tor fällt, steht es hier.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(liste) { meldung in
                    Meldungszeile(meldung: meldung)
                }
            }
        }
    }

    @ViewBuilder
    private var fusszeile: some View {
        if let zeit = daten.letzterAbruf {
            Text("Stand \(Zeitformate.uhrzeit.string(from: zeit)) Uhr")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 6)
        }
    }

    // MARK: Werkzeuge

    @ToolbarContentBuilder
    private var werkzeuge: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if daten.tickerLaeuft {
                ProgressView()
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Liga", selection: $filter) {
                    Text("Alle Ligen").tag(Liga?.none)
                    ForEach(Liga.allCases) { liga in
                        Text("\(liga.flagge) \(liga.name)").tag(Liga?.some(liga))
                    }
                }
                Divider()
                Button(role: .destructive) {
                    daten.tickerLeeren()
                } label: {
                    Label("Meldungen löschen", systemImage: "trash")
                }
            } label: {
                Label("Filter", systemImage: filter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }
}

/// Eine einzelne Tickermeldung.
struct Meldungszeile: View {
    let meldung: Tickermeldung

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: meldung.art.symbol)
                .font(.system(size: 15))
                .foregroundStyle(meldung.art == .tor ? Gestaltung.rasen : Color.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(meldung.paarung)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(meldung.stand)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Gestaltung.rasen)
                }
                HStack(spacing: 6) {
                    Text(meldung.liga.flagge)
                    if !meldung.minutentext.isEmpty {
                        Text(meldung.minutentext)
                            .font(.caption.monospacedDigit())
                    }
                    Text(meldung.zusatz)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Kurzer Hinweis am Kopf einer Liste.
struct Hinweiszeile: View {
    let text: String
    let ernst: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: ernst ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(ernst ? Color.orange : Color.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
