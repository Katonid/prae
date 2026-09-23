import Foundation

/// Eine Meldung der Autobahn GmbH: Stau, Baustelle oder Sperrung.
struct Verkehrsmeldung: Identifiable, Hashable {
    enum Art: String, Hashable {
        case stau, baustelle, sperrung, anschlussGesperrt

        var name: String {
            switch self {
            case .stau: return "Verkehrsmeldung"
            case .baustelle: return "Baustelle"
            case .sperrung: return "Sperrung"
            case .anschlussGesperrt: return "Anschlussstelle gesperrt"
            }
        }

        var symbol: String {
            switch self {
            case .stau: return "car.2.fill"
            case .baustelle: return "cone.fill"
            case .sperrung: return "xmark.octagon.fill"
            case .anschlussGesperrt: return "arrow.turn.right.up"
            }
        }
    }

    let id: String
    var art: Art
    var strasse: String
    var titel: String
    var richtung: String
    var beschreibung: [String]
    var punkte: [Punkt]
    /// Angekündigt, aber noch nicht gültig.
    var zukuenftig: Bool
    var gesperrt: Bool
    var verzoegerungMin: Double?
    /// „Maximale Durchfahrtsbreite" aus dem Text einer Baustelle.
    var hoechstbreiteM: Double?

    /// Kommt dieses Fahrzeug hier durch? Eine Sperrung sperrt jeden, eine
    /// Baustelle nur, wer breiter ist als die angegebene Durchfahrt.
    func sperrt(breite: Double?) -> Bool {
        if zukuenftig { return false }
        if art == .sperrung || gesperrt { return true }
        if let h = hoechstbreiteM, let b = breite, b > h { return true }
        return false
    }

    var mitte: Punkt? { punkte.isEmpty ? nil : punkte[punkte.count / 2] }

    /// Die Fläche, die beim Umfahren gemieden wird: ein Kästchen von rund
    /// 250 × 250 m um die Mitte der Meldung. Es sperrt BEIDE Richtungen und
    /// jede Straße, die es schneidet — genauer lässt sich eine Fläche nicht
    /// ziehen. Die Detailansicht sagt das dazu.
    var sperrflaeche: [Punkt]? {
        guard let m = mitte else { return nil }
        let db = 0.00115
        let dl = db / max(cos(m.breite * .pi / 180), 0.2)
        return [
            Punkt(breite: m.breite - db, laenge: m.laenge - dl),
            Punkt(breite: m.breite - db, laenge: m.laenge + dl),
            Punkt(breite: m.breite + db, laenge: m.laenge + dl),
            Punkt(breite: m.breite + db, laenge: m.laenge - dl),
            Punkt(breite: m.breite - db, laenge: m.laenge - dl),
        ]
    }
}

/// Verkehrsmeldungen der Autobahn GmbH des Bundes (verkehr.autobahn.de),
/// ohne Schlüssel.
///
/// Gemessen am 23.09.2026 an der A1: 207 Baustellen, 29 Sperrungen,
/// 4 Staumeldungen, jede mit Linienzug und Richtung. Drei Eigenheiten:
/// * `isBlocked` kommt als TEXT („false"), `future` als Wahrheitswert.
/// * Eine Sperrung heißt `CLOSURE`; `CLOSURE_ENTRY_EXIT` ist nur eine
///   gesperrte Auf- oder Abfahrt und sperrt die Strecke selbst nicht.
/// * Baustellen nennen im Text „Maximale Durchfahrtsbreite: 3.25 m" — für
///   ein Gespann die wichtigste Zeile der ganzen Meldung.
///
/// Was es NICHT gibt: Meldungen für Bundes-, Landes- und Stadtstraßen. Dafür
/// fand sich keine freie Quelle ohne Konto; die App sagt das dazu.
enum Autobahnverkehr {
    static let name = "Autobahn GmbH"
    private static let basis = "https://verkehr.autobahn.de/o/autobahn/"
    private static var zwischenspeicher: [String: (Date, [Verkehrsmeldung])] = [:]

    /// „A 1" und „A1" werden zu „A1". Nur Autobahnen — die Schnittstelle
    /// kennt nichts anderes.
    static func autobahnen(in strassen: Set<String>) -> [String] {
        var ergebnis = Set<String>()
        for s in strassen {
            let ohne = s.replacingOccurrences(of: " ", with: "")
            guard ohne.hasPrefix("A"), ohne.count >= 2,
                  ohne.dropFirst().allSatisfy({ $0.isNumber }) else { continue }
            ergebnis.insert(ohne)
        }
        return ergebnis.sorted()
    }

    /// Alle Meldungen der genannten Autobahnen. Ein Fehler bei einer Autobahn
    /// reißt die anderen nicht mit; er wird gezählt.
    static func meldungen(fuer strassen: [String]) async -> (meldungen: [Verkehrsmeldung], fehlgeschlagen: [String]) {
        var alle: [Verkehrsmeldung] = []
        var fehlgeschlagen: [String] = []
        await withTaskGroup(of: (String, [Verkehrsmeldung]?).self) { gruppe in
            for s in strassen.prefix(12) {
                gruppe.addTask { (s, try? await eineStrasse(s)) }
            }
            for await (s, liste) in gruppe {
                if let liste { alle += liste } else { fehlgeschlagen.append(s) }
            }
        }
        return (alle, fehlgeschlagen.sorted())
    }

