import SwiftUI
import UniformTypeIdentifiers

/// Autofahrten aus GPX-Dateien auf einmal übernehmen (ab 1.0.21). Dateien
/// wählen — beliebig viele —, die Fahrten stehen nach Tag geordnet zum
/// Abwählen da, dann „Übernehmen". Die Regeln stehen in `Fahrten.swift`.
struct FahrtenImportView: View {
    @ObservedObject var reise: Reise
    @Environment(\.dismiss) private var schliessen
    @ObservedObject private var farben = Kartenfarben.shared

    @State private var dateiWahl = false
    @State private var laedt = false
    @State private var fund: Fahrtenimport.Fund?
    @State private var abgewaehlt: Set<String> = []
    @State private var vorhanden: Set<String> = []

    private var gueltigeTage: Set<String> { Set(reise.bisherigeTage.map { Tag.schluessel($0) }) }

    /// Was übernommen würde: gewählt, neu und im Zeitraum der Reise.
    private var gewaehlt: [Fahrtenimport.Fahrt] {
        (fund?.fahrten ?? []).filter {
            !abgewaehlt.contains($0.kennung) && !vorhanden.contains($0.kennung) && gueltigeTage.contains($0.tag)
        }
    }

    private var ausserhalb: [Fahrtenimport.Fahrt] {
        (fund?.fahrten ?? []).filter { !gueltigeTage.contains($0.tag) }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let fund {
                    ergebnis(fund)
                } else {
                    anfang
                }
            }
            .navigationTitle("Autofahrten übernehmen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                if fund != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Übernehmen") {
                            Fahrtenimport.uebernehmen(gewaehlt, in: reise)
                            schliessen()
                        }
                        .fontWeight(.semibold)
                        .disabled(gewaehlt.isEmpty)
                    }
                }
            }
            .fileImporter(isPresented: $dateiWahl,
                          allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml, .xml],
                          allowsMultipleSelection: true) { ergebnis in
                if case .success(let urls) = ergebnis, !urls.isEmpty {
                    Task { await lesen(urls) }
                }
            }
            .overlay {
                if laedt {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Fahrten werden gelesen …").font(.callout).foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
    }

    // MARK: - Dateien wählen

    @ViewBuilder
    private var anfang: some View {
        Section {
            Button { dateiWahl = true } label: {
                Label("GPX-Dateien wählen", systemImage: "doc.on.doc")
            }
            .disabled(laedt)
        } footer: {
            Text("Wähle alle Fahrten auf einmal — in der Dateien-App mit „Auswählen“ oder durch Ziehen über mehrere Dateien. Jede Fahrt kommt an den Tag, an dem sie begann (Ortszeit am Start), und erscheint auf der Karte in der Farbe der Autofahrten.")
        }
    }

    private func lesen(_ urls: [URL]) async {
        laedt = true
        let neu = await Fahrtenimport.lesen(urls)
        vorhanden = Fahrtenimport.vorhanden(in: reise)
        abgewaehlt = []
        withAnimation { fund = neu }
        laedt = false
    }

    // MARK: - Prüfen

    @ViewBuilder
    private func ergebnis(_ fund: Fahrtenimport.Fund) -> some View {
        if !fund.ohneZeit.isEmpty || !fund.unlesbar.isEmpty {
            Section {
                if !fund.ohneZeit.isEmpty {
                    Label("Ohne Uhrzeiten, also keinem Tag zuzuordnen: \(fund.ohneZeit.joined(separator: ", "))",
                          systemImage: "clock.badge.questionmark")
                        .foregroundStyle(.orange)
                }
                if !fund.unlesbar.isEmpty {
                    Label("Nicht lesbar: \(fund.unlesbar.joined(separator: ", "))",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            .font(.callout)
        }
        if !ausserhalb.isEmpty {
            Section {
                Label(ausserhalb.count == 1
                      ? "1 Fahrt liegt außerhalb der Reise (\(Tag.zeitraum(reise.anfang, reise.ende)))."
                      : "\(ausserhalb.count) Fahrten liegen außerhalb der Reise (\(Tag.zeitraum(reise.anfang, reise.ende))).",
                      systemImage: "calendar.badge.exclamationmark")
                    .font(.callout)
                    .foregroundStyle(.orange)
                if let erweitert = erweiterung {
                    Button {
                        erweitern(von: erweitert.von, bis: erweitert.bis)
                    } label: {
                        Label("Reise auf \(Tag.zeitraum(erweitert.von, erweitert.bis)) erweitern",
                              systemImage: "arrow.left.and.right")
                    }
                }
            }
        }
        let jeTag = Dictionary(grouping: fund.fahrten.filter { gueltigeTage.contains($0.tag) }, by: \.tag)
        ForEach(jeTag.keys.sorted(), id: \.self) { t in
            Section {
                ForEach(jeTag[t] ?? []) { f in fahrtzeile(f) }
            } header: {
                if let d = Tag.datum(schluessel: t) {
                    Text(Tag.wochentagLang.string(from: d))
                }
            }
        }
        if fund.fahrten.isEmpty && fund.ohneZeit.isEmpty && fund.unlesbar.isEmpty {
            Section { Text("In den Dateien stand keine Fahrt.").foregroundStyle(.secondary) }
        }
        Section {
            Text(gewaehlt.count == 1 ? "1 Fahrt wird übernommen." : "\(gewaehlt.count) Fahrten werden übernommen.")
                .font(.subheadline.weight(.semibold))
            Button("Andere Dateien wählen") { dateiWahl = true }
        }
    }

    private func fahrtzeile(_ f: Fahrtenimport.Fahrt) -> some View {
        let schon = vorhanden.contains(f.kennung)
        let aus = abgewaehlt.contains(f.kennung)
        return Button {
            guard !schon else { return }
            if aus { abgewaehlt.remove(f.kennung) } else { abgewaehlt.insert(f.kennung) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: schon ? "checkmark.circle" : (aus ? "circle" : "checkmark.circle.fill"))
                    .font(.title3)
                    .foregroundStyle(schon ? Color.secondary : farben.fahrt)
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    let teile = [f.zeitspanne, Tagesspurwahl.kilometertext(f.meter / 1000),
                                 f.zone.identifier == TimeZone.current.identifier ? "" : "Ortszeit \(f.zone.abbreviation(for: f.beginn) ?? f.zone.identifier)",
                                 schon ? "schon in der Reise" : ""]
                    Text(teile.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "car.fill").foregroundStyle(farben.fahrt.opacity(schon || aus ? 0.35 : 1))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(schon ? 0.6 : 1)
    }

    /// Der Zeitraum, auf den sich die Reise erweitern ließe — nur länger,
    /// nie kürzer, und nie über heute hinaus.
    private var erweiterung: (von: Date, bis: Date)? {
        let tage = ausserhalb.compactMap { Tag.datum(schluessel: $0.tag) }
        guard let frueh = tage.min(), let spaet = tage.max() else { return nil }
        let von = min(frueh, reise.anfang)
        let bis = max(spaet, reise.schluss)
        guard bis <= Tag.anfang(Date()) else { return nil }
        return (von, bis)
    }

    private func erweitern(von: Date, bis: Date) {
        if von < reise.anfang { reise.beginn = von }
        if bis > reise.schluss { reise.ende = bis }
        Persistenz.shared.sichern()
        // `gueltigeTage` rechnet aus der Reise neu; die Liste folgt von selbst.
        reise.objectWillChange.send()
    }
}
