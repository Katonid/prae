import SwiftUI
import PhotosUI

struct PhotosPanel: View {
    @Binding var project: CalendarProject
    let onEditPhoto: (PhotoTarget) -> Void

    @EnvironmentObject private var store: ProjectStore
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var importDone = 0
    @State private var importTotal = 0
    @State private var importError: String?

    private let grid = [GridItem(.adaptive(minimum: 82), spacing: 8)]

    var body: some View {
        Form {
            Section {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: nil,
                             selectionBehavior: .ordered, matching: .images,
                             preferredItemEncoding: .current) {
                    Label("Fotos hinzufügen", systemImage: "photo.badge.plus")
                        .font(.headline)
                }
                .disabled(importing)
                if importing {
                    ProgressView(value: Double(importDone), total: Double(max(importTotal, 1))) {
                        Text("Übernehme \(importDone) von \(importTotal) …")
                            .font(.footnote)
                    }
                }
                if let importError {
                    Text(importError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Fotos werden in voller Auflösung für den Druck übernommen. Die Reihenfolge der Auswahl bestimmt die automatische Verteilung auf die Seiten.")
            }

            if !project.photos.isEmpty {
                Section("Deine Fotos (\(project.photos.count))") {
                    LazyVGrid(columns: grid, spacing: 8) {
                        ForEach(project.photos) { photo in
                            ThumbImage(id: photo.id)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 82)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(alignment: .bottomTrailing) {
                                    if photo.pixelWidth < 1800 && photo.pixelHeight < 1800 {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                            .padding(4)
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        project.design.backgroundSource = .photo
                                        project.design.backgroundPhotoID = photo.id
                                    } label: { Label("Als Hintergrund", systemImage: "rectangle.fill.on.rectangle.fill") }
                                    Button(role: .destructive) {
                                        store.removePhoto(photo.id, from: &project)
                                    } label: { Label("Entfernen", systemImage: "trash") }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                    HStack {
                        Button {
                            project.placements = [:]
                        } label: {
                            Label("Neu verteilen", systemImage: "arrow.triangle.2.circlepath")
                        }
                        Spacer()
                        Button {
                            project.photos.shuffle()
                            project.placements = [:]
                        } label: {
                            Label("Mischen", systemImage: "shuffle")
                        }
                    }
                    .buttonStyle(.borderless)
                }

                Section {
                    let slots = project.photoSlots
                    ForEach(slots.indices, id: \.self) { n in
                        let slot = slots[n]
                        ForEach(0..<slot.count, id: \.self) { j in
                            Button {
                                onEditPhoto(PhotoTarget(key: slot.key, index: j))
                            } label: {
                                HStack(spacing: 12) {
                                    if let pl = project.placement(key: slot.key, index: j) {
                                        ThumbImage(id: pl.photoID)
                                            .frame(width: 54, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    VStack(alignment: .leading) {
                                        Text(slot.count > 1 ? "\(slot.label) · Foto \(j + 1)" : slot.label)
                                        Text(project.placements[slot.key] == nil ? "automatisch" : "von dir gewählt")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Fotos auf den Seiten")
                } footer: {
                    Text("Tipp: Ein Foto direkt in der Vorschau antippen, um es zu tauschen, zu zoomen oder zu verschieben.")
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPhotos(items) }
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        importing = true
        importError = nil
        importDone = 0
        importTotal = items.count
        var failed = 0
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    failed += 1
                    continue
                }
                let photo = try await Task.detached(priority: .userInitiated) {
                    try ImageStore.shared.importImage(data: data)
                }.value
                project.photos.append(photo)
                PhotoInfo.register([photo])
            } catch {
                failed += 1
            }
            importDone += 1
        }
        if failed > 0 {
            importError = failed == 1 ? "Ein Foto ließ sich nicht übernehmen." : "\(failed) Fotos ließen sich nicht übernehmen."
        }
        pickerItems = []
        importing = false
    }
}
