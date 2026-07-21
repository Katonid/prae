import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: BoardStore
    @EnvironmentObject var engine: AudioEngine

    @State private var editingPadID: UUID?
    @State private var showBoardSettings = false
    @State private var draggedPadID: UUID?

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 650
            ZStack {
                background

                VStack(spacing: 0) {
                    header
                    boardChips
                    padGrid(columns: wide ? 4 : 2)
                    bottomBar
                }
            }
            .overlay(alignment: .bottom) { toast }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $editingPadID) { padID in
            PadEditorView(padID: padID)
                .environmentObject(store)
                .environmentObject(engine)
        }
        .sheet(isPresented: $showBoardSettings) {
            BoardSettingsView()
                .environmentObject(store)
                .environmentObject(engine)
        }
    }

    // MARK: - Hintergrund

    @ViewBuilder
    private var background: some View {
        let board = store.activeBoard
        StageBackground(boardColor: Color(hex: board?.colorHex ?? "#f7b32b"))
        if let board, let url = store.backgroundImageURL(for: board),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.55).ignoresSafeArea())
        }
    }

    // MARK: - Kopfbereich

    private var header: some View {
        HStack {
            Text(store.activeBoard?.displayIcon ?? "🎭")
                .font(.title2)
            Text(store.activeBoard?.name ?? "Soundboard")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button {
                showBoardSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(8)
                    .background(.white.opacity(0.08), in: Circle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }

    // MARK: - Board-Auswahl

    @ViewBuilder
    private var boardChips: some View {
        let visible = store.visibleBoards
        if visible.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(visible) { board in
                        let active = board.id == store.activeBoard?.id
                        Button {
                            Haptics.tap()
                            store.selectBoard(board.id)
                        } label: {
                            HStack(spacing: 6) {
                                Text(board.displayIcon)
                                    .font(.footnote)
                                Text(board.name)
                                    .font(.system(.footnote, design: .rounded, weight: active ? .bold : .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                active ? Color(hex: board.colorHex).opacity(0.3) : .white.opacity(0.07),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    active ? Color(hex: board.colorHex).opacity(0.8) : .clear,
                                    lineWidth: 1.5
                                )
                            )
                            .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        } else {
            Spacer().frame(height: 10)
        }
    }

    // MARK: - Raster

    private func padGrid(columns: Int) -> some View {
        let board = store.activeBoard
        let pads = (board?.pads ?? []).filter { store.editMode || !$0.hidden }
        let spacing: CGFloat = 12
        let grid = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)

        return Group {
            if columns >= 4 {
                // Breite Bildschirme (iPad): das ganze Raster passt ohne Scrollen auf den Schirm.
                GeometryReader { geo in
                    let rows = max(1, (pads.count + columns - 1) / columns)
                    let cellHeight = max(44, (geo.size.height - spacing * CGFloat(rows - 1) - 12) / CGFloat(rows))
                    LazyVGrid(columns: grid, spacing: spacing) {
                        ForEach(pads) { pad in
                            padCell(pad, boardID: board?.id)
                                .frame(height: cellHeight)
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: grid, spacing: spacing) {
                        ForEach(pads) { pad in
                            padCell(pad, boardID: board?.id)
                                .aspectRatio(1.15, contentMode: .fit)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
        }
        // Fängt Ablegen außerhalb der Felder ab, damit kein Feld abgedunkelt hängen bleibt.
        .onDrop(of: [.text], isTargeted: nil) { _ in
            draggedPadID = nil
            return true
        }
    }

    @ViewBuilder
    private func padCell(_ pad: SoundPad, boardID: UUID?) -> some View {
        let tile = PadView(pad: pad, isEditing: store.editMode, engine: engine) {
            editingPadID = pad.id
        }

        if store.editMode {
            // Im Bearbeiten-Modus: gedrückt halten und ziehen zum Sortieren.
            tile
                .opacity(draggedPadID == pad.id ? 0.35 : 1)
                .onDrag {
                    draggedPadID = pad.id
                    return NSItemProvider(object: pad.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: PadDropDelegate(
                    targetPadID: pad.id,
                    boardID: boardID,
                    draggedPadID: $draggedPadID,
                    store: store
                ))
        } else {
            tile
        }
    }

    // MARK: - Fußleiste

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.heavy()
                engine.resetAll()
                store.showStatus("Alle Töne auf Anfang gesetzt.")
            } label: {
                Label("Alle auf Anfang", systemImage: "backward.end.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }

            Button {
                Haptics.tap()
                draggedPadID = nil
                withAnimation(.spring(duration: 0.3)) {
                    store.editMode.toggle()
                }
                if store.editMode {
                    store.showStatus("Feld antippen zum Bearbeiten, gedrückt halten zum Verschieben.")
                }
            } label: {
                Label(store.editMode ? "Fertig" : "Bearbeiten",
                      systemImage: store.editMode ? "checkmark" : "pencil")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        store.editMode ? Color(hex: "#f7b32b").opacity(0.85) : .white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .foregroundStyle(store.editMode ? .black : .white)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Statusmeldung

    @ViewBuilder
    private var toast: some View {
        if let message = store.statusMessage {
            Text(message)
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black.opacity(0.8), in: Capsule())
                .padding(.bottom, 70)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: store.statusMessage)
        }
    }
}

/// Sortieren per Drag & Drop im Bearbeiten-Modus.
private struct PadDropDelegate: DropDelegate {
    let targetPadID: UUID
    let boardID: UUID?
    @Binding var draggedPadID: UUID?
    let store: BoardStore

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedPadID, dragged != targetPadID, let boardID else { return }
        store.movePad(inBoard: boardID, from: dragged, to: targetPadID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedPadID = nil
        return true
    }
}

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
