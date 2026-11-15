import SwiftUI

/// Seitenformat des Auftrags: Vorlage, Maße, Ausrichtung, Beschnitt.
struct FormatSheet: View {
    @Binding var format: PosterFormat
    /// Ein Bild des Auftrags für die Skizze (bei „Wie das Bild“).
    let sample: PosterItem?

    @Environment(\.dismiss) private var dismiss
    @AppStorage("eingabeDatenformat") private var enterDataSize = false

    private var landscapeView: Bool { format.orientation == .landscape }

    /// Breite und Höhe so, wie die Seite steht (bei „Wie das Bild“ hochkant).
    private var widthBinding: Binding<Double> {
        Binding(
            get: { (landscapeView ? format.longMM : format.shortMM) + extra },
            set: { v in
                let t = max(v - extra, 10)
                if landscapeView { format.longMM = t } else { format.shortMM = t }
            }
        )
    }

    private var heightBinding: Binding<Double> {
        Binding(
            get: { (landscapeView ? format.shortMM : format.longMM) + extra },
            set: { v in
                let t = max(v - extra, 10)
                if landscapeView { format.shortMM = t } else { format.longMM = t }
            }
        )
    }

    /// Bei Eingabe des Datenformats kommt der Beschnitt beidseitig dazu.
    private var extra: Double { enterDataSize ? 2 * format.bleedMM : 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    sketch
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                Section("Vorlage") {
                    Menu {
                        ForEach(PosterFormat.presets) { p in
                            Button("\(p.name) — \(p.shortMM.mmText) × \(p.longMM.mmText) mm") {
                                format.shortMM = p.shortMM
                                format.longMM = p.longMM
                            }
                        }
                    } label: {
                        LabeledContent("Format") {
                            HStack(spacing: 4) {
                                Text(format.presetName)
                                Image(systemName: "chevron.up.chevron.down").font(.caption)
                            }
                        }
                    }
                    Picker("Ausrichtung", selection: $format.orientation) {
                        ForEach(PageOrientation.allCases) { o in
                            Label(o.title, systemImage: o.symbol).tag(o)
                        }
                    }
                }

                Section {
                    Picker("Maße eingeben als", selection: $enterDataSize) {
                        Text("Endformat").tag(false)
                        Text("Datenformat").tag(true)
                    }
                    .pickerStyle(.segmented)
                    MMField(title: format.orientation == .auto ? "Breite (hochkant)" : "Breite", value: widthBinding)
                    MMField(title: format.orientation == .auto ? "Höhe (hochkant)" : "Höhe", value: heightBinding)
                } header: {
                    Text("Maße")
                } footer: {
                    Text(enterDataSize
                         ? "Datenformat = Endformat + Beschnitt auf beiden Seiten. So steht es oft im Datenblatt der Druckerei (DIN A2 mit 3 mm: 426 × 600 mm)."
                         : "Endformat = das fertige, geschnittene Poster (DIN A2: 420 × 594 mm).")
                }

                Section {
                    MMField(title: "Beschnitt je Seite", value: Binding(
                        get: { format.bleedMM },
                        set: { format.bleedMM = min(max($0, 0), 50) }
                    ))
                    MMField(title: "Sicherheitsabstand", value: Binding(
                        get: { format.safetyMM },
                        set: { format.safetyMM = min(max($0, 0), 100) }
                    ))
                } header: {
                    Text("Beschnitt")
                } footer: {
                    Text("Der Beschnitt ist der Rand, den die Druckerei nach dem Druck abschneidet — das Bild reicht bis dorthin, damit keine weißen Blitzer bleiben. In der Vorschau zeigt die rote gestrichelte Linie die Schnittkante. Ein Sicherheitsabstand (blau gestrichelt) markiert, wie weit Wichtiges vom Rand wegbleiben sollte; 0 = keine Linie.")
                }

                Section("Ergebnis") {
                    LabeledContent("Endformat", value: format.trimSummary)
                    LabeledContent("Datenformat (PDF-Seite)", value: format.dataSummary)
                    if format.orientation == .auto {
                        Text("Querformatige Bilder bekommen eine quer liegende Seite, hochformatige eine stehende.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.fontWeight(.bold)
                }
            }
            .onChange(of: format) { _, f in
                let name = PosterFormat.presetName(short: f.shortMM, long: f.longMM)
                if name != f.presetName { format.presetName = name }
            }
        }
    }

    /// Skizze der Seite mit Beschnitt und Maßen.
    private var sketch: some View {
        GeometryReader { geo in
            let item: PosterItem? = format.orientation == .auto ? sample : nil
            let g = PageGeometry(format: format, item: item)
            let s = min((geo.size.width - 120) / g.size.width, (geo.size.height - 50) / g.size.height)
            let scale = max(s, 0.01)
            VStack(spacing: 6) {
                ZStack(alignment: .topLeading) {
                    LinearGradient(colors: [Color(red: 0.55, green: 0.72, blue: 0.86), Color(red: 0.93, green: 0.78, blue: 0.62)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    GuidesOverlay(g: g, scale: scale)
                }
                .frame(width: g.size.width * scale, height: g.size.height * scale)
                .shadow(radius: 3)
                Text("Endformat \(g.trimMM.w.mmText) × \(g.trimMM.h.mmText) mm · Datenformat \(g.dataMM.w.mmText) × \(g.dataMM.h.mmText) mm")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
