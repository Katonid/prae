import Foundation
import WatchConnectivity
import WatchKit

/// Verbindung der Watch zum iPhone: holt den Board-Zustand,
/// schickt Auslöse-Befehle und tippt kurz vor Titelende ans Handgelenk.
@MainActor
final class PhoneLink: NSObject, ObservableObject {

    @Published private(set) var boards: [WatchState.Board] = []
    @Published private(set) var reachable = false
    @Published private(set) var everConnected = false

    private var pollTimer: Timer?
    /// Felder, für die das Endzeit-Tippen bereits ausgelöst wurde.
    private var warnedPads: Set<UUID> = []

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()

        // Laufende Wiedergabe regelmäßig abfragen (nur solange die App aktiv ist).
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        refresh()
    }

    // MARK: - Befehle ans iPhone

    func tap(_ pad: WatchState.Pad) {
        WKInterfaceDevice.current().play(.click)
        send(["cmd": "tap", "pad": pad.id.uuidString])
    }

    func stop(_ pad: WatchState.Pad) {
        WKInterfaceDevice.current().play(.click)
        send(["cmd": "stop", "pad": pad.id.uuidString])
    }

    func resetAll() {
        WKInterfaceDevice.current().play(.success)
        send(["cmd": "resetAll"])
    }

    func refresh() {
        send(["cmd": "state"])
    }

    private func send(_ message: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            reachable = false
            return
        }
        session.sendMessage(message, replyHandler: { [weak self] reply in
            Task { @MainActor [weak self] in
                self?.apply(reply)
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reachable = false
            }
        })
    }

    // MARK: - Zustand übernehmen

    private func apply(_ payload: [String: Any]) {
        guard let data = payload["state"] as? Data,
              let state = try? JSONDecoder().decode(WatchState.self, from: data) else { return }
        reachable = true
        everConnected = true
        boards = state.boards
        updateEndOfTrackHaptics(state)
    }

    /// Tippt ans Handgelenk, wenn ein laufender Titel nur noch ~10 Sekunden hat.
    private func updateEndOfTrackHaptics(_ state: WatchState) {
        var stillRelevant: Set<UUID> = []
        for board in state.boards {
            for pad in board.pads where pad.playing && pad.duration > 0 {
                let remaining = pad.duration - pad.current
                if remaining <= 10 {
                    stillRelevant.insert(pad.id)
                    if !warnedPads.contains(pad.id) {
                        warnedPads.insert(pad.id)
                        WKInterfaceDevice.current().play(.notification)
                    }
                }
            }
        }
        // Zurücksetzen, sobald der Titel neu gestartet oder gestoppt wurde.
        warnedPads = warnedPads.intersection(stillRelevant)
    }
}

// MARK: - WCSessionDelegate

extension PhoneLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor [weak self] in
            self?.refresh()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.refresh()
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor [weak self] in
            self?.apply(applicationContext)
        }
    }
}
