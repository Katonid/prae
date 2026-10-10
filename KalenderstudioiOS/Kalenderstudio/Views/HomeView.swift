import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var path: [UUID] = []
    @State private var showNew = false
    @State private var renaming: CalendarProject?
    @State private var newName = ""
    @State private var deleting: CalendarProject?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    if store.projects.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 20)], spacing: 24) {
                            ForEach(store.projects) { project in
                                Button {
                                    path.append(project.id)
                                } label: {
                                    ProjectCard(project: project)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        newName = project.name
                                        renaming = project
                                    } label: { Label("Umbenennen", systemImage: "pencil") }
                                    Button {
                                        store.duplicate(project)
                                    } label: { Label("Duplizieren", systemImage: "plus.square.on.square") }
                                    Button(role: .destructive) {
                                        deleting = project
                                    } label: { Label("Löschen", systemImage: "trash") }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Kalenderstudio")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNew = true
                    } label: {
                        Label("Neuer Kalender", systemImage: "plus")
                    }
                }
            }
            .task { probeIfRequested() }
            .navigationDestination(for: UUID.self) { id in
                if let binding = store.binding(for: id) {
                    EditorView(project: binding)
                } else {
                    ContentUnavailableView("Kalender nicht gefunden", systemImage: "calendar.badge.exclamationmark")
                }
            }
            .sheet(isPresented: $showNew) {
                NewCalendarView { project in
                    store.add(project)
                    showNew = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        path.append(project.id)
                    }
                }
            }
            .alert("Kalender umbenennen", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $newName)
                Button("Abbrechen", role: .cancel) { renaming = nil }
                Button("Sichern") {
                    if let r = renaming, let b = store.binding(for: r.id) {
                        b.wrappedValue.name = newName
                    }
                    renaming = nil
                }
            }
            .confirmationDialog("Kalender löschen?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                                titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    if let d = deleting { store.delete(d) }
                    deleting = nil
                }
            } message: {
                Text("Der Kalender und seine Fotos werden aus der App entfernt. Die Originale in deiner Fotomediathek bleiben erhalten.")
            }
        }
    }

    /// Nur für den Simulator-Arbeitsablauf: `-probe=year|week|doubleMonth`
    /// legt einen Kalender an und öffnet ihn sofort — so lässt sich der
    /// Editor ohne Antippen prüfen.
    private func probeIfRequested() {
        #if DEBUG
        guard let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-probe=") }),
              let kind = CalendarKind(rawValue: String(arg.dropFirst("-probe=".count))),
              path.isEmpty else { return }
        var p = CalendarProject(name: "Probe", kind: kind, year: 2027,
                                format: kind == .doubleMonth ? PageFormat(widthMM: 297, heightMM: 210)
                                                             : PageFormat(widthMM: 297, heightMM: 420),
                                design: .preset("aquarell"))
        p.dates.schoolStates = [SchoolSelection(state: .BY, color: SchoolSelection.palette[0])]
        store.add(p)
        path.append(p.id)
        #endif
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            PatternLayer(design: .preset("nordlicht"), size: CGSize(width: 900, height: 220),
                         safe: CGRect(x: 0, y: 0, width: 900, height: 220), unit: 4, seed: "start")
                .frame(height: 170)
                .clipped()
            VStack(alignment: .leading, spacing: 6) {
                Text("Dein Kalender, druckfertig.")
                    .font(.system(.title, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                Text("Fotos, Feiertage, Schulferien und persönliche Termine — gestaltet und als PDF für deinen Druckdienst.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.accentColor)
            Text("Noch kein Kalender")
                .font(.title2.weight(.bold))
            Text("Wähle eine Kalenderart, ein Format und eine Stilvorlage — danach kommen deine Fotos dazu.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                showNew = true
            } label: {
                Label("Ersten Kalender anlegen", systemImage: "sparkles")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct ProjectCard: View {
    let project: CalendarProject

    var body: some View {
        let marks = CalendarMarks.build(for: project)
        let pages = project.pages
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Color(.tertiarySystemBackground)
                if let page = pages.first {
                    GeometryReader { geo in
                        let size = ScaledPageView.displaySize(project.format, scale: 1, guides: false)
                        let scale = min(geo.size.width / size.width, geo.size.height / size.height) * 0.9
                        ScaledPageView(project: project, page: page, marks: marks, scale: scale)
                            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(project.kind.title) · \(project.yearText) · \(pages.count) Seiten")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(project.format.summary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }
}
