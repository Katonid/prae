import SwiftUI

/// Rahmen um ein Element: wählt die passende Darstellung und verbindet sie
/// mit dem Speicher. Im Bearbeitungsmodus liegt über dem Inhalt nur der
/// Auswahlrahmen — Werkzeugleiste und Größengriff zeichnet die Tafel selbst
/// (BoardCanvasView), damit sie nie von einem anderen Element verdeckt werden.
struct WidgetHostView: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.boardStyle) private var style

    let boardID: String
    let widget: BoardWidget
    /// Verkleinerungsfaktor der Tafel — Rahmenstärken bleiben dadurch gleich.
    let scale: CGFloat
    /// Wann ein Rahmen um das Element zu sehen ist (Vorgabe der Tafel).
    var frames: ShowRule = .always
    /// In der Stapelansicht wird nicht verschoben: Dort bleiben die Elemente
    /// immer bedienbar, Einstellungen gibt es über die Kopfzeile.
    var editable: Bool = true

    @State private var dragStart: CGPoint?
    /// Größe zu Beginn der Lupengeste — nil, solange nicht gezogen wird.
    @State private var groesseVorher: CGSize?
    /// Solange zwei Finger die Größe ändern, wird nicht verschoben. SwiftUI
    /// meldet beim Aufziehen nämlich auch eine Ziehbewegung (der Mittelpunkt
    /// beider Finger wandert), und das Element liefe sonst davon.
    @State private var aufziehen = false

    private var editing: Bool { store.editing && editable }
    private var selected: Bool { store.selectedWidgetID == widget.id }

    var body: some View {
        let base = content
            .environment(\.boardStyle, contentStyle)
            .environment(\.widgetMetrics, metrics)
            .frame(width: widget.width, height: widget.height)
            .background { if usesCard { Color.clear.widgetCard(style: style) } }
            // Ohne Karte steht der Inhalt unmittelbar auf dem Hintergrund.
            // Zwei Schatten, die Verschiedenes leisten:
            //
            // 1. Ein enger, dunkler Saum dicht am Zeichen. Er trennt Schrift
            //    von dem, was darunter liegt — auf einem Bild ist das mal
            //    hell, mal dunkel, und weiße Schrift verschwand darauf
            //    stellenweise. Zweimal aufgetragen, weil ein einzelner Saum
            //    auf hellem Grund zu dünn bleibt.
            // 2. Der weiche Fall darunter, der das Element vom Hintergrund
            //    abhebt (Web-App: `.widget--bare` mit
            //    `drop-shadow(0 6px 16px rgba(2,6,23,0.45))`).
            .shadow(color: saum, radius: saumRadius)
            .shadow(color: saum, radius: saumRadius)
            .shadow(color: Color(hex: "#020617").opacity(usesCard ? 0 : 0.45),
                    radius: 16, x: 0, y: 6)
            .allowsHitTesting(!editing)

        if editing {
            base
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.widgetCorner, style: .continuous)
                        .strokeBorder(selectionColor,
                                      style: StrokeStyle(lineWidth: (selected ? 3 : 1.5) / scale,
                                                         dash: selected ? [] : [6 / scale, 5 / scale]))
                }
                .overlay(alignment: .topTrailing) {
                    if widget.locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.amber)
                            .padding(9)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.tap()
                    store.selectedWidgetID = widget.id
                }
                .gesture(moveGesture.simultaneously(with: groessenGeste),
                         including: widget.locked ? .subviews : .all)
        } else {
            base
        }
    }

    /// Farbe des engen Saums um freie Inhalte. Auf einer Karte gibt es ihn
    /// nicht — dort steht die Schrift ohnehin auf ruhigem Grund.
    private var saum: Color {
        guard !usesCard else { return .clear }
        return Color(hex: "#020617").opacity(style.unruhigerGrund ? 0.6 : 0.4)
    }

    /// Hinter einem Bild etwas breiter, damit der Saum auch über hellen
    /// Stellen trägt. Gemessen in Tafelpunkten, also mitwachsend.
    private var saumRadius: Double { style.unruhigerGrund ? 4 : 2.5 }

    /// Festgesteckte Elemente heben sich beim Auswählen bernsteinfarben ab.
    private var selectionColor: Color {
        if selected { return widget.locked ? Theme.amber : Theme.accent }
        return Color.white.opacity(0.35)
    }

    /// Maßstab des Inhalts — wie in der Web-App aus dem Verhältnis von
    /// tatsächlicher zu vorgesehener Größe. Alle Größen im Element sind
    /// Vielfache der Grundschriftgröße, die daraus folgt.
    private var metrics: WidgetMetrics {
        WidgetMetrics.measure(CGSize(width: widget.width, height: widget.height),
                              standard: widget.kind.webSize)
    }

    /// Farben für den Inhalt: Ohne Karte gelten helle Schrift und hellere
    /// Flächen, sonst verschwindet alles auf dem dunklen Hintergrund.
    private var contentStyle: BoardStyle {
        var adjusted = style
        adjusted.bare = !usesCard
        return adjusted
    }

    /// Jedes Element steht auf einer Karte — außer es ist ausdrücklich
    /// rahmenlos gestellt oder die Tafel blendet die Rahmen gerade aus.
    /// (In der Web-App gilt genau diese Regel: `.widget` trägt die Karte,
    /// `.widget--bare` nimmt sie weg — auch bei Text und Bild.)
    private var usesCard: Bool {
        if widget.bare { return false }
        return frames.applies(editing: store.editing)
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
            TextWidgetView(content: bindText(value), interactive: !editing)
        case .image(let value):
            ImageWidgetView(content: value, onChoose: { store.settingsWidgetID = widget.id })
        case .sounds(let value):
            SoundsWidgetView(content: value, interactive: !editing,
                             onOpenSettings: { store.settingsWidgetID = widget.id })
        case .symbols(let value):
            SymbolWidgetView(content: bindSymbol(value), interactive: !editing)
        case .video(let value):
            VideoWidgetView(content: value, interactive: !editing,
                            onOpenSettings: { store.settingsWidgetID = widget.id })
        case .kamera(let value):
            KameraWidgetView(content: bindKamera(value), interactive: !editing,
                             onAblegen: { datei in
                                 store.legeBildAb(datei: datei, boardID: boardID)
                             },
                             onSichern: { daten in
                                 store.saveMedia(data: daten, fileExtension: "jpg")
                             })
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
                guard !aufziehen, let start = dragStart else { return }
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

    // MARK: - Größe mit zwei Fingern

    /// Aufziehen ändert die Größe — genau wie in der Web-App („mit zwei
    /// Fingern auf dem Element auseinanderziehen“). Das Element wächst um
    /// seine Mitte, das Seitenverhältnis bleibt.
    ///
    /// Am Telefon ist das der Hauptweg: Dort sind die Eck-Anfasser oft
    /// größer als das Element selbst und erscheinen erst, wenn genug Platz
    /// da ist (siehe BoardCanvasView).
    private var groessenGeste: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { wert in
                if groesseVorher == nil {
                    groesseVorher = CGSize(width: widget.width, height: widget.height)
                    store.selectedWidgetID = widget.id
                }
                guard let start = groesseVorher else { return }
                aufziehen = true
                let faktor = max(0.1, min(8, Double(wert.magnification)))
                store.updateWidget(widget.id, in: boardID, transient: true) { item in
                    let mitteX = item.x + item.width / 2
                    let mitteY = item.y + item.height / 2
                    item.width = spanne(Double(start.width) * faktor,
                                        klein: Layout.minWidth, gross: Layout.canvasWidth)
                    item.height = spanne(Double(start.height) * faktor,
                                         klein: Layout.minHeight, gross: Layout.canvasHeight)
                    item.x = mitteX - item.width / 2
                    item.y = mitteY - item.height / 2
                    item.clampToCanvas()
                }
            }
            .onEnded { _ in
                groesseVorher = nil
                aufziehen = false
                // Der Zug, der nebenher mitlief, darf jetzt nichts mehr
                // nachschieben — sonst springt das Element beim Loslassen.
                dragStart = nil
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
    }

    private func spanne(_ wert: Double, klein: Double, gross: Double) -> Double {
        max(klein, min(wert, gross))
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

    private func bindText(_ fallback: TextContent) -> Binding<TextContent> {
        Binding(
            get: {
                if case .text(let value)? = store.widget(widget.id, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.text($0), widgetID: widget.id, boardID: boardID) }
        )
    }

    private func bindSymbol(_ fallback: SymbolContent) -> Binding<SymbolContent> {
        Binding(
            get: {
                if case .symbols(let value)? = store.widget(widget.id, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.symbols($0), widgetID: widget.id, boardID: boardID) }
        )
    }

    private func bindKamera(_ fallback: KameraContent) -> Binding<KameraContent> {
        Binding(
            get: {
                if case .kamera(let value)? = store.widget(widget.id, in: boardID)?.content { return value }
                return fallback
            },
            set: { store.setContent(.kamera($0), widgetID: widget.id, boardID: boardID) }
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
