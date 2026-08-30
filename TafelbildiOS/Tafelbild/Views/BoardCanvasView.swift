import SwiftUI

/// Die Tafel selbst: Hintergrund, frei platzierte Elemente und — im
/// Bearbeitungsmodus — Werkzeugleiste und Größengriffe des gewählten Elements.
struct BoardCanvasView: View {
    /// Name des Koordinatensystems für alle Ziehgesten (unskalierte Bildschirmpunkte).
    static let space = "tafel-canvas"

    @EnvironmentObject private var store: BoardStore
    let board: Board

    /// Ansicht der Tafel: 1 = ganze Tafel im Bild, größer = hineingezoomt.
    /// Am Telefon ist das der Weg, überhaupt etwas erkennen zu können — die
    /// Tafel ist 1600 Punkte breit. Die Werte bleiben gespeichert, wie im Web.
    /// Schmaler Bildschirm = Telefon. Die Web-App zieht die Grenze bei
    /// 560 Pixeln; unter iOS ist die Größenklasse das Gegenstück.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage("boardZoom") private var zoom: Double = 1
    @AppStorage("boardPanX") private var panX: Double = 0
    @AppStorage("boardPanY") private var panY: Double = 0

    /// Zwischenstände der laufenden Geste — Ziehen und Lupe liefern
    /// Gesamtwerte, gebraucht wird die Änderung seit dem letzten Aufruf.
    @State private var letzteVerschiebung: CGSize = .zero
    @State private var letzteLupe: Double = 1

    static let zoomMin = 1.0
    static let zoomMax = 6.0

    /// Ab welcher Bildschirmkante ein Element Eck-Anfasser bekommt.
    ///
    /// Am Telefon steckt die ganze Tafel (1600 Punkte breit) in gut 390 —
    /// ein Element ist dann kleiner als die Griffe, die es fassen sollen.
    /// Deshalb erscheinen sie erst, wenn wirklich Platz ist: 110 Punkte
    /// lassen neben zwei Griffen (je 38) noch Luft. Beim Hineinzoomen sind
    /// sie dann da; unabhängig davon lässt sich jedes Element jederzeit mit
    /// zwei Fingern aufziehen.
    static let anfasserPlatz: Double = 110

    private var style: BoardStyle { BoardStyle(board: board, editing: store.editing) }

    /// Höhe der Tafelfläche — sie hängt am gewählten Format (16:10/16:9/4:3).
    private var hoehe: Double { board.hoehe }

