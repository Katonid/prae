import SwiftUI

struct PhotoTarget: Identifiable, Equatable {
    let key: String
    let index: Int
    var id: String { "\(key)#\(index)" }
}

enum PanelTab: String, CaseIterable, Identifiable {
    case layout, style, photos, dates, format
    var id: String { rawValue }
    var title: String {
        switch self {
        case .layout: return "Aufbau"
        case .style: return "Stil"
        case .photos: return "Fotos"
        case .dates: return "Termine"
        case .format: return "Format"
        }
    }
    var symbol: String {
        switch self {
        case .layout: return "square.grid.2x2"
        case .style: return "paintpalette"
        case .photos: return "photo.on.rectangle.angled"
        case .dates: return "calendar.badge.clock"
        case .format: return "ruler"
        }
    }
}

struct EditorView: View {
    @Binding var project: CalendarProject
    @EnvironmentObject private var store: ProjectStore
    @ObservedObject private var school = SchoolHolidayService.shared
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var spread = 0
    @State private var showInspector = false
    @State private var tab: PanelTab = .layout
    @State private var showGuides = false
    @State private var photoTarget: PhotoTarget?
    @State private var showExport = false

    var body: some View {
        let marks = CalendarMarks.build(for: project)
        let spreads = groupedSpreads
        VStack(spacing: 0) {
            canvas(marks: marks, spreads: spreads)
            thumbnails(marks: marks, spreads: spreads)
        }
        .background(StudioBackdrop())
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showGuides.toggle()
                } label: {
                    Label("Hilfslinien", systemImage: showGuides ? "viewfinder.circle.fill" : "viewfinder")
                }
                .help("Beschnitt und Sicherheitsabstand zeigen")
                Button {
                    showExport = true
                } label: {
                    Label("Exportieren", systemImage: "square.and.arrow.up")
                }
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Gestalten", systemImage: "slider.horizontal.3")
                }
            }
        }
        .inspector(isPresented: $showInspector) {
            InspectorPanel(project: $project, tab: $tab, onEditPhoto: { target in
                photoTarget = target
            })
            .inspectorColumnWidth(min: 330, ideal: 390, max: 520)
            .presentationDetents([.fraction(0.5), .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.5)))
        }
        .sheet(item: $photoTarget) { target in
            PhotoEditSheet(project: $project, target: target)
        }
        .sheet(isPresented: $showExport) {
            ExportSheet(project: project)
        }
        .onAppear {
            PhotoInfo.register(project.photos)
            if sizeClass == .regular { showInspector = true }
            let years = Array(project.yearRange)
            if years.contains(where: { !school.covers(year: $0) }) {
                Task { await school.refresh(years: years) }
            }
        }
        .onChange(of: project.photos) { _, photos in
            PhotoInfo.register(photos)
        }
        .onChange(of: spreads.count) { _, count in
            if spread >= count { spread = max(count - 1, 0) }
        }
    }

    private var groupedSpreads: [[PageSpec]] {
        var result: [[PageSpec]] = []
        for page in project.pages {
            if let last = result.last, last.first?.spread == page.spread {
                result[result.count - 1].append(page)
            } else {
                result.append([page])
            }
        }
        return result
    }

    // MARK: Arbeitsfläche

    private func canvas(marks: CalendarMarks, spreads: [[PageSpec]]) -> some View {
        GeometryReader { geo in
            TabView(selection: $spread) {
                ForEach(spreads.indices, id: \.self) { i in
                    spreadView(spreads[i], marks: marks, available: geo.size)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .environment(\.photoTap, { key, index in
                photoTarget = PhotoTarget(key: key, index: index)
            })
            .overlay(alignment: .bottom) {
                if project.photos.isEmpty {
                    Button {
                        tab = .photos
                        showInspector = true
                    } label: {
                        Label("Fotos hinzufügen", systemImage: "photo.badge.plus")
                            .font(.headline)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(.bottom, 14)
                }
            }
        }
    }

    private func spreadView(_ pages: [PageSpec], marks: CalendarMarks, available: CGSize) -> some View {
        let one = ScaledPageView.displaySize(project.format, scale: 1, guides: showGuides)
        let gap: CGFloat = pages.count > 1 ? 26 : 0
        let totalH = one.height * CGFloat(pages.count)
        let fit = min((available.width - 40) / one.width, (available.height - 40 - gap) / max(totalH, 1))
        let scale = max(fit, 0.05)
        return VStack(spacing: gap) {
            ForEach(pages) { page in
                ScaledPageView(project: project, page: page, marks: marks, scale: scale, showGuides: showGuides)
                    .shadow(color: .black.opacity(0.55), radius: 18, y: 10)
            }
        }
        .overlay {
            if pages.count > 1 {
                SpiralBinding(width: one.width * scale)
            }
        }
        .frame(width: available.width, height: available.height)
    }

    private func thumbnails(marks: CalendarMarks, spreads: [[PageSpec]]) -> some View {
        let one = ScaledPageView.displaySize(project.format, scale: 1, guides: false)
        let height: CGFloat = sizeClass == .regular ? 74 : 56
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(spreads.indices, id: \.self) { i in
                        let pages = spreads[i]
                        let scale = height / (one.height * CGFloat(pages.count))
                        Button {
                            withAnimation(.snappy) { spread = i }
                        } label: {
                            VStack(spacing: 4) {
                                VStack(spacing: 1) {
                                    ForEach(pages) { page in
                                        ScaledPageView(project: project, page: page, marks: marks, scale: scale)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .overlay(RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(spread == i ? Color.accentColor : Color.white.opacity(0.15),
                                                  lineWidth: spread == i ? 2.5 : 1))
                                Text(thumbLabel(pages))
                                    .font(.caption2.weight(spread == i ? .bold : .regular))
                                    .foregroundStyle(spread == i ? Color.white : Color.white.opacity(0.6))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .allowsHitTesting(true)
                        .environment(\.photoTap, nil)
                        .id(i)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(height: height + 38)
            .background(.ultraThinMaterial.opacity(0.6))
            .environment(\.colorScheme, .dark)
            .onChange(of: spread) { _, neu in
                withAnimation { proxy.scrollTo(neu, anchor: .center) }
            }
        }
    }

    private func thumbLabel(_ pages: [PageSpec]) -> String {
        guard let first = pages.first else { return "" }
        if pages.count > 1, let r = first.label.range(of: " · ") {
            return String(first.label[..<r.lowerBound])
        }
        return first.label
    }
}
