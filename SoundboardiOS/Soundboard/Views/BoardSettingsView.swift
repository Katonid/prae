import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Verwaltung der Boards: Reihenfolge, Name, Farbe, Sichtbarkeit, Hintergrundbild
/// sowie Export/Import aller Daten.
struct BoardSettingsView: View {
    @EnvironmentObject var store: BoardStore
    @EnvironmentObject var engine: AudioEngine
    @Environment(\.dismiss) private var dismiss

    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pendingImportURL: URL?
    @State private var exportDocument: ExportDocument?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.boards) { board in
                        NavigationLink {
                            BoardDetailView(boardID: board.id)
                                .environmentObject(store)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: board.colorHex))
                                    .frame(width: 12, height: 12)
                                Text(board.name)
                                Spacer()
                                if board.hidden {
                                    Image(systemName: "eye.slash")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .onMove { store.moveBoards(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("Boards")
                } footer: {
                    Text("Zum Sortieren ziehen. Ausgeblendete Boards erscheinen nicht in der Auswahlleiste.")
                }

                Section {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Alles exportieren …", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Export-Datei importieren …", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Sichern & Übertragen")
                } footer: {
                    Text("Der Export enthält alle Boards, Einstellungen und lokalen Tondateien. Beim Import werden die vorhandenen Daten ersetzt.")
                }
            }
            .navigationTitle("Boards & Daten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "Soundboard-Export"
            ) { result in
                if case .success = result {
                    store.showStatus("Export gespeichert.")
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    pendingImportURL = url
                }
            }
            .alert("Alle Daten ersetzen?", isPresented: Binding(
                get: { pendingImportURL != nil },
                set: { if !$0 { pendingImportURL = nil } }
            )) {
                Button("Importieren", role: .destructive) {
                    if let url = pendingImportURL {
                        engine.resetAll()
                        store.importData(from: url)
                    }
                    pendingImportURL = nil
                }
                Button("Abbrechen", role: .cancel) {
                    pendingImportURL = nil
                }
            } message: {
                Text("Beim Import werden alle vorhandenen Boards, Felder und Tondateien durch den Inhalt der Export-Datei ersetzt.")
            }
        }
    }

    private func prepareExport() {
        do {
            exportDocument = ExportDocument(data: try store.makeExportData())
            showExporter = true
        } catch {
            store.showStatus("Export fehlgeschlagen.")
        }
    }
}

/// Einstellungen eines einzelnen Boards.
struct BoardDetailView: View {
    let boardID: UUID
    @EnvironmentObject var store: BoardStore

    @State private var photoItem: PhotosPickerItem?

    private var board: SoundBoard {
        store.boards.first { $0.id == boardID } ?? SoundBoard()
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name des Boards", text: Binding(
                    get: { board.name },
                    set: { value in store.updateBoard(boardID) { $0.name = value } }
                ))
            }

            Section("Farbe") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                    ForEach(BoardDefaults.swatchColors, id: \.self) { hex in
                        let selected = board.colorHex.lowercased() == hex.lowercased()
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 30, height: 30)
                            .overlay {
                                if selected {
                                    Circle().strokeBorder(.white, lineWidth: 2.5)
                                }
                            }
                            .onTapGesture {
                                store.updateBoard(boardID) { $0.colorHex = hex }
                            }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Toggle("Board ausblenden", isOn: Binding(
                    get: { board.hidden },
                    set: { value in
                        let visibleCount = store.boards.filter { !$0.hidden }.count
                        if value && visibleCount <= 1 {
                            store.showStatus("Mindestens ein Board muss sichtbar bleiben.")
                            return
                        }
                        store.updateBoard(boardID) { $0.hidden = value }
                        if value && store.activeBoardID == boardID {
                            store.activeBoardID = store.visibleBoards.first?.id
                        }
                    }
                ))
            } footer: {
                Text("Ausgeblendete Boards behalten ihre Felder und Töne.")
            }

            Section("Hintergrundbild") {
                if let url = store.backgroundImageURL(for: board),
                   let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Bild aus Fotos wählen …", systemImage: "photo")
                }
                if board.backgroundImagePath != nil {
                    Button(role: .destructive) {
                        store.removeBackgroundImage(for: boardID)
                    } label: {
                        Label("Hintergrundbild entfernen", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(board.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem) {
            guard let item = photoItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let jpeg = image.jpegData(compressionQuality: 0.8) {
                    store.setBackgroundImage(data: jpeg, for: boardID)
                }
                photoItem = nil
            }
        }
    }
}

/// Hülle für den Datei-Export über `fileExporter`.
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
