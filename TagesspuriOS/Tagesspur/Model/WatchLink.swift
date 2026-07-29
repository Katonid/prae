import Foundation
import WatchConnectivity

/// iPhone-Seite der Watch-Verbindung: beantwortet Fernbedienungs-
/// Befehle der Watch (Aufzeichnung an/aus, hohe Genauigkeit) und hält
/// deren Status-Anzeige per Application-Context aktuell.
final class WatchLink: NSObject, WCSessionDelegate {
    static let shared = WatchLink()
    weak var tracker: LocationTracker?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Status zur Watch schicken — wird aus dem Widget-Update
    /// aufgerufen, dort liegen Tages-km und Schalter ohnehin frisch vor.
    func pushStatus(distanceMeters: Double, trackingEnabled: Bool, highAccuracy: Bool) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isPaired else { return }
        try? WCSession.default.updateApplicationContext([
            "distanceMeters": distanceMeters,
            "trackingEnabled": trackingEnabled,
            "highAccuracy": highAccuracy,
            "updatedAt": Date()
        ])
    }

    private func handle(_ message: [String: Any]) {
        DispatchQueue.main.async {
            if let value = message["setTracking"] as? Bool {
                self.tracker?.trackingEnabled = value
            }
            if let value = message["setHighAccuracy"] as? Bool {
                self.tracker?.highAccuracy = value
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
