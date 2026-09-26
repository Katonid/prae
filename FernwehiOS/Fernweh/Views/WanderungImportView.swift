import SwiftUI
import MapKit
import UniformTypeIdentifiers

/// Eine Wanderung aus Komoot (Link) oder einer GPX-Datei übernehmen (ab
/// 1.0.17). Erst laden, dann prüfen und übernehmen: Name, Start, Länge, Dauer,
/// Höhenmeter und die Strecke auf der Karte. Die Regeln stehen in
/// `Wanderung.swift`.
struct WanderungImportView: View {
    /// Die Reise, in die sie gehört — `nil` heißt: ins Lebenstagebuch.
    let reise: Reise?
    @Environment(\.dismiss) private var schliessen

    @State private var link = ""
    @State private var laedt = false
    @State private var fehler: String?
    @State private var wanderung: Wanderung?
    @State private var titel = ""
    @State private var text = ""
    @State private var beginn = Date()
    @State private var zone: TimeZone = .current
    @State private var dateiWahl = false
    @State private var sichert = false

    private var palette: Palette { reise?.palette ?? .meer }

    /// Liegt der Start im Zeitraum der Reise? Ohne Reise immer.
    private var passtInReise: Bool {
        guard let reise else { return true }
        let tag = Tag.schluessel(beginn, zone: zone)
        return tag >= Tag.schluessel(reise.anfang) && tag <= Tag.schluessel(reise.schluss)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let wanderung {
                    vorschau(wanderung)
                } else {
                    quellen
                }
            }
            .navigationTitle(wanderung == nil ? "Wanderung übernehmen" : "Prüfen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() }.disabled(sichert) }
                if wanderung != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Übernehmen") { Task { await sichern() } }
                            .fontWeight(.semibold)
                            .disabled(!passtInReise || sichert)
                    }
                }
            }
            .fileImporter(isPresented: $dateiWahl,
                          allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml, .xml],
                          allowsMultipleSelection: false) { ergebnis in
                if case .success(let urls) = ergebnis, let url = urls.first { dateiLesen(url) }
            }
        }
    }

    // MARK: - Laden

    @ViewBuilder
    private var quellen: some View {
        Section {
            TextField("komoot.com/tour/…", text: $link, axis: .vertical)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            PasteButton(payloadType: String.self) { texte in
                if let t = texte.first { link = t }
            }
            Button {
                Task { await komootLaden() }
            } label: {
                HStack {
                    Text("Von Komoot laden")
                    if laedt { Spacer(); ProgressView() }
                }
            }
            .disabled(link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || laedt)
        } header: {
            Text("Komoot-Link")
        } footer: {
            Text("In Komoot: Tour öffnen → „Teilen“ → „Link kopieren“. Der Teilen-Link öffnet auch private Touren; eine öffentliche geht mit jedem Link.")
        }
        if let fehler {
            Section {
                Label(fehler, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
        }
        Section {
            Button { dateiWahl = true } label: { Label("GPX-Datei wählen", systemImage: "doc.badge.arrow.up") }
        } header: {
            Text("Oder als Datei")
        } footer: {
            Text("Komoot: Tour → „…“ → „GPX-Datei herunterladen“. Genauso geht jede Datei einer Sportuhr oder anderen Wander-App.")
        }
    }

    private func komootLaden() async {
        laedt = true
        fehler = nil
        defer { laedt = false }
        do {
            let w = try await Komoot.laden(link)
            await uebernehmen(w)
        } catch {
            fehler = error.localizedDescription
        }
    }

    private func dateiLesen(_ url: URL) {
        let zugriff = url.startAccessingSecurityScopedResource()
        defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
        do {
            let daten = try Data(contentsOf: url)
            let w = try GPXLeser.lesen(daten, dateiname: url.lastPathComponent)
            Task { await uebernehmen(w) }
        } catch {
            fehler = error.localizedDescription
        }
    }

    private func uebernehmen(_ w: Wanderung) async {
        var w = w
        // Die Ortszeit am Start: Die Uhrzeiten sollen die vom Weg sein, nicht
        // die, die daheim gerade gilt.
        if let start = w.punkte.first, let name = await Ortsnamen.shared.name(fuer: start.koordinate),
           let z = TimeZone(identifier: name.zeitzone) {
            zone = z
        }
        // Eine geplante Tour ohne Tag in der Reise: auf deren ersten Tag
        // legen, um 9 Uhr — verschieben lässt sie sich im Datumsfeld.
        if w.geplant, let reise, !passt(w.beginn, in: reise) {
            var k = Tag.kalender
            k.timeZone = zone
            let t = Tag.kalender.dateComponents([.year, .month, .day], from: reise.anfang)
            if let neu = k.date(from: DateComponents(year: t.year, month: t.month, day: t.day, hour: 9)) {
                w.beginnen(neu)
            }
        }
        titel = w.name
        beginn = w.beginn
        withAnimation { wanderung = w }
    }

    private func passt(_ d: Date, in reise: Reise) -> Bool {
        let tag = Tag.schluessel(d, zone: zone)
        return tag >= Tag.schluessel(reise.anfang) && tag <= Tag.schluessel(reise.schluss)
    }

    // MARK: - Prüfen

    @ViewBuilder
    private func vorschau(_ w: Wanderung) -> some View {
        Section {
            Map(initialPosition: .automatic, interactionModes: []) {
                let punkte = w.punkte.map(\.koordinate)
                MapPolyline(coordinates: punkte)
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: punkte)
                    .stroke(Kartenfarben.shared.wanderung, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                if let a = punkte.first {
                    Annotation("Start", coordinate: a) { Circle().fill(.green).frame(width: 12, height: 12).overlay(Circle().stroke(.white, lineWidth: 2)) }
                }
                if let b = punkte.last {
                    Annotation("Ziel", coordinate: b) { Circle().fill(.red).frame(width: 12, height: 12).overlay(Circle().stroke(.white, lineWidth: 2)) }
                }
            }
            .frame(height: 220)
            .listRowInsets(EdgeInsets())
            .allowsHitTesting(false)
            HStack(spacing: 0) {
                Kennzahl(wert: Tagesspurwahl.kilometertext(w.meter / 1000), beschriftung: "Strecke", symbol: "figure.hiking")
                if w.dauer >= 60 {
                    Kennzahl(wert: Wanderung.dauertext(w.dauer), beschriftung: w.geplant ? "geschätzt" : "Dauer", symbol: "clock")
                }
                if w.hoehenmeter >= 1 {
                    Kennzahl(wert: "\(Int(w.hoehenmeter)) m", beschriftung: "bergauf", symbol: "arrow.up.right")
                }
            }
        }
        Section {
            TextField("Name", text: $titel)
            DatePicker("Start", selection: $beginn)
                .environment(\.timeZone, zone)
            if zone.identifier != TimeZone.current.identifier {
                Text("Ortszeit am Start (\(zone.abbreviation(for: beginn) ?? zone.identifier)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            if w.geplant {
                Text("Eine geplante Tour trägt keine echten Uhrzeiten. Sie sind mit 4 km/h geschätzt — stell den Start auf den Tag und die Uhrzeit, an dem du gegangen bist.")
            } else {
                Text("Die Uhrzeiten stammen aus der Aufzeichnung. Verschiebst du den Start, wandern alle Punkte mit.")
            }
        }
        if !passtInReise, let reise {
            Section {
                Label("Der Start liegt nicht im Zeitraum der Reise (\(Tag.zeitraum(reise.anfang, reise.ende))). Passe den Start an — oder den Zeitraum der Reise.",
                      systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
        }
        Section("Text") {
            TextEditor(text: $text).frame(minHeight: 110)
        }
        Section {
            Button("Andere Tour laden") { withAnimation { wanderung = nil; fehler = nil } }
        }
    }

    private func sichern() async {
        guard var w = wanderung else { return }
        sichert = true
        w.beginnen(beginn)
        _ = await Nachtrag.anlegen(w, titel: titel, text: text, in: reise, zone: zone)
        sichert = false
        schliessen()
    }
}
