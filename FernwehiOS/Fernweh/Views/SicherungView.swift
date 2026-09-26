import SwiftUI
import CoreData
import UniformTypeIdentifiers

/// Eine Sicherung erstellen (ab 1.0.22): alles, eine Reise oder ein
/// Tagebuch. Die Regeln stehen in `Sicherung.swift`.
struct SicherungView: View {
    /// Vorgewählt, etwa aus dem Menü einer Reise.
    var vorgabe: Sicherung.Umfang = .alles
    @Environment(\.dismiss) private var schliessen

    private enum Art: Hashable { case alles, reise, tagebuch }

    @State private var art: Art = .alles
    @State private var reiseID: NSManagedObjectID?
    @State private var tagebuch = ""
    @State private var laeuft = false
    @State private var fertig = 0
    @State private var gesamt = 0
    @State private var fehler: String?
    @State private var ergebnis: Sicherung.Ergebnis?
    @State private var zahl: Sicherung.Zaehlung?

    @FetchRequest(fetchRequest: Reise.alle()) private var reisen: FetchedResults<Reise>
    @State private var tagebuecher: [String] = []

    private var umfang: Sicherung.Umfang? {
        switch art {
        case .alles: return .alles
        case .reise: return reiseID.map { .reise($0) }
        case .tagebuch: return .tagebuch(tagebuch)
        }
    }

    private var titel: String {
        switch art {
        case .alles: return "alles"
        case .reise: return reisen.first { $0.objectID == reiseID }?.anzeigeTitel ?? "Reise"
        case .tagebuch: return tagebuch.isEmpty ? "ohne Tagebuch" : tagebuch
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Was", selection: $art) {
                        Text("Alles").tag(Art.alles)
                        Text("Eine Reise").tag(Art.reise)
                        Text("Ein Tagebuch").tag(Art.tagebuch)
                    }
                    .pickerStyle(.segmented)
                    if art == .reise {
                        Picker("Reise", selection: $reiseID) {
                            ForEach(reisen) { r in
                                Text(r.anzeigeTitel).tag(Optional(r.objectID))
                            }
                        }
                    }
                    if art == .tagebuch {
                        Picker("Tagebuch", selection: $tagebuch) {
                            ForEach(tagebuecher, id: \.self) { n in
                                Text(n.isEmpty ? "Ohne Tagebuch" : n).tag(n)
                            }
                        }
                    }
                } footer: {
                    Text("Mit Fotos (die Kopien, die in Fernweh liegen), Texten, Orten, Wetter, Spuren, Wanderungen und Autofahrten. Die Originale in deiner Mediathek sichert iCloud-Fotos, nicht Fernweh.")
                }

