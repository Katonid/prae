import SwiftUI

struct NewCalendarView: View {
    let onCreate: (CalendarProject) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: CalendarKind = .doubleMonth
    @State private var name = "Familienkalender"
    @State private var year: Int = {
        let now = Date()
        let c = Calendar.current.dateComponents([.year, .month], from: now)
        let y = c.year ?? 2027
        return (c.month ?? 1) >= 7 ? y + 1 : y
    }()
    @State private var presetName = "A4 quer"
    @State private var format = PageFormat(widthMM: 297, heightMM: 210)
    @State private var designID = "nordlicht"
    /// Eigene Vorlage statt einer eingebauten (ab 1.0.13).
    @State private var templateID: UUID?
    @ObservedObject private var templates = TemplateStore.shared
    @State private var state: Bundesland = .BY

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    section("Kalenderart") {
                        VStack(spacing: 12) {
                            ForEach(CalendarKind.allCases) { k in
                                kindCard(k)
                            }
                        }
                    }
                    section("Vorschau") {
                        preview
                    }
                    section("Stilvorlage") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(templates.templates) { t in
                                    Button {
                                        withAnimation(.snappy) { templateID = t.id }
                                    } label: {
                                        DesignSwatch(design: t.design, name: t.name, selected: templateID == t.id)
                                    }
                                    .buttonStyle(.plain)
                                }
                                ForEach(Design.presetIDs, id: \.self) { id in
                                    Button {
                                        withAnimation(.snappy) {
                                            designID = id
                                            templateID = nil
                                        }
                                    } label: {
                                        DesignSwatch(design: .preset(id), name: Design.presetName(id),
                                                     selected: templateID == nil && id == designID)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 2)
                        }
                    }
                    section("Angaben") {
                        VStack(spacing: 12) {
                            TextField("Name des Kalenders", text: $name)
                                .textFieldStyle(.roundedBorder)
                            Stepper(value: $year, in: 2020...2040) {
                                Text(verbatim: "Jahr: \(year)")
                            }
                            Picker("Bundesland (Feiertage und Ferien)", selection: $state) {
                                ForEach(Bundesland.allCases) { b in
                                    Text(b.name).tag(b)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    section("Seitenformat") {
                        VStack(alignment: .leading, spacing: 8) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(PageFormat.presets.indices, id: \.self) { i in
                                        let preset = PageFormat.presets[i]
                                        Button(preset.name) {
                                            presetName = preset.name
                                            format = preset.format
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(presetName == preset.name ? Color.accentColor : Color.secondary)
                                    }
                                }
                            }
                            MMField(title: "Beschnitt je Seite", value: $format.bleedMM, range: 0...20)
                            MMField(title: "Sicherheitsabstand", value: $format.safetyMM, range: 0...40)
                            Text("Den Beschnitt gibt der Druckdienst vor (meist 2–3 mm). Größe, Bindungsrand und alles andere lassen sich auch später unter „Format“ frei eingeben.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Neuer Kalender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anlegen") { onCreate(makeProject()) }
                        .fontWeight(.bold)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
            content()
        }
    }

    private func kindCard(_ k: CalendarKind) -> some View {
        Button {
            withAnimation(.snappy) {
                kind = k
                let preset = defaultPreset(for: k)
                presetName = preset.name
                format = preset.format
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: k.symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(kind == k ? Color.accentColor : Color(.tertiarySystemFill)))
                    .foregroundStyle(kind == k ? Color.white : Color.primary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(k.title).font(.headline)
                    Text(k.subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: kind == k ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(kind == k ? Color.accentColor : Color.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(kind == k ? Color.accentColor : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func defaultPreset(for k: CalendarKind) -> (name: String, format: PageFormat) {
        let wanted: String
        switch k {
        case .year: wanted = "A3 hoch"
        case .week: wanted = "A5 hoch"
        case .doubleMonth: wanted = "A4 quer"
        }
        return PageFormat.presets.first { $0.name == wanted } ?? PageFormat.presets[0]
    }

    private func makeProject() -> CalendarProject {
        var p = CalendarProject(name: name.isEmpty ? "Kalender" : name, kind: kind, year: year,
                                format: format, design: .preset(designID))
        p.dates.state = state
        p.dates.schoolStates = [SchoolSelection(state: state, color: SchoolSelection.palette[0])]
        if kind == .week { p.photoStyle = .full }
        if kind == .doubleMonth { p.photoStyle = .full }
        if let id = templateID, let t = templates.template(id) { p.apply(t) }
        return p
    }

    /// Live-Vorschau der zweiten Seite mit der gewählten Vorlage.
    private var preview: some View {
        let p = makeProject()
        let marks = CalendarMarks.build(for: p)
        let pages = p.pages
        let page = pages.first(where: { $0.content != .cover && !isPhotoOnly($0.content) }) ?? pages[0]
        return GeometryReader { geo in
            let size = ScaledPageView.displaySize(p.format, scale: 1, guides: false)
            let scale = min(geo.size.width / size.width, geo.size.height / size.height)
            ScaledPageView(project: p, page: page, marks: marks, scale: scale)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                .frame(width: geo.size.width, height: geo.size.height)
                .allowsHitTesting(false)
        }
        .frame(height: 300)
        .padding(.vertical, 8)
        .background(StudioBackdrop().clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)))
    }

    private func isPhotoOnly(_ c: PageContent) -> Bool {
        if case .monthPhoto = c { return true }
        return false
    }
}
