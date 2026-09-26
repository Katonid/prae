import CoreData
import CloudKit
import Foundation

// WAS DER iCLOUD-ABGLEICH GERADE TUT (ab 1.0.22, gemeldet 09/2026: „eine auf
// dem iPad angelegte Reise [wurde] nicht aufs iPhone übertragen. Bei beiden
// ist jedoch der iCloud Sync aktiviert.").
//
// `NSPersistentCloudKitContainer` gleicht still ab — und scheitert still.
// Bis 1.0.21 sah man davon nichts; die Einstellungen sagten nur „iCloud:
// Angemeldet". Hier werden seine Ereignisse mitgeschrieben
// (`eventChangedNotification`): je Richtung (Einrichten, Senden, Empfangen)
// und Speicher (privat, geteilt) der letzte Lauf, ob er gelang, und wenn
// nicht, Apples Fehlermeldung ROH — die Ursache steht darin, und sie zu
// deuten, bevor man sie gesehen hat, wäre geraten.
//
// Die zwei häufigsten Ursachen dafür, dass zwei Geräte einander nicht sehen,
// lassen sich damit unterscheiden:
// 1. **Zwei Umgebungen.** Ein aus Xcode installierter Bau spricht mit der
//    CloudKit-ENTWICKLUNGSumgebung, TestFlight und App Store mit der
//    PRODUKTIONSumgebung — zwei getrennte Datenbanken. Die Zeile „Umgebung"
//    sagt, welche.
// 2. **Schema nicht in Produktion.** Ein Datensatz mit einem Feld, das in
//    der Produktion fehlt, wird abgewiesen; das Senden scheitert dann bei
//    JEDEM Lauf mit einer Meldung, die den Feldnamen nennt (`CD_…`).
@MainActor
final class Abgleichstatus: ObservableObject {
    static let shared = Abgleichstatus()

    struct Lauf: Identifiable {
        let art: String
        let speicher: String
        let ende: Date?
        let fehler: String?
        var id: String { art + speicher }
    }

    @Published private(set) var laeufe: [String: Lauf] = [:]

    /// Die CloudKit-Umgebung dieses Baus.
    static var umgebung: String {
        #if DEBUG
        return "Entwicklung (von Xcode installiert)"
        #else
        return "Produktion (TestFlight / App Store)"
        #endif
    }

    private var beobachter: NSObjectProtocol?

    func beobachten() {
        guard beobachter == nil else { return }
        beobachter = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: Persistenz.shared.container, queue: .main
        ) { [weak self] meldung in
            guard let ereignis = meldung.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            let art: String
            switch ereignis.type {
            case .setup: art = "Einrichten"
            case .import: art = "Empfangen"
            case .export: art = "Senden"
            @unknown default: art = "Anderes"
            }
            let persistenz = Persistenz.shared
            let speicher = ereignis.storeIdentifier == persistenz.geteilterSpeicher?.identifier ? "geteilt" : "privat"
            let fehler = ereignis.error.map { Self.beschreibung($0) }
            let lauf = Lauf(art: art, speicher: speicher, ende: ereignis.endDate, fehler: fehler)
            MainActor.assumeIsolated {
                // Ein laufendes Ereignis (ohne Ende) überschreibt keinen
                // abgeschlossenen Fehler — sonst verschwände die Meldung,
                // sobald der nächste Versuch beginnt.
                if lauf.ende == nil, self?.laeufe[lauf.id]?.fehler != nil { return }
                self?.laeufe[lauf.id] = lauf
            }
        }
    }

    /// Die Laufliste in fester Reihenfolge.
    var liste: [Lauf] {
        let reihe = ["Einrichten", "Senden", "Empfangen"]
        return laeufe.values.sorted {
            ($0.speicher, reihe.firstIndex(of: $0.art) ?? 9) < ($1.speicher, reihe.firstIndex(of: $1.art) ?? 9)
        }
    }

    var hatFehler: Bool { laeufe.values.contains { $0.fehler != nil } }

    /// Apples Meldung samt den Teilfehlern einzelner Datensätze — dort steht
    /// bei einem fehlenden Schema der Feldname.
    nonisolated static func beschreibung(_ fehler: Error) -> String {
        var teile = [fehler.localizedDescription]
        if let ck = fehler as? CKError {
            teile.append("CKError \(ck.code.rawValue)")
            if let einzeln = ck.partialErrorsByItemID?.values.prefix(3) {
                for e in einzeln { teile.append(e.localizedDescription) }
            }
        }
        let ns = fehler as NSError
        if let unter = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            teile.append(unter.localizedDescription)
        }
        var gesehen: [String] = []
        for t in teile where !gesehen.contains(t) { gesehen.append(t) }
        return gesehen.joined(separator: " — ")
    }

    /// Ein Hinweis, WAS zu tun ist — nur, wo die Meldung es erkennen lässt.
    static func rat(_ fehler: String) -> String? {
        let f = fehler.lowercased()
        if f.contains("cd_") || f.contains("schema") || f.contains("record type") || f.contains("field") {
            return "Das sieht nach einem Schema aus, das in der Produktion fehlt: Mit Xcode einen Debug-Bau starten → Einstellungen → „CloudKit-Schema anlegen“, dann in der CloudKit-Konsole „Deploy Schema Changes to Production“."
        }
        if f.contains("quota") {
            return "Der iCloud-Speicher ist voll."
        }
        if f.contains("not authenticated") || f.contains("account") {
            return "Das Gerät ist nicht (mehr) bei iCloud angemeldet oder iCloud Drive ist für Fernweh aus."
        }
        return nil
    }
}
