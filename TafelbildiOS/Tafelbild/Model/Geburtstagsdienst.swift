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
//
// **Weggeräumtes bleibt weg.** Umgekehrt gilt dasselbe: Wer eine Seite
// löscht, hat sie gelöscht. Ohne einen Merker wäre das folgenlos, solange
// der Geburtstag noch läuft — der Dienst sähe beim nächsten Aktivwerden
// nach, fände die Seite nicht und legte sie wieder an. Genau das ist
// aufgefallen (Nutzer, 08/2026). Deshalb `Board.geburtstagWeg`.

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
        guard let stand = board(boardID), stand.geburtstage else { return }
        guard let listeID = stand.geburtstagslisteID(vorhanden: nameLists),
              let liste = nameLists.first(where: { $0.id == listeID }) else { return }

        let jahr = Calendar.current.component(.year, from: heute)
        let feiernde = Geburtstage.feiernde(in: liste, am: heute)
        guard !feiernde.isEmpty else { return }

        let ich = myUserID ?? ""
        var etwasGetan = false

        aendere(boardID) { tafel in
            // Eine Tafel ohne ausdrückliche Seiten hat genau eine — die muss
            // stehen, bevor eine zweite dazukommt.
            if tafel.pages.isEmpty {
                tafel.pages = [BoardPage(name: "", drawing: tafel.drawing)]
            }
            // Welche Feiern zuletzt liefen — damit sich nicht zwei Kinder am
            // selben Tag dasselbe teilen.
            var bisher = tafel.widgets.compactMap { widget -> String? in
                if case .geburtstag(let inhalt) = widget.content { return inhalt.feier }
                return nil
            }
            // Dasselbe für die Fanfare: Zwei Kinder am selben Tag sollen
            // nicht dieselbe bekommen.
            var bisherigeFanfaren = tafel.widgets.compactMap { widget -> String? in
                if case .geburtstag(let inhalt) = widget.content, !inhalt.hinweis {
                    return inhalt.fanfare
                }
                return nil
            }

            for eintrag in feiernde {
                // Steht die Seite für dieses Kind und dieses Jahr schon?
                let schonDa = tafel.widgets.contains { widget in
                    guard case .geburtstag(let inhalt) = widget.content else { return false }
                    return inhalt.eintragID == eintrag.id && inhalt.jahr == jahr && !inhalt.hinweis
                }
                if schonDa { continue }
                // Von Hand weggeräumt heißt weggeräumt — auch am
                // Geburtstag selbst.
                if tafel.geburtstagWeg.contains(Geburtstagsmerker.feier(eintrag.id, jahr)) {
                    continue
                }

                Self.legeSeiteAn(auf: &tafel, eintrag: eintrag, jahr: jahr,
                                 nachgefeiert: false, bisher: &bisher,
                                 fanfaren: &bisherigeFanfaren, ich: ich)
                etwasGetan = true
            }
        }

        if etwasGetan { touch(boardID) }
    }

    /// Eine Geburtstagsseite anlegen — für heute oder nachträglich.
    ///
    /// `static` und mit `inout`, aus demselben Grund wie `setzeHinweis`:
    /// Sie läuft innerhalb von `aendere`, und dort ist die Tafel schon
    /// ausgeliehen.
    private static func legeSeiteAn(auf tafel: inout Board, eintrag: NameEntry,
                                    jahr: Int, nachgefeiert: Bool,
                                    bisher: inout [String], fanfaren: inout [String],
                                    ich: String) {
        let art = Feierart.naechste(nach: bisher)
        bisher.append(art.rawValue)
        let klang = Fanfare.naechste(nach: fanfaren)
        fanfaren.append(klang.rawValue)

        var seite = BoardPage()
        seite.name = "🎂 " + (eintrag.text.nonEmpty ?? "Geburtstag")
        tafel.pages.append(seite)

        var inhalt = GeburtstagContent()
        inhalt.eintragID = eintrag.id
        inhalt.name = eintrag.text
        inhalt.geburtstag = eintrag.geburtstag
        inhalt.jahr = jahr
        inhalt.feier = art.rawValue
        inhalt.fanfare = klang.rawValue
        inhalt.nachgefeiert = nachgefeiert

        var element = BoardWidget(content: .geburtstag(inhalt))
        let masse = WidgetKind.geburtstag.defaultSize
        element.width = masse.width
        element.height = masse.height
        element.x = (Layout.canvasWidth - masse.width) / 2
        element.y = (tafel.hoehe - masse.height) / 2
        element.z = (tafel.widgets.map(\.z).max() ?? 0) + 1
        element.pageID = seite.id
        element.erstelltVon = ich
        element.clampToCanvas(hoehe: tafel.hoehe)
        tafel.widgets.append(element)

        setzeHinweis(auf: &tafel, eintrag: eintrag, jahr: jahr,
                     zielSeite: seite.id, ich: ich)
    }

    // MARK: - Nachfeiern

    /// Legt Seiten für Geburtstage an, die schon waren.
    ///
    /// **Der Fall aus dem echten Leben**: Nach sechs Wochen Ferien hatte
    /// die halbe Klasse Geburtstag, und am ersten Schultag soll das
    /// nachgeholt werden. Von selbst passiert das nicht — der Dienst sieht
    /// immer nur den heutigen Tag an, und das ist auch richtig so: Sonst
    /// bekäme ein iPad, das drei Wochen im Schrank stand, beim Einschalten
    /// zwanzig Seiten auf einmal.
    ///
    /// Deshalb wird ausdrücklich gewählt, wer nachfeiert.
    ///
    /// **Das Jahr kommt vom tatsächlichen Geburtstag**, nicht von heute.
    /// Ein Kind, das im Dezember sieben wurde und im Januar nachfeiert,
    /// wird sonst acht.
    func legeNachfeierAn(boardID: String, wen: [Geburtstage.Vergangen]) {
        guard !wen.isEmpty, let stand = board(boardID), stand.geburtstage else { return }
        let ich = myUserID ?? ""

        aendere(boardID) { tafel in
            if tafel.pages.isEmpty {
                tafel.pages = [BoardPage(name: "", drawing: tafel.drawing)]
            }
            var bisher = tafel.widgets.compactMap { widget -> String? in
                if case .geburtstag(let inhalt) = widget.content { return inhalt.feier }
                return nil
            }
            var fanfaren = tafel.widgets.compactMap { widget -> String? in
                if case .geburtstag(let inhalt) = widget.content, !inhalt.hinweis {
                    return inhalt.fanfare
                }
                return nil
            }

            for fall in wen {
                let schonDa = tafel.widgets.contains { widget in
                    guard case .geburtstag(let inhalt) = widget.content else { return false }
                    return inhalt.eintragID == fall.eintrag.id
                        && inhalt.jahr == fall.jahr && !inhalt.hinweis
                }
                if schonDa { continue }
                // Ein von Hand weggeräumter Geburtstag kommt auch hier
                // nicht zurück — es sei denn, er wird ausdrücklich noch
                // einmal gewählt. Genau das tut diese Liste, also wird der
                // Merker zurückgenommen.
                tafel.geburtstagWeg.removeAll {
                    $0 == Geburtstagsmerker.feier(fall.eintrag.id, fall.jahr)
                        || $0 == Geburtstagsmerker.hinweis(fall.eintrag.id, fall.jahr)
                }
                Self.legeSeiteAn(auf: &tafel, eintrag: fall.eintrag, jahr: fall.jahr,
                                 nachgefeiert: true, bisher: &bisher,
                                 fanfaren: &fanfaren, ich: ich)
            }
        }
        touch(boardID)
    }

    /// Der kleine Hinweis auf der ersten Seite, der zur Feier führt.
    ///
    /// `static` und mit `inout`: Er läuft innerhalb von `aendere`, und dort
    /// ist die Tafel schon ausgeliehen — ein zweiter Zugriff über `boards`
    /// wäre ein Zugriff auf denselben Wert.
    private static func setzeHinweis(auf tafel: inout Board, eintrag: NameEntry,
                                     jahr: Int, zielSeite: String, ich: String) {
        let ersteSeite = tafel.ersteSeitenID
        let schonDa = tafel.widgets.contains { widget in
            guard case .geburtstag(let inhalt) = widget.content else { return false }
            return inhalt.hinweis && inhalt.eintragID == eintrag.id && inhalt.jahr == jahr
        }
        guard !schonDa else { return }
        guard !tafel.geburtstagWeg.contains(Geburtstagsmerker.hinweis(eintrag.id, jahr))
        else { return }

        var inhalt = GeburtstagContent()
        inhalt.eintragID = eintrag.id
        inhalt.name = eintrag.text
        inhalt.geburtstag = eintrag.geburtstag
        inhalt.jahr = jahr
        inhalt.hinweis = true
        inhalt.zielSeite = zielSeite

        var element = BoardWidget(content: .geburtstag(inhalt))
        // Schmaler als früher (380): Auf dem Kärtchen steht ein Vorname
        // und zwei Wörter, mehr nicht — und mit der neuen Schrift, die die
        // Karte füllt, war die alte Breite deutlich zu viel (gemeldet
        // 08/2026). Größer ziehen geht ja jederzeit.
        element.width = 280
        element.height = 110
        // Oben rechts, wo sonst nichts steht — und wo es auffällt, ohne
        // etwas zu verdecken.
        element.x = Layout.canvasWidth - 280 - 40
        // Untereinander, wenn mehrere Kinder feiern.
        let schonHinweise = tafel.widgets.filter { widget in
            if case .geburtstag(let i) = widget.content { return i.hinweis }
            return false
        }.count
        element.y = 40 + Double(schonHinweise) * 126
        element.z = (tafel.widgets.map(\.z).max() ?? 0) + 1
        element.pageID = ersteSeite
        element.erstelltVon = ich
        element.karte = .nie
        element.clampToCanvas(hoehe: tafel.hoehe)
        tafel.widgets.append(element)
    }

    /// Nimmt alle Merker zurück und sieht sofort neu nach.
    ///
    /// Der Rückweg zum Löschen: Wer eine Seite versehentlich weggeräumt
    /// hat, bekommt sie damit zurück — aber nur, wenn der Geburtstag noch
    /// läuft. Ein Geburtstag von gestern kommt auch so nicht wieder; die
    /// Seite war ab dem Tag danach eine gewöhnliche Seite und ist es
    /// geblieben.
    func geburtstageWiederAnlegen(boardID: String) {
        aendere(boardID) { tafel in tafel.geburtstagWeg = [] }
        touch(boardID)
        legeGeburtstagsseitenAn(boardID: boardID)
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
        // Die Zentrale im Rückruf frisch holen statt sie einzufangen: Sie
        // ist nicht als über Fäden hinweg sicher gekennzeichnet, und
        // `current()` gibt ohnehin immer dieselbe zurück.
        zentrale.getPendingNotificationRequests { offen in
            let alte = offen.map(\.identifier).filter { $0.hasPrefix("geburtstag-") }
            guard !alte.isEmpty else { return }
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: alte)
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
