import SwiftUI

/// Die Tafel selbst: Hintergrund, frei platzierte Elemente und — im
/// Bearbeitungsmodus — Werkzeugleiste und Größengriffe des gewählten Elements.
struct BoardCanvasView: View {
    /// Name des Koordinatensystems für alle Ziehgesten (unskalierte Bildschirmpunkte).
    static let space = "tafel-canvas"

    @EnvironmentObject private var store: BoardStore
    let board: Board

    private var style: BoardStyle { BoardStyle(board: board, editing: store.editing) }

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
            .environment(\.boardStyle, style)
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
                WidgetHostView(boardID: board.id, widget: widget, scale: scale,
                               frames: board.frames)
                    .offset(x: widget.x, y: widget.y)
            }

            // Handschrift liegt über den Elementen, fängt aber nur
            // Berührungen, solange geschrieben wird.
            DrawingLayerView(drawing: drawingBinding, active: store.drawing,
                             pencilOnly: store.pencilOnly)
                .frame(width: Layout.canvas.width, height: Layout.canvas.height)
                .allowsHitTesting(store.drawing)

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

    /// Handschrift immer aus dem Speicher lesen — sonst überschriebe ein
    /// Strich einen Stand, der eben aus iCloud gekommen ist.
    private var drawingBinding: Binding<String> {
        Binding(
            get: { store.board(board.id)?.drawing ?? "" },
            set: { value in
                guard var updated = store.board(board.id), updated.drawing != value else { return }
                updated.drawing = value
                store.updateBoard(updated)
            }
        )
    }
}

// MARK: - Werkzeuge am gewählten Element

private struct SelectionChrome: View {
    @EnvironmentObject private var store: BoardStore
    let boardID: String
    let widget: BoardWidget
    let scale: CGFloat

    @State private var resizeStart: CGRect?

    /// Maßstab als Double — alle Rechnungen laufen in Tafelpunkten.
    private var factor: Double { Double(scale) }

    /// Die vier Ecken bekommen je einen Griff — so lässt sich ein Element
    /// auch nach links oben aufziehen, ohne es vorher zu verschieben.
    private enum Corner: CaseIterable {
        case topLeading, topTrailing, bottomLeading, bottomTrailing

        var symbol: String {
            switch self {
            case .topLeading, .bottomTrailing: return "arrow.up.left.and.arrow.down.right"
            case .topTrailing, .bottomLeading: return "arrow.up.right.and.arrow.down.left"
            }
        }
        var movesX: Bool { self == .topLeading || self == .bottomLeading }
        var movesY: Bool { self == .topLeading || self == .topTrailing }
    }

    var body: some View {
        ZStack {
            toolbar
                .scaleEffect(1 / scale)
                .position(x: toolbarX, y: toolbarY)

            if !widget.locked {
                ForEach(Array(Corner.allCases.enumerated()), id: \.offset) { item in
                    handle(item.element)
                        .scaleEffect(1 / scale)
                        .position(x: cornerX(item.element), y: cornerY(item.element))
                }
            }
        }
        .frame(width: Layout.canvas.width, height: Layout.canvas.height)
    }

    private func cornerX(_ corner: Corner) -> Double {
        corner.movesX ? widget.x : widget.x + widget.width
    }

    private func cornerY(_ corner: Corner) -> Double {
        corner.movesY ? widget.y : widget.y + widget.height
    }

    /// Mittig über dem Element, aber nicht über den Tafelrand hinaus.
    private var toolbarX: Double {
        min(max(widget.x + widget.width / 2, 280), Layout.canvasWidth - 280)
    }

    /// Oberhalb des Elements — außer es klebt am oberen Rand.
    private var toolbarY: Double {
        widget.y > 90 / factor
            ? widget.y - 34 / factor
            : widget.y + widget.height + 34 / factor
    }