    @MainActor
    private static func gemerkt(_ s: String) -> [Verkehrsmeldung]? {
        guard let eintrag = zwischenspeicher[s], Date().timeIntervalSince(eintrag.0) < 300 else { return nil }
        return eintrag.1
    }

    @MainActor
    private static func merken(_ s: String, _ liste: [Verkehrsmeldung]) {
        zwischenspeicher[s] = (Date(), liste)
    }

    private static func eineStrasse(_ s: String) async throws -> [Verkehrsmeldung] {
        if let liste = await gemerkt(s) { return liste }
        var liste: [Verkehrsmeldung] = []
        for dienst in ["closure", "warning", "roadworks"] {
            guard let url = URL(string: basis + s + "/services/" + dienst) else { continue }
            let (daten, status) = try await Netz.holen(URLRequest(url: url))
            guard status == 200, let json = Netz.objekt(daten) else {
                throw Routenfehler.dienst(name, "HTTP \(status)")
            }
            let eintraege = (json[dienst] as? [[String: Any]]) ?? []
            liste += eintraege.compactMap { lesen($0, strasse: s, dienst: dienst) }
        }
        await merken(s, liste)
        return liste
    }

    private static func lesen(_ e: [String: Any], strasse: String, dienst: String) -> Verkehrsmeldung? {
        guard let id = e["identifier"] as? String else { return nil }
        let typ = (e["display_type"] as? String) ?? ""
        let art: Verkehrsmeldung.Art
        switch dienst {
        case "closure": art = typ == "CLOSURE_ENTRY_EXIT" ? .anschlussGesperrt : .sperrung
        case "warning": art = .stau
        default: art = .baustelle
        }
        var punkte: [Punkt] = []
        if let g = e["geometry"] as? [String: Any], let k = g["coordinates"] as? [[Any]] {
            punkte = k.compactMap { p in
                guard p.count >= 2, let lo = Wert.zahl(p[0]), let la = Wert.zahl(p[1]) else { return nil }
                return Punkt(breite: la, laenge: lo)
            }
        }
        if punkte.isEmpty, let c = e["coordinate"] as? [String: Any],
           let la = Wert.zahl(c["lat"]), let lo = Wert.zahl(c["long"]) {
            punkte = [Punkt(breite: la, laenge: lo)]
        }
        guard !punkte.isEmpty else { return nil }
        let beschreibung = ((e["description"] as? [Any]) ?? []).compactMap { $0 as? String }
        return Verkehrsmeldung(
            id: id,
            art: art,
            strasse: strasse,
            titel: ((e["title"] as? String) ?? strasse).trimmingCharacters(in: .whitespaces),
            richtung: ((e["subtitle"] as? String) ?? "").trimmingCharacters(in: .whitespaces),
            beschreibung: beschreibung,
            punkte: punkte,
            zukuenftig: Wert.wahr(e["future"]),
            gesperrt: Wert.wahr(e["isBlocked"]),
            verzoegerungMin: Wert.zahl(e["delayTimeValue"]),
            hoechstbreiteM: breite(in: beschreibung))
    }

    /// Liest „Maximale Durchfahrtsbreite: 3.25 m" aus dem Text.
    static func breite(in zeilen: [String]) -> Double? {
        for zeile in zeilen {
            for teil in zeile.components(separatedBy: "|") {
                guard let r = teil.range(of: "Durchfahrtsbreite:") else { continue }
                let rest = teil[r.upperBound...].trimmingCharacters(in: .whitespaces)
                let zahl = rest.prefix { $0.isNumber || $0 == "." || $0 == "," }
                if let w = Wert.zahl(String(zahl)), w > 1, w < 10 { return w }
            }
        }
        return nil
    }

    /// Welche Meldungen liegen auf der Route — und zwar in IHRER Richtung?
    ///
    /// Geprüft werden Anfang, Mitte und Ende der Meldung: Alle drei müssen
    /// dicht an der Route liegen (60 m). Die Richtung ergibt sich daraus, in
    /// welcher Reihenfolge die Route an Anfang und Ende vorbeikommt — eine
    /// Meldung für die Gegenfahrbahn liegt genauso dicht daneben, aber
    /// rückwärts.
    static func aufDerRoute(_ meldungen: [Verkehrsmeldung], route: [Punkt]) -> [Verkehrsmeldung] {
        guard route.count > 1 else { return [] }
        var minB = 90.0, maxB = -90.0, minL = 180.0, maxL = -180.0
        for p in route {
            minB = min(minB, p.breite); maxB = max(maxB, p.breite)
            minL = min(minL, p.laenge); maxL = max(maxL, p.laenge)
        }
        let rand = 0.01
        return meldungen.filter { m in
            guard let erster = m.punkte.first, let letzter = m.punkte.last else { return false }
            let proben = [erster, m.punkte[m.punkte.count / 2], letzter]
            guard proben.allSatisfy({ $0.breite > minB - rand && $0.breite < maxB + rand
                                        && $0.laenge > minL - rand && $0.laenge < maxL + rand })
            else { return false }
            let stellen = proben.map { Geo.naechsteStelle($0, auf: route) }
            guard stellen.allSatisfy({ $0.abstand < 60 }) else { return false }
            if Geo.abstand(erster, letzter) < 80 { return true }
            return stellen[0].index <= stellen[2].index
        }
    }
}
