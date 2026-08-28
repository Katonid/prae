import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

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
    /// Bild aus der Dateien-App. Getrennt von der Fotomediathek, weil vieles
    /// gar nicht dort liegt — Arbeitsblätter, aus dem Netz Geladenes, Dateien
    /// auf einem Netzlaufwerk.
    @State private var zeigtDateiwahl = false
    @State private var showDelete = false
    /// Eigener Hintergrund, solange er noch nicht übernommen wurde.
    @State private var eigenVon: String = "#1668a8"
    @State private var eigenBis: String = ""
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

                if !board.versteckteWidgets.isEmpty {
                    Section {
                        ForEach(board.versteckteWidgets) { widget in
                            Button {
                                store.zeigeWieder(widget.id, in: boardID)
                                Haptics.tap()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: widget.kind.systemImage)
                                        .foregroundStyle(Theme.accent)
                                        .frame(width: 26)
                                    Text(widget.kind.title)
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 0)
                                    Image(systemName: "eye")
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            store.zeigeAlleWieder(boardID: boardID)
                            Haptics.tap()
                        } label: {
                            Label("Alle wieder zeigen", systemImage: "eye")
                        }
                    } header: {
                        Text("Von mir ausgeblendet")
                    } footer: {
                        Text("Diese Elemente sind nur auf diesem Gerät versteckt. Auf einer "
                             + "geteilten Tafel stehen sie bei den anderen weiterhin.")
                    }
                }

                Section {
                    Toggle("Eigene Farben", isOn: Binding(
                        get: { !board.accentVon.isEmpty },
                        set: { an in
                            var updated = board
                            if an {
                                let schema = AccentSchemes.find(board.accent)
                                updated.accentVon = schema.from
                                updated.accentBis = schema.to
                            } else {
                                updated.accentVon = ""
                                updated.accentBis = ""
                            }
                            store.updateBoard(updated)
                        }
                    ))
                    if !board.accentVon.isEmpty {
                        Verlaufwahl(titel: "Akzentfarbe",
                                    von: bindung(\.accentVon), bis: bindung(\.accentBis))
                    }
                } header: {
                    Text("Eigenes Farbschema")
                } footer: {
                    Text("Statt eines der sechs Schemata eine eigene Farbe — oder ein Verlauf "
                         + "aus zwei eigenen Farben.")
                }

                Section {
                    Picker("Format", selection: Binding(
                        get: { board.format },
                        set: { wert in store.setzeFormat(wert, boardID: board.id) }
                    )) {
                        ForEach(Tafelformat.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Format der Tafel")
                } footer: {
                    Text(board.format.erklaerung
                         + " Die Breite bleibt gleich, nur die Höhe ändert sich — die "
                         + "Elemente behalten also ihre Lage. Wer beim Wechsel auf ein "
                         + "flacheres Format unten überstand, rückt herein.")
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

                Section {
                    Schriftfarbwahl(automatikTitel: "Automatisch",
                                    hex: bindung(\.schriftfarbe))
                } header: {
                    Text("Schriftfarbe")
                } footer: {
                    Text("Gilt für alle Elemente dieser Tafel: Überschriften, Hinweise und "
                         + "den Inhalt — den gezogenen Namen, die Uhrzeit, den Pegel. "
                         + "„Automatisch“ ist die bisherige Regel: helle Schrift auf dunklem "
                         + "Grund, dunkle auf hellem. Bei einem hellen Tafelhintergrund lohnt "
                         + "„Dunkel“.\n\nEinzelne Elemente dürfen abweichen — in ihren "
                         + "Einstellungen unter „Schriftfarbe“. Was dort steht, bleibt "
                         + "stehen, auch wenn hier später etwas anderes gewählt wird.")
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

                Section {
                    Verlaufwahl(titel: "Eigene Farbe",
                                von: $eigenVon, bis: $eigenBis)
                    Button {
                        apply(eigenBis.nonEmpty == nil ? .solid(eigenVon)
                                                       : .gradient(eigenVon, eigenBis))
                        Haptics.tap()
                    } label: {
                        Label("Als Hintergrund nehmen", systemImage: "checkmark.circle")
                    }
                } header: {
                    Text("Eigener Hintergrund")
                } footer: {
                    Text("Erst die Farben wählen, dann übernehmen. Mit Verlauf entsteht ein "
                         + "weicher Übergang von oben links nach unten rechts.")
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
                        Label("Aus der Fotomediathek", systemImage: "photo")
                    }
                    Button {
                        zeigtDateiwahl = true
                    } label: {
                        Label("Aus einer Datei öffnen", systemImage: "folder")
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
                    Text("Dunkle Bilder wirken auf der Tafel am ruhigsten — heller Text bleibt "
                         + "so gut lesbar. Über „Aus einer Datei“ erreichen Sie auch iCloud "
                         + "Drive, Netzlaufwerke und alles, was nicht in der Fotomediathek liegt.")
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
            // Ohne Filter auf Dateiarten, aus demselben Grund wie bei Klang und
            // Video: iPadOS blendet sonst Dateien aus, deren Art der Anbieter
            // nicht mitliefert. Passt sie nicht, sagen wir es hinterher.
            .fileImporter(isPresented: $zeigtDateiwahl, allowedContentTypes: [.item]) { ergebnis in
                // Schalter zuerst zurücksetzen, sonst tut der zweite Versuch
                // nichts mehr (siehe SoundsSettings in WidgetSettingsSheet).
                zeigtDateiwahl = false
                uebernimmHintergrund(ergebnis)
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

    /// Bilddatei als Hintergrund übernehmen.
    private func uebernimmHintergrund(_ ergebnis: Result<URL, Error>) {
        guard case .success(let url) = ergebnis else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let daten = try? Data(contentsOf: url), !daten.isEmpty else {
            store.showStatus("Die Datei ließ sich nicht lesen. Liegt sie in iCloud, "
                             + "muss sie erst geladen werden.")
            return
        }
        guard let bild = UIImage(data: daten) else {
            store.showStatus("„\(url.lastPathComponent)“ ist kein Bild, das die App öffnen kann.")
            return
        }
        guard let fertig = MediaCache.prepareForBoard(bild),
              let dateiname = store.saveMedia(data: fertig.daten,
                                              fileExtension: fertig.endung)
        else { return }
        apply(.image(dateiname, dim))
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

    /// Schreibt ein einzelnes Feld der Tafel zurück in den Speicher.
    private func bindung(_ pfad: WritableKeyPath<Board, String>) -> Binding<String> {
        Binding(
            get: { board[keyPath: pfad] },
            set: { neu in
                var updated = board
                updated[keyPath: pfad] = neu
                store.updateBoard(updated)
            }
        )
    }

    private func apply(_ background: BoardBackground) {
        var updated = board
        updated.background = background
        store.updateBoard(updated)
        Haptics.tap()
    }
}
