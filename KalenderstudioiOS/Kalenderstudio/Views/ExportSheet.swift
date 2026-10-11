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

    /// Schriften, die fehlen oder nicht eingebettet werden dürfen — die
    /// Druckerei ersetzte sie stillschweigend.
    private var fontProblems: [(family: String, problem: String)] {
        let d = project.design
        var seen = Set<String>()
        var result: [(family: String, problem: String)] = []
        for family in [d.titleFont, d.bodyFont, d.numberFont] where seen.insert(family).inserted {
            switch FontLicense.check(family: family) {
            case .restricted:
                result.append((family: family, problem: "darf laut Lizenz nicht ins PDF eingebettet werden — die Druckerei würde sie ersetzen"))
            case .unavailable:
                result.append((family: family, problem: "ist auf diesem Gerät nicht verfügbar — gedruckt würde die Systemschrift"))
            case .allowed, .unknown:
                break
            }
        }
        return result
    }

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
                        if project.kind == .year && project.yearLayout == .halfMonth {
                            Toggle("Rückseiten auf den Kopf stellen", isOn: $options.flipBacks)
                        }
                    }
                } header: {
                    Text("Einstellungen")
                } footer: {
                    Text("Jede Seite enthält den Beschnitt rundum. Im PDF sind Endformat (TrimBox) und Beschnitt (BleedBox) hinterlegt. Schnittmarken nur, wenn der Druckdienst sie verlangt — die meisten möchten keine.\(project.kind == .year && project.yearLayout == .halfMonth ? " Beidseitig: Die Seiten stehen chronologisch und aufrecht im PDF (so verlangt es das Druckhaus Bochum). „Rückseiten auf den Kopf“ nur, wenn eine Druckerei „Kopf an Fuß“ verlangt." : "")")
                }

                if project.photos.isEmpty || !weakPhotos.isEmpty || !fontProblems.isEmpty {
                    Section("Hinweise") {
                        if project.photos.isEmpty {
                            Label("Noch keine Fotos — die Fotoflächen bleiben farbig.", systemImage: "photo")
                                .foregroundStyle(.orange)
                        }
                        let problems = fontProblems
                        ForEach(problems.indices, id: \.self) { i in
                            let item = problems[i]
                            Label("Schrift „\(item.family)“ \(item.problem).", systemImage: "textformat")
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
