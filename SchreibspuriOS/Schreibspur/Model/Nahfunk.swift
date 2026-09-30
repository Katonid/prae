import Foundation
import MultipeerConnectivity
import UIKit

/// Funk im Klassenzimmer (seit 1.0.13): Kinder- und Lehrergerät tauschen
/// direkt Daten aus — über Bluetooth und WLAN zwischen den Geräten, auch
/// wenn das Schulnetz Geräte voneinander trennt, und **ohne Apple-ID**.
///
/// Das ist der Weg für den **Gast auf dem geteilten iPad**: Er hat kein
/// iCloud und kann nichts hochladen. Solange das Lehrergerät im Raum ist
/// und Schreibspur dort offen ist, gehen seine Seiten direkt dorthin. Für
/// alle anderen ist es der zweite Weg neben dem Briefkasten in iCloud
/// (kein Netz, iCloud gestört).
///
/// * Lehrergerät: kündigt sich an (`MCNearbyServiceAdvertiser`) mit den
///   Codes seiner Klassen; nimmt Kinder dieser Klassen an.
/// * Kindergerät: sucht (`MCNearbyServiceBrowser`) ein Lehrergerät mit
///   seinem Code und verbindet sich.
/// * Zweites Lehrergerät: sucht ein Lehrergerät, um mit der dort gezeigten
///   Zahl den Schlüssel zu übernehmen.
///
/// Die Verbindung ist verschlüsselt (`.required`); was ein Kind schickt,
/// ist zusätzlich für die Lehrkraft verschlüsselt (`Umschlag`).
final class Nahfunk: NSObject, @unchecked Sendable {
    static let dienst = "schreibspur"

    enum Art {
        /// Kündigt Klassen an (Codes).
        case lehrer(codes: [String])
        /// Sucht das Lehrergerät dieser Klasse.
        case kind(code: String)
        /// Sucht irgendein Lehrergerät (Schlüssel übernehmen).
        case uebernahme
    }

    /// Kommt auf dem Hauptfaden an: Nachricht und von wem.
    var empfangen: (@MainActor (Nachricht, MCPeerID) -> Void)?
    /// Verbunden / getrennt (Hauptfaden).
    var verbunden: (@MainActor (MCPeerID) -> Void)?
    var getrennt: (@MainActor (MCPeerID) -> Void)?

    private let ich: MCPeerID
    private let session: MCSession
    private var ankuendigung: MCNearbyServiceAdvertiser?
    private var suche: MCNearbyServiceBrowser?
    private(set) var art: Art

    init(_ art: Art) {
        self.art = art
        let name: String
        switch art {
        case .lehrer: name = "Lehrkraft"
        case .kind, .uebernahme: name = "Schreibspur-\(Int.random(in: 1000...9999))"
        }
        ich = MCPeerID(displayName: name)
        session = MCSession(peer: ich, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    var gegenueber: [MCPeerID] { session.connectedPeers }

    func starten() {
        stoppen()
        switch art {
        case .lehrer(let codes):
            // Die Codes stehen in der Ankündigung; so verbindet sich ein
            // Kind nur mit dem Gerät seiner Lehrkraft.
            let a = MCNearbyServiceAdvertiser(peer: ich, discoveryInfo: ["c": codes.joined(separator: ","), "l": "1"],
                                              serviceType: Self.dienst)
            a.delegate = self
            a.startAdvertisingPeer()
            ankuendigung = a
        case .kind, .uebernahme:
            let b = MCNearbyServiceBrowser(peer: ich, serviceType: Self.dienst)
            b.delegate = self
            b.startBrowsingForPeers()
            suche = b
        }
    }

    /// Lehrergerät: neue oder gelöschte Klasse — neu ankündigen.
    func codesAendern(_ codes: [String]) {
        art = .lehrer(codes: codes)
        ankuendigung?.stopAdvertisingPeer()
        ankuendigung = nil
        starten()
    }

    func stoppen() {
        ankuendigung?.stopAdvertisingPeer()
        suche?.stopBrowsingForPeers()
        ankuendigung = nil
        suche = nil
    }

    func beenden() {
        stoppen()
        session.disconnect()
    }

    func senden(_ n: Nachricht, an: [MCPeerID]? = nil) {
        let ziele = an ?? session.connectedPeers
        guard !ziele.isEmpty, let daten = try? JSONEncoder().encode(n) else { return }
        try? session.send(daten, toPeers: ziele, with: .reliable)
    }
}

extension Nahfunk: MCSessionDelegate {
    func session(_ session: MCSession, peer: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected: self.verbunden?(peer)
            case .notConnected: self.getrennt?(peer)
            default: break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peer: MCPeerID) {
        guard let n = try? JSONDecoder().decode(Nachricht.self, from: data) else { return }
        Task { @MainActor in self.empfangen?(n, peer) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension Nahfunk: MCNearbyServiceAdvertiserDelegate {
    /// Lehrergerät: Kinder der eigenen Klassen und andere Lehrergeräte
    /// (für die Übernahme — die prüft dann die Zahl) annehmen.
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peer: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let wunsch = context.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        guard case .lehrer(let codes) = art, codes.contains(wunsch) || wunsch == "uebernahme" else {
            invitationHandler(false, nil)
            return
        }
        invitationHandler(true, session)
    }
}

extension Nahfunk: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peer: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard info?["l"] == "1", !session.connectedPeers.contains(peer) else { return }
        let codes = (info?["c"] ?? "").split(separator: ",").map(String.init)
        switch art {
        case .kind(let code):
            guard codes.contains(code) else { return }
            browser.invitePeer(peer, to: session, withContext: Data(code.utf8), timeout: 20)
        case .uebernahme:
            browser.invitePeer(peer, to: session, withContext: Data("uebernahme".utf8), timeout: 20)
        case .lehrer:
            break
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
