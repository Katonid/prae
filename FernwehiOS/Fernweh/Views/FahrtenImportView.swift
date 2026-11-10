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
    /// Die gewählten Dateien, schon gelesen (ab 1.0.22) — die Pause lässt
    /// sich ändern, ohne sie neu zu wählen.
    @State private var dateien: [Fahrtenimport.Datei] = []
    @State private var nichtGelesen: [String] = []
    /// Was gerade berechnet wird (CSV: eine Fahrt nach der anderen).
    @State private var meldung = "Fahrten werden gelesen …"
    @State private var auswertung: Task<Void, Never>?
    /// Minuten ohne Punkt, ab denen eine neue Fahrt beginnt; 0 = nur an den
    /// Spuren der Datei trennen.
    @AppStorage("fernweh.fahrtenpause") private var pauseMinuten = 15

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

    /// Tage außerhalb der Reise — aus GPX berechnete Fahrten und, aus einem
    /// Fahrtenbuch, die nicht berechneten Zeilen (ab 1.0.37).
    private var ausserhalbTage: [String] {
        ausserhalb.map(\.tag) + (fund?.csvAusserhalb ?? []).filter { !gueltigeTage.contains($0) }
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
                          allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml, .xml, .commaSeparatedText, .plainText],
                          allowsMultipleSelection: true) { ergebnis in
                if case .success(let urls) = ergebnis, !urls.isEmpty {
                    let gelesen = Fahrtenimport.dateien(urls)
                    dateien = gelesen.dateien
                    nichtGelesen = gelesen.unlesbar
                    neuAuswerten()
                }
            }
            .overlay {
                if laedt {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(meldung).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
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
                Label("GPX- oder CSV-Dateien wählen", systemImage: "doc.on.doc")
            }
            .disabled(laedt)
        } footer: {
            Text("Wähle alle Dateien auf einmal — in der Dateien-App mit „Auswählen“. Eine Datei darf mehrere Fahrten enthalten: Getrennt wird an jeder Spur der Datei und an jeder längeren Pause. Jede Fahrt kommt an den Tag, an dem sie begann (Ortszeit am Start), und erscheint auf der Karte in der Farbe der Autofahrten.\n\nCSV aus einem Fahrtenbuch (etwa Autoaid): eine Zeile je Fahrt mit Datum, Uhrzeiten, Start- und Zieladresse. Den Weg berechnet Apple Karten aus den Adressen — er kann vom wirklich gefahrenen abweichen. Die Kilometer kommen aus der Datei. Berechnet werden nur Fahrten an Tagen der Reise; das dauert etwa zwei Sekunden je Fahrt.")
        }
        autoaidHinweis
    }

    // MARK: - Hinweis: autoaid über Scriptable (ab 1.0.38)

    @State private var skriptKopiert = false

    /// So kommen Fahrten aus autoaid MIT echtem Streckenverlauf herein —
    /// der Weg der Osterreise 2026, hier festgehalten (`AutoaidSkript`).
    private var autoaidHinweis: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("autoaid gibt im Fahrtenbuch nur eine CSV heraus — ohne Streckenverlauf. Die echten GPS-Punkte holt das Skript „autoaid → GPX“ in der App Scriptable:")
                Text("1. In autoaid die Fahrten als CSV exportieren.\n2. In Scriptable das Skript starten (beim ersten Mal unten kopieren und als neues Skript einfügen) → „↻ Neue CSV einlesen …“ → die CSV wählen.\n3. „📅 Zeitraum gesammelt exportieren …“ → Zeitraum der Reise → einmal bei autoaid anmelden → GPX-Datei in „Dateien“ sichern.\n4. Hier „GPX- oder CSV-Dateien wählen“ → die GPX-Datei.")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.vertical, 2)
            Button {
                UIPasteboard.general.string = AutoaidSkript.text
                withAnimation { skriptKopiert = true }
            } label: {
                Label(skriptKopiert ? "Skript kopiert — in Scriptable einfügen" : "Skript für Scriptable kopieren",
                      systemImage: skriptKopiert ? "checkmark.circle.fill" : "doc.on.clipboard")
            }
        } header: {
            Label("Fahrten aus autoaid mit echtem Weg", systemImage: "car.fill")
        } footer: {
            Text("Skript-Fassung \(AutoaidSkript.fassung). Es liest den deutschen und den englischen autoaid-Export. Dein autoaid-Passwort fragt es einmal ab und behält nur einen Anmelde-Schlüssel im Schlüsselbund.")
        }
    }

    /// Wertet neu aus; eine laufende Auswertung wird abgebrochen.
    private func neuAuswerten() {
        auswertung?.cancel()
        auswertung = Task { await auswerten() }
    }

    private func auswerten() async {
        laedt = true
        meldung = "Fahrten werden gelesen …"
        var neu = await Fahrtenimport.auswerten(dateien, pause: pauseMinuten > 0 ? Double(pauseMinuten) * 60 : nil,
                                                tage: gueltigeTage) { text in meldung = text }
        guard !Task.isCancelled else { return }
        neu.unlesbar = nichtGelesen + neu.unlesbar
        let belegt = Fahrtenimport.belegt(in: reise)
        vorhanden = Set(neu.fahrten.filter { Fahrtenimport.schonDa($0, belegt) }.map(\.kennung))
        abgewaehlt = []
        withAnimation { fund = neu }
        laedt = false
    }

    /// Was beim Berechnen aus einem Fahrtenbuch herauskam (ab 1.0.37).
    private func csvHinweise(_ fund: Fahrtenimport.Fund) -> some View {
        Section {
            if fund.berechnet > 0 {
                Label(fund.berechnet == 1
                      ? "1 Weg über Apple Karten berechnet."
                      : "\(fund.berechnet) Wege über Apple Karten berechnet.",
                      systemImage: "map")
            }
            if fund.luftlinie > 0 {
                Label(fund.luftlinie == 1
                      ? "1 Fahrt ohne Route — als gerade Linie von Start zu Ziel."
                      : "\(fund.luftlinie) Fahrten ohne Route — als gerade Linie von Start zu Ziel.",
                      systemImage: "line.diagonal")
                    .foregroundStyle(.orange)
            }
            if !fund.nichtGefunden.isEmpty {
                Label("Adresse nicht gefunden: \(fund.nichtGefunden.joined(separator: "; "))",
                      systemImage: "mappin.slash")
                    .foregroundStyle(.orange)
            }
            if fund.zuKurz > 0 {
                Label("\(fund.zuKurz) Fahrten unter 200 m weggelassen.", systemImage: "arrow.down.right.and.arrow.up.left")
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("Der Weg ist gerechnet, nicht aufgezeichnet: die schnellste Autoroute zwischen den Adressen. Die Uhrzeiten sind über die Strecke verteilt.")
        }
        .font(.callout)
    }

    /// Wie getrennt wird — für Dateien mit mehreren Fahrten.
    private var trennung: some View {
        Section {
            Picker("Neue Fahrt nach einer Pause von", selection: $pauseMinuten) {
                Text("5 Minuten").tag(5)
                Text("15 Minuten").tag(15)
                Text("30 Minuten").tag(30)
                Text("1 Stunde").tag(60)
                Text("nie").tag(0)
            }
            .onChange(of: pauseMinuten) { _, _ in neuAuswerten() }
        } footer: {
            Text((fund?.fahrten.count ?? 0) == 1
                 ? "1 Fahrt aus \(fund?.dateien ?? 0) Datei."
                 : "\(fund?.fahrten.count ?? 0) Fahrten aus \(fund?.dateien ?? 0) \((fund?.dateien ?? 0) == 1 ? "Datei" : "Dateien"). Getrennt wird immer an jeder Spur der Datei; eine Pause trennt zusätzlich — „nie“ lässt eine Spur ganz."
                 + ((fund?.zuKurz ?? 0) > 0 ? " \(fund?.zuKurz ?? 0) Stücke unter 200 m sind weggelassen." : ""))
        }
    }

    // MARK: - Prüfen

    @ViewBuilder
    private func ergebnis(_ fund: Fahrtenimport.Fund) -> some View {
        if dateien.contains(where: { !FahrtenCSV.istCSV($0.name) }) { trennung }
        if fund.csv { csvHinweise(fund) }
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
        if !ausserhalbTage.isEmpty {
            Section {
                Label(ausserhalbTage.count == 1
                      ? "1 Fahrt liegt außerhalb der Reise (\(Tag.zeitraum(reise.anfang, reise.ende)))."
                      : "\(ausserhalbTage.count) Fahrten liegen außerhalb der Reise (\(Tag.zeitraum(reise.anfang, reise.ende))).",
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
        let tage = ausserhalbTage.compactMap { Tag.datum(schluessel: $0) }
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
        // Fahrten aus einem Fahrtenbuch sind erst für die Tage der Reise
        // berechnet — die neuen Tage jetzt nachholen.
        if fund?.csv == true { neuAuswerten() }
    }
}
