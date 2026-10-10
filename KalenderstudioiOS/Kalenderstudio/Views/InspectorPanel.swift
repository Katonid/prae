import SwiftUI
import UniformTypeIdentifiers

struct InspectorPanel: View {
    @Binding var project: CalendarProject
    @Binding var tab: PanelTab
    let onEditPhoto: (PhotoTarget) -> Void

    var body: some View {
        // Bewusst KEIN eigener NavigationStack: Das Panel liegt im Stapel
        // der Startseite, und ein zweiter Stapel darin ließ den Editor
        // beim Öffnen zurückspringen und beim nächsten Mal abstürzen.
        VStack(spacing: 0) {
                Picker("Bereich", selection: $tab) {
                    ForEach(PanelTab.allCases) { t in
                        Label(t.title, systemImage: t.symbol).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .labelStyle(.titleOnly)
                .padding(.horizontal)
                .padding(.vertical, 8)
                Group {
                    switch tab {
                    case .layout: LayoutPanel(project: $project)
                    case .style: StylePanel(project: $project)
                    case .photos: PhotosPanel(project: $project, onEditPhoto: onEditPhoto)
                    case .dates: DatesPanel(project: $project)
                    case .format: FormatPanel(project: $project)
                    }
                }
                .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Aufbau

struct LayoutPanel: View {
    @Binding var project: CalendarProject

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        Form {
            Section("Kalenderart") {
                Picker("Art", selection: $project.kind) {
                    ForEach(CalendarKind.allCases) { k in
                        Text(k.title).tag(k)
                    }
                }
                Stepper(value: $project.year, in: 2020...2040) {
                    Text(verbatim: "Jahr \(project.year)")
                }
                if project.monthsInUse {
                    Picker("Beginnt mit", selection: $project.startMonth) {
                        ForEach(1...12, id: \.self) { m in
                            Text(CalendarMath.monthName(m)).tag(m)
                        }
                    }
                }
            }

            switch project.kind {
            case .year:
                Section("Gestaltungsformat") {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(YearLayout.allCases) { l in
                            ChoiceTile(title: l.title, symbol: l.symbol, detail: l.detail,
                                       selected: project.yearLayout == l) {
                                project.yearLayout = l
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            case .week:
                Section("Gestaltungsformat") {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(WeekLayout.allCases) { l in
                            ChoiceTile(title: l.title, symbol: l.symbol, detail: l.detail,
                                       selected: project.weekLayout == l) {
                                project.weekLayout = l
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            case .doubleMonth:
                EmptyView()
            }

            if project.monthsInUse {
                Section("Kalendarium") {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(MonthGridLayout.allCases) { l in
                            ChoiceTile(title: l.title, symbol: l.symbol, detail: l.detail,
                                       selected: project.gridLayout == l) {
                                project.gridLayout = l
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(PhotoStyle.allCases) { s in
                        ChoiceTile(title: s.title, symbol: s.symbol, selected: project.photoStyle == s) {
                            project.photoStyle = s
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Fotos")
            } footer: {
                Text("„Randlos“ füllt die Fotofläche bis in den Beschnitt. Die Collage zeigt drei Fotos.")
            }

            Section("Titelblatt") {
                if project.kind != .year || project.yearLayout == .monthly {
                    Toggle("Titelblatt", isOn: $project.hasCover)
                }
                Picker("Gestaltung", selection: $project.coverStyle) {
                    ForEach(CoverStyle.allCases) { c in
                        Text(c.title).tag(c)
                    }
                }
                TextField("Titel", text: $project.title)
                TextField("Untertitel", text: $project.subtitle)
            }
        }
    }
}

// MARK: - Stil

struct StylePanel: View {
    @Binding var project: CalendarProject

    private var d: Binding<Design> { $project.design }

    private enum FontRole: String, Identifiable {
        case title, body, number
        var id: String { rawValue }
    }

    @State private var fontRole: FontRole?

    var body: some View {
        Form {
            Section("Stilvorlagen") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Design.presetIDs, id: \.self) { id in
                            Button {
                                withAnimation(.snappy) { apply(id) }
                            } label: {
                                DesignSwatch(design: .preset(id), name: Design.presetName(id),
                                             selected: project.design.presetID == id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            Section("Hintergrund") {
                Picker("Quelle", selection: d.backgroundSource) {
                    ForEach(BackgroundSource.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                switch project.design.backgroundSource {
                case .theme:
                    Picker("Muster", selection: d.pattern) {
                        ForEach(BackgroundPattern.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                case .photo, .pagePhoto:
                    if project.design.backgroundSource == .photo {
                        PhotoStrip(photos: project.photos, selected: project.design.backgroundPhotoID) { id in
                            project.design.backgroundPhotoID = id
                        }
                    } else {
                        Text("Jede Seite nutzt ihr eigenes Foto, weichgezeichnet. Bei „Monat auf zwei Seiten“ liegt so das Monatsfoto hinter dem Kalendarium.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    LabeledSlider(title: "Weichzeichnen", value: d.backgroundBlur, range: 0...1)
                    LabeledSlider(title: project.design.isDark ? "Abdunkeln" : "Aufhellen", value: d.backgroundDim, range: 0...0.9)
                }
            }

            Section {
                Toggle("Farbe des Monats aus dem Foto", isOn: d.monthColorFromPhoto)
                Toggle("Foto läuft weich aus", isOn: d.photoFade)
                Toggle("Große Monatszahl im Hintergrund", isOn: d.bigNumeral)
                Toggle("Monat als Zahl („03“)", isOn: d.monthAsNumber)
                Toggle("Monate im Wechsel hell und dunkel", isOn: d.alternateDark)
            } header: {
                Text("Monatsseiten")
            } footer: {
                Text("„Farbe des Monats“ nimmt die prägende Farbe des Monatsfotos für Hintergrund und Akzent. „Läuft aus“ gilt für randlose Fotos und blendet zur Kalenderseite hin weich über.")
            }

            Section("Farben") {
                ColorPicker("Verlauf oben", selection: d.bg1.color, supportsOpacity: false)
                ColorPicker("Verlauf unten", selection: d.bg2.color, supportsOpacity: false)
                ColorPicker("Musterfarbe", selection: d.bg3.color, supportsOpacity: false)
                ColorPicker("Schrift", selection: d.text.color, supportsOpacity: false)
                ColorPicker("Nebenschrift", selection: d.secondary.color, supportsOpacity: false)
                ColorPicker("Akzent", selection: d.accent.color, supportsOpacity: false)
                ColorPicker("Feiertage und Sonntage", selection: d.holiday.color, supportsOpacity: false)
                ColorPicker("Kartenfläche", selection: d.card.color, supportsOpacity: true)
            }

            Section("Schriften") {
                Button {
                    fontRole = .title
                } label: {
                    LabeledContent("Titel") {
                        Text(project.design.titleFont)
                            .font(FontLibrary.font(project.design.titleFont, size: 17, weight: project.design.titleWeight.weight))
                    }
                }
                Picker("Titel-Stärke", selection: d.titleWeight) {
                    ForEach(WeightChoice.allCases) { w in Text(w.title).tag(w) }
                }
                LabeledSlider(title: "Titelgröße", value: d.titleScale, range: 0.5...1.8, percent: true)
                Toggle("Titel in Großbuchstaben", isOn: d.titleUppercase)
                LabeledSlider(title: "Sperrung", value: d.titleTracking, range: 0...0.25)

                Button {
                    fontRole = .body
                } label: {
                    LabeledContent("Text") {
                        Text(project.design.bodyFont)
                            .font(FontLibrary.font(project.design.bodyFont, size: 17, weight: .regular))
                    }
                }
                LabeledSlider(title: "Textgröße", value: d.bodyScale, range: 0.5...1.8, percent: true)

                Button {
                    fontRole = .number
                } label: {
                    LabeledContent("Zahlen") {
                        Text(project.design.numberFont)
                            .font(FontLibrary.font(project.design.numberFont, size: 17, weight: project.design.numberWeight.weight))
                    }
                }
                Picker("Zahlen-Stärke", selection: d.numberWeight) {
                    ForEach(WeightChoice.allCases) { w in Text(w.title).tag(w) }
                }
                LabeledSlider(title: "Zahlengröße", value: d.numberScale, range: 0.5...1.8, percent: true)
            }

            Section("Effekte") {
                LabeledSlider(title: "Schatten", value: d.shadow, range: 0...1, percent: true)
                Picker("Kalenderfläche", selection: d.cardStyle) {
                    ForEach(CardStyle.allCases) { c in Text(c.title).tag(c) }
                }
                .pickerStyle(.segmented)
                LabeledSlider(title: "Rundung", value: d.corner, range: 0...1, percent: true)
                LabeledSlider(title: "Fotorahmen", value: d.photoBorder, range: 0...1, percent: true)
            }
        }
        .sheet(item: $fontRole) { role in
            fontSheet(role)
        }
    }

    private func fontSheet(_ role: FontRole) -> some View {
        let title: String
        let selection: Binding<String>
        switch role {
        case .title: title = "Titelschrift"; selection = d.titleFont
        case .body: title = "Textschrift"; selection = d.bodyFont
        case .number: title = "Zahlenschrift"; selection = d.numberFont
        }
        return NavigationStack {
            FontListView(title: title, selection: selection)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { fontRole = nil }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }

    private func apply(_ id: String) {
        var neu = Design.preset(id)
        // Ein gewähltes Hintergrundfoto bleibt erhalten.
        neu.backgroundSource = project.design.backgroundSource
        neu.backgroundPhotoID = project.design.backgroundPhotoID
        neu.backgroundBlur = project.design.backgroundBlur
        neu.backgroundDim = project.design.backgroundDim
        project.design = neu
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var percent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(percent ? "\(Int((value * 100).rounded())) %" : String(format: "%.2f", value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
        }
    }
}

struct FontListView: View {
    let title: String
    @Binding var selection: String

    @ObservedObject private var fonts = FontStore.shared
    @State private var showPicker = false
    @State private var showImporter = false

    var body: some View {
        List {
            Section {
                Button {
                    showPicker = true
                } label: {
                    Label("Installierte Schrift wählen …", systemImage: "textformat")
                }
                Button {
                    showImporter = true
                } label: {
                    Label("Schriftdatei laden (.ttf, .otf)", systemImage: "doc.badge.plus")
                }
                if let message = fonts.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("„Installierte Schrift“ öffnet die Schriftauswahl von iOS — dort stehen auch Schriften, die du selbst auf dem Gerät installiert hast (z. B. über Adobe Fonts oder eine Schrift-App; zu sehen unter Einstellungen › Allgemein › Schriften). Was dort fehlt, gibt iOS dieser App nicht heraus — Zahlen dazu unter Einstellungen › Schriften.")
            }

            if !fonts.families.isEmpty {
                Section("Eigene Schriften") {
                    ForEach(fonts.families, id: \.self) { family in
                        row(family, custom: true)
                    }
                    .onDelete { offsets in
                        for i in offsets { fonts.remove(fonts.families[i]) }
                    }
                }
            }

            let installed = fonts.systemFamilies.filter {
                !fonts.families.contains($0) && !FontLibrary.families.contains($0)
            }
            if !installed.isEmpty {
                Section {
                    ForEach(installed, id: \.self) { family in
                        row(family, custom: true)
                    }
                } header: {
                    Text("Auf diesem Gerät installiert")
                } footer: {
                    Text("Diese Schriften meldet iOS als selbst installiert; die App meldet sie bei jedem Start für sich an.")
                }
            }

            Section("Mitgelieferte Schriften") {
                ForEach(FontLibrary.available, id: \.self) { family in
                    row(family, custom: false)
                }
            }
        }
        .navigationTitle(title)
        .sheet(isPresented: $showPicker) {
            SystemFontPicker { descriptor in
                showPicker = false
                guard let descriptor else { return }
                fonts.message = "Wird angemeldet …"
                fonts.adopt(descriptor) { family in
                    if let family { selection = family }
                }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: UTType.fontFiles,
                      allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            let before = Set(fonts.families)
            for url in urls { fonts.importFile(url) }
            if let neu = fonts.families.first(where: { !before.contains($0) }) {
                selection = neu
            }
        }
    }

    private func row(_ family: String, custom: Bool) -> some View {
        return Button {
            selection = family
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Januar 2027 · 24")
                        .font(FontLibrary.font(family, size: 24, weight: .regular))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(family)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if custom {
                            FontStatusBadge(family: family)
                        }
                    }
                }
                Spacer()
                if family == selection {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PhotoStrip: View {
    let photos: [PhotoItem]
    let selected: UUID?
    let onSelect: (UUID) -> Void

    var body: some View {
        if photos.isEmpty {
            Text("Noch keine Fotos — füge sie unter „Fotos“ hinzu.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos) { photo in
                        Button {
                            onSelect(photo.id)
                        } label: {
                            ThumbImage(id: photo.id)
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(selected == photo.id ? Color.accentColor : .clear, lineWidth: 3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct ThumbImage: View {
    let id: UUID

    var body: some View {
        if let img = ImageStore.shared.thumbnail(id) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            Color.gray.opacity(0.3)
        }
    }
}
