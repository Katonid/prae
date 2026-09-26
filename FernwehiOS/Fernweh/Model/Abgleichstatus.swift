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
    ///
    /// Ab 1.0.23 TIEFER (gemeldet 09/2026 mit zwei Bildschirmfotos: auf
    /// iPad UND iPhone „Senden (privat) gescheitert … CKErrorDomain-Fehler 2"
    /// — mehr nicht). Code 2 ist `partialFailure`, ein Sammelfehler; die
    /// Ursache steckt in den Teilfehlern, und deren `localizedDescription` ist
    /// ebenso nichtssagend. Die Begründung des SERVERS steht im
    /// `NSDebugDescription` bzw. „ServerErrorDescription" der `userInfo`.
    /// Gesammelt wird deshalb rekursiv: Code, Serverbegründung, Teilfehler
    /// (je Datensatztyp/-name), darunterliegende Fehler.
    nonisolated static func beschreibung(_ fehler: Error) -> String {
        var teile: [String] = []
        sammeln(fehler, in: &teile, tiefe: 0)
        var gesehen: [String] = []
        for t in teile where !t.isEmpty && !gesehen.contains(t) { gesehen.append(t) }
        var text = gesehen.prefix(12).joined(separator: "\n")
        // ROH dazu (ab 1.0.25, gemeldet 26.09.2026: 1.0.24 zeigte nur
        // „CKError 2 (Teilfehler)" — die Teilfehler standen NICHT unter
        // `CKPartialErrorsByItemIDKey`, wo sie erwartet waren). Die
        // Beschreibung eines CKError listet selbst alle Schlüssel seiner
        // `userInfo` samt Teilfehlern; sie wird deshalb ungedeutet
        // angehängt, dazu die Namen der Schlüssel. Deuten kommt danach.
        let ns = fehler as NSError
        let schluessel = ns.userInfo.keys.map { "\($0)" }.sorted().joined(separator: ", ")
        text += "\n— Schlüssel: " + (schluessel.isEmpty ? "keine" : schluessel)
        text += "\n— Roh: " + String(String(describing: fehler).prefix(3000))
        return text
    }

    nonisolated private static func sammeln(_ fehler: Error, in teile: inout [String], tiefe: Int) {
        guard tiefe < 4 else { return }
        let ns = fehler as NSError
        var zeile = ns.domain == CKError.errorDomain
            ? "CKError \(ns.code) (\(codename(ns.code)))"
            : "\(ns.domain) \(ns.code)"
        for schluessel in [NSDebugDescriptionErrorKey, "ServerErrorDescription", "CKErrorDescription",
                           NSLocalizedFailureReasonErrorKey] {
            if let text = ns.userInfo[schluessel] as? String, !text.isEmpty { zeile += ": " + text; break }
        }
        teile.append(zeile)
        var einzeln: [AnyHashable: Error] = [:]
        if let roh = ns.userInfo[CKPartialErrorsByItemIDKey] as? NSDictionary {
            for (k, v) in roh {
                if let schluessel = k as? AnyHashable, let e = v as? Error { einzeln[schluessel] = e }
            }
        }
        if !einzeln.isEmpty {
            // Gleiche Ursachen zusammenfassen: dieselbe Meldung für hundert
            // Datensätze ist EINE Zeile.
            var nachArt: [String: Int] = [:]
            var ersteZeilen: [String] = []
            for (schluessel, e) in einzeln {
                var unter: [String] = []
                sammeln(e, in: &unter, tiefe: tiefe + 1)
                let wo = (schluessel as? CKRecord.ID)?.recordName ?? "\(schluessel)"
                let text = unter.joined(separator: " / ")
                if nachArt[text] == nil { ersteZeilen.append("• \(text) — z. B. \(wo)") }
                nachArt[text, default: 0] += 1
            }
            for z in ersteZeilen.prefix(4) { teile.append(z) }
            teile.append("(\(einzeln.count) Datensätze betroffen, \(nachArt.count) verschiedene Ursachen)")
        }
        if let unter = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            sammeln(unter, in: &teile, tiefe: tiefe + 1)
        }
        if let mehrere = ns.userInfo[NSDetailedErrorsKey] as? [Error] {
            for e in mehrere.prefix(3) { sammeln(e, in: &teile, tiefe: tiefe + 1) }
        }
    }

    nonisolated private static func codename(_ code: Int) -> String {
        switch CKError.Code(rawValue: code) {
        case .partialFailure: return "Teilfehler"
        case .invalidArguments: return "ungültige Angaben — oft: Feld fehlt im Produktionsschema"
        case .serverRejectedRequest: return "vom Server abgewiesen"
        case .batchRequestFailed: return "Stapel abgebrochen wegen eines anderen Datensatzes"
        case .quotaExceeded: return "iCloud-Speicher voll"
        case .limitExceeded: return "zu groß"
        case .assetFileNotFound: return "Bilddatei fehlt"
        case .zoneNotFound, .userDeletedZone: return "Zone fehlt"
        case .notAuthenticated: return "nicht angemeldet"
        case .permissionFailure: return "keine Berechtigung"
        case .serverRecordChanged: return "Datensatz geändert"
        case .unknownItem: return "unbekannter Datensatz"
        default: return "Code \(code)"
        }
    }

    /// Ein Hinweis, WAS zu tun ist — nur, wo die Meldung es erkennen lässt.
    static func rat(_ fehler: String) -> String? {
        let f = fehler.lowercased()
        if f.contains("cd_") || f.contains("schema") || f.contains("record type") || f.contains("field")
            || f.contains("ungültige angaben") {
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
