import SwiftUI

/// Die Tafel selbst: Hintergrund, frei platzierte Elemente und — im
/// Bearbeitungsmodus — Werkzeugleiste und Größengriff des gewählten Elements.
struct BoardCanvasView: View {
    /// Name des Koordinatensystems für alle Ziehgesten (unskalierte Bildschirmpunkte).
    static let space = "tafel-canvas"

    @EnvironmentObject private var store: BoardStore
    let board: Board

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / Layout.canvas.width,
                            geo.size.height / Layout.canvas.height)
            ZStack {
                BoardBackgroundView(background: board.background)
                    .ignoresSafeArea()

                canvas(scale: scale)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .onTapGesture {
                if store.editing { store.selectedWidgetID = nil }
            }
            .coordinateSpace(name: Self.space)
        }
    }

    private func canvas(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Arbeitsfläche im Bearbeitungsmodus sichtbar machen.
            if store.editing {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18),
                                  style: StrokeStyle(lineWidth: 2 / scale, dash: [10 / scale, 8 / scale]))
                    .frame(width: Layout.canvas.width, height: Layout.canvas.height)
            }

            ForEach(board.sortedWidgets) { widget in
                WidgetHostView(boardID: board.id, widget: widget, scale: scale)
                    .offset(x: widget.x, y: widget.y)
            }

            if store.editing, let selected = selectedWidget {
                SelectionChrome(boardID: board.id, widget: selected, scale: scale)
            }
        }
        .frame(width: Layout.canvas.width, height: Layout.canvas.height, alignment: .topLeading)
        .scaleEffect(scale)
        .frame(width: Layout.canvas.width * scale, height: Layout.canvas.height * scale)
    }

    private var selectedWidget: BoardWidget? {
        guard let id = store.selectedWidgetID else { return nil }
        return board.widgets.first { $0.id == id }
    }
}

// MARK: - Werkzeuge am gewählten Element

private struct SelectionChrome: View {
    @EnvironmentObject private var store: BoardStore
    let boardID: String
    let widget: BoardWidget
    let scale: CGFloat

    @State private var resizeStart: CGSize?

    var body: some View {
        ZStack {
            toolbar
                .scaleEffect(1 / scale)
                .position(x: min(max(widget.x + widget.width / 2, 200), Layout.canvas.width - 200),
                          y: toolbarY)

            handle
                .scaleEffect(1 / scale)
                .position(x: widget.x + widget.width, y: widget.y + widget.height)
        }
        .frame(width: Layout.canvas.width, height: Layout.canvas.height)
    }

    /// Oberhalb des Elements — außer es klebt am oberen Rand.
    private var toolbarY: Double {
        widget.y > 90 / scale ? widget.y - 34 / scale : widget.y + widget.height + 34 / scale
    }

    private var toolbar: some View {
        HStack(spacing: 2) {
            button("gearshape.fill", label: "Einstellungen") { store.settingsWidgetID = widget.id }
            button("plus.square.on.square", label: "Duplizieren") {
                store.duplicateWidget(widget.id, in: boardID)
            }
            Menu {
                Button {
                    store.bringToFront(widget.id, in: boardID)
                } label: {
                    Label("Nach vorn", systemImage: "square.3.layers.3d.top.filled")
                }
                Button {
                    store.sendToBack(widget.id, in: boardID)
                } label: {
                    Label("Nach hinten", systemImage: "square.3.layers.3d.bottom.filled")
                }
                Button {
                    store.updateWidget(widget.id, in: boardID) { item in
                        item.width = item.kind.defaultSize.width
                        item.height = item.kind.defaultSize.height
                        item.clampToCanvas()
                    }
                } label: {
                    Label("Standardgröße", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            } label: {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
            button("trash.fill", label: "Löschen", tint: Theme.danger) {
                store.removeWidget(widget.id, from: boardID)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 46)
        .chromeBar(corner: 23)
        .fixedSize()
    }

    private func button(_ symbol: String, label: String, tint: Color = .white,
                        action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var handle: some View {
        Circle()
            .fill(Theme.accent)
            .overlay {
                Image(systemName: "arrow.down.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(BoardCanvasView.space))
                    .onChanged { value in
                        if resizeStart == nil {
                            resizeStart = CGSize(width: widget.width, height: widget.height)
                        }
                        guard let start = resizeStart else { return }
                        store.updateWidget(widget.id, in: boardID, transient: true) { item in
                            item.width = start.width + value.translation.width / scale
                            item.height = start.height + value.translation.height / scale
                            item.clampToCanvas()
                        }
                    }
                    .onEnded { _ in
                        resizeStart = nil
                        store.updateWidget(widget.id, in: boardID, transient: true) { item in
                            item.width = (item.width / Layout.grid).rounded() * Layout.grid
                            item.height = (item.height / Layout.grid).rounded() * Layout.grid
                            item.clampToCanvas()
                        }
                        store.commitLayout(boardID: boardID)
                        Haptics.tap()
                    }
            )
    }
}

// MARK: - Hintergrund

struct BoardBackgroundView: View {
    let background: BoardBackground

    var body: some View {
        switch background {
        case .solid(let hex):
            Color(hex: hex)
        case .gradient(let from, let to):
            LinearGradient(colors: [Color(hex: from), Color(hex: to)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .image(let fileName, let dim):
            ZStack {
                Color(hex: "#0b1020")
                if let image = MediaCache.shared.image(fileName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                Color.black.opacity(dim)
            }
        }
    }
}

// MARK: - Stapelansicht (iPhone)

/// Auf schmalen Geräten stehen die Elemente untereinander in voller Breite —
/// so bleibt alles bedienbar, ohne auf der Tafel zu zoomen.
struct BoardStackView: View {
    @EnvironmentObject private var store: BoardStore
    let board: Board

    var body: some View {
        ZStack {
            BoardBackgroundView(background: board.background)
                .ignoresSafeArea()

            GeometryReader { geo in
                let width = geo.size.width - 24
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(board.sortedWidgets) { widget in
                            let scale = width / widget.width
                            VStack(spacing: 6) {
                                if store.editing {
                                    HStack(spacing: 10) {
                                        Text(widget.kind.title)
                                            .font(Theme.font(15, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.7))
                                        Spacer()
                                        Button {
                                            store.settingsWidgetID = widget.id
                                        } label: {
                                            Image(systemName: "gearshape.fill")
                                        }
                                        Button(role: .destructive) {
                                            store.removeWidget(widget.id, from: board.id)
                                        } label: {
                                            Image(systemName: "trash.fill")
                                        }
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                }

                                WidgetHostView(boardID: board.id, widget: widget,
                                               scale: scale, editable: false)
                                    .frame(width: widget.width, height: widget.height)
                                    .scaleEffect(scale, anchor: .topLeading)
                                    .frame(width: width, height: widget.height * scale,
                                           alignment: .topLeading)
                            }
                        }
                    }
                    .padding(12)
                    .padding(.top, 70)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}
