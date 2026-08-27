import Foundation
import UserNotifications

/// Schickt Mitteilungen auf den Sperrbildschirm.
///
/// Wichtig zum Verständnis: Das sind **örtliche** Mitteilungen, keine echten
/// Push-Nachrichten von einem Server. Die App hat keinen eigenen Server — sie
/// fragt football-data.org mit dem Schlüssel des Nutzers. Deshalb entstehen
/// Mitteilungen dort, wo die App den Spielstand vergleicht: im Vordergrund
/// sofort, im Hintergrund immer dann, wenn iOS der App eine Auffrischung
/// gewährt (siehe `Hintergrundpflege`).
enum Benachrichtiger {

    /// Erinnerungen an den Anpfiff sind der einzige Fall, der auf die Sekunde
    /// verlässlich ist: Die Anstoßzeit steht vorher fest, iOS stellt den
    /// Wecker selbst.
    private static let erinnerungsPraefix = "anstoss-erinnerung-"

    // MARK: Sofortmeldungen

    static func melden(_ meldungen: [Tickermeldung], wunsch: Meldungswunsch) {
        let passend = meldungen.filter {
            wunsch.arten.contains($0.art) && wunsch.meldetFuer(spielID: $0.spielID, liga: $0.liga)
        }
        guard !passend.isEmpty else { return }

        let zentrale = UNUserNotificationCenter.current()
        for meldung in passend.prefix(12) {
            let inhalt = UNMutableNotificationContent()
            inhalt.title = titel(meldung)
            inhalt.body = text(meldung)
            inhalt.sound = meldung.art == .tor ? .default : nil
            inhalt.threadIdentifier = "spiel-\(meldung.spielID)"
            inhalt.interruptionLevel = meldung.art == .tor ? .timeSensitive : .active

            // Die Kennung ist dieselbe wie die der Tickermeldung: Damit kann
            // dasselbe Ereignis nicht zweimal auf dem Sperrbildschirm landen,
            // auch wenn Vordergrund und Hintergrund es beide entdecken.
            let auftrag = UNNotificationRequest(identifier: "meldung-\(meldung.id)",
                                                content: inhalt,
                                                trigger: nil)
            zentrale.add(auftrag)
        }
    }

    private static func titel(_ meldung: Tickermeldung) -> String {
        switch meldung.art {
        case .tor:
            return "\(meldung.liga.flagge) Tor — \(meldung.stand)"
        case .anpfiff:
            return "\(meldung.liga.flagge) Anpfiff"
        case .halbzeit:
            return "\(meldung.liga.flagge) Halbzeit — \(meldung.stand)"
        case .abpfiff:
            return "\(meldung.liga.flagge) Endstand — \(meldung.stand)"
        }
    }

    private static func text(_ meldung: Tickermeldung) -> String {
        var teile = [meldung.paarung]
        if !meldung.minutentext.isEmpty { teile.append(meldung.minutentext) }
        if !meldung.zusatz.isEmpty, meldung.art == .tor {
            teile.append(meldung.zusatz)
        }
        return teile.joined(separator: " · ")
    }

    // MARK: Nachrichten rund um die Ligen

    /// Meldet Transfers, Gerüchte und dergleichen. Anders als beim Ticker
    /// gibt es hier eine Obergrenze je Durchgang: Eine Quelle, die zwanzig
    /// Meldungen auf einmal nachliefert, soll nicht zwanzig Mal klingeln.
    static func meldenNachrichten(_ nachrichten: [Nachricht], wunsch: Meldungswunsch) {
        let passend = nachrichten.filter(wunsch.meldetFuer)
        guard !passend.isEmpty else { return }

        let zentrale = UNUserNotificationCenter.current()
        for nachricht in passend.sorted(by: { $0.zeitpunkt > $1.zeitpunkt }).prefix(4) {
            let inhalt = UNMutableNotificationContent()
            let vorsatz = nachricht.liga.map { $0.flagge + " " } ?? ""
            inhalt.title = vorsatz + nachricht.art.name
            inhalt.subtitle = nachricht.titel
            inhalt.body = nachricht.anriss.isEmpty ? nachricht.quellenname
                : nachricht.anriss + " · " + nachricht.quellenname
            inhalt.sound = nil
            inhalt.interruptionLevel = .passive
            inhalt.threadIdentifier = "nachrichten"
            if let adresse = nachricht.adresse {
                inhalt.userInfo = ["adresse": adresse.absoluteString]
            }

            let auftrag = UNNotificationRequest(identifier: "nachricht-" + nachricht.id,
                                                content: inhalt,
                                                trigger: nil)
            zentrale.add(auftrag)
        }
    }

    // MARK: Erinnerung an den Anpfiff

    /// Stellt für jedes freigeschaltete Spiel einen Wecker. Alte Wecker
    /// werden vorher abgeräumt, damit abgesagte oder verlegte Spiele nicht
    /// als Karteileiche weiterlaufen.
    static func anstosserinnerungenPlanen(spiele: [Spiel], wunsch: Meldungswunsch) async {
        let zentrale = UNUserNotificationCenter.current()
        let offen = await zentrale.pendingNotificationRequests()
        let alte = offen.map(\.identifier).filter { $0.hasPrefix(erinnerungsPraefix) }
        zentrale.removePendingNotificationRequests(withIdentifiers: alte)

        guard wunsch.anstosserinnerung else { return }

        let vorlauf = TimeInterval(max(wunsch.vorlaufMinuten, 1) * 60)
        let kalender = Calendar.current

        for spiel in spiele where wunsch.meldetFuer(spiel) && spiel.status == .geplant {
            let weckzeit = spiel.anstoss.addingTimeInterval(-vorlauf)
            guard weckzeit > Date() else { continue }

            let inhalt = UNMutableNotificationContent()
            inhalt.title = "\(spiel.liga.flagge) Gleich geht es los"
            inhalt.body = "\(spiel.heim.anzeige) – \(spiel.gast.anzeige) · Anstoß "
                + Zeitformate.uhrzeit.string(from: spiel.anstoss) + " Uhr"
            inhalt.sound = .default
            inhalt.threadIdentifier = "spiel-\(spiel.id)"

            let teile = kalender.dateComponents([.year, .month, .day, .hour, .minute], from: weckzeit)
            let ausloeser = UNCalendarNotificationTrigger(dateMatching: teile, repeats: false)
            let auftrag = UNNotificationRequest(identifier: erinnerungsPraefix + String(spiel.id),
                                                content: inhalt,
                                                trigger: ausloeser)
            try? await zentrale.add(auftrag)
        }
    }

    // MARK: Aufräumen

    static func alleEntfernen() {
        let zentrale = UNUserNotificationCenter.current()
        zentrale.removeAllPendingNotificationRequests()
        zentrale.removeAllDeliveredNotifications()
    }
}
