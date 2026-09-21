import PDFKit
import SwiftUI

struct AusgabeView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    @State private var anteil: Double = 0
    @State private var laeuft = false
    @State private var fertig: URL?
    @State private var fehler: String?
    @State private var teilen = false
    @State private var guete: Bildguete = .druck

    enum Bildguete: String, CaseIterable, Identifiable {
        case sparsam
        case druck
        case voll

        var id: String { rawValue }

        var kante: Int {
            switch self {
            case .sparsam: return 1400
            case .druck: return 2400
            case .voll: return 4000
            }
        }

        var name: String {
            switch self {
            case .sparsam: return "Sparsam"
            case .druck: return "Für den Druck"
            case .voll: return "Volle Auflösung"
            }
        }

        var erklaerung: String {
            switch self {
            case .sparsam: return "Kleine Datei, gut zum Anschauen und Verschicken. Für den Druck zu wenig."
            case .druck: return "Genug für eine gedruckte A4-Seite. Der übliche Fall."
            case .voll: return "So groß wie die Bilder hergeben. Die Datei kann sehr groß werden."
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Seiten", value: "\(werk.reise.seitenzahl)")
                    LabeledContent("Format", value: werk.reise.format.name)
                    Picker("Bildgüte", selection: $guete) {
                        ForEach(Bildguete.allCases) { g in Text(g.name).tag(g) }
                    }
                    Text(guete.erklaerung)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Was ausgegeben wird")
                } footer: {
                    Text("Der Text wird als Text gesetzt, nicht als Bild — das PDF bleibt durchsuchbar und wiegt einen Bruchteil.")
                }

                if laeuft {
                    Section {
                        ProgressView(value: anteil)
                        Text(anteil < 0.45
                             ? "Kartenbilder werden geholt…"
                             : "Seiten werden gesetzt…")
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
                    Section {
                        PDFVorschau(adresse: fertig)
                            .frame(height: 320)
                            .listRowInsets(EdgeInsets())
                        Button {
                            teilen = true
                        } label: {
                            Label("Sichern oder teilen", systemImage: "square.and.arrow.up")
                        }
                    } header: {
                        Text("Fertig")
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
                if let fertig {
                    Teilenblatt(gegenstaende: [fertig])
                }
            }
        }
    }

    private func ausgeben() async {
        laeuft = true
        fehler = nil
        anteil = 0
        do {
            let ziel = try await Buchausgabe.pdf(werk.reise, bildkante: guete.kante) { wert in
                anteil = wert
            }
            fertig = ziel
        } catch {
            fehler = error.localizedDescription
        }
        laeuft = false
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
