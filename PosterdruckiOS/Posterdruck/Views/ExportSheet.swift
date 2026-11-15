import SwiftUI

struct ExportSheet: View {
    let project: PosterProject

    @Environment(\.dismiss) private var dismiss
    @State private var options = ExportOptions()
    @State private var running = false
    @State private var progress = 0.0
    @State private var progressText = ""
    @State private var files: [URL] = []
    @State private var showShare = false
    @State private var errorText: String?

    private struct Weak: Identifiable {
        let index: Int
        let dpi: Double
        var id: Int { index }
    }

    private var weak: [Weak] {
        project.items.enumerated().compactMap { n, item -> Weak? in
            let g = PageGeometry(format: project.format, item: item)
            let dpi = PosterLayout.effectiveDPI(item: item, geometry: g)
            return PosterLayout.quality(dpi: dpi) == .good ? nil : Weak(index: n, dpi: dpi)
        }
    }

    private var totalBytes: Int64 {
        project.items.reduce(0) { $0 + PhotoStore.shared.fileSize($1.photoID) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Druckdatei") {
                    LabeledContent("Poster", value: "\(project.items.count)")
                    LabeledContent("Endformat", value: project.format.trimSummary)
                    LabeledContent("Beschnitt", value: "\(project.format.bleedMM.mmText) mm je Seite")
                    LabeledContent("Datenformat (PDF-Seite)", value: project.format.dataSummary)
                    LabeledContent("Ungefähre Größe", value: ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                }

                Section {
                    Picker("Dateien", selection: $options.oneFile) {
                        Text("Eine PDF, ein Poster je Seite").tag(true)
                        Text("Eine PDF je Poster").tag(false)
                    }
                    Toggle("Schnittmarken", isOn: $options.cropMarks)
                } header: {
                    Text("Einstellungen")
                } footer: {
                    Text("Jede Seite hat das Datenformat — das Bild reicht bis in den Beschnitt. Endformat (TrimBox) und Beschnitt (BleedBox) sind in der PDF hinterlegt. Die gestrichelte Linie der Vorschau kommt NICHT in die Druckdatei. Schnittmarken nur, wenn die Druckerei sie verlangt; sie vergrößern die Seite um den Markenrand. Die Bilder werden in voller Auflösung übernommen, JPEG-Fotos ohne erneute Kompression.")
                }

                if !weak.isEmpty {
                    Section("Hinweise") {
                        ForEach(weak) { w in
                            Label("Poster \(w.index + 1): nur \(Int(w.dpi.rounded())) dpi — \(PosterLayout.quality(dpi: w.dpi) == .low ? "wirkt im Druck weich" : "aus Abstand noch brauchbar").",
                                  systemImage: "exclamationmark.triangle")
                                .foregroundStyle(PosterLayout.quality(dpi: w.dpi) == .low ? Color.red : Color.orange)
                        }
                    }
                }

                Section {
                    if running {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: progress)
                            Text(progressText).font(.footnote).foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            Task { await run() }
                        } label: {
                            Label("PDF erstellen", systemImage: "printer.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                    if !files.isEmpty && !running {
                        Button {
                            showShare = true
                        } label: {
                            Label(files.count == 1 ? "Teilen oder in Dateien sichern" : "\(files.count) Dateien teilen oder sichern",
                                  systemImage: "square.and.arrow.up")
                        }
                    }
                    if let errorText {
                        Text(errorText).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("PDF erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schließen") { dismiss() }
                        .disabled(running)
                }
            }
            .sheet(isPresented: $showShare) {
                ShareSheet(items: files)
                    .ignoresSafeArea()
            }
        }
        .interactiveDismissDisabled(running)
    }

    private func run() async {
        running = true
        errorText = nil
        files = []
        progress = 0
        let project = self.project
        let options = self.options
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try PDFExporter.export(project: project, options: options) { value, text in
                    Task { @MainActor in
                        progress = value
                        progressText = text
                    }
                }
            }.value
            files = result
            showShare = true
        } catch {
            errorText = "Die PDF ließ sich nicht erstellen: \(error.localizedDescription)"
        }
        running = false
    }
}
