//
//  WatchSessionBridge.swift
//  FlightMate
//
//  Brücke zur Watch-App (Flug-Begleiter): schickt Drohnenprofil und
//  Wetter-Anker als ApplicationContext ans Handgelenk und nimmt
//  fertige Flüge entgegen — daraus entsteht automatisch ein
//  Logbuch-Eintrag (Datum/Uhrzeit, Dauer und Akkuzahl in den
//  Notizen, Ort falls die Watch einen hatte).
//

import Foundation
import CoreLocation
import WatchConnectivity

final class WatchSessionBridge: NSObject, WCSessionDelegate {
    static let shared = WatchSessionBridge()

    static func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = shared
        WCSession.default.activate()
    }

    /// Profil + Wetter-Anker an die Watch geben (letzter Stand gewinnt).
    static func pushContext(profile: DroneProfile?, location: CLLocationCoordinate2D?) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        var context: [String: Any] = [:]
        if let profile {
            context["profileName"] = profile.name
            context["maxWindKmh"] = profile.maxWindKmh
            context["nominalFlightMinutes"] = profile.nominalFlightMinutes
        }
        if let location {
            context["lat"] = location.latitude
            context["lon"] = location.longitude
        }
        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// Fertiger Flug von der Watch → Logbuch-Eintrag. transferUserInfo
    /// liefert auch nach, wenn die iPhone-App erst später startet.
    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo["type"] as? String == "flight",
              let start = userInfo["start"] as? TimeInterval,
              let duration = userInfo["durationS"] as? TimeInterval else { return }
        let batteries = userInfo["batteries"] as? Int ?? 1
        let lat = userInfo["lat"] as? Double
        let lon = userInfo["lon"] as? Double
        DispatchQueue.main.async {
            var entry = FlightLogEntry()
            entry.date = Date(timeIntervalSince1970: start)
            let minutes = max(1, Int((duration / 60).rounded()))
            entry.notes = "Vom Watch-Flugbegleiter: \(minutes) min Flugzeit, "
                + "\(batteries) Akku\(batteries == 1 ? "" : "s")."
            entry.latitude = lat
            entry.longitude = lon
            FlightLog.save(entry)
        }
    }
}
