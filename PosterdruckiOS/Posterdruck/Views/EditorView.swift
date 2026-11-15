import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Ein Auftrag: alle Poster als Raster, Bilder hinzufügen, Format, Export.
struct EditorView: View {
    @Binding var project: PosterProject

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showFiles = false
    @State private var showFormat = false
    @State private var showExport = false
    @State private var editing: EditTarget?
    @State private var importing = 0
    @State private var importErrors = 0
    @State private var showGuides = true

    struct EditTarget: Identifiable {
        let id: UUID
    }

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 18)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                formatCard
                if project.items.isEmpty {
                    emptyHint
                } else {
                    LazyVGrid(columns: columns, spacing: 22) {
                        ForEach(Array(project.items.enumerated()), id: \.element.id) { index, item in
                            tile(item, index: index)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: nil, matching: .images,
                                 preferredItemEncoding: .current) {
                        Label("Aus Fotos", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        showFiles = true
                    } label: {
                        Label("Aus Dateien", systemImage: "folder")
                    }
                } label: {
                    Label("Bilder hinzufügen", systemImage: "plus")
                }
                Button {
                    showExport = true
                } label: {
                    Label("PDF erstellen", systemImage: "square.and.arrow.up")
                }
                .disabled(project.items.isEmpty || importing > 0)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if importing > 0 {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(importing == 1 ? "1 Bild wird übernommen …" : "\(importing) Bilder werden übernommen …")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(.regularMaterial))
                .padding(.bottom, 8)
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            pickerItems = []
            importFromPhotos(items)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                importFromFiles(urls)
            }
        }
        .sheet(isPresented: $showFormat) {
            FormatSheet(format: $project.format, sample: project.items.first)
        }
        .sheet(isPresented: $showExport) {
            ExportSheet(project: project)
        }
        .fullScreenCover(item: $editing) { target in
            PosterEditSheet(project: $project, itemID: target.id)
        }
        .alert("Nicht alle Bilder ließen sich lesen",
               isPresented: Binding(get: { importErrors > 0 }, set: { if !$0 { importErrors = 0 } })) {
            Button("OK") { importErrors = 0 }
        } message: {
            Text(importErrors == 1 ? "Ein Bild wurde übersprungen." : "\(importErrors) Bilder wurden übersprungen.")
        }
    }

    // MARK: - Teile

    private var formatCard: some View {
        Button {
            showFormat = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: project.format.orientation.symbol)
                    .font(.title)
                    .foregroundStyle(.tint)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(project.format.presetName) · \(project.format.orientation.title)")
                        .font(.headline)
                    Text("Endformat \(project.format.trimSummary) · Beschnitt \(project.format.bleedMM.mmText) mm")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Datenformat \(project.format.dataSummary)")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                Text("Ändern")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if !project.items.isEmpty {
                Toggle("Beschnitt zeigen", isOn: $showGuides)
                    .toggleStyle(.button)
                    .font(.caption)
                    .padding(8)
            }
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
            Text("Noch keine Bilder")
                .font(.title3.bold())
            Text("Jedes Bild wird ein Poster — eine Seite in der PDF. Oben rechts mit „+“ hinzufügen.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            PhotosPicker(selection: $pickerItems, maxSelectionCount: nil, matching: .images,
                         preferredItemEncoding: .current) {
                Label("Bilder aus Fotos wählen", systemImage: "photo.on.rectangle")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            Button {
                showFiles = true
            } label: {
                Label("Aus Dateien", systemImage: "folder")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func tile(_ item: PosterItem, index: Int) -> some View {
        let g = PageGeometry(format: project.format, item: item)
        let dpi = PosterLayout.effectiveDPI(item: item, geometry: g)
        return VStack(spacing: 8) {
            GeometryReader { geo in
                let s = min(geo.size.width / g.size.width, geo.size.height / g.size.height)
                PosterPageView(format: project.format, item: item, scale: s, guides: showGuides)
                    .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: 210)
            .overlay(alignment: .topTrailing) {
                DPIBadge(dpi: dpi).padding(6)
            }
            .contentShape(Rectangle())
            .onTapGesture { editing = EditTarget(id: item.id) }
            Text("Poster \(index + 1)")
                .font(.caption.weight(.semibold))
            Text(item.originalName.isEmpty ? "\(item.pixelWidth) × \(item.pixelHeight) px" : item.originalName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contextMenu {
            Button {
                editing = EditTarget(id: item.id)
            } label: { Label("Ausschnitt bearbeiten", systemImage: "crop") }
            Button {
                update(item.id) { $0.quarterTurns = ($0.quarterTurns + 1) % 4; $0.offsetX = 0; $0.offsetY = 0 }
            } label: { Label("Um 90° drehen", systemImage: "rotate.right") }
            Button {
                duplicate(item)
            } label: { Label("Duplizieren", systemImage: "plus.square.on.square") }
            if index > 0 {
                Button {
                    project.items.swapAt(index, index - 1)
                } label: { Label("Nach vorn", systemImage: "arrow.left") }
            }
            if index < project.items.count - 1 {
                Button {
                    project.items.swapAt(index, index + 1)
                } label: { Label("Nach hinten", systemImage: "arrow.right") }
            }
            Button(role: .destructive) {
                remove(item)
            } label: { Label("Entfernen", systemImage: "trash") }
        }
    }

    // MARK: - Aktionen

    private func update(_ id: UUID, _ change: (inout PosterItem) -> Void) {
        guard let i = project.items.firstIndex(where: { $0.id == id }) else { return }
        change(&project.items[i])
    }

    private func duplicate(_ item: PosterItem) {
        guard let photo = PhotoStore.shared.duplicate(item.photoID),
              let i = project.items.firstIndex(where: { $0.id == item.id }) else { return }
        var copy = item
        copy.id = UUID()
        copy.photoID = photo
        project.items.insert(copy, at: i + 1)
    }

    private func remove(_ item: PosterItem) {
        project.items.removeAll { $0.id == item.id }
        PhotoStore.shared.delete(item.photoID)
    }

    private func importFromPhotos(_ items: [PhotosPickerItem]) {
        importing += items.count
        Task {
            for item in items {
                let data = try? await item.loadTransferable(type: Data.self)
                await add(data: data, name: "")
            }
        }
    }

    private func importFromFiles(_ urls: [URL]) {
        importing += urls.count
        Task {
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                let data = try? Data(contentsOf: url)
                if access { url.stopAccessingSecurityScopedResource() }
                await add(data: data, name: url.lastPathComponent)
            }
        }
    }

    private func add(data: Data?, name: String) async {
        defer { importing -= 1 }
        guard let data else {
            importErrors += 1
            return
        }
        let result = await Task.detached(priority: .userInitiated) {
            try? PhotoStore.shared.importImage(data: data)
        }.value
        guard let result else {
            importErrors += 1
            return
        }
        project.items.append(PosterItem(photoID: result.id, pixelWidth: result.pixelWidth,
                                        pixelHeight: result.pixelHeight, originalName: name))
    }
}
