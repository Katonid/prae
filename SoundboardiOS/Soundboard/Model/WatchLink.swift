import Foundation
import WatchConnectivity

/// iPhone-Seite der Watch-Verbindung: beantwortet Zustandsabfragen der Watch
/// und führt von dort ausgelöste Befehle aus (Feld antippen, stoppen,
/// alle auf Anfang). Die Töne spielen immer auf dem iPhone.
@MainActor
final class WatchLink: NSObject, ObservableObject {

    weak var store: BoardStore?
    weak var engine: AudioEngine?

    private var pushTask: Task<Void, Never>?

    /// Datenpaket für die Watch (Gegenstück: WatchModels.swift im Watch-Modul –
    /// beide Definitionen müssen inhaltlich identisch bleiben).
    struct WatchState: Codable {
        struct Board: Codable {
            var id: UUID
            var name: String
            var color: String
            var icon: String
            var pads: [Pad]
        }
        struct Pad: Codable {
            var id: UUID
            var label: String
            var color: String
            var playing: Bool
            var current: Double
            var duration: Double
        }
        var boards: [Board]
    }

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Nach Datenänderungen den neuen Stand zur Watch schieben (gebündelt).
    func pushStateSoon() {
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.pushStateNow()
        }
    }

    private func pushStateNow() {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled,
              let data = stateData() else { return }
        try? session.updateApplicationContext(["state": data])
    }

    // MARK: - Zustand & Befehle

    private func stateData() -> Data? {
        guard let store, let engine else { return nil }
        let boards = store.visibleBoards.map { board in
            WatchState.Board(
                id: board.id,
                name: board.name,
                color: board.colorHex,
                icon: board.displayIcon,
                pads: board.pads
                    .filter { !$0.hidden && !$0.source.isEmpty }
                    .map { pad in
                        let progress = engine.progress(pad)
                        return WatchState.Pad(
                            id: pad.id,
                            label: pad.displayLabel,
                            color: pad.colorHex,
                            playing: engine.isPlaying(pad),
                            current: progress?.current ?? 0,
                            duration: progress?.duration ?? 0
                        )
                    }
            )
        }
        return try? JSONEncoder().encode(WatchState(boards: boards))
    }

    private func handle(_ message: [String: Any]) -> [String: Any] {
        if let cmd = message["cmd"] as? String, let store, let engine {
            switch cmd {
            case "tap":
                if let pad = pad(from: message, in: store) {
                    engine.perform(pad.singleTap, pad: pad)
                }
            case "stop":
                if let pad = pad(from: message, in: store) {
                    engine.perform(.stopReset, pad: pad)
                }
            case "resetAll":
                engine.resetAll()
            default:
                break
            }
        }
        if let data = stateData() {
            return ["state": data]
        }
        return [:]
    }

    private func pad(from message: [String: Any], in store: BoardStore) -> SoundPad? {
        guard let idString = message["pad"] as? String,
              let id = UUID(uuidString: idString) else { return nil }
        return store.pad(id)
    }
}

// MARK: - WCSessionDelegate

extension WatchLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor [weak self] in
            self?.pushStateSoon()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else {
                replyHandler([:])
                return
            }
            replyHandler(self.handle(message))
        }
    }
}
