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

    private var kopfGroesse: Double { widget?.labelSize ?? 1 }

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
                    case .symbols(let value):
                        SymbolSettings(content: bindSymbol(value))
                    case .video(let value):
                        VideoSettings(content: bindVideo(value))
                    case .kamera(let value):
                        KameraSettings(content: bindKamera(value))
                    }

                    Section {
                        Picker("Karte", selection: Binding(
                            get: { store.widget(widgetID, in: boardID)?.karte ?? .tafel },
                            set: { wert in
                                store.updateWidget(widgetID, in: boardID) { $0.karte = wert }
                            }
                        )) {
                            ForEach(WidgetKarte.allCases) { Text($0.title).tag($0) }
                        }

                        Toggle("Nur für mich ausblenden", isOn: Binding(
                            get: { store.widget(widgetID, in: boardID)?.versteckt ?? false },
                            set: { value in
                                store.updateWidget(widgetID, in: boardID) { $0.versteckt = value }
                            }
                        ))
                        Toggle("Position festecken", isOn: Binding(
                            get: { store.widget(widgetID, in: boardID)?.locked ?? false },
                            set: { value in
                                store.updateWidget(widgetID, in: boardID) { $0.locked = value }
                            }
                        ))
                    } header: {
                        Text("Auf der Tafel")
                    } footer: {
                        Text("Die Karte ist die helle Fläche unter dem Element. „Nur Rahmen“ "
                             + "zeichnet bloß die Grenze, der Tafelhintergrund bleibt zu sehen; "
                             + "„Ohne“ stellt den Inhalt frei auf die Tafel. „Wie die Tafel“ "
                             + "folgt der Einstellung „Rahmen“ unter „Aussehen“, die anderen "
                             + "setzen sich darüber hinweg.\n\nAusgeblendet heißt: nur für mich, "
                             + "und nur im Unterricht. Beim Bearbeiten bleibt das Element blass "
                             + "stehen, damit es zurückzuholen ist. Auf einer geteilten Tafel "
                             + "sehen es die anderen weiterhin.")
                    }

                    Section {
                        Picker("Beschriftung", selection: Binding(
                            get: { store.widget(widgetID, in: boardID)?.labels ?? .tafel },
                            set: { wert in
                                store.updateWidget(widgetID, in: boardID) { $0.labels = wert }
                            }
                        )) {
                            ForEach(WidgetLabelRegel.allCases) { Text($0.title).tag($0) }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Größe der Überschrift")
                                Spacer()
                                Text("\(Int((kopfGroesse * 100).rounded())) %")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: Binding(
                                get: { kopfGroesse },
                                set: { wert in
                                    store.updateWidget(widgetID, in: boardID) { $0.labelSize = wert }
                                }
                            ), in: 0.6...2.5, step: 0.05)
                            HStack {
                                Text("kleiner").font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Button("Vorgabe") {
                                    store.updateWidget(widgetID, in: boardID) { $0.labelSize = 1 }
                                    Haptics.tap()
                                }
                                .font(.caption)
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.accent)
                                Spacer()
                                Text("größer").font(.caption2).foregroundStyle(.secondary)
                            }
                        }

                        Schriftfarbwahl(automatikTitel: "Wie die Tafel",
                                        hex: Binding(
                                            get: { store.widget(widgetID, in: boardID)?.schriftfarbe ?? "" },
                                            set: { wert in
                                                store.updateWidget(widgetID, in: boardID) {
                                                    $0.schriftfarbe = wert
                                                }
                                            }
                                        ))
                    } header: {
                        Text("Beschriftung und Farbe")
                    } footer: {
                        Text("Gilt nur für dieses Element — unabhängig davon, was unter "
                             + "„Aussehen“ für die ganze Tafel eingestellt ist. Ein- und "
                             + "ausschalten betrifft Überschriften und Hinweise, nicht den "
                             + "Inhalt: Der gezogene Name, die Zeit und das Datum bleiben in "
                             + "jedem Fall stehen.\n\nDie Schriftfarbe färbt beides — "
                             + "Beschriftung und Inhalt. „Wie die Tafel“ folgt der Vorgabe "
                             + "unter „Aussehen“; jede andere Wahl bleibt hier stehen, auch "
                             + "wenn die Tafel später umgestellt wird.")
                    }

                    Section {
                        Button {
                            store.duplicateWidget(widgetID, in: boardID)
                            dismiss()
                        } label: {
                            Label("Element duplizieren", systemImage: "plus.square.on.square")
                        }
                        Button {
                            store.kopiereWidget(widgetID, in: boardID)
                            dismiss()
                        } label: {
                            Label("Element kopieren", systemImage: "doc.on.doc")
                        }
                        Button {
                            // Erst schließen, dann das nächste Blatt — zwei
                            // Blätter gleichzeitig zeigt iOS nicht.
                            let id = widgetID
                            dismiss()
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(350))
                                store.uebertragenWidgetID = id
                            }
                        } label: {
                            Label("Verschieben oder kopieren …",
                                  systemImage: "arrow.right.square")
                        }
                        Button(role: .destructive) {
                            store.removeWidget(widgetID, from: boardID)
                            dismiss()
                        } label: {
                            Label("Element entfernen", systemImage: "trash")
                        }
                    } footer: {
                        Text("Duplizieren legt sofort eine Kopie daneben. Kopieren merkt "
                             + "sich das Element: Auf jeder anderen Seite und jeder anderen "
                             + "Tafel steht dann beim Anordnen unten in der Leiste "
                             + "„Einfügen“ — auch morgen noch. „Verschieben oder kopieren“ "
                             + "geht den Weg in einem Schritt, mit Auswahl des Ziels.")
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

    private func bindSymbol(_ fallback: SymbolContent) -> Binding<SymbolContent> {
        Binding(
            get: {
                if case .symbols(let value)? = store.widget(widgetID, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.symbols($0), widgetID: widgetID, boardID: boardID) }
        )
    }

    private func bindKamera(_ fallback: KameraContent) -> Binding<KameraContent> {
        Binding(
            get: {
                if case .kamera(let value)? = store.widget(widgetID, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.kamera($0), widgetID: widgetID, boardID: boardID) }
        )
    }

    private func bindVideo(_ fallback: VideoContent) -> Binding<VideoContent> {
        Binding(
            get: {
                if case .video(let value)? = store.widget(widgetID, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.video($0), widgetID: widgetID, boardID: boardID) }
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
        Section {
            Toggle("Größe an das Feld anpassen", isOn: $content.autoSize)
            if !content.autoSize {
                HStack {
                    Text("Größe")
                    Slider(value: $content.fontSize, in: 20...200, step: 2)
                    Text("\(Int(content.fontSize))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Schriftgröße")
        } footer: {
            Text("Angepasst heißt: Das Element größer ziehen macht die Schrift größer. "
                 + "Auf der Tafel öffnet ein Doppeltipp die Schreibfläche.")
        }

        Section("Darstellung") {
            Toggle("Fett", isOn: $content.bold)
            Picker("Ausrichtung", selection: $content.alignment) {
                ForEach(TextContent.TextAlign.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Verlaufwahl(titel: "Schriftfarbe", von: $content.colorHex, bis: $content.colorHex2)
            Verlaufwahl(titel: "Hintergrund", von: $content.backgroundHex,
                        bis: $content.backgroundHex2)
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
                      let fileName = store.saveMedia(data: prepared.daten,
                                                     fileExtension: prepared.endung)
                else { return }
                content.fileName = fileName
                photo = nil
            }
        }
        // Schalter zuerst zurücksetzen und abseits des Hauptfadens lesen —
        // aus denselben zwei Gründen wie beim Klang (siehe SoundsSettings).
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.image]) { result in
            showFiles = false
            guard case .success(let url) = result else { return }
            Task { @MainActor in
                let vorbereitet = await Task.detached(priority: .userInitiated) {
                    () -> (daten: Data, endung: String)? in
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    guard let data = try? Data(contentsOf: url),
                          let image = UIImage(data: data) else { return nil }
                    return MediaCache.prepareForBoard(image)
                }.value
                guard let vorbereitet,
                      let fileName = store.saveMedia(data: vorbereitet.daten,
                                                     fileExtension: vorbereitet.endung)
                else { return }
                content.fileName = fileName
            }
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
        }

        if content.style != .digital {
            Section {
                Picker("Zifferblatt", selection: $content.face) {
                    ForEach(ClockFace.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
                Verlaufwahl(titel: "Farbe des Zifferblatts", von: $content.faceHex,
                            bis: $content.faceHex2)
            } header: {
                Text("Zifferblatt")
            } footer: {
                Text("Die Lernuhr zeigt den Stundenzeiger blau, den Minutenzeiger orange und "
                     + "außen die Minutenzahlen — so wie im Unterricht eingeführt.")
            }
        }
    }
}

// MARK: - Timer

private struct TimerSettings: View {
    @Binding var content: TimerContent
    @State private var minutes = 5
    @State private var seconds = 0

    var body: some View {
        // Alle Abschnitte in einer Klammer: So hängt `onAppear` am Ganzen und
        // nicht am letzten Abschnitt.
        Group {
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
            Toggle("Bedienknöpfe zeigen", isOn: $content.knoepfe)
        }

        Section {
            Picker("Darstellung", selection: $content.darstellung) {
                ForEach(TimerDarstellung.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        } footer: {
            Text("Der Ring zeigt die Zeit als Zahl. Die Scheibe zeigt sie als "
                 + "Fläche, die kleiner wird — so wie die Uhren, die in vielen "
                 + "Klassenzimmern stehen. Dafür muss niemand die Uhr lesen "
                 + "können.")
        }

        if content.darstellung == .scheibe {
            Section {
                Picker("Ziffernblatt fasst", selection: $content.skalaMinuten) {
                    Text("Passend zur Dauer").tag(0)
                    ForEach(TimerContent.skalen, id: \.self) { Text("\($0) Minuten").tag($0) }
                }
                Picker("Ziffernblatt", selection: $content.ziffernblatt) {
                    ForEach(Timerblatt.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Zeiger zeigen", isOn: $content.zeiger)
                Toggle("Zeit als Zahl darunter", isOn: $content.zeitZeigen)
            } header: {
                Text("Scheibe")
            } footer: {
                Text("„Passend zur Dauer“ nimmt die nächste übliche Marke oberhalb "
                     + "der eingestellten Zeit — bei 20 Minuten also ein "
                     + "20-Minuten-Blatt. Ein festes Blatt lohnt sich, wenn immer "
                     + "dieselbe Scheibe zu sehen sein soll.")
            }

            Section("Farbe der Fläche") {
                Verlaufwahl(titel: "Farbe", von: $content.scheibeHex, bis: $content.scheibeHex2)
            }

            Section {
                ColorPicker("Ziffernblatt", selection: $content.blattHex.asColor,
                            supportsOpacity: false)
                HStack(spacing: 10) {
                    ForEach(TimerSettings.blattvorlagen, id: \.self) { hex in
                        Button {
                            content.blattHex = hex
                            Haptics.tap()
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Circle().strokeBorder(
                                        content.blattHex.lowercased() == hex
                                            ? Theme.accent : Color.secondary.opacity(0.35),
                                        lineWidth: content.blattHex.lowercased() == hex ? 3 : 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
            } header: {
                Text("Grundfarbe")
            } footer: {
                Text("Striche und Zahlen richten sich von selbst danach: auf hellem "
                     + "Blatt dunkel, auf dunklem hell.")
            }
        }
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

    /// Ein paar Ziffernblätter zum Antippen — von Papierweiß bis Schiefer.
    static let blattvorlagen = ["#f8fafc", "#fde68a", "#bbf7d0", "#bfdbfe",
                                "#1f2937", "#0f172a"]
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
        Group {
        Section("Lautstärke") {
            TextField("Überschrift", text: $content.title)
            Toggle("Warnung anzeigen", isOn: $content.alert)
        }

        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Schwelle „zu laut“")
                    Spacer()
                    Text("\(Int(content.schwelleDb.rounded())) dB")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $content.schwelleDb,
                       in: NoiseSkala.schwelleMin...NoiseSkala.schwelleMax, step: 1)
                pegelband
            }
        } header: {
            Text("Ab wann zu laut?")
        } footer: {
            Text("Gemessene Werte aus dem Unterricht: Stillarbeit liegt selbst in ruhigen "
                 + "Klassen bei mindestens 50 dB, Unterrichtsgespräch und Gruppenarbeit bei "
                 + "70 bis 75 dB — so laut wie ein Staubsauger im Zimmer. Über 80 dB ist "
                 + "Ausnahmezustand; ab 85 dB drohen bei Dauerbelastung Gehörschäden. "
                 + "Die Vorgabe steht deshalb bei 75 dB.")
        }

        Section {
            ForEach(NoiseSkala.vorschlaege) { vorschlag in
                Button {
                    content.schwelleDb = vorschlag.dezibel
                    Haptics.tap()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vorschlag.titel)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(vorschlag.hinweis)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Text("\(Int(vorschlag.dezibel)) dB")
                            .font(.system(size: 15, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        if abs(content.schwelleDb - vorschlag.dezibel) < 0.5 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Für die Arbeitsform")
        }

        Section {
            HStack {
                Text("Feinabgleich")
                Spacer()
                Text("\(Int(meter.abgleich.rounded())) dB")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $meter.abgleich,
                   in: NoiseSkala.abgleichMin...NoiseSkala.abgleichMax, step: 1)
            Button {
                meter.abgleich = NoiseSkala.abgleichVorgabe
                Haptics.tap()
            } label: {
                Label("Auf Vorgabe zurücksetzen", systemImage: "arrow.uturn.backward")
            }
            .disabled(abs(meter.abgleich - NoiseSkala.abgleichVorgabe) < 0.5)
        } header: {
            Text("Abgleich des Mikrofons")
        } footer: {
            Text("Das Mikrofon eines iPads ist kein geeichter Schallpegelmesser — die Zahl "
                 + "ist eine Schätzung. Wer es genauer haben möchte, stellt eine "
                 + "Schallpegel-App daneben und schiebt hier so lange, bis beide Werte "
                 + "übereinstimmen. Der Abgleich gilt für das Gerät, nicht für die Tafel.")
        }
        }
        .onAppear { meter.retain() }
        .onDisappear { meter.release() }
    }

    /// Was das Mikrofon gerade hört — beim Einstellen der Schwelle hilfreich.
    private var pegelband: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    Capsule()
                        .fill(meter.dezibel >= content.schwelleDb ? Theme.danger : Theme.mint)
                        .frame(width: geo.size.width * CGFloat(meter.level))
                    // Strich an der eingestellten Schwelle.
                    Capsule()
                        .fill(Color.primary.opacity(0.5))
                        .frame(width: 2)
                        .offset(x: geo.size.width * CGFloat(NoiseSkala.ausschlag(content.schwelleDb)))
                }
            }
            .frame(height: 8)
            Text(meter.running
                 ? "Im Raum gerade \(Int(meter.dezibel.rounded())) dB"
                 : "Kein Zugriff auf das Mikrofon")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Tagesablauf

private struct ChecklistSettings: View {
    @Binding var content: ChecklistContent
    @State private var newItem = ""
    @State private var bulk = ""
    @State private var showReplace = false

    var body: some View {
        Section("Tagesablauf") {
            TextField("Überschrift", text: $content.title)
            Toggle("Fortschritt anzeigen", isOn: $content.showProgress)
            Toggle("Erledigtes durchstreichen", isOn: $content.strikeDone)
            Toggle("Täglich zurücksetzen", isOn: $content.resetDaily)
        }
        Section {
            Toggle("Eingabefeld auf der Karte", isOn: $content.quickAdd)
        } footer: {
            Text("Damit lässt sich ein Punkt direkt an der Tafel ergänzen, ohne dieses Blatt zu öffnen.")
        }
        Section("Schritte") {
            ForEach($content.items) { $item in
                HStack {
                    EmojiField(emoji: $item.emoji, placeholder: "🙂", fontSize: 22)
                        .frame(width: 44, height: 34)
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

        Section {
            TextEditor(text: $bulk)
                .frame(minHeight: 120)
                .font(.system(.body, design: .rounded))
            Button {
                showReplace = true
            } label: {
                Label("Liste ersetzen", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(bulk.trimmed.isEmpty)
        } header: {
            Text("Schnell erfassen")
        } footer: {
            Text("Eine Zeile je Punkt — praktisch, um einen ganzen Tagesablauf auf einmal einzutragen.")
        }
        .onAppear {
            if bulk.isEmpty { bulk = content.items.map(\.text).joined(separator: "\n") }
        }
        .alert("Liste ersetzen?", isPresented: $showReplace) {
            Button("Ersetzen", role: .destructive) { replace() }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Die bisherigen Punkte werden durch die Zeilen oben ersetzt.")
        }
    }

    private func add() {
        guard let text = newItem.nonEmpty else { return }
        content.items.append(ChecklistItem(text: text))
        newItem = ""
    }

    private func replace() {
        let lines = bulk.split(whereSeparator: { $0 == "\n" })
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
        content.items = lines.map { ChecklistItem(text: $0) }
    }
}

// MARK: - Zufälliger Name

private struct NamePickerSettings: View {
    @EnvironmentObject private var store: BoardStore
    @Binding var content: NamePickerContent

    private var list: NameList? { store.nameList(content.listID) }

    // Vier Blöcke, immer in derselben Reihenfolge — und in jedem steht nur,
    // was zum gewählten Modus gehört. „Aufdecken“ gibt es nur beim
    // Einzelnamen, „Gruppengröße“ nur bei Gruppen. Was lang wird (Klänge,
    // die Liste der Gezogenen), liegt auf einer eigenen Seite; die Zeile
    // zeigt die aktuelle Wahl, das genügt zum Nachsehen.
    var body: some View {
        Group {
            wasGezogenWird
            wieEsAussieht
            wieGezogenWird
            wasSchonWar
        }
    }

    // MARK: 1. Was gezogen wird

    private var wasGezogenWird: some View {
        Group {
            Section {
                ForEach(Ziehmodus.allCases) { modus in
                    modusZeile(modus)
                }
            } header: {
                Text("Was gezogen wird")
            }

            Section {
                TextField(ueberschriftPlatzhalter, text: Binding(
                    get: { content.ueberschrift },
                    set: { content.ueberschrift = $0 }
                ))

                Picker("Namensliste", selection: Binding(
                    get: { content.listID ?? "" },
                    set: { content.listID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("Keine Liste").tag("")
                    ForEach(store.visibleNameLists) { liste in
                        Text(liste.name).tag(liste.id)
                    }
                }

                if let list {
                    NavigationLink {
                        NameListEditor(listID: list.id)
                    } label: {
                        Label("Liste bearbeiten (\(list.entries.count) Namen)",
                              systemImage: "pencil")
                    }
                }

                if content.modus == .gruppen {
                    Stepper(value: $content.gruppenGroesse, in: 1...15) {
                        LabeledContent("Gruppengröße", value: "\(content.gruppenGroesse)")
                    }
                }
                if content.modus == .tagesgruppe {
                    Stepper(value: $content.tagesgruppeAnzahl, in: 1...30) {
                        LabeledContent("Wie viele Namen",
                                       value: "\(content.tagesgruppeAnzahl)")
                    }
                }
            } footer: {
                Text(fussZuGezogen)
            }
        }
    }

    private func modusZeile(_ modus: Ziehmodus) -> some View {
        let gewaehlt = content.modus == modus
        return Button {
            content.modus = modus
            Haptics.tap()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: modus.symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(gewaehlt ? Theme.accent : .secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(modus.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(modus.erklaerung)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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

    private var ueberschriftPlatzhalter: String {
        switch content.modus {
        case .einzel:      return "Überschrift (z. B. „Wer liest vor?“)"
        case .gruppen:     return "Überschrift (z. B. „Partnerarbeit“)"
        case .tagesgruppe: return "Überschrift (z. B. „Klassendienst“)"
        }
    }

    private var fussZuGezogen: String {
        let gemeinsam = "Die Überschrift gehört zum Modus: Beim Umschalten kommt die "
            + "jeweils passende zurück. Sie bleibt auch dann sichtbar, wenn die Tafel "
            + "unter „Aussehen“ keine Beschriftungen zeigt."
        switch content.modus {
        case .einzel:
            return gemeinsam + " Ohne eigene Überschrift steht dort der Name der Liste."
        case .gruppen:
            return gemeinsam + " Die letzte Gruppe darf unvollständig bleiben — "
                + "das hängt an der Zahl der Namen, nicht an der Einstellung."
        case .tagesgruppe:
            return gemeinsam
        }
    }

    // MARK: 2. Wie es aussieht

    private var wieEsAussieht: some View {
        Group {
            if content.modus == .einzel {
                Section {
                    NavigationLink {
                        AufdeckenSeite(content: $content)
                    } label: {
                        LabeledContent("Aufdecken", value: content.reveal.title)
                    }
                    Picker("Gezogene Namen zeigen", selection: $content.showDrawn) {
                        ForEach(ShowRule.allCases) { Text($0.title).tag($0) }
                    }
                    kaertchenfarbe
                } header: {
                    Text("Wie es aussieht")
                } footer: {
                    Text(fussZuEinzel)
                }
            } else {
                Section {
                    Picker("Ergebnis zeigen als", selection: $content.anzeige) {
                        ForEach(Ergebnisanzeige.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if content.anzeige == .zaehlen, !content.zaehler.isEmpty {
                        Button(role: .destructive) {
                            content.zaehler = [:]
                            Haptics.tap()
                        } label: {
                            Label("Zähler zurücksetzen", systemImage: "arrow.counterclockwise")
                        }
                    }

                    Toggle("Ergebnis festhalten", isOn: $content.festgehalten)

                    kaertchenfarbe
                } header: {
                    Text("Wie es aussieht")
                } footer: {
                    Text(fussZuAnzeige)
                }
            }
        }
    }

    /// Farbe der Namenskärtchen — dieselben Zeilen in beiden Ansichten.
    ///
    /// Aus heißt: wie bisher, eine ruhige Aufhellung des Untergrunds. Erst
    /// der Schalter macht daraus eine feste Farbe; nur so bleibt die Vorgabe
    /// erkennbar von einer bewussten Wahl unterschieden.
    @ViewBuilder
    private var kaertchenfarbe: some View {
        Toggle("Eigene Farbe der Kärtchen", isOn: Binding(
            get: { !content.kartenfarbe.isEmpty },
            set: { an in
                content.kartenfarbe = an ? "#0f9b8e" : ""
                if !an { content.kartenfarbe2 = "" }
            }
        ))
        if !content.kartenfarbe.isEmpty {
            Verlaufwahl(titel: "Farbe der Kärtchen",
                        von: $content.kartenfarbe, bis: $content.kartenfarbe2)
        }
    }

    private var fussZuEinzel: String {
        "Bei „Beim Bearbeiten“ bleibt die Liste im Unterricht verborgen — so lässt "
        + "sich nicht ablesen, wer noch fehlt.\n\n" + fussZuKartenfarbe
    }

    private var fussZuKartenfarbe: String {
        "Die Kärtchen sind ab Werk nur eine leichte Aufhellung des Untergrunds. "
        + "Eine eigene Farbe macht sie kräftig; die Schrift darauf stellt sich "
        + "auf hell oder dunkel ein, solange keine eigene Schriftfarbe gewählt ist."
    }

    /// Als eigene Größe, damit der Übersetzer nicht über einem
    /// verschachtelten Text-Ausdruck aufgibt.
    private var fussZuAnzeige: String {
        var text = content.anzeige.erklaerung
        text += "\n\nFestgehalten heißt: Es löst nichts mehr neu aus, weder der "
            + "Knopf noch ein Tipp auf ein Kärtchen. Abhaken und Zählen gehen "
            + "weiterhin. Derselbe Schalter sitzt als Schloss oben rechts auf dem "
            + "Element, damit er im Unterricht erreichbar ist."
        if content.anzeige == .zaehlen {
            text += "\n\nIn der Zählansicht löst ein Tipp auf ein Kärtchen keine "
                + "Neuauslosung mehr aus — dafür ist der Knopf unten da."
        }
        text += "\n\n" + fussZuKartenfarbe
        return text
    }

    // MARK: 3. Wie gezogen wird

    private var wieGezogenWird: some View {
        Section {
            if content.modus == .einzel {
                Picker("Ziehweise", selection: $content.mode) {
                    ForEach(NamePickerContent.DrawMode.allCases) { Text($0.title).tag($0) }
                }
            } else {
                Picker("Merkmale in der Gruppe", selection: $content.merkmalsvorgabe) {
                    ForEach(Merkmalsvorgabe.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled((list?.merkmale ?? []).isEmpty)

                // Welches Merkmal gemeint ist, muss nur gefragt werden, wenn
                // es mehr als eines gibt.
                if content.merkmalsvorgabe != .egal, (list?.merkmale.count ?? 0) > 1 {
                    Picker("Welches Merkmal", selection: $content.mischMerkmalID) {
                        ForEach(list?.merkmale ?? []) { merkmal in
                            Text(merkmal.name.nonEmpty ?? "Merkmal").tag(merkmal.id)
                        }
                    }
                }
            }

            Toggle("Namen durchlaufen lassen", isOn: $content.animate)

            NavigationLink {
                KlangSeite(content: $content)
            } label: {
                LabeledContent("Klang beim Ziehen", value: content.spinSound.title)
            }
        } header: {
            Text("Wie gezogen wird")
        } footer: {
            Text(fussZuZiehen)
        }
    }

    private var fussZuZiehen: String {
        if content.modus == .einzel {
            return content.mode.explanation
                + " Ohne Durchlaufen steht der Name sofort da; dann gibt es auch keinen Klang."
        }
        guard let list, !list.merkmale.isEmpty else {
            return "Merkmale legst du in der Namensliste an — zum Beispiel „J“ und „M“. "
                + "Dann kann die Ziehung darauf achten, wie die Gruppen zusammengesetzt "
                + "sind."
        }
        var text = content.merkmalsvorgabe.erklaerung
        if let merkmalID = content.merkmal(in: list),
           let merkmal = list.merkmal(merkmalID) {
            let name = merkmal.name.nonEmpty ?? "Merkmal"
            text += "\n\nGewählt ist „\(name)“ — " + verteilungstext(list, merkmalID)
            text += "\n\nReicht die Zahl der Namen nicht aus, geht es so weit auf, "
                + "wie es geht; die App tut nicht so, als ginge mehr."
        }
        return text
    }

    /// „J 12 · M 14 · ohne Angabe 2" — auf einen Blick, ob noch etwas fehlt.
    private func verteilungstext(_ list: NameList, _ merkmalID: String) -> String {
        let verteilung = list.verteilung(merkmalID)
        guard let merkmal = list.merkmal(merkmalID) else { return "" }
        var teile: [String] = []
        for wert in merkmal.werte {
            teile.append("\(wert) \(verteilung[wert] ?? 0)")
        }
        if let ohne = verteilung[""], ohne > 0 {
            teile.append("ohne Angabe \(ohne)")
        }
        return teile.isEmpty ? "noch keine Werte vergeben."
                             : teile.joined(separator: " · ") + "."
    }

    // MARK: 4. Was schon war

    /// Als eigene Größe, nicht in der Ansicht zusammengesetzt: Der Übersetzer
    /// bricht sonst über einem verschachtelten Text-Ausdruck ab
    /// („unable to type-check this expression in reasonable time“).
    private var fussZuArchiv: String {
        var text = "Die App merkt sich, wer schon mit wem zusammen war, und zieht "
            + "bevorzugt Paarungen, die es noch nicht gab. Beides gehört zu "
            + "DIESEM Element: Zwei Kacheln mit derselben Namensliste — etwa "
            + "„Sitzplätze“ und „Kinder des Tages“ — führen getrennt Buch."
        text += "\n\nEin Vorgang, ein Eintrag: „Neu auslosen“ beginnt einen neuen, "
            + "ein Tipp auf ein Kärtchen berichtigt den laufenden. Was nur ein "
            + "Zwischenschritt war, steht später nirgends."
        if !content.ergebnis.isEmpty {
            text += "\n\n„Ergebnis verwerfen“ nimmt den laufenden Vorgang ganz "
                + "heraus — auch aus Archiv und Gedächtnis. Er hat ja nie gegolten."
        }
        return text
    }

    private var wasSchonWar: some View {
        Group {
            if content.modus == .einzel {
                Section {
                    NavigationLink {
                        BereitsGezogenSeite(content: $content, list: list)
                    } label: {
                        LabeledContent("Bereits gezogen",
                                       value: "\(content.drawnIDs.count) von \(list?.entries.count ?? 0)")
                    }
                } header: {
                    Text("Was schon war")
                }
            } else {
                Section {
                    NavigationLink {
                        ZiehungenSeite(content: $content)
                    } label: {
                        LabeledContent("Vergangene Ziehungen",
                                       value: "\(content.ziehungen.count)")
                    }
                    if !content.ergebnis.isEmpty {
                        Button(role: .destructive) {
                            // Auch aus Archiv und Gedächtnis nehmen: Dieser
                            // Sitzplan hat nie gegolten.
                            content.merkeZiehung([], vorher: content.ergebnis,
                                                 ersetzt: content.ziehungID, liste: list)
                            content.ergebnis = []
                            content.erledigt = []
                            content.ziehungID = ""
                            content.festgehalten = false
                            Haptics.tap()
                        } label: {
                            Label("Ergebnis verwerfen", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("Was schon war")
                } footer: {
                    Text(fussZuArchiv)
                }
            }
        }
    }
}

// MARK: - Unterseiten der Ziehung

private struct AufdeckenSeite: View {
    @Binding var content: NamePickerContent

    var body: some View {
        List {
            Section {
                Picker("Aufdecken", selection: $content.reveal) {
                    ForEach(RevealMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
            } footer: {
                Text(content.reveal.explanation
                     + (content.reveal == .instant ? ""
                        : " Jeder Tipp auf die Karte deckt einen Schritt auf; "
                        + "das Auge zeigt sofort alles."))
            }
        }
        .navigationTitle("Aufdecken")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct KlangSeite: View {
    @Binding var content: NamePickerContent

    var body: some View {
        List {
            Section {
                ForEach(SpinSound.allCases) { klang in
                    klangZeile(klang)
                }
            } footer: {
                Text("Alle Klänge entstehen im Gerät — es wird nichts nachgeladen, "
                     + "und sie funktionieren ohne Netz. Ein Tipp spielt den Klang "
                     + "gleich zur Probe ab.")
            }
        }
        .navigationTitle("Klang beim Ziehen")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Der Tipp wählt den Klang und spielt ihn gleich ab — hören ist hier
    /// aussagekräftiger als jede Beschreibung.
    private func klangZeile(_ klang: SpinSound) -> some View {
        let gewaehlt = content.spinSound == klang
        return Button {
            content.spinSound = klang
            Haptics.tap()
            Ziehklang.shared.probe(klang)
        } label: {
            HStack(spacing: 13) {
                Image(systemName: klang.symbol)
                    .font(.system(size: 17))
                    .foregroundStyle(gewaehlt ? Theme.accent : .secondary)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(klang.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(klang.hint)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
}

/// Die vergangenen Auslosungen **dieses Elements**.
private struct ZiehungenSeite: View {
    @Binding var content: NamePickerContent

    @State private var fragtNach = false

    var body: some View {
        List {
            if !content.ziehungen.isEmpty {
                ForEach(content.ziehungen) { ziehung in
                    Section {
                        ForEach(Array(ziehung.zeilen.enumerated()), id: \.offset) { _, zeile in
                            Text(zeile.joined(separator: "  ·  "))
                                .font(.system(size: 15))
                        }
                    } header: {
                        Text(kopf(ziehung))
                    }
                }

                Section {
                    Button(role: .destructive) {
                        fragtNach = true
                    } label: {
                        Label("Alles zurücksetzen", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Löscht die vergangenen Ziehungen und das Gedächtnis dieses "
                         + "Elements: Danach darf wieder jeder mit jedem, als wäre "
                         + "nichts gewesen. Andere Kacheln bleiben unberührt.")
                }
            } else {
                Section {
                    Text("Noch keine Ziehung gespeichert.")
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Sobald du auf dieser Kachel Gruppen oder eine Tagesgruppe "
                         + "auslost, steht sie hier — mit Datum und Wochentag. Es "
                         + "bleiben die letzten \(NamePickerContent.archivGrenze) stehen.")
                }
            }
        }
        .navigationTitle("Vergangene Ziehungen")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Alles zurücksetzen?", isPresented: $fragtNach) {
            Button("Zurücksetzen", role: .destructive) {
                content.setzeZiehungenZurueck()
                Haptics.success()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Die vergangenen Ziehungen dieser Kachel werden gelöscht, und die "
                 + "App vergisst, wer dort schon mit wem zusammen war. Das lässt sich "
                 + "nicht rückgängig machen.")
        }
    }

    private func kopf(_ ziehung: Ziehung) -> String {
        var teile = [ClockWidgetView.dateText(ziehung.zeitpunkt)]
        teile.append(ClockWidgetView.timeText(ziehung.zeitpunkt, showSeconds: false,
                                              twentyFour: true))
        if let titel = ziehung.titel.nonEmpty { teile.append(titel) }
        return teile.joined(separator: " · ")
    }
}

private struct BereitsGezogenSeite: View {
    @Binding var content: NamePickerContent
    let list: NameList?

    var body: some View {
        List {
            Section {
                ForEach(list?.entries ?? []) { entry in
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
                Button {
                    content.drawnIDs = []
                    content.currentID = nil
                } label: {
                    Label("Alle zurücklegen", systemImage: "arrow.counterclockwise")
                }
            } footer: {
                Text("Antippen schaltet um: So lässt sich jemand nachträglich als "
                     + "gezogen markieren oder wieder in den Topf legen.")
            }
        }
        .navigationTitle("Bereits gezogen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Klänge

private struct SoundsSettings: View {
    @EnvironmentObject private var store: BoardStore
    @Binding var content: SoundsContent

    @StateObject private var recorder = VoiceRecorder()
    /// Für welches Feld gerade eine Datei gesucht wird. Bewusst getrennt
    /// vom Schalter unten: Hingen beide am selben Wert, löschte das
    /// Schließen des Blattes das Ziel, bevor die Auswahl ausgewertet war —
    /// die Datei landete dann nirgends und die Karte sagte weiter
    /// „Kein Ton hinterlegt".
    @State private var importingFor: String?
    @State private var zeigtDateiwahl = false
    @State private var recordingFor: String?

    var body: some View {
        Group {
        Section {
            Toggle("Beschriftungen zeigen", isOn: $content.showLabels)
        } header: {
            Text("Klangfelder")
        } footer: {
            Text("Die Beschriftung steht auf dem Feld und sagt, was erklingt. "
                 + "Sie bleibt auch dann sichtbar, wenn die Tafel unter „Aussehen“ "
                 + "keine Beschriftungen zeigt — nur dieser Schalter blendet sie aus.")
        }

        ForEach($content.buttons) { $button in
            Section {
                HStack {
                    EmojiField(emoji: $button.emoji, placeholder: "🔔", fontSize: 24)
                        .frame(width: 50, height: 36)
                    TextField("Beschriftung", text: $button.label)
                }
                Verlaufwahl(titel: "Farbe", von: $button.colorHex, bis: $button.colorHex2)

                HStack {
                    Image(systemName: button.hasSource ? "waveform" : "waveform.slash")
                        .foregroundStyle(button.hasSource ? Theme.mint : .secondary)
                    Text(button.fileName != nil ? "Datei hinterlegt"
                         : (button.url.nonEmpty != nil ? "Link hinterlegt" : "Kein Ton hinterlegt"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if button.hasSource {
                        Button {
                            SoundPlayer.shared.play(button)
                        } label: {
                            Image(systemName: "play.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    importingFor = button.id
                    zeigtDateiwahl = true
                } label: {
                    Label("Tondatei wählen", systemImage: "folder")
                }

                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                    TextField("https://… (Klang aus dem Netz)", text: $button.url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
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
            } footer: {
                Text("Eine Tondatei geht über iCloud an alle Geräte mit. Ein Link funktioniert "
                     + "ebenfalls überall — braucht aber eine Internetverbindung.")
            }
        }

        Section {
            Button {
                content.buttons.append(SoundButton(label: "Klang", emoji: "🔔",
                                                   colorHex: BackgroundPreset.solids.randomElement() ?? "#0f9b8e"))
            } label: {
                Label("Feld hinzufügen", systemImage: "plus")
            }
        }
        // Der Dateiwähler hängt an genau EINEM Abschnitt. Läge er an der
        // Group, legte SwiftUI ihn an jedes Kind an — es gäbe so viele
        // Wähler wie Abschnitte, alle am selben Schalter.
        .fileImporter(isPresented: $zeigtDateiwahl,
                      // Bewusst ohne Filter: iPadOS blendet sonst Dateien
                      // aus, deren Art der Anbieter nicht mitliefert — bei
                      // MP3s in iCloud Drive und auf Netzlaufwerken passiert
                      // genau das (dieselbe Erfahrung wie in der Web-App).
                      // Passt die Datei nicht, sagen wir es hinterher.
                      allowedContentTypes: [.item]) { ergebnis in
            uebernimmDatei(ergebnis)
        }
        }
    }

    /// Gewählte Datei in das Feld legen, für das der Wähler geöffnet wurde.
    ///
    /// Zwei Dinge sind hier wichtig, beide gegen ein Hängenbleiben:
    ///
    /// 1. **Der Schalter wird zuerst zurückgesetzt.** Vorher schloss den
    ///    Wähler erst das Neuzeichnen, das die Zuweisung weiter unten
    ///    auslöst — und dabei ging das Schließen gelegentlich verloren. Der
    ///    Schalter blieb dann innerlich auf „offen", und ein zweiter Tipp auf
    ///    „Tondatei wählen" tat gar nichts mehr. Genau der gemeldete Fehler.
    /// 2. **Gelesen wird abseits des Hauptfadens.** Liegt die Datei in iCloud
    ///    oder auf einem Netzlaufwerk, lädt `Data(contentsOf:)` sie erst
    ///    herunter. Auf dem Hauptfaden stünde so lange die ganze App.
    private func uebernimmDatei(_ ergebnis: Result<URL, Error>) {
        zeigtDateiwahl = false
        let ziel = importingFor
        importingFor = nil
        // Abbrechen ist kein Fehler — nur echte Fehler melden.
        guard let ziel, case .success(let url) = ergebnis else { return }

        Task { @MainActor in
            let daten = await Task.detached(priority: .userInitiated) { () -> Data? in
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                return try? Data(contentsOf: url)
            }.value

            guard let daten, !daten.isEmpty else {
                store.showStatus("Die Datei ließ sich nicht lesen. Liegt sie in iCloud, "
                                 + "muss sie erst geladen werden.")
                return
            }
            let endung = url.pathExtension.isEmpty ? "m4a" : url.pathExtension.lowercased()
            guard let dateiname = store.saveMedia(data: daten, fileExtension: endung) else {
                return  // saveMedia meldet den Fehler selbst
            }
            guard let index = content.buttons.firstIndex(where: { $0.id == ziel }) else {
                store.showStatus("Das Klangfeld gibt es nicht mehr.")
                return
            }
            content.buttons[index].fileName = dateiname
            if content.buttons[index].label.isEmpty
                || content.buttons[index].label == "Klang" {
                content.buttons[index].label = url.deletingPathExtension().lastPathComponent
            }
            let bekannt = ["mp3", "m4a", "wav", "aac", "aif", "aiff", "caf", "ogg"]
            if !bekannt.contains(endung) {
                store.showStatus("„\(url.lastPathComponent)“ ist vielleicht keine Tondatei — "
                                 + "sie ist trotzdem hinterlegt.")
            }
        }
    }
}


// MARK: - Dokumentenkamera

private struct KameraSettings: View {
    @Binding var content: KameraContent
    @ObservedObject private var kamera = Kameraquelle.shared

    var body: some View {
        Section {
            TextField("Aufschrift (z. B. „Merlins Heft“)", text: $content.caption)
            Toggle("Bild füllend zeigen", isOn: $content.fuellend)
        } header: {
            Text("Dokumentenkamera")
        } footer: {
            Text("Füllend nutzt die ganze Fläche und schneidet an den Rändern etwas ab. "
                 + "Ausgeschaltet ist das ganze Bild zu sehen, dafür mit Rändern.")
        }

        Section {
            if content.eingefroren != nil {
                Button {
                    content.eingefroren = nil
                    Haptics.tap()
                } label: {
                    Label("Standbild verwerfen", systemImage: "arrow.counterclockwise")
                }
            } else {
                Text("Kein Standbild — die Kamera läuft.")
                    .foregroundStyle(.secondary)
            }
            if kamera.erlaubnis == .verweigert {
                Text("Kein Zugriff auf die Kamera. In den iOS-Einstellungen unter "
                     + "Klassenraum wieder erlauben.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Standbild")
        } footer: {
            Text("Ein Tipp auf das Element friert das Bild ein und taut es wieder auf. "
                 + "Auf dem eingefrorenen Bild lässt sich mit dem Stift schreiben — die "
                 + "Handschrift der Tafel liegt darüber. „Als Bild ablegen“ macht daraus "
                 + "ein eigenes Bildelement, das stehen bleibt, während die Kamera "
                 + "weiterläuft.")
        }
    }
}

// MARK: - Arbeitssymbol

private struct SymbolSettings: View {
    @Binding var content: SymbolContent

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    var body: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(WorkSymbol.allCases) { symbol in
                    Button {
                        content.symbol = symbol
                        Haptics.tap()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: symbol.systemImage)
                                .font(.system(size: 30, weight: .semibold))
                            Text(symbol.title)
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(content.symbol == symbol
                                      ? Theme.accent.opacity(0.18) : Color.secondary.opacity(0.10))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(content.symbol == symbol ? Theme.accent : .clear,
                                              lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Symbol")
        } footer: {
            Text("Auf der Tafel schaltet ein Tipp auf das Element zur nächsten Arbeitsform weiter.")
        }

        Section("Anzeige") {
            Toggle("Beschriftung anzeigen", isOn: $content.showLabel)
        }
    }
}


// MARK: - Video

private struct VideoSettings: View {
    @EnvironmentObject private var store: BoardStore
    @Binding var content: VideoContent

    @State private var showFiles = false
    @State private var video: PhotosPickerItem?

    var body: some View {
        Section {
            HStack {
                Image(systemName: content.playbackURL == nil ? "questionmark.video" : "play.rectangle.fill")
                    .foregroundStyle(content.playbackURL == nil ? .secondary : Theme.mint)
                Text(quelle)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            PhotosPicker(selection: $video, matching: .videos) {
                Label("Video aus Fotos wählen", systemImage: "photo.on.rectangle")
            }
            Button {
                showFiles = true
            } label: {
                Label("Video aus Dateien wählen", systemImage: "folder")
            }
            if content.fileName != nil {
                Button(role: .destructive) {
                    content.fileName = nil
                    content.sourceLabel = ""
                } label: {
                    Label("Datei entfernen", systemImage: "trash")
                }
            }
        } header: {
            Text("Quelle")
        } footer: {
            Text("Videodateien bleiben auf diesem Gerät — sie werden nicht über iCloud verteilt, "
                 + "weil sie schnell mehrere hundert Megabyte groß sind. Für alle Geräte und für "
                 + "geteilte Tafeln stattdessen einen Link eintragen.")
        }

        Section {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                TextField("https://…", text: $content.url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
        } header: {
            Text("Link")
        } footer: {
            Text("Ein Link reist mit der Tafel mit. Er wird nur benutzt, wenn keine Datei auf "
                 + "diesem Gerät liegt.")
        }

        Section("Abspielen") {
            Toggle("Bedienleiste anzeigen", isOn: $content.showControls)
            Toggle("In Schleife wiederholen", isOn: $content.loop)
            Toggle("Ohne Ton starten", isOn: $content.muted)
            TextField("Beschriftung", text: $content.caption)
        }
        // Ohne Filter, aus demselben Grund wie beim Klang: iPadOS blendet
        // Dateien aus, deren Art der Anbieter nicht mitliefert.
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item]) { result in
            // Schalter zuerst zurücksetzen, sonst tut der zweite Versuch
            // nichts mehr (siehe SoundsSettings).
            showFiles = false
            guard case .success(let url) = result else { return }
            let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
            if let fileName = store.saveLocalMedia(from: url, fileExtension: ext) {
                content.fileName = fileName
                content.sourceLabel = url.lastPathComponent
            }
        }
        .onChange(of: video) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                let temporary = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".mov")
                guard (try? data.write(to: temporary)) != nil,
                      let fileName = store.saveLocalMedia(from: temporary, fileExtension: "mov")
                else { return }
                try? FileManager.default.removeItem(at: temporary)
                content.fileName = fileName
                content.sourceLabel = "Video aus Fotos"
                video = nil
            }
        }
    }

    private var quelle: String {
        if content.fileMissing { return "Die hinterlegte Datei liegt nicht auf diesem Gerät." }
        if content.fileName != nil {
            return "Datei: " + (content.sourceLabel.nonEmpty ?? "auf diesem Gerät")
        }
        if let link = content.url.nonEmpty { return "Link: " + link }
        return "Noch kein Video ausgewählt."
    }
}
