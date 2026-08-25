import SwiftUI

/// Hauptansicht: Tafel im Vollbild, darüber eine schwebende Leiste.
struct RootView: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Nur ein Blatt gleichzeitig — das ist verlässlicher als mehrere
    /// `sheet`-Schalter nebeneinander.
    @State private var sheet: RootSheet?
    /// Welche Seite gerade umbenannt wird — nil, wenn keine.
    @State private var seiteUmbenennen: String?
    @State private var seiteNeuerName = ""

    /// Die Schrift der App. Sie steht hier nur, damit ein Wechsel sofort
    /// sichtbar wird: `Theme.font` liest den Wert direkt aus den
    /// Einstellungen, davon bekäme SwiftUI sonst nichts mit.
    @AppStorage(AppFont.speicherSchluessel) private var schriftWahl: AppFont = .lexend

    /// Listenansicht ist eine bewusste Wahl, keine Automatik mehr. Vorgabe
    /// ist überall die Tafel — am Telefon lässt sie sich zoomen und
    /// verschieben (Web-App 1.6.3).
    @AppStorage("stackModeManual") private var listenansicht = false
    /// Elementleiste unten ausgeblendet? Bleibt gespeichert.
    @AppStorage("dockHidden") private var leisteAus = false

    private var compact: Bool { horizontalSizeClass == .compact }

    /// Farbschema der aktiven Tafel — färbt auch die Bedienleiste.
    private var style: BoardStyle {
        guard let board = store.activeBoard else { return .standard }
        return BoardStyle(board: board, editing: store.editing)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#04100f").ignoresSafeArea()

            if let board = store.activeBoard {
                Group {
                    if listenansicht {
                        BoardStackView(board: board)
                    } else {
                        BoardCanvasView(board: board)
                    }
                }
                .id(board.id)
                .onAppear { store.stelleSeiteAufAnfang(board) }
                .onChange(of: board.id) { _, _ in store.stelleSeiteAufAnfang(board) }
            } else {
                EmptyBoardView(onCreate: { store.createBoard() }, onJoin: { sheet = .boards })
            }

            if store.presenting {
                revealButton
            } else {
                topBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Seitenwechsler: auch im Unterricht erreichbar — zwischen den
            // Seiten wird ja gerade dann gewechselt. Nur im
            // Präsentationsmodus ist alles weg.
            if !store.presenting, let board = store.activeBoard,
               board.hatMehrereSeiten || store.editing {
                VStack {
                    Spacer()
                    seitenWechsler(board)
                        .padding(.bottom, store.editing
                                 ? (leisteAus ? 60 : 152) : 16)
                }
                .transition(.opacity)
            }

            if store.editing && !store.presenting {
                VStack(spacing: 0) {
                    Spacer()
                    leisteSchalter
                    if !leisteAus {
                        WidgetDock { kind in
                            if let board = store.activeBoard {
                                store.addWidget(kind: kind, to: board.id)
                            }
                        }
                        .environment(\.boardStyle, style)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let message = store.statusMessage {
                statusBanner(message)
            }
        }
        // Die Bildschirmtastatur darf die Tafel NICHT zusammenschieben.
        //
        // Ohne diese Zeile zieht SwiftUI den sicheren Bereich um die
        // Tastaturhöhe ein — auf dem iPad fast die halbe Höhe. Die Tafel
        // rechnet sich dann auf diesen Rest herunter und die Elementleiste
        // sitzt mitten im Bild. Verschwindet die Tastatur, bleibt das
        // gelegentlich so stehen; es sah nach einem Zeichenfehler aus.
        //
        // Eine Tafel ist eine feste Fläche: Sie behält ihre Größe, die
        // Tastatur legt sich darüber. Wer unten schreibt, schiebt die Tafel
        // mit einem Finger hoch.
        .ignoresSafeArea(.keyboard)
        .alert("Seite umbenennen", isPresented: Binding(
            get: { seiteUmbenennen != nil },
            set: { if !$0 { seiteUmbenennen = nil } }
        )) {
            TextField("Name der Seite", text: $seiteNeuerName)
            Button("Sichern") {
                if let seite = seiteUmbenennen, let board = store.activeBoard {
                    store.seiteUmbenennen(seite, auf: seiteNeuerName, boardID: board.id)
                }
                seiteUmbenennen = nil
            }
            Button("Abbrechen", role: .cancel) { seiteUmbenennen = nil }
        } message: {
            Text("Ohne Namen heißt sie nach ihrer Reihenfolge — „Seite 1“, „Seite 2“ …")
        }
        // Beim Schriftwechsel die Ansicht neu aufbauen — sonst behielten
        // schon gezeichnete Texte die alte Schrift.
        .id(schriftWahl)
        .animation(.easeInOut(duration: 0.25), value: store.presenting)
        .statusBarHidden(store.presenting)
        .persistentSystemOverlays(store.presenting ? .hidden : .automatic)
        .sheet(item: $sheet) { which in
            switch which {
            case .boards:
                BoardsSheet()
            case .addWidget:
                AddWidgetSheet { kind in
                    if let board = store.activeBoard {
                        store.addWidget(kind: kind, to: board.id)
                    }
                }
            case .boardSettings:
                if let board = store.activeBoard {
                    BoardSettingsSheet(boardID: board.id)
                }
            case .nameLists:
                NameListsSheet()
            case .share:
                if let board = store.activeBoard {
                    ShareSheet(boardID: board.id)
                }
            case .seiten:
                if let board = store.activeBoard {
                    SeitenSheet(boardID: board.id)
                }
            case .settings:
                AppSettingsSheet()
            case .diagnose:
                NavigationStack { SyncDiagnoseView() }
            }
        }
        .sheet(item: Binding(
            get: { store.settingsWidgetID.map { WidgetReference(id: $0) } },
            set: { store.settingsWidgetID = $0?.id }
        )) { reference in
            if let board = store.activeBoard {
                WidgetSettingsSheet(boardID: board.id, widgetID: reference.id)
            }
        }
        .onOpenURL { url in
            // tafelbild://join/ABC123
            guard url.scheme == "tafelbild" else { return }
            let code = url.lastPathComponent
            store.joinBoard(code: code) { success in
                if !success { store.showStatus("Zu diesem Code wurde keine Tafel gefunden.") }
            }
        }
    }

    // MARK: - Leiste

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                Haptics.tap()
                sheet = .boards
            } label: {
                HStack(spacing: 9) {
                    Text(store.activeBoard?.emoji ?? "🌟")
                        .font(.system(size: 17))
                    if !compact {
                        Text(store.activeBoard?.name ?? "Tafelbild")
                            .font(Theme.font(15, weight: .bold))
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 42)
                .chromeGlass()
            }
            .buttonStyle(.plain)

            if store.syncStatus.isError {
                Button {
                    Haptics.tap()
                    sheet = .diagnose
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.icloud.fill")
                        if !compact {
                            Text("Abgleich klemmt")
                                .font(Theme.font(14, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 13)
                    .frame(height: 36)
                    .background { Capsule().fill(Theme.amber) }
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            // In der Kopfleiste steht nur noch, was während der Stunde
            // zählt: Schreiben, Bearbeiten, Vollbild. „Listen", „Teilen"
            // und „Aussehen" sind ins Menü gewandert — alles drei richtet
            // man einmal ein und rührt es dann nicht mehr an.
            ChromeButton(systemImage: store.drawing ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle",
                         active: store.drawing) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.drawing.toggle()
                    if store.drawing {
                        store.editing = false
                        store.selectedWidgetID = nil
                    }
                }
            }

            ChromeButton(systemImage: store.editing ? "checkmark" : "square.grid.2x2",
                         // Wortlaut wie in der Web-App: „Bearbeiten" führt
                         // hinein, „Fertig" wieder heraus.
                         title: store.editing ? "Fertig" : (compact ? nil : "Bearbeiten"),
                         primary: true,
                         gradient: style.accentGradient) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    store.editing.toggle()
                    if store.editing { store.drawing = false }
                    if !store.editing { store.selectedWidgetID = nil }
                }
            }

            ChromeButton(systemImage: "rectangle.inset.filled.and.person.filled") {
                store.editing = false
                store.drawing = false
                store.selectedWidgetID = nil
                store.presenting = true
            }

            Menu {
                Button {
                    sheet = .nameLists
                } label: {
                    Label("Namenslisten", systemImage: "list.bullet.rectangle.portrait")
                }
                Button {
                    sheet = .share
                } label: {
                    Label("Tafel teilen", systemImage: "square.and.arrow.up")
                }
                Button {
                    sheet = .boardSettings
                } label: {
                    Label("Aussehen", systemImage: "paintbrush")
                }
                Divider()
                Button {
                    sheet = .seiten
                } label: {
                    Label("Seiten verwalten", systemImage: "doc.on.doc")
                }
                Button {
                    sheet = .addWidget
                } label: {
                    Label("Element hinzufügen", systemImage: "plus")
                }
                Button {
                    guard var board = store.activeBoard else { return }
                    board.drawing = ""
                    store.updateBoard(board)
                    Haptics.tap()
                } label: {
                    Label("Handschrift wegwischen", systemImage: "eraser")
                }
                .disabled(store.activeBoard?.drawing.isEmpty ?? true)
                Divider()
                Button {
                    sheet = .settings
                } label: {
                    Label("Einstellungen", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .chromeGlass()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    /// Reihe der Seiten. Ein Tipp wechselt, „+" legt eine an (nur beim
    /// Bearbeiten), langes Drücken öffnet die Verwaltung.
    private func seitenWechsler(_ board: Board) -> some View {
        let seiten = board.seiten
        let aktiv = seiten.contains { $0.id == store.aktiveSeitenID }
            ? store.aktiveSeitenID : board.ersteSeitenID
        return HStack(spacing: 4) {
            ForEach(Array(seiten.enumerated()), id: \.element.id) { paar in
                let seite = paar.element
                let gewaehlt = seite.id == aktiv
                Button {
                    store.zeigeSeite(seite.id)
                } label: {
                    Text(board.seitenName(seite.id))
                        .font(Theme.font(13, weight: gewaehlt ? .bold : .semibold))
                        .foregroundStyle(gewaehlt ? Color.white : .white.opacity(0.6))
                        .lineLimit(1)
                        .padding(.horizontal, 13)
                        .frame(height: 32)
                        .background {
                            if gewaehlt {
                                Capsule().fill(style.accentGradient)
                            }
                        }
                }
                .buttonStyle(.plain)
                // Umbenennen dort, wo die Seite steht — nicht erst zwei
                // Ebenen tiefer in der Verwaltung.
                .contextMenu {
                    Button {
                        seiteNeuerName = seite.name
                        seiteUmbenennen = seite.id
                    } label: {
                        Label("Umbenennen", systemImage: "pencil")
                    }
                    Button {
                        store.seiteDuplizieren(seite.id, boardID: board.id)
                    } label: {
                        Label("Kopie anlegen", systemImage: "plus.square.on.square")
                    }
                    if seiten.count > 1 {
                        Button(role: .destructive) {
                            store.seiteLoeschen(seite.id, boardID: board.id)
                        } label: {
                            Label("Seite löschen", systemImage: "trash")
                        }
                    }
                }
            }

            if store.editing {
                Button {
                    Haptics.tap()
                    store.seiteAnlegen(boardID: board.id)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 34, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .chromeGlass()
        .contextMenu {
            Button {
                sheet = .seiten
            } label: {
                Label("Seiten verwalten", systemImage: "doc.on.doc")
            }
        }
    }

    /// Schmaler Knopf über der Elementleiste: blendet sie weg — am Telefon
    /// gewinnt die Tafel dadurch spürbar Platz. Ausgeblendet heißt er
    /// „Elemente" und holt sie zurück (Wortlaut wie in der Web-App).
    private var leisteSchalter: some View {
        Button {
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.22)) { leisteAus.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: leisteAus ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                Text(leisteAus ? "Elemente" : "Leiste")
                    .font(Theme.font(12, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 14)
            .frame(height: 26)
            .chromeGlass()
        }
        .buttonStyle(.plain)
        .padding(.bottom, leisteAus ? 14 : 6)
    }

    /// Im Präsentationsmodus bleibt nur ein dezenter Knopf stehen.
    private var revealButton: some View {
        HStack {
            Spacer()
            Button {
                Haptics.tap()
                store.presenting = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 42, height: 30)
                    .background { Capsule().fill(Color.black.opacity(0.35)) }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
            .padding(.top, 6)
        }
    }

    private func statusBanner(_ message: String) -> some View {
        Text(message)
            .font(Theme.font(16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .chromeGlass(corner: 18)
            .padding(.top, store.presenting ? 14 : 80)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: store.statusMessage)
    }
}

/// Blätter der Hauptansicht.
enum RootSheet: String, Identifiable {
    case boards, addWidget, boardSettings, nameLists, share, seiten, settings, diagnose
    var id: String { rawValue }
}

/// Hülle, damit `sheet(item:)` mit einer String-ID arbeiten kann.
struct WidgetReference: Identifiable, Equatable {
    let id: String
}

// MARK: - Leerer Zustand

struct EmptyBoardView: View {
    var onCreate: () -> Void
    var onJoin: () -> Void

    var body: some View {
        ZStack {
            AuroraBackgroundView(preset: AuroraPresets.find("nordlicht"))
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))
                Text("Noch keine Tafel")
                    .font(Theme.font(30, weight: .bold))
                    .foregroundStyle(.white)
                Text("Lege eine Tafel für deine Klasse an — oder tritt der Tafel einer Kollegin mit dem Einladungscode bei.")
                    .font(Theme.font(18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                HStack(spacing: 12) {
                    Button(action: onCreate) {
                        Label("Tafel anlegen", systemImage: "plus")
                            .font(Theme.font(17, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 22)
                            .frame(height: 50)
                            .background { Capsule().fill(Color.white) }
                    }
                    .buttonStyle(.plain)
                    Button(action: onJoin) {
                        Label("Beitreten", systemImage: "person.badge.plus")
                            .font(Theme.font(17, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .frame(height: 50)
                            .background { Capsule().fill(Color.white.opacity(0.14)) }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(30)
        }
    }
}
