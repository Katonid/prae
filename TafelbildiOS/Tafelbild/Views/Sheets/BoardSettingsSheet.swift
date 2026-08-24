import SwiftUI
import PhotosUI

/// Tafel gestalten: Name, Symbol und Hintergrund.
struct BoardSettingsSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss
    let boardID: String

    /// Immer den aktuellen Stand aus dem Speicher lesen — sonst würde eine
    /// Änderung eine kurz zuvor gemachte wieder überschreiben.
    private var board: Board { store.board(boardID) ?? Board() }

    @State private var name: String = ""
    @State private var emoji: String = ""
    @State private var dim: Double = 0.25
    @State private var photo: PhotosPickerItem?
    @State private var showDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name der Tafel", text: $name)
                        .onChange(of: name) { _, value in
                            var updated = board
                            updated.name = value.nonEmpty ?? "Tafel"
                            store.updateBoard(updated)
                        }
                    EmojiPickerRow(emoji: Binding(
                        get: { emoji },
                        set: { value in
                            emoji = value
                            var updated = board
                            updated.emoji = value.isEmpty ? "🌟" : value
                            store.updateBoard(updated)
                        }
                    ))
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                        ForEach(AuroraPresets.all) { preset in
                            swatch(LinearGradient(colors: [Color(hex: preset.base)]
                                                  + preset.blobs.map { Color(hex: $0) },
                                                  startPoint: .topLeading, endPoint: .bottomTrailing),
                                   selected: isSelected(.aurora(preset.id)),
                                   caption: preset.label) {
                                apply(.aurora(preset.id))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Bewegter Hintergrund")
                } footer: {
                    Text("Große Farbwolken ziehen sehr langsam über den Grund — ruhig genug "
                         + "für den Unterricht. Bei eingeschalteter Bewegungsreduzierung "
                         + "stehen sie still.")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                        ForEach(AccentSchemes.all) { entry in
                            swatch(LinearGradient(colors: [Color(hex: entry.from),
                                                           Color(hex: entry.mid),
                                                           Color(hex: entry.to)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing),
                                   selected: board.accent == entry.id,
                                   caption: entry.label) {
                                var updated = board
                                updated.accent = entry.id
                                store.updateBoard(updated)
                                Haptics.tap()
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    Toggle("Farbverlauf statt einer Farbe", isOn: Binding(
                        get: { board.gradient },
                        set: { value in
                            var updated = board
                            updated.gradient = value
                            store.updateBoard(updated)
                        }
                    ))
                } header: {
                    Text("Farbschema")
                } footer: {
                    Text("Das Schema färbt Knöpfe, Ringe, Zeiger und gezogene Namen auf der "
                         + "ganzen Tafel.")
                }

                Section {
                    Picker("Karten", selection: Binding(
                        get: { board.cardStyle },
                        set: { value in
                            var updated = board
                            updated.cardStyle = value
                            store.updateBoard(updated)
                        }
                    )) {
                        ForEach(CardStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Kartenstil")
                } footer: {
                    Text(board.cardStyle.explanation)
                }

                Section {
                    Picker("Rahmen", selection: Binding(
                        get: { board.frames },
                        set: { value in
                            var updated = board
                            updated.frames = value
                            store.updateBoard(updated)
                        }
                    )) {
                        ForEach(ShowRule.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Beschriftungen", selection: Binding(
                        get: { board.labels },
                        set: { value in
                            var updated = board
                            updated.labels = value
                            store.updateBoard(updated)
                        }
                    )) {
                        ForEach(ShowRule.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Ruhe auf der Tafel")
                } footer: {
                    Text("Ohne Rahmen stehen Uhr, Ampel und Bilder frei auf dem Hintergrund. "
                         + "Ohne Beschriftungen verschwinden Überschriften und Hinweise — "
                         + "die Tafel wirkt aufgeräumter, die Bedienung bleibt gleich.")
                }

                Section("Farbverlauf") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 10)], spacing: 10) {
                        ForEach(Array(BackgroundPreset.gradients.enumerated()), id: \.offset) { item in
                            let pair = item.element
                            swatch(LinearGradient(colors: [Color(hex: pair.0), Color(hex: pair.1)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing),
                                   selected: isSelected(.gradient(pair.0, pair.1))) {
                                apply(.gradient(pair.0, pair.1))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Einfarbig") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 10)], spacing: 10) {
                        ForEach(BackgroundPreset.solids, id: \.self) { hex in
                            swatch(Color(hex: hex), selected: isSelected(.solid(hex))) {
                                apply(.solid(hex))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label("Hintergrundbild wählen", systemImage: "photo")
                    }
                    if case .image(_, let currentDim) = board.background {
                        VStack(alignment: .leading) {
                            Text("Abdunkeln: \(Int(dim * 100)) %")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Slider(value: $dim, in: 0...0.85)
                                .onChange(of: dim) { _, value in
                                    if case .image(let file, _) = board.background {
                                        apply(.image(file, value))
                                    }
                                }
                        }
                        .onAppear { dim = currentDim }
                        Button(role: .destructive) {
                            apply(.aurora("nordlicht"))
                        } label: {
                            Label("Bild entfernen", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("Hintergrundbild")
                } footer: {
                    Text("Dunkle Bilder wirken auf der Tafel am ruhigsten — heller Text bleibt so gut lesbar.")
                }

                Section {
                    Button(role: .destructive) {
                        showDelete = true
                    } label: {
                        Label("Tafel löschen", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Tafel gestalten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onAppear {
                name = board.name
                emoji = board.emoji
                if case .image(_, let value) = board.background { dim = value }
            }
            .onChange(of: photo) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data),
                          let prepared = MediaCache.prepareForBoard(image),
                          let fileName = store.saveMedia(data: prepared, fileExtension: "jpg")
                    else { return }
                    apply(.image(fileName, dim))
                    photo = nil
                }
            }
            .alert("Tafel löschen?", isPresented: $showDelete) {
                Button("Löschen", role: .destructive) {
                    store.deleteBoard(board)
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Die Tafel verschwindet auf allen Geräten, die sie sehen.")
            }
        }
    }

    private func swatch(_ fill: some ShapeStyle, selected: Bool, caption: String? = nil,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fill)
                    .frame(height: 54)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(selected ? Theme.accent : Color.primary.opacity(0.15),
                                          lineWidth: selected ? 3 : 1)
                    }
                if let caption {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(selected ? Theme.accent : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func isSelected(_ background: BoardBackground) -> Bool {
        board.background == background
    }

    private func apply(_ background: BoardBackground) {
        var updated = board
        updated.background = background
        store.updateBoard(updated)
        Haptics.tap()
    }
}
