import Foundation
import UserNotifications

// Der Teil, der von selbst passiert: Seiten anlegen, Hinweis setzen,
// erinnern.
//
// **Gerechnet, nicht vorgemerkt.** Beim Aktivwerden der App sieht der Dienst
// nach, wer heute Geburtstag hat, und legt an, was fehlt. Eine Warteschlange
// künftiger Seiten wäre falsch: Datteln ändern sich, Kinder wechseln die
// Klasse, und ein iPad steht schon mal drei Wochen im Schrank. Was zählt,
// ist immer der heutige Tag und die Liste, wie sie jetzt aussieht.
//
// **Angelegtes bleibt.** Eine Seite, die einmal steht, wird nie automatisch
// entfernt — Ansage des Nutzers. Sie ist danach eine gewöhnliche Seite: Sie
// lässt sich bearbeiten, beschreiben und irgendwann von Hand löschen.

extension BoardStore {

    // MARK: - Nachsehen und anlegen

    /// Sieht für alle Tafeln nach, ob heute jemand feiert.
    ///
    /// Gerufen beim Aktivwerden der App und nach jedem Abgleich — beides
    /// billig, weil ohne Geburtstage sofort wieder herausgesprungen wird.
    func pruefeGeburtstage(heute: Date = Date()) {
        for board in boards where board.geburtstage && !board.deleted {
            legeGeburtstagsseitenAn(boardID: board.id, heute: heute)
        }
        planeGeburtstagsmeldungen()
    }

    /// Legt für jedes Kind, das heute feiert, eine Seite an — falls sie
    /// nicht schon steht.
    func legeGeburtstagsseitenAn(boardID: String, heute: Date = Date()) {
        guard let stelle = boards.firstIndex(where: { $0.id == boardID }) else { return }
        guard boards[stelle].geburtstage else { return }
        guard let listeID = boards[stelle].geburtstagslisteID(vorhanden: nameLists),
              let liste = nameLists.first(where: { $0.id == listeID }) else { return }

        let jahr = Calendar.current.component(.year, from: heute)
        let feiernde = Geburtstage.feiernde(in: liste, am: heute)
        guard !feiernde.isEmpty else { return }

        stelleSeitenSicher(stelle)
        var etwasGetan = false
        // Welche Feiern zuletzt liefen — damit sich nicht zwei Kinder am
        // selben Tag dasselbe teilen.
        var bisher = boards[stelle].widgets.compactMap { widget -> String? in
            if case .geburtstag(let inhalt) = widget.content { return inhalt.feier }
            return nil
        }

        for eintrag in feiernde {
            // Steht die Seite für dieses Kind und dieses Jahr schon?
            let schonDa = boards[stelle].widgets.contains { widget in
                guard case .geburtstag(let inhalt) = widget.content else { return false }
                return inhalt.eintragID == eintrag.id && inhalt.jahr == jahr && !inhalt.hinweis
            }
            if schonDa { continue }

            let art = Feierart.naechste(nach: bisher)
            bisher.append(art.rawValue)

            var seite = BoardPage()
            seite.name = "🎂 " + (eintrag.text.nonEmpty ?? "Geburtstag")
            boards[stelle].pages.append(seite)

            var inhalt = GeburtstagContent()
            inhalt.eintragID = eintrag.id
            inhalt.name = eintrag.text
            inhalt.geburtstag = eintrag.geburtstag
            inhalt.jahr = jahr
            inhalt.feier = art.rawValue

            var element = BoardWidget(content: .geburtstag(inhalt))
            let masse = WidgetKind.geburtstag.defaultSize
            element.width = masse.width
            element.height = masse.height
            element.x = (Layout.canvasWidth - masse.width) / 2
            element.y = (boards[stelle].hoehe - masse.height) / 2
            element.z = (boards[stelle].widgets.map(\.z).max() ?? 0) + 1
            element.pageID = seite.id
            element.erstelltVon = myUserID ?? ""
            element.clampToCanvas(hoehe: boards[stelle].hoehe)
            boards[stelle].widgets.append(element)

            setzeHinweis(stelle: stelle, eintrag: eintrag, jahr: jahr, zielSeite: seite.id)
            etwasGetan = true
        }

        if etwasGetan { touch(boardID) }
    }

