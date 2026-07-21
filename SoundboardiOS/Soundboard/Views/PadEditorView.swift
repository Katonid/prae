import SwiftUI
import UniformTypeIdentifiers

/// Editor für ein einzelnes Feld: Beschriftung, Farbe, Tonquelle, Wiedergabe-Einstellungen.
struct PadEditorView: View {
    let padID: UUID
    @EnvironmentObject var store: BoardStore
    @EnvironmentObject var engine: AudioEngine
    @Environment(\.dismiss) private var dismiss

    @State private var showFileImporter = false
    @State private var streamingService: StreamingServiceKind?

    private var pad: SoundPad {
        store.pad(padID) ?? SoundPad()
    }

    var body: some View {
        NavigationStack {
            Form {
                labelSection
                colorSection
                sourceSection
                if !pad.source.isEmpty {
                    playbackSection
                    gestureSection
                }
                visibilitySection
                clearSection
            }
            .navigationTitle("Feld bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    assignFile(url: url)
                }
            }
            .sheet(item: $streamingService) { service in
                StreamingPickerView(service: service) { source in
                    assignStreaming(source: source)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Abschnitte

    private var labelSection: some View {
        Section("Beschriftung") {
            TextField("Name des Feldes", text: binding(\.label))
        }
    }

    private var colorSection: some View {
        Section("Farbe") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                ForEach(BoardDefaults.swatchColors, id: \.self) { hex in
                    let selected = pad.colorHex.lowercased() == hex.lowercased()
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 30, height: 30)
                        .overlay {
                            if selected {
                                Circle().strokeBorder(.white, lineWidth: 2.5)
                                Image(systemName: "checkmark")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .onTapGesture {
                            Haptics.tap()
                            update { $0.colorHex = hex }
                        }
                }
            }
            .padding(.vertical, 4)

            ColorPicker("Eigene Farbe", selection: Binding(
                get: { Color(hex: pad.colorHex) },
                set: { update { $0.colorHex = $1.toHex() } }
            ), supportsOpacity: false)
        }
    }

    private var sourceSection: some View {
        Section("Ton") {
            sourceInfoRow

            Button {
                showFileImporter = true
            } label: {
                Label("Audiodatei wählen …", systemImage: "folder")
            }
            Button {
                streamingService = .appleMusic
            } label: {
                Label("Apple Music durchsuchen …", systemImage: "applelogo")
            }
            Button {
                streamingService = .deezer
            } label: {
                Label("Deezer durchsuchen …", systemImage: "magnifyingglass")
            }
            Button {
                streamingService = .spotify
            } label: {
                Label("Spotify-Link einfügen …", systemImage: "link")
            }

            if !pad.source.isEmpty {
                Button(role: .destructive) {
                    removeSource()
                } label: {
                    Label("Ton entfernen", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var sourceInfoRow: some View {
        switch pad.source {
        case .empty:
            Label("Keine Tonquelle zugewiesen", systemImage: "speaker.slash")
                .foregroundStyle(.secondary)
        case .file(let fileName, _):
            Label(fileName, systemImage: "waveform")
        case .appleMusic(_, let title, let artist, _, _):
            Label("\(title) – \(artist)", systemImage: "applelogo")
        case .deezer(_, let title, let artist, _, _, _, _):
            VStack(alignment: .leading, spacing: 2) {
                Label("\(title) – \(artist)", systemImage: "music.note")
                Text("Deezer: In der App wird die 30-Sekunden-Vorschau angespielt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .spotify(_, let title):
            VStack(alignment: .leading, spacing: 2) {
                Label(title.isEmpty ? "Spotify-Titel" : title, systemImage: "link")
                Text("Wird beim Antippen in der Spotify-App abgespielt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var playbackSection: some View {
        let volumeAdjustable: Bool = {
            switch pad.source {
            case .file, .deezer: return true
            default: return false
            }
        }()

        Section("Wiedergabe") {
            if volumeAdjustable {
                VStack(alignment: .leading) {
                    Text("Lautstärke: \(Int(pad.volume * 100)) %")
                        .font(.subheadline)
                    Slider(value: Binding(
                        get: { pad.volume },
                        set: { value in
                            update { $0.volume = value }
                            if let fresh = store.pad(padID) {
                                engine.applyVolume(fresh)
                            }
                        }
                    ), in: 0...1)
                }
                VStack(alignment: .leading) {
                    Text("Ausblenden beim Stoppen: \(pad.fadeOutSeconds, specifier: "%.1f") s")
                        .font(.subheadline)
                    Slider(value: binding(\.fadeOutSeconds), in: 0...10, step: 0.5)
                }
            } else {
                Text("Lautstärke und Ausblenden steuert der Streamingdienst.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var gestureSection: some View {
        Section("Gesten") {
            Picker("Einfacher Tipp", selection: binding(\.singleTap)) {
                ForEach(GestureAction.allCases) { action in
                    Text(action.title).tag(action)
                }
            }
            Picker("Doppeltipp", selection: binding(\.doubleTap)) {
                ForEach(GestureAction.allCases) { action in
                    Text(action.title).tag(action)
                }
            }
            Picker("Langes Drücken", selection: binding(\.longPress)) {
                ForEach(GestureAction.allCases) { action in
                    Text(action.title).tag(action)
                }
            }
            Text("Tipp: Ohne Doppeltipp-Aktion reagiert der einfache Tipp schneller.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var visibilitySection: some View {
        Section {
            Toggle("Im Wiedergabemodus ausblenden", isOn: binding(\.hidden))
        }
    }

    private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                removeSource()
                update { pad in
                    pad.label = ""
                    pad.volume = 1
                    pad.fadeOutSeconds = 0.5
                    pad.hidden = false
                    pad.singleTap = .restartOrResume
                    pad.doubleTap = .pause
                    pad.longPress = .stopReset
                }
                store.showStatus("Feld zurückgesetzt.")
            } label: {
                Label("Feld komplett zurücksetzen", systemImage: "arrow.counterclockwise")
            }
        }
    }

    // MARK: - Änderungen

    private func update(_ change: (inout SoundPad) -> Void) {
        store.updatePad(padID, change)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<SoundPad, T>) -> Binding<T> {
        Binding(
            get: { pad[keyPath: keyPath] },
            set: { value in update { $0[keyPath: keyPath] = value } }
        )
    }

    private func assignFile(url: URL) {
        guard let source = store.importAudioFile(from: url) else { return }
        replaceSource(with: source)
    }

    private func assignStreaming(source: PadSource) {
        replaceSource(with: source)
    }

    private func replaceSource(with source: PadSource) {
        engine.discard(padID: padID)
        store.deleteStoredAudio(of: pad.source)
        update { pad in
            pad.source = source
            if pad.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pad.label = source.defaultLabel
            }
        }
        Haptics.success()
    }

    private func removeSource() {
        engine.discard(padID: padID)
        store.deleteStoredAudio(of: pad.source)
        update { $0.source = .empty }
    }
}
