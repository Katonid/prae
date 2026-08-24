import SwiftUI

/// Hauptansicht: Tafel im Vollbild, darüber eine schwebende Leiste.
struct RootView: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Nur ein Blatt gleichzeitig — das ist verlässlicher als mehrere
    /// `sheet`-Schalter nebeneinander.
    @State private var sheet: RootSheet?

    private var compact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#05070f").ignoresSafeArea()

            if let board = store.activeBoard {
                Group {
                    if compact {
                        BoardStackView(board: board)
                    } else {
                        BoardCanvasView(board: board)
                    }
                }
                .id(board.id)
            } else {
                EmptyBoardView(onCreate: { store.createBoard() }, onJoin: { sheet = .boards })
            }

            if store.presenting {
                revealButton
            } else {
                topBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let message = store.statusMessage {
                statusBanner(message)
            }
        }
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
            case .settings:
                AppSettingsSheet()
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
                HStack(spacing: 8) {
                    Text(store.activeBoard?.emoji ?? "🌟")
                        .font(.system(size: 20))
                    if !compact {
                        Text(store.activeBoard?.name ?? "Tafelbild")
                            .font(Theme.font(17, weight: .bold))
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background { Capsule().fill(Color.white.opacity(0.10)) }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            ChromeButton(systemImage: "plus", title: compact ? nil : "Element",
                         tint: .white) {
                sheet = .addWidget
            }

            ChromeButton(systemImage: store.editing ? "checkmark" : "slider.horizontal.3",
                         title: (compact || store.editing) ? nil : "Anordnen",
                         active: store.editing) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.editing.toggle()
                    if !store.editing { store.selectedWidgetID = nil }
                }
            }

            ChromeButton(systemImage: "rectangle.inset.filled.and.person.filled") {
                store.editing = false
                store.selectedWidgetID = nil
                store.presenting = true
            }

            Menu {
                Button {
                    sheet = .boardSettings
                } label: {
                    Label("Tafel gestalten", systemImage: "paintbrush")
                }
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
                Divider()
                Button {
                    sheet = .settings
                } label: {
                    Label("Einstellungen", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background { Capsule().fill(Color.white.opacity(0.10)) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .chromeBar(corner: 26)
        .padding(.horizontal, 12)
        .padding(.top, 6)
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
            .chromeBar(corner: 18)
            .padding(.top, store.presenting ? 14 : 80)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: store.statusMessage)
    }
}

/// Blätter der Hauptansicht.
enum RootSheet: String, Identifiable {
    case boards, addWidget, boardSettings, nameLists, share, settings
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
            LinearGradient(colors: [Color(hex: "#1e1b4b"), Color(hex: "#0b1020")],
                           startPoint: .top, endPoint: .bottom)
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
