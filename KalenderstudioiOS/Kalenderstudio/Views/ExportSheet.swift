import SwiftUI

struct ExportSheet: View {
    let project: CalendarProject

    @Environment(\.dismiss) private var dismiss
    @State private var options = ExportOptions()
    @State private var running = false
    @State private var progress = 0.0
    @State private var progressText = ""
    @State private var files: [URL] = []
    @State private var showShare = false
    @State private var errorText: String?

    private var weakPhotos: [PhotoItem] {
        project.photos.filter { max($0.pixelWidth, $0.pixelHeight) < 2000 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Druckdatei") {
                    LabeledContent("Kalender", value: "\(project.kind.title) \(project.yearText)")
                    LabeledContent("Seiten", value: "\(project.pages.count)")
                    LabeledContent("Endformat", value: project.format.summary)
                    LabeledContent("Mit Beschnitt",
                                   value: "\(project.format.documentWidthMM.mmText) × \(project.format.documentHeightMM.mmText) mm")
                    LabeledContent("Sicherheitsabstand", value: "\(project.format.safetyMM.mmText) mm")
                }

                Section {
                    Picker("Dateiart", selection: $options.format) {
                        ForEach(ExportOptions.Format.allCases) { f in Text(f.title).tag(f) }
                    }
                    Picker("Auflösung", selection: $options.dpi) {
                        Text("150 dpi (Entwurf)").tag(150.0)
                        Text("200 dpi").tag(200.0)
                        Text("300 dpi (Druck)").tag(300.0)
                    }
                    if options.format == .pdf {
                        Toggle("Schnittmarken", isOn: $options.cropMarks)
                    }
                } header: {
                    Text("Einstellungen")
                } footer: {
                    Text("Jede Seite enthält den Beschnitt rundum. Im PDF sind Endformat (TrimBox) und Beschnitt (BleedBox) hinterlegt. Schnittmarken nur, wenn der Druckdienst sie verlangt — die meisten möchten keine.")
                }

                if project.photos.isEmpty || !weakPhotos.isEmpty {
                    Section("Hinweise") {
                        if project.photos.isEmpty {
                            Label("Noch keine Fotos — die Fotoflächen bleiben farbig.", systemImage: "photo")
                                .foregroundStyle(.orange)
                        }
                        if !weakPhotos.isEmpty {
                            Label("\(weakPhotos.count) Foto(s) mit geringer Auflösung können im Druck unscharf wirken. In der Vorschau zeigt ein orangefarbenes Schild die betroffenen Flächen.",
                                  systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
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
                            Label("Druckdatei erstellen", systemImage: "printer.fill")
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
                            Label(files.count == 1 ? "Teilen oder sichern" : "\(files.count) Dateien teilen oder sichern",
                                  systemImage: "square.and.arrow.up")
                        }
                    }
                    if let errorText {
                        Text(errorText).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Exportieren")
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
        do {
            let result = try await Exporter.export(project: project, options: options) { value, text in
                progress = value
                progressText = text
            }
            files = result
            showShare = true
        } catch {
            errorText = "Der Export ist fehlgeschlagen: \(error.localizedDescription)"
        }
        running = false
    }
}