    /// Der kleine Hinweis auf der ersten Seite, der zur Feier führt.
    private func setzeHinweis(stelle: Int, eintrag: NameEntry, jahr: Int, zielSeite: String) {
        let ersteSeite = boards[stelle].ersteSeitenID
        let schonDa = boards[stelle].widgets.contains { widget in
            guard case .geburtstag(let inhalt) = widget.content else { return false }
            return inhalt.hinweis && inhalt.eintragID == eintrag.id && inhalt.jahr == jahr
        }
        guard !schonDa else { return }

        var inhalt = GeburtstagContent()
        inhalt.eintragID = eintrag.id
        inhalt.name = eintrag.text
        inhalt.geburtstag = eintrag.geburtstag
        inhalt.jahr = jahr
        inhalt.hinweis = true
        inhalt.zielSeite = zielSeite

        var element = BoardWidget(content: .geburtstag(inhalt))
        element.width = 380
        element.height = 110
        // Oben rechts, wo sonst nichts steht — und wo es auffällt, ohne
        // etwas zu verdecken.
        element.x = Layout.canvasWidth - 380 - 40
        // Untereinander, wenn mehrere Kinder feiern.
        let schonHinweise = boards[stelle].widgets.filter { widget in
            if case .geburtstag(let i) = widget.content { return i.hinweis }
            return false
        }.count
        element.y = 40 + Double(schonHinweise) * 126
        element.z = (boards[stelle].widgets.map(\.z).max() ?? 0) + 1
        element.pageID = ersteSeite
        element.erstelltVon = myUserID ?? ""
        element.karte = .nie
        element.clampToCanvas(hoehe: boards[stelle].hoehe)
        boards[stelle].widgets.append(element)
    }

    /// Zeigt eine Seite — der Hinweis springt damit zur Feier.
    func zeigeSeite(_ seite: String, auf boardID: String) {
        guard let board = board(boardID),
              board.seiten.contains(where: { $0.id == seite }) else { return }
        if activeBoardID != boardID { activeBoardID = boardID }
        aktiveSeitenID = seite
        selectedWidgetID = nil
    }

    // MARK: - Erinnern

    /// Merkt für jede Tafel die nächsten Geburtstage bei iOS vor.
    ///
    /// Nur die nächsten dreißig Tage und höchstens zwanzig Meldungen: iOS
    /// nimmt je App nur 64 vorgemerkte Meldungen an, und die teilen sich
    /// Geburtstage mit den Timern. Beim nächsten Öffnen wird ohnehin neu
    /// geplant — es muss also nicht das ganze Jahr im Voraus stehen.
    func planeGeburtstagsmeldungen(heute: Date = Date()) {
        let zentrale = UNUserNotificationCenter.current()
        zentrale.getPendingNotificationRequests { offen in
            let alte = offen.map(\.identifier).filter { $0.hasPrefix("geburtstag-") }
            zentrale.removePendingNotificationRequests(withIdentifiers: alte)
        }

        guard Weckdienst.shared.erlaubnis == .erlaubt else { return }
        let kalender = Calendar.current
        var geplant = 0

        for board in boards where board.geburtstage && !board.deleted {
            let regel = Geburtstagserinnerung.aus(board.geburtstagsErinnerung)
            guard regel != .aus else { continue }
            guard let listeID = board.geburtstagslisteID(vorhanden: nameLists),
                  let liste = nameLists.first(where: { $0.id == listeID }) else { continue }

            let minuten = regel == .amVortag ? board.geburtstagsZeitVortag : board.geburtstagsZeit

            for eintrag in liste.entries {
                guard geplant < 20 else { break }
                guard let naechster = Geburtstage.naechster(eintrag, ab: heute) else { continue }
                guard let melden = kalender.date(byAdding: .day,
                                                 value: -regel.tageVorher,
                                                 to: naechster) else { continue }
                var wann = kalender.dateComponents([.year, .month, .day], from: melden)
                wann.hour = minuten / 60
                wann.minute = minuten % 60
                guard let zeitpunkt = kalender.date(from: wann),
                      zeitpunkt > heute,
                      zeitpunkt.timeIntervalSince(heute) < 30 * 24 * 3600 else { continue }

                let text = UNMutableNotificationContent()
                text.title = board.name.nonEmpty ?? "Tafelbild"
                let name = eintrag.text.nonEmpty ?? "Ein Kind"
                if regel == .amVortag {
                    text.body = "\(name) hat morgen Geburtstag."
                } else if let alter = alterAm(naechster, geboren: eintrag.geburtstag) {
                    text.body = "\(name) wird heute \(alter)."
                } else {
                    text.body = "\(name) hat heute Geburtstag."
                }
                text.sound = .default

                let anstoss = UNCalendarNotificationTrigger(dateMatching: wann, repeats: false)
                zentrale.add(UNNotificationRequest(
                    identifier: "geburtstag-\(board.id)-\(eintrag.id)-\(kalender.component(.year, from: naechster))",
                    content: text, trigger: anstoss))
                geplant += 1
            }
        }
    }

    private func alterAm(_ tag: Date, geboren: String) -> Int? {
        guard let datum = Geburtstage.datum(geboren) else { return nil }
        let jahre = Calendar.current.dateComponents([.year], from: datum, to: tag).year
        guard let jahre, (1...130).contains(jahre) else { return nil }
        return jahre
    }
}
