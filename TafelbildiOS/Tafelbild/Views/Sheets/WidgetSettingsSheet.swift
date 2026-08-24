import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Einstellungen eines Elements — je nach Typ mit eigenem Abschnitt.
struct WidgetSettingsSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss

    let boardID: String
    let widgetID: String

    private var widget: BoardWidget? { store.widget(widgetID, in: boardID) }

    var body: some View {
        NavigationStack {
            Form {
                if let widget {
                    switch widget.content {
                    case .text(let value):
                        TextSettings(content: bindText(value))
                    case .image(let value):
                        ImageSettings(content: bindImage(value))
                    case .clock(let value):
                        ClockSettings(content: bindClock(value))
                    case .timer(let value):
                        TimerSettings(content: bindTimer(value))
                    case .trafficLight(let value):
                        TrafficLightSettings(content: bindTrafficLight(value))
                    case .noise(let value):
                        NoiseSettings(content: bindNoise(value))
                    case .checklist(let value):
                        ChecklistSettings(content: bindChecklist(value))
                    case .namePicker(let value):
                        NamePickerSettings(content: bindNamePicker(value))
                    case .sounds(let value):
                        SoundsSettings(content: bindSounds(value))
                    }

                    Section {
                        Button {
                            store.duplicateWidget(widgetID, in: boardID)
                            dismiss()
                        } label: {
                            Label("Element duplizieren", systemImage: "plus.square.on.square")
                        }
                        Button(role: .destructive) {
                            store.removeWidget(widgetID, from: boardID)
                            dismiss()
                        } label: {
                            Label("Element entfernen", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(widget?.kind.title ?? "Element")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // Bindungen auf den Inhalt des Elements im Speicher — bewusst je Typ
    // ausgeschrieben, damit der Zustand immer frisch aus dem Speicher kommt.

    private func bindText(_ fallback: TextContent) -> Binding<TextContent> {
        Binding(
            get: {
                if case .text(let value)? = store.widget(widgetID, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.text($0), widgetID: widgetID, boardID: boardID) }
        )
    }

    private func bindImage(_ fallback: ImageContent) -> Binding<ImageContent> {
        Binding(
            get: {
                if case .image(let value)? = store.widget(widgetID, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.image($0), widgetID: widgetID, boardID: boardID) }
        )
    }

    private func bindClock(_ fallback: ClockContent) -> Binding<ClockContent> {
        Binding(
            get: {
                if case .clock(let value)? = store.widget(widgetID, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.clock($0), widgetID: widgetID, boardID: boardID) }
        )
    }

    private func bindTimer(_ fallback: TimerContent) -> Binding<TimerContent> {
        Binding(
            get: {
                if case .timer(let value)? = store.widget(widgetID, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.timer($0), widgetID: widgetID, boardID: boardID) }
        )
    }

    private func bindTrafficLight(_ fallback: TrafficLightContent) -> Binding<TrafficLightContent> {
        Binding(
            get: {
                if case .trafficLight(let value)? = store.widget(widgetID, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.trafficLight($0), widgetID: widgetID, boardID: boardID) }
        )
    }

    private func bindNoise(_ fallback: NoiseContent) -> Binding<NoiseContent> {
        Binding(
            get: {
                if case .noise(let value)? = store.widget(widgetID, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.noise($0), widgetID: widgetID, boardID: boardID) }
        )
    }

    private func bindChecklist(_ fallback: ChecklistContent) -> Binding<ChecklistContent> {
        Binding(
            get: {
                if case .checklist(let value)? = store.widget(widgetID, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.checklist($0), widgetID: widgetID, boardID: boardID) }
        )
    }

    private func bindNamePicker(_ fallback: NamePickerContent) -> Binding<NamePickerContent> {
        Binding(
            get: {
                if case .namePicker(let value)? = store.widget(widgetID, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.namePicker($0), widgetID: widgetID, boardID: boardID) }
        )
    }

    private func bindSounds(_ fallback: SoundsContent) -> Binding<SoundsContent> {
        Binding(
            get: {
                if case .sounds(let value)? = store.widget(widgetID, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.sounds($0), widgetID: widgetID, boardID: boardID) }
        )
    }
}

// MARK: - Farbe als Hex

extension Binding where Value == String {
    /// Verbindet ein Hex-Feld mit einem SwiftUI-Farbwähler.
    var asColor: Binding<Color> {
        Binding<Color>(
            get: { Color(hex: wrappedValue) },
            set: { wrappedValue = $0.toHex() }
        )
    }
}

// MARK: - Text

private struct TextSettings: View {
    @Binding var content: TextContent

    var body: some View {
        Section("Text") {
            TextEditor(text: $content.text)
                .frame(minHeight: 110)
                .font(.system(.body, design: .rounded))
        }
        Section("Darstellung") {
            HStack {
                Text("Größe")
                Slider(value: $content.fontSize, in: 20...200, step: 2)
                Text("\(Int(content.fontSize))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Toggle("Fett", isOn: $content.bold)
            Picker("Ausrichtung", selection: $content.alignment) {
                ForEach(TextContent.TextAlign.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            ColorPicker("Schriftfarbe", selection: $content.colorHex.asColor, supportsOpacity: false)
            ColorPicker("Hintergrund", selection: $content.backgroundHex.asColor, supportsOpacity: false)
            HStack {
                Text("Deckkraft")
                Slider(value: $content.backgroundOpacity, in: 0...1)
                Text("\(Int(content.backgroundOpacity * 100)) %")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Bild

private struct ImageSettings: View {
    @EnvironmentObject private var store: BoardStore
    @Binding var content: ImageContent
    @State private var photo: PhotosPickerItem?
    @State private var showFiles = false

    var body: some View {
        Group {
        Section("Bild") {
            PhotosPicker(selection: $photo, matching: .images) {
                Label(content.fileName == nil ? "Aus Fotos wählen" : "Anderes Foto wählen",
                      systemImage: "photo.on.rectangle")
            }
            Button {
                showFiles = true
            } label: {
                Label("Aus Dateien wählen", systemImage: "folder")
            }
            if content.fileName != nil {
                Button(role: .destructive) {
                    content.fileName = nil
                } label: {
                    Label("Bild entfernen", systemImage: "trash")
                }
            }
        }
        Section("Darstellung") {
            Picker("Zuschnitt", selection: $content.fill) {
                Text("Füllend").tag(true)
                Text("Vollständig").tag(false)
            }
            .pickerStyle(.segmented)
            HStack {
                Text("Ecken")
                Slider(value: $content.cornerRadius, in: 0...60, step: 2)
            }
            TextField("Bildunterschrift (optional)", text: $content.caption)
        }
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let prepared = MediaCache.prepareForBoard(image),
                      let fileName = store.saveMedia(data: prepared, fileExtension: "jpg")
                else { return }
                content.fileName = fileName
                photo = nil
            }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data),
                  let prepared = MediaCache.prepareForBoard(image),
                  let fileName = store.saveMedia(data: prepared, fileExtension: "jpg")
            else { return }
            content.fileName = fileName
        }
    }
}

// MARK: - Uhr

private struct ClockSettings: View {
    @Binding var content: ClockContent

    var body: some View {
        Section("Uhr") {
            Picker("Anzeige", selection: $content.style) {
                ForEach(ClockContent.ClockStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Sekundenzeiger", isOn: $content.showSeconds)
            Toggle("Datum anzeigen", isOn: $content.showDate)
            Toggle("24-Stunden-Format", isOn: $content.twentyFourHour)
            ColorPicker("Zifferblatt", selection: $content.faceHex.asColor, supportsOpacity: false)
            ColorPicker("Akzent", selection: $content.accentHex.asColor, supportsOpacity: false)
        }
    }
}

// MARK: - Timer

private struct TimerSettings: View {
    @Binding var content: TimerContent
    @State private var minutes = 5
    @State private var seconds = 0

    var body: some View {
        Section("Timer") {
            Picker("Modus", selection: $content.mode) {
                ForEach(TimerContent.TimerMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if content.mode == .countdown {
                HStack {
                    Picker("Minuten", selection: $minutes) {
                        ForEach(0..<121, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 110)
                    Picker("Sekunden", selection: $seconds) {
                        ForEach(0..<60, id: \.self) { Text("\($0) s").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 110)
                }
                .onChange(of: minutes) { _, _ in applyDuration() }
                .onChange(of: seconds) { _, _ in applyDuration() }
            }

            Toggle("Signal am Ende", isOn: $content.soundOnEnd)
            Toggle("Bedienknöpfe zeigen", isOn: $content.showControls)
            ColorPicker("Farbe", selection: $content.accentHex.asColor, supportsOpacity: false)
        }
        .onAppear {
            minutes = Int(content.duration) / 60
            seconds = Int(content.duration) % 60
        }
    }

    private func applyDuration() {
        content.duration = Double(minutes * 60 + seconds)
        content.endsAtMs = nil
        content.pausedValue = nil
    }
}

// MARK: - Ampel

private struct TrafficLightSettings: View {
    @Binding var content: TrafficLightContent

    var body: some View {
        Section("Ampel") {
            Picker("Zustand", selection: $content.state) {
                Text("Aus").tag(TrafficLightContent.LightState.off)
                Text("Rot").tag(TrafficLightContent.LightState.red)
                Text("Gelb").tag(TrafficLightContent.LightState.yellow)
                Text("Grün").tag(TrafficLightContent.LightState.green)
            }
            .pickerStyle(.segmented)
            Toggle("Waagerecht", isOn: $content.horizontal)
            Toggle("Beschriftung zeigen", isOn: $content.showLabels)
        }
        Section("Beschriftung") {
            TextField("Rot", text: $content.redLabel)
            TextField("Gelb", text: $content.yellowLabel)
            TextField("Grün", text: $content.greenLabel)
        }
    }
}

// MARK: - Lautstärke

private struct NoiseSettings: View {
    @Binding var content: NoiseContent
    @ObservedObject private var meter = NoiseMeter.shared

    var body: some View {
        Section("Lautstärke") {
            TextField("Überschrift", text: $content.title)
            Picker("Darstellung", selection: $content.style) {
                ForEach(NoiseContent.NoiseStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Schwelle „zu laut“")
                    Spacer()
                    Text("\(Int(content.threshold * 100))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $content.threshold, in: 0.1...1)
                // Live-Pegel als Orientierung beim Einstellen.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.1))
                        Capsule()
                            .fill(meter.level * content.gain > content.threshold ? Theme.danger : Theme.mint)
                            .frame(width: geo.size.width * min(1, meter.level * content.gain))
                    }
                }
                .frame(height: 8)
                Text("Aktueller Pegel im Raum")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Empfindlichkeit")
                Slider(value: $content.gain, in: 0.5...2.5)
            }
            Toggle("Warnung anzeigen", isOn: $content.alert)
        }
        .onAppear { meter.retain() }
        .onDisappear { meter.release() }
    }
}

// MARK: - Tagesablauf

private struct ChecklistSettings: View {
    @Binding var content: ChecklistContent
    @State private var newItem = ""

    var body: some View {
        Section("Tagesablauf") {
            TextField("Überschrift", text: $content.title)
            Toggle("Fortschritt anzeigen", isOn: $content.showProgress)
            Toggle("Täglich zurücksetzen", isOn: $content.resetDaily)
        }
        Section("Schritte") {
            ForEach($content.items) { $item in
                HStack {
                    TextField("Emoji", text: $item.emoji)
                        .frame(width: 44)
                        .multilineTextAlignment(.center)
                    TextField("Schritt", text: $item.text)
                    Button {
                        item.done.toggle()
                    } label: {
                        Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.done ? Theme.mint : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete { content.items.remove(atOffsets: $0) }
            .onMove { content.items.move(fromOffsets: $0, toOffset: $1) }

            HStack {
                TextField("Neuer Schritt", text: $newItem)
                    .onSubmit(add)
                Button("Hinzufügen", action: add)
                    .disabled(newItem.trimmed.isEmpty)
            }
            Button {
                for index in content.items.indices { content.items[index].done = false }
            } label: {
                Label("Alle Haken entfernen", systemImage: "arrow.counterclockwise")
            }
        }
    }

    private func add() {
        guard let text = newItem.nonEmpty else { return }
        content.items.append(ChecklistItem(text: text))
        newItem = ""
    }
}

// MARK: - Zufälliger Name

private struct NamePickerSettings: View {
    @EnvironmentObject private var store: BoardStore
    @Binding var content: NamePickerContent

    private var list: NameList? { store.nameList(content.listID) }

    var body: some View {
        Section("Namensliste") {
            Picker("Liste", selection: Binding(
                get: { content.listID ?? "" },
                set: { content.listID = $0.isEmpty ? nil : $0 }
            )) {
                Text("Keine Liste").tag("")
                ForEach(store.visibleNameLists) { list in
                    Text(list.name).tag(list.id)
                }
            }
            if let list {
                NavigationLink {
                    NameListEditor(listID: list.id)
                } label: {
                    Label("Liste bearbeiten (\(list.entries.count) Namen)", systemImage: "pencil")
                }
            }
        }

        Section {
            Picker("Ziehweise", selection: $content.mode) {
                ForEach(NamePickerContent.DrawMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.inline)
        } header: {
            Text("Ziehweise")
        } footer: {
            Text(content.mode.explanation)
        }

        Section("Anzeige") {
            Toggle("Gezogene Namen zeigen", isOn: $content.showHistory)
            Toggle("Ziehen animieren", isOn: $content.animate)
        }

        Section {
            if let list {
                ForEach(list.entries) { entry in
                    let drawn = content.drawnIDs.contains(entry.id)
                    Button {
                        if drawn {
                            content.drawnIDs.removeAll { $0 == entry.id }
                            if content.currentID == entry.id { content.currentID = nil }
                        } else {
                            content.drawnIDs.append(entry.id)
                        }
                    } label: {
                        HStack {
                            Image(systemName: drawn ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(drawn ? Theme.accent : .secondary)
                            Text(entry.text)
                                .foregroundStyle(.primary)
                            if entry.paused {
                                Spacer()
                                Text("pausiert")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Button {
                content.drawnIDs = []
                content.currentID = nil
            } label: {
                Label("Alle zurücklegen", systemImage: "arrow.counterclockwise")
            }
        } header: {
            Text("Bereits gezogen")
        } footer: {
            Text("Antippen schaltet um: So lässt sich jemand nachträglich als gezogen markieren oder wieder in den Topf legen.")
        }
    }
}

// MARK: - Klänge

private struct SoundsSettings: View {
    @EnvironmentObject private var store: BoardStore
    @Binding var content: SoundsContent

    @StateObject private var recorder = VoiceRecorder()
    @State private var importingFor: String?
    @State private var recordingFor: String?

    var body: some View {
        Group {
        Section("Klangfelder") {
            Toggle("Beschriftungen zeigen", isOn: $content.showLabels)
        }

        ForEach($content.buttons) { $button in
            Section {
                HStack {
                    TextField("Emoji", text: $button.emoji)
                        .frame(width: 50)
                        .multilineTextAlignment(.center)
                    TextField("Beschriftung", text: $button.label)
                }
                ColorPicker("Farbe", selection: $button.colorHex.asColor, supportsOpacity: false)

                HStack {
                    Image(systemName: button.fileName == nil ? "waveform.slash" : "waveform")
                        .foregroundStyle(button.fileName == nil ? .secondary : Theme.mint)
                    Text(button.fileName == nil ? "Kein Ton hinterlegt" : "Ton hinterlegt")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let fileName = button.fileName {
                        Button {
                            SoundPlayer.shared.play(buttonID: button.id, fileName: fileName,
                                                    volume: button.volume, toggle: true)
                        } label: {
                            Image(systemName: "play.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    importingFor = button.id
                } label: {
                    Label("Tondatei wählen", systemImage: "folder")
                }

                if recorder.recording && recordingFor == button.id {
                    Button(role: .destructive) {
                        if let data = recorder.stop(),
                           let fileName = store.saveMedia(data: data, fileExtension: "m4a") {
                            button.fileName = fileName
                        }
                        recordingFor = nil
                    } label: {
                        Label("Aufnahme beenden (\(String(format: "%.0f", recorder.seconds)) s)",
                              systemImage: "stop.circle.fill")
                    }
                } else {
                    Button {
                        recordingFor = button.id
                        recorder.start()
                    } label: {
                        Label("Selbst aufnehmen", systemImage: "mic.circle")
                    }
                    .disabled(recorder.recording)
                }

                HStack {
                    Text("Lautstärke")
                    Slider(value: $button.volume, in: 0...1)
                }
                Toggle("Erneutes Antippen stoppt", isOn: $button.toggle)

                Button(role: .destructive) {
                    content.buttons.removeAll { $0.id == button.id }
                } label: {
                    Label("Feld entfernen", systemImage: "trash")
                }
            } header: {
                Text(button.label.nonEmpty ?? "Feld")
            }
        }

        Section {
            Button {
                content.buttons.append(SoundButton(label: "Neu", emoji: "🔔",
                                                   colorHex: BackgroundPreset.solids.randomElement() ?? "#7c5cff"))
            } label: {
                Label("Feld hinzufügen", systemImage: "plus")
            }
        }
        }
        .fileImporter(isPresented: Binding(get: { importingFor != nil },
                                           set: { if !$0 { importingFor = nil } }),
                      allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav]) { result in
            guard case .success(let url) = result, let target = importingFor else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
            if let fileName = store.saveMedia(data: data, fileExtension: ext),
               let index = content.buttons.firstIndex(where: { $0.id == target }) {
                content.buttons[index].fileName = fileName
                if content.buttons[index].label.isEmpty {
                    content.buttons[index].label = url.deletingPathExtension().lastPathComponent
                }
            }
            importingFor = nil
        }
    }
}
