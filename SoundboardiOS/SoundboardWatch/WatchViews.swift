import SwiftUI

/// Farb-Hilfe (eigene Kopie für das Watch-Modul).
extension Color {
    init(watchHex hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        Scanner(string: cleaned).scanHexInt64(&value)
        if cleaned.count == 6 {
            self.init(
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255
            )
        } else {
            self.init(white: 0.5)
        }
    }
}

/// Wurzelansicht: Boards zum Auslösen + „Läuft gerade“.
struct WatchRootView: View {
    @EnvironmentObject var link: PhoneLink

    var body: some View {
        TabView {
            BoardsView()
            NowPlayingView()
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Boards & Felder

struct BoardsView: View {
    @EnvironmentObject var link: PhoneLink

    var body: some View {
        NavigationStack {
            Group {
                if link.boards.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: link.reachable ? "square.grid.2x2" : "iphone.slash")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(link.reachable
                             ? "Keine belegten Felder gefunden."
                             : "iPhone nicht erreichbar – bitte Soundboard auf dem iPhone öffnen.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Erneut versuchen") {
                            link.refresh()
                        }
                        .font(.footnote)
                    }
                    .padding()
                } else {
                    List(link.boards) { board in
                        NavigationLink {
                            PadGridView(boardID: board.id)
                        } label: {
                            HStack(spacing: 6) {
                                Text(board.icon)
                                Text(board.name)
                                    .lineLimit(1)
                                Spacer()
                                Circle()
                                    .fill(Color(watchHex: board.color))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Soundboard")
        }
    }
}

struct PadGridView: View {
    let boardID: UUID
    @EnvironmentObject var link: PhoneLink

    private var board: WatchState.Board? {
        link.boards.first { $0.id == boardID }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                      spacing: 6) {
                ForEach(board?.pads ?? []) { pad in
                    Button {
                        link.tap(pad)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            if pad.playing {
                                Image(systemName: "waveform")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            Spacer(minLength: 0)
                            Text(pad.label.isEmpty ? "Feld" : pad.label)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .background(
                            Color(watchHex: pad.color).opacity(pad.playing ? 1.0 : 0.75),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(board.map { "\($0.icon) \($0.name)" } ?? "Board")
    }
}

// MARK: - Läuft gerade

struct NowPlayingView: View {
    @EnvironmentObject var link: PhoneLink

    private var playingPads: [WatchState.Pad] {
        link.boards.flatMap(\.pads).filter(\.playing)
    }

    var body: some View {
        NavigationStack {
            List {
                if playingPads.isEmpty {
                    Text("Gerade spielt nichts.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(playingPads) { pad in
                        Button {
                            link.stop(pad)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(watchHex: pad.color))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(pad.label.isEmpty ? "Feld" : pad.label)
                                        .font(.footnote.weight(.semibold))
                                        .lineLimit(1)
                                    if pad.duration > 0 {
                                        Text("noch \(watchFormatTime(max(0, pad.duration - pad.current)))")
                                            .font(.system(.caption2, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "stop.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Button {
                    link.resetAll()
                } label: {
                    Label("Alle auf Anfang", systemImage: "backward.end.fill")
                        .font(.footnote.weight(.semibold))
                }
            }
            .navigationTitle("Läuft gerade")
        }
    }
}