    var body: some View {
        GeometryReader { geo in
            let passend = anpassung(geo)
            let scale = passend * zoom
            ZStack {
                // Hintergrund liegt unter allem: Was hier ankommt, hat kein
                // Element getroffen — also die „freie Fläche" der Web-App.
                BoardBackgroundView(background: board.background)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { ganzeTafel() }
                    .onTapGesture {
                        if store.editing { store.selectedWidgetID = nil }
                    }
                    .gesture(blickGeste(geo))

                canvas(scale: scale)
                    .offset(x: panX, y: panY)
                    // Die Seite hat eine eigene Kennung — dadurch wandert
                    // beim Blättern die alte Seite hinaus und die neue
                    // herein, statt dass der Inhalt springt.
                    .id(sichtbareSeite)
                    .transition(.asymmetric(
                        insertion: .move(edge: store.seitenRichtung > 0 ? .trailing : .leading)
                            .combined(with: .opacity),
                        removal: .move(edge: store.seitenRichtung > 0 ? .leading : .trailing)
                            .combined(with: .opacity)))

                // Am Telefon sitzt die Werkzeugleiste des gewählten Elements
                // fest unten, nicht über dem Element.
                if schmal, store.editing, !store.presenting, let gewaehlt = selectedWidget {
                    VStack {
                        Spacer()
                        SelectionChrome(boardID: board.id, widget: gewaehlt,
                                        scale: 1, angedockt: true)
                            .padding(.bottom, store.editing ? 62 : 16)
                    }
                }

                if !store.presenting {
                    blickKnoepfe
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            // Wischen blättert. Nur im Unterricht und nur bei ganzer Tafel:
            // Beim Bearbeiten zieht dieselbe Bewegung ein Element, beim
            // Schreiben den Stift, und hineingezoomt verschiebt sie den
            // Ausschnitt. `simultaneousGesture` lässt Tippen unberührt —
            // ein Name lässt sich also weiterhin ziehen, ohne dass die
            // Seite wechselt.
            .simultaneousGesture(seitenWisch,
                                 including: wischErlaubt ? .all : .subviews)
            .coordinateSpace(name: Self.space)
            .environment(\.boardStyle, style)
            .onChange(of: geo.size) { _, _ in begrenze(geo) }
        }
    }

    // MARK: - Blättern

    /// Wischen ist nur dann das Naheliegende, wenn die Bewegung sonst nichts
    /// zu tun hat.
    private var wischErlaubt: Bool {
        !store.editing && !store.drawing && zoom < Self.zoomMin + 0.01
    }

    /// Waagerecht wischen wechselt die Seite.
    ///
    /// Die Schwellen sind bewusst deutlich: 70 Punkte Weg und doppelt so
    /// waagerecht wie senkrecht. Wer auf ein Kärtchen tippt oder mit dem
    /// Finger etwas nach unten wischt, soll nicht aus Versehen blättern.
    private var seitenWisch: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { wert in
                blaettereWenn(wert.translation)
            }
    }

    private func blaettereWenn(_ weg: CGSize) {
        guard abs(weg.width) > 70, abs(weg.width) > abs(weg.height) * 2 else { return }
        store.blaettere(weg.width < 0 ? 1 : -1, boardID: board.id)
    }

    // MARK: - Hineinzoomen und verschieben

    /// Maßstab, bei dem die ganze Tafel ins Bild passt (Web: `fit`).
    private func anpassung(_ geo: GeometryProxy) -> Double {
        min(geo.size.width / Layout.canvasWidth,
            geo.size.height / hoehe)
    }

    /// Ein Finger auf der freien Fläche verschiebt, zwei Finger zoomen.
    private func blickGeste(_ geo: GeometryProxy) -> some Gesture {
        let schieben = DragGesture()
            .onChanged { wert in
                panX += wert.translation.width - letzteVerschiebung.width
                panY += wert.translation.height - letzteVerschiebung.height
                letzteVerschiebung = wert.translation
                begrenze(geo)
            }
            .onEnded { wert in
                letzteVerschiebung = .zero
                // Auf der freien Fläche blättert dasselbe Wischen auch beim
                // Bearbeiten — dort ist es kein Verschieben, solange die
                // ganze Tafel im Bild ist. Nur beim Bearbeiten: Im Unterricht
                // hört schon die Geste auf der ganzen Fläche zu, und beides
                // zusammen blätterte zwei Seiten weit.
                if store.editing, zoom < Self.zoomMin + 0.01 {
                    blaettereWenn(wert.translation)
                }
            }

        let lupe = MagnifyGesture()
            .onChanged { wert in
                let faktor = wert.magnification / letzteLupe
                letzteLupe = wert.magnification
                setzeZoom(zoom * faktor, anker: wert.startLocation, geo: geo)
            }
            .onEnded { _ in letzteLupe = 1 }

        return schieben.simultaneously(with: lupe)
    }

    /// Zoomt auf einen Punkt zu, sodass die Stelle unter den Fingern
    /// stehen bleibt (dieselbe Rechnung wie in `board.js`).
    private func setzeZoom(_ gewuenscht: Double, anker: CGPoint?, geo: GeometryProxy) {
        let neu = min(max(gewuenscht, Self.zoomMin), Self.zoomMax)
        guard abs(neu - zoom) > 0.001 else { return }
        if let anker {
            let relX = anker.x - geo.size.width / 2 - panX
            let relY = anker.y - geo.size.height / 2 - panY
            let faktor = neu / zoom
            panX -= relX * (faktor - 1)
            panY -= relY * (faktor - 1)
        }
        zoom = neu
        begrenze(geo)
    }

    /// Der Ausschnitt darf nicht über den Tafelrand hinauslaufen.
    private func begrenze(_ geo: GeometryProxy) {
        let scale = anpassung(geo) * zoom
        let ueberX = max(0, (Layout.canvasWidth * scale - geo.size.width) / 2)
        let ueberY = max(0, (hoehe * scale - geo.size.height) / 2)
        panX = min(max(panX, -ueberX), ueberX)
        panY = min(max(panY, -ueberY), ueberY)
    }

    /// Zurück auf „ganze Tafel im Bild".
    private func ganzeTafel() {
        withAnimation(.easeInOut(duration: 0.25)) {
            zoom = 1
            panX = 0
            panY = 0
        }
        Haptics.tap()
    }

    /// Nur noch ein Knopf, und nur solange hineingezoomt ist: der Weg zurück
    /// zur ganzen Tafel. Vergrößert und verschoben wird mit den Fingern — die
    /// Knöpfe −/+ sind entfallen. Ganz ohne Knopf sollte es aber nicht sein:
    /// Wer versehentlich hineinzoomt, sieht sonst nur einen Ausschnitt und
    /// muss das Doppeltippen erst kennen. Sichtbar ist er nur dann, wenn er
    /// gebraucht wird.
    private var blickKnoepfe: some View {
        VStack {
            Spacer()
            HStack {
                if zoom > Self.zoomMin + 0.001 {
                    Button {
                        Haptics.tap()
                        ganzeTafel()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Ganze Tafel")
                                .font(Theme.font(13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .chromeGlass()
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
                Spacer()
            }
            .padding(.leading, 14)
            .padding(.bottom, store.editing ? 118 : 16)
        }
        .animation(.easeInOut(duration: 0.2), value: zoom > Self.zoomMin + 0.001)
    }

    private func canvas(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Arbeitsfläche im Bearbeitungsmodus sichtbar machen.
            if store.editing {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18),
                                  style: StrokeStyle(lineWidth: 2 / scale, dash: [10 / scale, 8 / scale]))
                    .frame(width: Layout.canvasWidth, height: hoehe)
            }

            ForEach(board.widgets(auf: sichtbareSeite, mitVersteckten: store.editing)) { widget in
                WidgetHostView(boardID: board.id, widget: widget, scale: scale,
                               frames: board.frames)
                    .offset(x: widget.x, y: widget.y)
            }

            // Handschrift liegt über den Elementen, fängt aber nur
            // Berührungen, solange geschrieben wird.
            DrawingLayerView(drawing: drawingBinding, active: store.drawing,
                             pencilOnly: store.pencilOnly,
                             dunklerGrund: board.background.wirktDunkel)
                .frame(width: Layout.canvasWidth, height: hoehe)
                .allowsHitTesting(store.drawing)

            // Auf breiten Bildschirmen schwebt die Leiste über dem Element;
            // am Telefon liegt sie stattdessen unten (siehe oben) — dort
            // bleiben hier nur die Eck-Anfasser.
            if store.editing, let selected = selectedWidget {
                SelectionChrome(boardID: board.id, widget: selected, scale: scale,
                                nurAnfasser: schmal,
                                mindestKante: schmal ? Self.anfasserPlatz : 0)
            }
        }
        .frame(width: Layout.canvasWidth, height: hoehe, alignment: .topLeading)
        .scaleEffect(scale)
        .frame(width: Layout.canvasWidth * scale, height: hoehe * scale)
    }

    private var schmal: Bool { horizontalSizeClass == .compact }

    private var selectedWidget: BoardWidget? {
        guard let id = store.selectedWidgetID,
              let treffer = board.widgets.first(where: { $0.id == id }),
              (store.editing || !treffer.versteckt),
              board.liegtAuf(treffer, seite: sichtbareSeite)
        else { return nil }
        return treffer
    }

    /// Welche Seite gerade zu sehen ist. Kennt die Tafel die gespeicherte
    /// Seite nicht (etwa direkt nach einem Tafelwechsel), gilt die erste.
    private var sichtbareSeite: String {
        board.seiten.contains { $0.id == store.aktiveSeitenID }
            ? store.aktiveSeitenID : board.ersteSeitenID
    }

    /// Handschrift immer aus dem Speicher lesen — sonst überschriebe ein
    /// Strich einen Stand, der eben aus iCloud gekommen ist. Sie gehört zur
    /// Seite, nicht zur ganzen Tafel.
    private var drawingBinding: Binding<String> {
        Binding(
            get: { store.board(board.id)?.handschrift(auf: sichtbareSeite) ?? "" },
            set: { value in
                store.setzeHandschrift(value, seite: sichtbareSeite, boardID: board.id)
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
    /// Am Telefon sitzt die Leiste fest am unteren Bildschirmrand statt über
    /// dem Element — frei schwebend verdeckte sie dort halbe Tafeln
    /// (Web-App 1.6.4: `.selection-toolbar.is-docked`). Angedockt entfallen
    /// auch die Eck-Anfasser; die zeichnet dann die Tafel selbst.
    var angedockt: Bool = false
    /// Gegenstück dazu: nur die Anfasser, ohne Leiste — für das Telefon,
    /// wo die Leiste unten klebt, die Griffe aber am Element sitzen müssen.
    var nurAnfasser: Bool = false
    /// Kleinste Bildschirmkante, ab der Anfasser gezeigt werden (0 = immer).
    var mindestKante: Double = 0

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
        if angedockt {
            // In Bildschirmkoordinaten, also ohne Gegenmaßstab und ohne
            // Tafelrahmen — den setzt die aufrufende Stelle.
            toolbar
        } else {
            ZStack {
                if !nurAnfasser {
                    toolbar
                        .scaleEffect(1 / scale)
                        .position(x: toolbarX, y: toolbarY)
                }

                if !widget.locked, anfasserPassen {
                    ForEach(Array(Corner.allCases.enumerated()), id: \.offset) { item in
                        handle(item.element)
                            .scaleEffect(1 / scale)
                            .position(x: cornerX(item.element), y: cornerY(item.element))
                    }
                }
            }
            .frame(width: Layout.canvasWidth, height: hoehe)
        }
    }

    /// Passen die Griffe an das Element, ohne es zu verdecken? Gemessen wird
    /// die Kante auf dem Bildschirm, nicht auf der Tafel — beim Hineinzoomen
    /// wird ein Element größer, ohne dass sich sein Maß ändert.
    private var anfasserPassen: Bool {
        guard mindestKante > 0 else { return true }
        return widget.width * factor >= mindestKante
            && widget.height * factor >= mindestKante
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

    /// Was oben die Kopfleiste und unten die Seitenreiter beanspruchen —
    /// in Tafelpunkten, also durch den Maßstab geteilt.
    ///
    /// Beides schwebt über der Tafel und gehört nicht zu ihr; die Leiste
    /// des gewählten Elements muss ihm ausweichen.
    /// Oben genügen 90 — der Wert stand hier schon und hat sich bewährt.
    /// Unten muss mehr frei bleiben: Seitenreiter (rund 40) plus „Leiste"
    /// (rund 35) plus Abstand, und die Leiste wird über ihrer Mitte
    /// gesetzt, hängt also noch gut 20 tiefer als der Wert sagt.
    private var obererSaum: Double { 90 / factor }
    private var untererSaum: Double { 190 / factor }

    /// Wo die Werkzeugleiste steht.
    ///
    /// **Drei Lagen, in dieser Reihenfolge** (gemeldet 08/2026: „Die
    /// Menüleiste eines angetippten Feldes kommt regelmäßig der
    /// Seitenleiste ins Gehege."):
    ///
    /// 1. **Darüber.** Der Regelfall — sie verdeckt nichts vom Element.
    /// 2. **Darunter**, wenn das Element am oberen Rand klebt. Aber nur,
    ///    solange sie dort nicht in die Seitenreiter läuft. Genau das
    ///    passierte bei einem hohen Element, das oben anfängt und unten
    ///    aufhört — beim Sitzplan also fast immer.
    /// 3. **Auf dem oberen Rand des Elements**, wenn beides nicht geht.
    ///    Dann ist ein Streifen des Elements verdeckt. Das ist der
    ///    geringste Schaden: Man sieht die Leiste ganz, man trifft ihre
    ///    Knöpfe, und man reißt sich nicht am Seitenwechsler.
    private var toolbarY: Double {
        if widget.y > obererSaum { return widget.y - 34 / factor }
        let unten = widget.y + widget.height + 34 / factor
        if unten < hoehe - untererSaum { return unten }
        return max(widget.y + 34 / factor, obererSaum + 34 / factor)
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
            // Durchtippen: Karte → nur Rahmen → ohne → Karte.
            button(kartenstil.symbol, label: "Karte: \(kartenstil.title)",
                   tint: kartenstil == .immer ? .white : Theme.mint) {
                let neu = kartenstil.naechste
                store.updateWidget(widget.id, in: boardID) { $0.karte = neu }
            }
            // Beschriftungen dieses Elements — unabhängig von der Tafelregel.
            button(beschriftungAn ? "tag.fill" : "tag.slash",
                   label: beschriftungAn ? "Beschriftung ausblenden" : "Beschriftung zeigen",
                   tint: beschriftungAn ? .white : Theme.mint) {
                let neu: WidgetLabelRegel = beschriftungAn ? .nie : .immer
                store.updateWidget(widget.id, in: boardID) { $0.labels = neu }
            }
            // Ausblenden gilt nur für mich; auf einer geteilten Tafel bleibt
            // das Element für die anderen stehen. Beim Bearbeiten steht es
            // weiterhin blass auf der Tafel — sonst wäre der Knopf dasselbe
            // wie Löschen.
            button(widget.versteckt ? "eye" : "eye.slash",
                   label: widget.versteckt ? "Wieder zeigen" : "Nur für mich ausblenden",
                   tint: widget.versteckt ? Theme.mint : .white) {
                let neu = !widget.versteckt
                store.updateWidget(widget.id, in: boardID) { $0.versteckt = neu }
            }
            button(widget.locked ? "lock.fill" : "lock.open",
                   label: widget.locked ? "Entsperren" : "Gegen Verschieben sperren",
                   tint: widget.locked ? Theme.amber : .white) {
                store.updateWidget(widget.id, in: boardID) { $0.locked.toggle() }
            }
            button("plus.square.on.square", label: "Duplizieren") {
                store.duplicateWidget(widget.id, in: boardID)
            }
            // Kopieren steht als eigener Knopf da, nicht im Menü: Es ist der
            // Weg auf eine andere Seite oder Tafel, und danach hatte gesucht,
            // wer „Duplizieren" fand und trotzdem nicht weiterkam.
            button("doc.on.doc", label: "Kopieren") {
                store.kopiereWidget(widget.id, in: boardID)
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
                        item.clampToCanvas(hoehe: hoehe)
                    }
                } label: {
                    Label("Standardgröße", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                Divider()
                Button {
                    store.kopiereWidget(widget.id, in: boardID)
                } label: {
                    Label("Kopieren", systemImage: "doc.on.doc")
                }
                Button {
                    store.uebertragenWidgetID = widget.id
                } label: {
                    Label("Verschieben oder kopieren …", systemImage: "arrow.right.square")
                }
                Divider()
                // Zurücksetzen steht hier und nicht bei den Einstellungen:
                // Es ist kein Einrichten, sondern ein Handgriff zwischen
                // zwei Stunden. Ausgegraut, wenn nichts zu vergessen ist —
                // ein Knopf, der nichts tut, ist schlimmer als keiner.
                Button {
                    store.setzeZurueck(widget.id, in: boardID, tiefe: .ergebnis)
                    Haptics.tap()
                } label: {
                    Label("Auf unbenutzt zurücksetzen",
                          systemImage: "arrow.counterclockwise")
                }
                .disabled(!widget.content.benutzt(.ergebnis))
                // Die tiefere Stufe steht nur da, wo es ein Gedächtnis
                // gibt — beim Zufälligen Namen. Überall sonst wären beide
                // Punkte dasselbe, und zwei gleiche Punkte im Menü sind
                // schlimmer als einer.
                if widget.kind == .namePicker {
                    Button {
                        store.setzeZurueck(widget.id, in: boardID, tiefe: .alles)
                        Haptics.tap()
                    } label: {
                        Label("… auch die gezogenen Namen",
                              systemImage: "arrow.counterclockwise.circle")
                    }
                    .disabled(!widget.content.benutzt(.alles))
                }
                Divider()
                if store.darfLoeschen(widget, in: boardID) {
                    Button(role: .destructive) {
                        store.removeWidget(widget.id, from: boardID)
                    } label: {
                        Label("Für alle entfernen", systemImage: "trash")
                    }
                } else {
                    // Nicht einfach weglassen: Wer den Eintrag sucht, soll
                    // lesen, warum er fehlt — sonst sieht es nach einem
                    // Fehler aus.
                    Button { } label: {
                        Label("Löschen darf nur, wer es angelegt hat",
                              systemImage: "lock")
                    }
                    .disabled(true)
                }
            } label: {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
            // Auf einer geteilten Tafel steht der Papierkorb nur da, wenn er
            // auch etwas bewirkt. „Nur für mich ausblenden" links davon
            // bleibt jedem — das ist der Weg, fremde Elemente loszuwerden,
            // ohne sie anderen wegzunehmen.
            if store.darfLoeschen(widget, in: boardID) {
                button("trash.fill", label: "Löschen", tint: Theme.danger) {
                    store.removeWidget(widget.id, from: boardID)
                }
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 46)
        .chromeBar(corner: 23)
        .fixedSize()
    }

    /// Die Tafel, auf der das Element liegt — für die Vorgaberegeln.
    private var tafel: Board? { store.board(boardID) }

    /// Höhe der Tafelfläche (16:10, 16:9 oder 4:3).
    private var hoehe: Double { tafel?.hoehe ?? Layout.canvasHeight }

    /// Wie das Element gerade steht (Tafelregel plus eigene Wahl).
    private var kartenstil: WidgetKarte {
        widget.karte.gilt(tafel: tafel?.frames.applies(editing: store.editing) ?? true)
    }

    /// Zeigt das Element gerade seine Beschriftungen?
    private var beschriftungAn: Bool {
        widget.labels.gilt(tafel: tafel?.labels.applies(editing: store.editing) ?? true)
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
            item.height = min(max(item.height * amount, Layout.minHeight), hoehe)
            item.x = centerX - item.width / 2
            item.y = centerY - item.height / 2
            item.clampToCanvas(hoehe: hoehe)
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
            item.height = max(Layout.minHeight, min(bottom + dy, hoehe) - top)
        }
        item.clampToCanvas(hoehe: hoehe)
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

    /// Auch die Liste zeigt nur die Elemente der sichtbaren Seite.
    private var sichtbareSeite: String {
        board.seiten.contains { $0.id == store.aktiveSeitenID }
            ? store.aktiveSeitenID : board.ersteSeitenID
    }

    var body: some View {
        ZStack {
            BoardBackgroundView(background: board.background)
                .ignoresSafeArea()

            GeometryReader { geo in
                let width = geo.size.width - 24
                let liste = board.widgets(auf: sichtbareSeite, mitVersteckten: store.editing)
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(liste.enumerated()), id: \.element.id) { stelle, widget in
                            let scale = width / CGFloat(widget.width)
                            VStack(spacing: 6) {
                                if store.editing {
                                    HStack(spacing: 10) {
                                        Text(widget.kind.title)
                                            .font(Theme.font(15, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.7))
                                        Spacer()
                                        // Reihenfolge ändern. Die Liste ordnet
                                        // nach derselben Zahl wie die Tafel:
                                        // Wer hier nach oben rückt, liegt dort
                                        // weiter hinten.
                                        Button {
                                            Haptics.tap()
                                            store.verschiebe(widget.id, in: board.id, umEinen: -1)
                                        } label: {
                                            Image(systemName: "arrow.up")
                                        }
                                        .disabled(stelle == 0)
                                        .opacity(stelle == 0 ? 0.3 : 1)
                                        .accessibilityLabel("Nach oben")
                                        Button {
                                            Haptics.tap()
                                            store.verschiebe(widget.id, in: board.id, umEinen: 1)
                                        } label: {
                                            Image(systemName: "arrow.down")
                                        }
                                        .disabled(stelle == liste.count - 1)
                                        .opacity(stelle == liste.count - 1 ? 0.3 : 1)
                                        .accessibilityLabel("Nach unten")
                                        Button {
                                            store.settingsWidgetID = widget.id
                                        } label: {
                                            Image(systemName: "gearshape.fill")
                                        }
                                        if store.darfLoeschen(widget, in: board.id) {
                                            Button(role: .destructive) {
                                                store.removeWidget(widget.id, from: board.id)
                                            } label: {
                                                Image(systemName: "trash.fill")
                                            }
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
                    .animation(.easeInOut(duration: 0.22), value: liste.map(\.id))
                    .padding(12)
                    .padding(.top, 70)
                    .padding(.bottom, 40)
                }
            }
        }
        .environment(\.boardStyle, style)
    }
}