                if let zahl {
                    Section("Inhalt") {
                        Text(zahl.text)
                        if zahl.gesperrt > 0 {
                            Label("\(zahl.gesperrt) Einträge aus gesperrten Tagebüchern gehen nicht mit. Öffne diese Tagebücher vorher, wenn sie in die Sicherung sollen.",
                                  systemImage: "lock.fill")
                                .font(.callout)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    Button {
                        Task { await erstellen() }
                    } label: {
                        HStack {
                            Label("Sicherung erstellen", systemImage: "externaldrive.badge.plus")
                            if laeuft { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(umfang == nil || laeuft)
                    if laeuft && gesamt > 0 {
                        ProgressView(value: Double(fertig), total: Double(gesamt))
                    }
                    if let ergebnis {
                        Button { weitergeben(ergebnis.datei) } label: {
                            Label("Datei sichern oder teilen …", systemImage: "square.and.arrow.up")
                        }
                    }
                } footer: {
                    if ergebnis != nil {
                        Text("Am besten „In Dateien sichern“ — in iCloud Drive oder auf einen USB-Stick. Eine Sicherung, die nur auf diesem Gerät liegt, verschwindet mit ihm.")
                    }
                }

                if let fehler {
                    Section {
                        Label(fehler, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Sicherung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() }.disabled(laeuft) }
            }
            .interactiveDismissDisabled(laeuft)
            .onAppear {
                tagebuecher = Sicherung.tagebuchnamen()
                switch vorgabe {
                case .alles: art = .alles
                case .reise(let id): art = .reise; reiseID = id
                case .tagebuch(let n): art = .tagebuch; tagebuch = n
                }
                if reiseID == nil { reiseID = reisen.first?.objectID }
                if art != .tagebuch, let erstes = tagebuecher.first { tagebuch = erstes }
            }
            // Gezählt wird beim Wechsel, nicht bei jedem Zeichnen — für
            // „Alles" geht das über jeden Eintrag.
            .task(id: umfang) { zahl = umfang.map { Sicherung.objekte($0).zahl } }
            .onChange(of: art) { _, _ in ergebnis = nil }
            .onChange(of: reiseID) { _, _ in ergebnis = nil }
            .onChange(of: tagebuch) { _, _ in ergebnis = nil }
        }
    }

    private func erstellen() async {
        guard let umfang else { return }
        laeuft = true
        fehler = nil
        ergebnis = nil
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            laeuft = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
        do {
            let e = try await Sicherung.erstellen(umfang, titel: titel) { f, g in
                fertig = f
                gesamt = g
            }
            ergebnis = e
            weitergeben(e.datei)
        } catch {
            fehler = "Die Sicherung ließ sich nicht schreiben: \(error.localizedDescription)"
        }
    }

    /// Teilen-Blatt über UIKit, wie bei der Übergabe.
    private func weitergeben(_ datei: URL) {
        guard let oben = Teilen.obersterController() else { return }
        let blatt = UIActivityViewController(activityItems: [datei], applicationActivities: nil)
        if let pop = blatt.popoverPresentationController {
            pop.sourceView = oben.view
            pop.sourceRect = CGRect(x: oben.view.bounds.midX, y: oben.view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        oben.present(blatt, animated: true)
    }
}

/// Aus einer Sicherung wiederherstellen (ab 1.0.22): Datei wählen, Inhalt
/// sehen, zusammenführen. Was schon da ist, bleibt unverändert.
struct WiederherstellenView: View {
    @Environment(\.dismiss) private var schliessen

    @State private var dateiWahl = false
    @State private var url: URL?
    @State private var zugriff = false
    @State private var inhalt: Sicherung.Inhalt?
    @State private var fehler: String?
    @State private var laeuft = false
    @State private var fertig = 0
    @State private var gesamt = 0
    @State private var bericht: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { dateiWahl = true } label: {
                        Label(inhalt == nil ? "Sicherung wählen" : "Andere Sicherung wählen", systemImage: "doc.zipper")
                    }
                    .disabled(laeuft)
                } footer: {
                    Text("Eine Datei „Fernweh-Sicherung … .zip“. Wiederhergestellt wird zusammenführend: Was schon da ist, bleibt, wie es ist; nur Fehlendes kommt dazu — gelöschte Einträge, Fotos und Reisen kehren so zurück.")
                }
                if let inhalt {
                    Section("In der Sicherung") {
                        LabeledContent("Umfang", value: inhalt.umfang)
                        if let d = inhalt.erzeugt {
                            LabeledContent("Erstellt", value: Tag.text(d, "d. MMMM yyyy, HH:mm", zone: .current))
                        }
                        Text(inhalt.zahl.text)
                        if !inhalt.app.isEmpty {
                            Text(inhalt.app).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        Button {
                            Task { await wiederherstellen(inhalt) }
                        } label: {
                            HStack {
                                Label("Wiederherstellen", systemImage: "arrow.counterclockwise.circle")
                                if laeuft { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(laeuft || bericht != nil)
                        if laeuft && gesamt > 0 {
                            ProgressView(value: Double(fertig), total: Double(gesamt))
                        }
                    }
                }
                if let bericht {
                    Section { Label(bericht, systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                }
                if let fehler {
                    Section { Label(fehler, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                }
            }
            .navigationTitle("Wiederherstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() }.disabled(laeuft) }
            }
            .interactiveDismissDisabled(laeuft)
            .fileImporter(isPresented: $dateiWahl, allowedContentTypes: [.zip, .data],
                          allowsMultipleSelection: false) { ergebnis in
                if case .success(let urls) = ergebnis, let neu = urls.first { oeffnen(neu) }
            }
            .onDisappear { freigeben() }
        }
    }

    /// Der Zugriff auf die gewählte Datei bleibt offen, solange das Blatt
    /// steht: Das Archiv wird nicht kopiert, sondern abgebildet und beim
    /// Wiederherstellen Stück für Stück gelesen.
    private func oeffnen(_ neu: URL) {
        freigeben()
        fehler = nil
        bericht = nil
        inhalt = nil
        zugriff = neu.startAccessingSecurityScopedResource()
        url = neu
        do {
            inhalt = try Sicherung.lesen(neu)
        } catch {
            fehler = error.localizedDescription
        }
    }

    private func freigeben() {
        if zugriff, let url { url.stopAccessingSecurityScopedResource() }
        zugriff = false
    }

    private func wiederherstellen(_ inhalt: Sicherung.Inhalt) async {
        laeuft = true
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            laeuft = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
        let b = await Sicherung.wiederherstellen(inhalt) { f, g in
            fertig = f
            gesamt = g
        }
        bericht = b.text
    }
}
