import Foundation
import WatchConnectivity

/// Verbindung zum iPhone: Status empfangen (Tages-km, Schalter) und
/// die Aufzeichnung dort fernbedienen.
final class PhoneLink: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneLink()

    @Published var trackingEnabled: Bool?
    @Published var highAccuracy: Bool?
    @Published var phoneDistanceMeters: Double = 0
    @Published var statusDate: Date?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func setTracking(_ on: Bool) {
        trackingEnabled = on
        send(["setTracking": on])
    }

    func setHighAccuracy(_ on: Bool) {
        highAccuracy = on
        send(["setHighAccuracy": on])
    }

    /// Direktnachricht, wenn das iPhone erreichbar ist; sonst in die
    /// Warteschlange (wird bei nächster Verbindung zugestellt).
    private func send(_ message: [String: Any]) {
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        let context = session.receivedApplicationContext
        DispatchQueue.main.async { self.apply(context) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.apply(applicationContext) }
    }

    private func apply(_ context: [String: Any]) {
        guard !context.isEmpty else { return }
        trackingEnabled = context["trackingEnabled"] as? Bool
        highAccuracy = context["highAccuracy"] as? Bool
        phoneDistanceMeters = context["distanceMeters"] as? Double ?? 0
        statusDate = context["updatedAt"] as? Date
    }
}
