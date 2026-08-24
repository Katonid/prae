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
    /// Schrift der ganzen App (nicht nur dieser Tafel).
    @AppStorage(AppFont.speicherSchluessel) private var schriftWahl: AppFont = .lexend

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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        ForEach(AuroraPresets.all) { preset in
                            auroraTile(preset, selected: isSelected(.aurora(preset.id))) {
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
                    ForEach(AppFont.allCases) { schrift in
                        schriftZeile(schrift)
                    }
                } header: {
                    Text("Schrift")
                } footer: {
                    Text("Die Vorgabe Lexend hat ein rundes a mit Strich — so, wie Kinder es in "
                         + "der Grundschule schreiben lernen. Die Systemschrift des Geräts zeigt "
                         + "dagegen das gedruckte a mit Bogen. Die Einstellung gilt für die ganze "
                         + "App, nicht nur für diese Tafel.")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                        ForEach(AccentSchemes.all) { entry in
                            schemeCard(entry, selected: board.accent == entry.id) {
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

    /// Eine Schrift zur Auswahl — der Name steht in der Schrift selbst,
    /// dazu „Aa" als Probe, damit das runde a sofort zu sehen ist.
    private func schriftZeile(_ schrift: AppFont) -> some View {
        let gewaehlt = schriftWahl == schrift
        return Button {
            schriftWahl = schrift
            Haptics.tap()
        } label: {
            HStack(spacing: 14) {
                Text("Aa")
                    .font(probe(schrift, size: 26, weight: .bold))
                    .frame(width: 52, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(schrift.title)
                        .font(probe(schrift, size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(schrift.hint)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !schrift.vorhanden {
                        Text("Schriftdatei fehlt — es gilt die Systemschrift.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.amber)
                    }
                }
                Spacer(minLength: 0)
                if gewaehlt {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Probe-Schrift für die Auswahl — unabhängig davon, was gerade gilt.
    private func probe(_ schrift: AppFont, size: Double, weight: Font.Weight) -> Font {
        guard let name = schrift.postScriptName(for: weight) else {
            return .system(size: size, weight: weight)
        }
        return .custom(name, size: size)
    }

    /// Farbschema als Karte: großer Farbkreis, Name darunter.
    private func schemeCard(_ entry: AccentScheme, selected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: entry.from),
                                                  Color(hex: entry.mid),
                                                  Color(hex: entry.to)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                    .shadow(color: Color(hex: entry.from).opacity(0.45), radius: 10, y: 5)
                Text(entry.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Color(hex: entry.from) : Color.primary.opacity(0.12),
                                  lineWidth: selected ? 2.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    /// Hintergrundvorlage als breite Kachel mit Namen darin.
    private func auroraTile(_ preset: AuroraPreset, selected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                AuroraBackgroundView(preset: preset)
                    .frame(height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(preset.label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(preset.isLight ? Color(hex: "#0f172a") : .white)
                    .shadow(color: .black.opacity(preset.isLight ? 0 : 0.5), radius: 4)
                    .padding(10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Theme.accent : Color.primary.opacity(0.12),
                                  lineWidth: selected ? 3 : 1)
            }
        }
        .buttonStyle(.plain)
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
