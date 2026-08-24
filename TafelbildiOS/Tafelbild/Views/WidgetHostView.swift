import SwiftUI

/// Rahmen um ein Element: wählt die passende Darstellung und verbindet sie
/// mit dem Speicher. Im Bearbeitungsmodus liegt über dem Inhalt nur der
/// Auswahlrahmen — Werkzeugleiste und Größengriff zeichnet die Tafel selbst
/// (BoardCanvasView), damit sie nie von einem anderen Element verdeckt werden.
struct WidgetHostView: View {
    @EnvironmentObject private var store: BoardStore

    let boardID: String
    let widget: BoardWidget
    /// Verkleinerungsfaktor der Tafel — Rahmenstärken bleiben dadurch gleich.
    let scale: CGFloat
    /// In der Stapelansicht wird nicht verschoben: Dort bleiben die Elemente
    /// immer bedienbar, Einstellungen gibt es über die Kopfzeile.
    var editable: Bool = true

    @State private var dragStart: CGPoint?

    private var editing: Bool { store.editing && editable }
    private var selected: Bool { store.selectedWidgetID == widget.id }

    var body: some View {
        let base = content
            .frame(width: widget.width, height: widget.height)
            .background { if usesCard { Color.clear.widgetCard() } }
            .allowsHitTesting(!editing)

        if editing {
            base
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.widgetCorner, style: .continuous)
                        .strokeBorder(selected ? Theme.accent : Color.white.opacity(0.35),
                                      style: StrokeStyle(lineWidth: (selected ? 3 : 1.5) / scale,
                                                         dash: selected ? [] : [6 / scale, 5 / scale]))
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.tap()
                    store.selectedWidgetID = widget.id
                }
                .gesture(moveGesture)
        } else {
            base
        }
    }

    /// Text und Bild bringen ihren eigenen Hintergrund mit.
    private var usesCard: Bool {
        switch widget.content {
        case .text, .image: return false
        default: return true
        }
    }

    // MARK: - Inhalt

    @ViewBuilder
    private var content: some View {
        switch widget.content {
        case .namePicker(let value):
            NamePickerWidgetView(
                content: bindNamePicker(value),
                interactive: !editing,
                list: store.nameList(value.listID),
                onOpenSettings: { store.settingsWidgetID = widget.id },
                onDeleteEntry: { entry in
                    guard var list = store.nameList(value.listID) else { return }
                    list.entries.removeAll { $0.id == entry.id }
                    store.updateNameList(list)
                }
            )
        case .timer(let value):
            TimerWidgetView(content: bindTimer(value), interactive: !editing)
        case .clock(let value):
            ClockWidgetView(content: value)
        case .trafficLight(let value):
            TrafficLightWidgetView(content: bindTrafficLight(value), interactive: !editing)
        case .noise(let value):
            NoiseWidgetView(content: value, interactive: !editing)
        case .checklist(let value):
            ChecklistWidgetView(content: bindChecklist(value), interactive: !editing)
        case .text(let value):
            TextWidgetView(content: value)
        case .image(let value):
            ImageWidgetView(content: value, onChoose: { store.settingsWidgetID = widget.id })
        case .sounds(let value):
            SoundsWidgetView(content: value, interactive: !editing,
                             onOpenSettings: { store.settingsWidgetID = widget.id })
        }
    }

    // MARK: - Verschieben

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(BoardCanvasView.space))
            .onChanged { value in
                if dragStart == nil {
                    dragStart = CGPoint(x: widget.x, y: widget.y)
                    store.selectedWidgetID = widget.id
                }
                guard let start = dragStart else { return }
                let factor = Double(scale)
                let dx = Double(value.translation.width) / factor
                let dy = Double(value.translation.height) / factor
                store.updateWidget(widget.id, in: boardID, transient: true) { moved in
                    moved.x = Double(start.x) + dx
                    moved.y = Double(start.y) + dy
                    moved.clampToCanvas()
                }
            }
            .onEnded { _ in
                dragStart = nil
                store.updateWidget(widget.id, in: boardID, transient: true) { moved in
                    moved.x = (moved.x / Layout.grid).rounded() * Layout.grid
                    moved.y = (moved.y / Layout.grid).rounded() * Layout.grid
                    moved.clampToCanvas()
                }
                store.commitLayout(boardID: boardID)
                Haptics.tap()
            }
    }

    // MARK: - Bindungen zum Speicher

    private func bindNamePicker(_ fallback: NamePickerContent) -> Binding<NamePickerContent> {
        Binding(
            get: {
                if case .namePicker(let value)? = store.widget(widget.id, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.namePicker($0), widgetID: widget.id, boardID: boardID) }
        )
    }

    private func bindTimer(_ fallback: TimerContent) -> Binding<TimerContent> {
        Binding(
            get: {
                if case .timer(let value)? = store.widget(widget.id, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.timer($0), widgetID: widget.id, boardID: boardID) }
        )
    }

    private func bindTrafficLight(_ fallback: TrafficLightContent) -> Binding<TrafficLightContent> {
        Binding(
            get: {
                if case .trafficLight(let value)? = store.widget(widget.id, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.trafficLight($0), widgetID: widget.id, boardID: boardID) }
        )
    }

    private func bindChecklist(_ fallback: ChecklistContent) -> Binding<ChecklistContent> {
        Binding(
            get: {
                if case .checklist(let value)? = store.widget(widget.id, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.checklist($0), widgetID: widget.id, boardID: boardID) }
        )
    }
}
