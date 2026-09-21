import PDFKit
import SwiftUI

struct AusgabeView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    @State private var anteil: Double = 0
    @State private var laeuft = false
    @State private var fertig: URL?
    @State private var befundAmPDF: [Druckpruefung.Zeile] = []
    @State private var fehler: String?
    @State private var teilen = false
    @State private var guete: Bildguete = .druck
    @State private var ohneTransparenz = false
    @State private var umfang: Umfang = .ganzesBuch
    @State private var teilenliste: [URL] = []

    enum Umfang: String, CaseIterable, Identifiable {
        case ganzesBuch
        case getrennt

        var id: String { rawValue }
        var name: String {
            switch self {
            case .ganzesBuch: return "Eine Datei"
            case .getrennt: return "Umschlag getrennt"
            }
        }
    }

    enum Bildguete: String, CaseIterable, Identifiable {
        case sparsam
        case druck
        case voll

        var id: String { rawValue }

        var kante: Int {
            switch self {
            case .sparsam: return 1600
            case .druck: return 3600
            case .voll: return 6000
            }
        }

        var name: String {
            switch self {
            case .sparsam: return "Zum Ansehen"
            case .druck: return "Für den Druck"
            case .voll: return "Volle Auflösung"
            }
        }

        var erklaerung: String {
            switch self {
            case .sparsam:
                return "Kleine Datei zum Durchsehen und Verschicken. Für den Druck zu wenig."
            case .druck:
                return "Bis 3600 Bildpunkte je Kante — das reicht für 300 dpi auf einer ganzen A4-Seite. Der übliche Fall."
            case .voll:
                return "So groß, wie die Bilder hergeben. Nötig nur bei Formaten über 30 cm; die Datei kann sehr groß werden."
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Seiten", value: "\(werk.reise.seitenzahl)")
                    LabeledContent("Endformat", value: werk.reise.format.masstext)
                    Picker("Bildgüte", selection: $guete) {
                        ForEach(Bildguete.allCases) { g in Text(g.name).tag(g) }
                    }
                    Text(guete.erklaerung)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Umfang", selection: $umfang) {
                        ForEach(Umfang.allCases) { u in Text(u.name).tag(u) }
                    }
                    Toggle("Ohne Transparenz (PDF/X-1a, X-3)", isOn: $ohneTransparenz)
                    if ohneTransparenz {
                        Text("Schatten fallen weg, und der Verlauf unter einer Überschrift auf einem Foto wird zu einem geschlossenen Feld. Nur nötig, wenn die Druckerei ausdrücklich danach fragt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Was ausgegeben wird")
                } footer: {
                    Text("Der Text wird als Text gesetzt, nicht als Bild — das PDF bleibt durchsuchbar und wiegt einen Bruchteil. Endformat und Anschnitt stehen als TrimBox und BleedBox darin.")
                }

                Section("Vor dem Ausgeben geprüft") {
                    ForEach(Druckpruefung.vorab(werk.reise)) { zeile in
                        BefundZeile(zeile: zeile)
                    }
                }

                if laeuft {
                    Section {
                        ProgressView(value: anteil)
                        Text(anteil < 0.45 ? "Kartenbilder werden geholt…" : "Seiten werden gesetzt…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let fehler {
                    Section {
                        Label(fehler, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                if let fertig {
                    Section("An der fertigen Datei gemessen") {
                        ForEach(befundAmPDF) { zeile in BefundZeile(zeile: zeile) }
                    }
                    Section {
                        PDFVorschau(adresse: fertig)
                            .frame(height: 320)
                            .listRowInsets(EdgeInsets())
                        Button {
                            teilen = true
                        } label: {
                            Label("Sichern oder teilen", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Section {
                    Button {
                        Task { await ausgeben() }
                    } label: {
                        Label(fertig == nil ? "PDF erzeugen" : "Noch einmal erzeugen",
                              systemImage: "doc.badge.gearshape")
                    }
                    .disabled(laeuft)
                }
            }
            .navigationTitle("Als PDF sichern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            .sheet(isPresented: $teilen) {
                Teilenblatt(gegenstaende: teilenliste)
            }
        }
    }

    private func ausgeben() async {
        laeuft = true
        fehler = nil
        anteil = 0
        befundAmPDF = []
        do {
            if umfang == .getrennt {
                // Viele Buchdienste wollen Umschlag und Innenteil als zwei
                // Dateien. Ausgegeben wird dann der Innenteil als Hauptdatei
                // und der Umschlag daneben — beide liegen im selben Ordner
                // und werden zusammen geteilt.
                let umschlag = try await Buchausgabe.pdf(
                    werk.reise,
                    auftrag: .init(bildkante: guete.kante, ohneTransparenz: ohneTransparenz,
                                   nurUmschlag: true),
                    fortschritt: { _ in })
                let innen = try await Buchausgabe.pdf(
                    werk.reise,
                    auftrag: .init(bildkante: guete.kante, ohneTransparenz: ohneTransparenz,
                                   ohneUmschlag: true),
                    fortschritt: { wert in anteil = wert })
                fertig = innen
                befundAmPDF = Druckpruefung.amPDF(innen)
                    + [Druckpruefung.Zeile(
                        stufe: .gut, titel: "Umschlag getrennt gesichert",
                        text: umschlag.lastPathComponent)]
                teilenliste = [innen, umschlag]
            } else {
                let ziel = try await Buchausgabe.pdf(
                    werk.reise,
                    auftrag: .init(bildkante: guete.kante, ohneTransparenz: ohneTransparenz),
                    fortschritt: { wert in anteil = wert })
                fertig = ziel
                befundAmPDF = Druckpruefung.amPDF(ziel)
                teilenliste = [ziel]
            }
        } catch {
            fehler = error.localizedDescription
        }
        laeuft = false
    }

}

struct BefundZeile: View {
    let zeile: Druckpruefung.Zeile

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: zeile.stufe.symbol)
                .foregroundStyle(farbe)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(zeile.titel)
                    .font(.subheadline.weight(.medium))
                Text(zeile.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
    }

    private var farbe: Color {
        switch zeile.stufe {
        case .gut: return .green
        case .hinweis: return .secondary
        case .warnung: return .orange
        }
    }
}

struct PDFVorschau: UIViewRepresentable {
    let adresse: URL

    func makeUIView(context: Context) -> PDFView {
        let ansicht = PDFView()
        ansicht.autoScales = true
        ansicht.displayMode = .singlePageContinuous
        ansicht.displayDirection = .vertical
        ansicht.backgroundColor = .systemGroupedBackground
        return ansicht
    }

    func updateUIView(_ ansicht: PDFView, context: Context) {
        if ansicht.document?.documentURL != adresse {
            ansicht.document = PDFDocument(url: adresse)
        }
    }
}
