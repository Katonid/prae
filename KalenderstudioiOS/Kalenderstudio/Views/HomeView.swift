import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var path: [UUID] = []
    @State private var showNew = false
    @State private var renaming: CalendarProject?
    @State private var newName = ""
    @State private var deleting: CalendarProject?
    @State private var showSettings = false
    @State private var backupFile: URL?
    @State private var backupError: String?

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
                                .contextMenu { cardActions(project) }
                                // Sichtbar statt nur per langem Drücken (Ansage des
                                // Nutzers, 1.0.13: „ein Projekt duplizieren“ wurde
                                // nicht gefunden).
                                .overlay(alignment: .topTrailing) {
                                    Menu {
                                        cardActions(project)
                                    } label: {
                                        Image(systemName: "ellipsis.circle.fill")
                                            .font(.system(size: 28))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, Color.black.opacity(0.45))
                                            .padding(14)
                                    }
                                    .accessibilityLabel("Aktionen für \(project.name)")
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Einstellungen", systemImage: store.cloudActive ? "checkmark.icloud" : "gearshape")
                    }
                }
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
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: Binding(get: { backupFile.map(SharedFile.init) }, set: { if $0 == nil { backupFile = nil } })) { f in
                ShareSheet(items: [f.url]).ignoresSafeArea()
            }
            .alert("Sichern fehlgeschlagen", isPresented: Binding(get: { backupError != nil }, set: { if !$0 { backupError = nil } })) {
                Button("OK", role: .cancel) { backupError = nil }
            } message: {
                Text(backupError ?? "")
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

    @ViewBuilder
    private func cardActions(_ project: CalendarProject) -> some View {
        Button {
            newName = project.name
            renaming = project
        } label: { Label("Umbenennen", systemImage: "pencil") }
        Button {
            store.duplicate(project)
        } label: { Label("Duplizieren", systemImage: "plus.square.on.square") }
        Button {
            do {
                backupFile = try Backup.write([project], title: project.name).url
            } catch {
                backupError = error.localizedDescription
            }
        } label: { Label("Als Datei sichern", systemImage: "externaldrive.badge.plus") }
        Button(role: .destructive) {
            deleting = project
        } label: { Label("Löschen", systemImage: "trash") }
    }

    /// Nur für den Simulator-Arbeitsablauf: `-probe=year|week|doubleMonth`,
    /// wahlweise mit Kalendarium, Stilvorlage und Fotoanteil
    /// (`-probe=year:strip:leinen`, `-probe=year:classic:aquarell:0.78`),
    /// legt einen Kalender an und öffnet ihn sofort — so lässt sich der
    /// Editor ohne Antippen prüfen. Mit Kalendarium entfällt das Titelblatt,
    /// damit gleich ein Monat zu sehen ist.
    private func probeIfRequested() {
        #if DEBUG
        guard let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-probe=") }),
              path.isEmpty else { return }
        let parts = arg.dropFirst("-probe=".count).split(separator: ":").map(String.init)
        // „half“ = Jahreskalender als Halbmonat (beidseitig).
        guard let first = parts.first, let kind = first == "half" ? CalendarKind.year : CalendarKind(rawValue: first) else { return }
        var p = CalendarProject(name: "Probe", kind: kind, year: 2027,
                                format: kind == .doubleMonth ? PageFormat(widthMM: 297, heightMM: 210)
                                                             : PageFormat(widthMM: 297, heightMM: 420),
                                design: .preset(parts.count > 2 ? parts[2] : "aquarell"))
        if first == "half" { p.yearLayout = .halfMonth }
        if parts.count > 1, let layout = MonthGridLayout(rawValue: parts[1]) {
            p.gridLayout = layout
            p.hasCover = false
            p.startMonth = 5
        }
        if parts.count > 3, let share = Double(parts[3]), share > 0 { p.photoShare = share }
        // Fünfter Teil: ein Testfoto (Panorama 3 : 1, passt absichtlich nicht
        // in die Fläche) — „ganz“ zeigt es ganz mit weichem Hintergrund,
        // „farbe“ mit Farbe, „fuellen“ füllend. Sechster Teil „lupe“ öffnet
        // danach die Seitenprüfung (siehe EditorView).
        if parts.count > 4, let item = Self.probePhoto() {
            p.photos = [item]
            var pl = PhotoPlacement(photoID: item.id)
            pl.fit = parts[4] == "ganz" ? .blurBackdrop : (parts[4] == "farbe" ? .colorBackdrop : .fill)
            for i in 0..<12 { p.placements["m\(i)"] = [pl] }
            PhotoInfo.register(p.photos)
        }
        p.dates.schoolStates = [SchoolSelection(state: .BY, color: SchoolSelection.palette[0])]
        store.add(p)
        // „…:sicherung“: sichern, wieder einladen, Ergebnis ins Protokoll.
        if arg.hasSuffix(":sicherung") {
            do {
                let w = try Backup.write(store.projects, title: "Probe")
                let size = (try? FileManager.default.attributesOfItem(atPath: w.url.path))?[.size] as? NSNumber
                let r = try Backup.restore(from: w.url, into: store)
                NSLog("Sicherungsprobe: \(w.projects) Kalender, \(w.photos) Fotos, \(size?.intValue ?? 0) Byte; geladen: \(r.text)")
            } catch {
                NSLog("Sicherungsprobe FEHLER: \(error.localizedDescription)")
            }
        }
        path.append(p.id)
        #endif
    }

    #if DEBUG
    /// Ein gezeichnetes Panorama: Himmel, Sonne, Berge — bunt genug für
    /// „Farbe des Monats“ und für den weichen Hintergrund.
    static func probePhoto() -> PhotoItem? {
        let size = CGSize(width: 3600, height: 1200)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let colors = [UIColor(red: 0.98, green: 0.62, blue: 0.35, alpha: 1).cgColor,
                          UIColor(red: 0.35, green: 0.45, blue: 0.85, alpha: 1).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                c.drawLinearGradient(g, start: CGPoint(x: 0, y: size.height), end: .zero, options: [])
            }
            UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1).setFill()
            c.fillEllipse(in: CGRect(x: 2500, y: 250, width: 360, height: 360))
            UIColor(red: 0.18, green: 0.32, blue: 0.3, alpha: 1).setFill()
            let m = UIBezierPath()
            m.move(to: CGPoint(x: 0, y: size.height))
            for (i, y) in [700.0, 420, 820, 360, 760, 520, 880, 600].enumerated() {
                m.addLine(to: CGPoint(x: Double(i) * 520, y: y))
            }
            m.addLine(to: CGPoint(x: size.width, y: 700))
            m.addLine(to: CGPoint(x: size.width, y: size.height))
            m.close()
            m.fill()
        }
        guard let data = img.jpegData(compressionQuality: 0.9) else { return nil }
        return try? ImageStore.shared.importImage(data: data)
    }
    #endif

    /// Das Muster liegt als HINTERGRUND und bestimmt die Breite nicht mit —
    /// sonst ragte das Band auf dem iPhone über den Rand und schob die
    /// Karten aus dem Bild (1.0.9).
    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 6) {
                Text("Dein Kalender, druckfertig.")
                    .font(.system(.title, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                Text("Fotos, Feiertage, Schulferien und persönliche Termine — gestaltet und als PDF für deinen Druckdienst.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .bottomLeading)
        .background {
            // Das Muster wird in der Größe des Bandes gezeichnet: Eine feste
            // Breite machte das Band auf dem iPad nur 900 pt breit.
            GeometryReader { geo in
                PatternLayer(design: .preset("nordlicht"), size: geo.size,
                             safe: CGRect(origin: .zero, size: geo.size), unit: 4, seed: "start")
            }
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
