import SwiftUI

/// Ein Poster bearbeiten: Ausschnitt ziehen und zoomen, drehen, ganzes Bild
/// mit Hintergrundfarbe. Die gestrichelte rote Linie ist die Schnittkante —
/// was außerhalb liegt, fällt beim Schneiden weg.
struct PosterEditSheet: View {
    @Binding var project: PosterProject
    @State var itemID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var dragStart: PosterItem?
    @State private var pinchStart: Double?
    @State private var showGuides = true

    private var index: Int? { project.items.firstIndex(where: { $0.id == itemID }) }

    private var item: PosterItem? { index.map { project.items[$0] } }

    private func change(_ edit: (inout PosterItem) -> Void) {
        guard let i = index else { return }
        edit(&project.items[i])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let item {
                    preview(item)
                        .frame(maxHeight: .infinity)
                        .background(StudioBackdrop())
                    controls(item)
                } else {
                    Text("Dieses Poster ist nicht mehr da.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(index.map { "Poster \($0 + 1) von \(project.items.count)" } ?? "Poster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.bold)
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        step(-1)
                    } label: { Image(systemName: "chevron.left") }
                    .disabled((index ?? 0) == 0)
                    Button {
                        step(1)
                    } label: { Image(systemName: "chevron.right") }
                    .disabled((index ?? 0) >= project.items.count - 1)
                }
            }
        }
    }

    private func step(_ d: Int) {
        guard let i = index else { return }
        let n = i + d
        guard project.items.indices.contains(n) else { return }
        itemID = project.items[n].id
    }

    // MARK: - Vorschau

    private func preview(_ item: PosterItem) -> some View {
        GeometryReader { geo in
            let g = PageGeometry(format: project.format, item: item)
            let scale = min((geo.size.width - 40) / g.size.width, (geo.size.height - 70) / g.size.height)
            PosterPageView(format: project.format, item: item, scale: max(scale, 0.01), guides: showGuides)
                .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(dragGesture(scale: max(scale, 0.01)).simultaneously(with: pinchGesture))
                .overlay(alignment: .top) {
                    Text("Ziehen verschiebt · zwei Finger zoomen")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.black.opacity(0.5)))
                        .foregroundStyle(.white)
                        .padding(.top, 8)
                }
                .overlay(alignment: .bottom) {
                    HStack(spacing: 14) {
                        legend(color: .red, text: "Schnittkante")
                        if project.format.safetyMM > 0 {
                            legend(color: .blue, text: "Sicherheitsabstand")
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.black.opacity(0.5)))
                    .padding(.bottom, 8)
                    .opacity(showGuides ? 1 : 0)
                }
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 4))
                p.addLine(to: CGPoint(x: 22, y: 4))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
            .frame(width: 22, height: 8)
            Text(text)
        }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pinchStart == nil { pinchStart = item?.zoom ?? 1 }
                guard let start = pinchStart, let fit = item?.fit else { return }
                let r = PosterLayout.zoomRange(fit)
                let z = min(max(start * Double(value.magnification), r.lowerBound), r.upperBound)
                change { $0.zoom = z }
            }
            .onEnded { _ in pinchStart = nil }
    }

    private func dragGesture(scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragStart == nil { dragStart = item }
                guard let start = dragStart else { return }
                let g = PageGeometry(format: project.format, item: start)
                let r = PosterLayout.imageRect(item: start, geometry: g)
                let frame = start.fit == .fill ? g.fullRect : g.trimRect
                let slackX = abs(r.width - frame.width) / 2 * scale
                let slackY = abs(r.height - frame.height) / 2 * scale
                change {
                    if slackX > 0.5 {
                        $0.offsetX = min(max(start.offsetX + Double(value.translation.width / slackX), -1), 1)
                    }
                    if slackY > 0.5 {
                        $0.offsetY = min(max(start.offsetY + Double(value.translation.height / slackY), -1), 1)
                    }
                }
            }
            .onEnded { _ in dragStart = nil }
    }

    // MARK: - Bedienung

    private func controls(_ item: PosterItem) -> some View {
        let g = PageGeometry(format: project.format, item: item)
        let dpi = PosterLayout.effectiveDPI(item: item, geometry: g)
        return VStack(alignment: .leading, spacing: 12) {
            Picker("Darstellung", selection: Binding(
                get: { item.fit },
                set: { f in change { $0.fit = f; $0.zoom = 1; $0.offsetX = 0; $0.offsetY = 0 } }
            )) {
                ForEach(PosterFit.allCases) { f in
                    Label(f.title, systemImage: f.symbol).tag(f)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Image(systemName: "minus.magnifyingglass")
                Slider(value: Binding(get: { PosterLayout.clampedZoom(item) },
                                      set: { z in change { $0.zoom = z } }),
                       in: PosterLayout.zoomRange(item.fit))
                Image(systemName: "plus.magnifyingglass")
            }

            HStack(spacing: 12) {
                Button {
                    change { $0.quarterTurns = ($0.quarterTurns + 1) % 4; $0.offsetX = 0; $0.offsetY = 0 }
                } label: {
                    Label("Drehen", systemImage: "rotate.right")
                }
                Button {
                    change { $0.zoom = 1; $0.offsetX = 0; $0.offsetY = 0 }
                } label: {
                    Label("Zurücksetzen", systemImage: "arrow.uturn.backward")
                }
                if item.fit == .fit {
                    ColorPicker("Hintergrund", selection: Binding(
                        get: { item.background.color },
                        set: { c in change { $0.background = RGBA(c) } }
                    ), supportsOpacity: false)
                    .fixedSize()
                }
                Spacer()
                Toggle(isOn: $showGuides) {
                    Image(systemName: "rectangle.dashed")
                }
                .toggleStyle(.button)
                .accessibilityLabel("Beschnitt zeigen")
            }
            .buttonStyle(.bordered)

            HStack(spacing: 8) {
                DPIBadge(dpi: dpi)
                Text(qualityText(dpi: dpi, item: item, g: g))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    private func qualityText(dpi: Double, item: PosterItem, g: PageGeometry) -> String {
        let px = "\(item.pixelWidth) × \(item.pixelHeight) px"
        let format = "Endformat \(g.trimMM.w.mmText) × \(g.trimMM.h.mmText) mm"
        switch PosterLayout.quality(dpi: dpi) {
        case .good: return "\(px) — gute Auflösung für \(format)."
        case .ok: return "\(px) — für ein Poster mit Betrachtungsabstand noch brauchbar."
        case .low: return "\(px) — wirkt im Druck weich. Weniger zoomen oder ein größeres Bild verwenden."
        }
    }
}