    private var toolbar: some View {
        HStack(spacing: 2) {
            button("gearshape.fill", label: "Einstellungen") { store.settingsWidgetID = widget.id }
            // Nur beim Zufallsnamen und nur, solange etwas verdeckt ist —
            // wie das Augensymbol in der Web-App (Fassung 1.5.3).
            if verdeckterName != nil {
                button("eye", label: "Ganz aufdecken", tint: Theme.mint) { alleAufdecken() }
            }
            button("minus.magnifyingglass", label: "Kleiner") { resize(by: 0.88) }
            button("plus.magnifyingglass", label: "Größer") { resize(by: 1.14) }
            button(widget.bare ? "square.dashed" : "square.on.square",
                   label: widget.bare ? "Karte zeigen" : "Karte ausblenden",
                   tint: widget.bare ? Theme.mint : .white) {
                store.updateWidget(widget.id, in: boardID) { $0.bare.toggle() }
            }
            button(widget.locked ? "lock.fill" : "lock.open",
                   label: widget.locked ? "Entsperren" : "Festecken",
                   tint: widget.locked ? Theme.amber : .white) {
                store.updateWidget(widget.id, in: boardID) { $0.locked.toggle() }
            }
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

    /// Der Name, der gerade noch verdeckt ist — sonst nil.
    private var verdeckterName: String? {
        guard case .namePicker(let inhalt) = widget.content,
              let eintragID = inhalt.currentID,
              let liste = store.nameList(inhalt.listID),
              let eintrag = liste.entries.first(where: { $0.id == eintragID }),
              inhalt.istVerdeckt(name: eintrag.text)
        else { return nil }
        return eintrag.text
    }

    private func alleAufdecken() {
        guard case .namePicker(var inhalt) = widget.content, let name = verdeckterName else { return }
        inhalt.alleAufdecken(name: name)
        store.setContent(.namePicker(inhalt), widgetID: widget.id, boardID: boardID)
        Haptics.success()
    }

    /// Stufenloses Vergrößern/Verkleinern um die Mitte des Elements.
    private func resize(by amount: Double) {
        store.updateWidget(widget.id, in: boardID) { item in
            let centerX = item.x + item.width / 2
            let centerY = item.y + item.height / 2
            item.width = min(max(item.width * amount, Layout.minWidth), Layout.canvasWidth)
            item.height = min(max(item.height * amount, Layout.minHeight), Layout.canvasHeight)
            item.x = centerX - item.width / 2
            item.y = centerY - item.height / 2
            item.clampToCanvas()
        }
        Haptics.tap()
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

    private func handle(_ corner: Corner) -> some View {
        Circle()
            .fill(Color.white)
            .overlay {
                Image(systemName: corner.symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .overlay { Circle().strokeBorder(Theme.accent, lineWidth: 2.5) }
            .frame(width: 38, height: 38)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(BoardCanvasView.space))
                    .onChanged { value in
                        if resizeStart == nil { resizeStart = widget.rect }
                        guard let start = resizeStart else { return }
                        let dx = Double(value.translation.width) / factor
                        let dy = Double(value.translation.height) / factor
                        store.updateWidget(widget.id, in: boardID, transient: true) { item in
                            apply(corner: corner, start: start, dx: dx, dy: dy, to: &item)
                        }
                    }
                    .onEnded { _ in
                        resizeStart = nil
                        store.updateWidget(widget.id, in: boardID, transient: true) { item in
                            item.width = (item.width / Layout.grid).rounded() * Layout.grid
                            item.height = (item.height / Layout.grid).rounded() * Layout.grid
                            item.x = (item.x / Layout.grid).rounded() * Layout.grid
                            item.y = (item.y / Layout.grid).rounded() * Layout.grid
                            item.clampToCanvas()
                        }
                        store.commitLayout(boardID: boardID)
                        Haptics.tap()
                    }
            )
    }

    /// Zieht die gewählte Ecke; die gegenüberliegende bleibt liegen.
    private func apply(corner: Corner, start: CGRect, dx: Double, dy: Double,
                       to item: inout BoardWidget) {
        let left = Double(start.minX)
        let top = Double(start.minY)
        let right = Double(start.maxX)
        let bottom = Double(start.maxY)

        if corner.movesX {
            let newLeft = min(left + dx, right - Layout.minWidth)
            item.x = max(0, newLeft)
            item.width = right - item.x
        } else {
            item.x = left
            item.width = max(Layout.minWidth, min(right + dx, Layout.canvasWidth) - left)
        }

        if corner.movesY {
            let newTop = min(top + dy, bottom - Layout.minHeight)
            item.y = max(0, newTop)
            item.height = bottom - item.y
        } else {
            item.y = top
            item.height = max(Layout.minHeight, min(bottom + dy, Layout.canvasHeight) - top)
        }
        item.clampToCanvas()
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
        case .aurora(let id):
            AuroraBackgroundView(preset: AuroraPresets.find(id))
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

    private var style: BoardStyle { BoardStyle(board: board, editing: store.editing) }

    var body: some View {
        ZStack {
            BoardBackgroundView(background: board.background)
                .ignoresSafeArea()

            GeometryReader { geo in
                let width = geo.size.width - 24
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(board.sortedWidgets) { widget in
                            let scale = width / CGFloat(widget.width)
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
                                               scale: scale, frames: board.frames, editable: false)
                                    .frame(width: widget.width, height: widget.height)
                                    .scaleEffect(scale, anchor: .topLeading)
                                    .frame(width: width, height: CGFloat(widget.height) * scale,
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
        .environment(\.boardStyle, style)
    }
}
