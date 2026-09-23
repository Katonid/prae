import Foundation

/// Die Fahrzeit, selbst gerechnet und in Posten zerlegt.
///
/// Der Routendienst rechnet mit einem gewöhnlichen Pkw. Ein Gespann fährt
/// außerorts 80 km/h, auf der Autobahn 80 oder mit Tempo-100-Zulassung 100,
/// und es braucht beim Anfahren länger. Die Posten sagen, woher jede Minute
/// kommt — eine nackte Zahl wäre eine Zusage und keine Rechnung.
enum Fahrzeit {
    enum Lage { case autobahn, ausserorts, innerorts }

    /// Innerorts ist, wo das Tempolimit höchstens 60 beträgt. Fehlt das
    /// Limit, entscheidet die Bebauungsdichte, die Valhalla je Stück mitgibt
    /// (0 bis 15; gemessen in Dortmund: Wohnstraßen 13, Hauptstraßen 11–12,
    /// Autobahn 4–11). Die Schwelle 11 ist gewählt, nicht gemessen.
    static func lage(_ k: Valhalla.Kante) -> Lage {
        if k.klasse == "motorway" { return .autobahn }
        if k.klasse == "trunk" { return .ausserorts }
        if let l = k.tempolimit, l > 0 { return l <= 60 ? .innerorts : .ausserorts }
        return k.dichte >= 11 ? .innerorts : .ausserorts
    }

    /// Das Höchsttempo dieses Fahrzeugs in dieser Lage — `nil` heißt: keine
    /// eigene Grenze, es gilt das Tempo des Dienstes.
    static func grenze(_ lage: Lage, profil: Fahrzeugprofil) -> Double? {
        var g = profil.hoechsttempo
        if profil.mitAnhaenger {
            let a: Double?
            switch lage {
            case .autobahn: a = profil.tempo100 ? 100 : 80
            case .ausserorts: a = 80
            case .innerorts: a = nil
            }
            if let a { g = min(g ?? a, a) }
        }
        return g
    }

    static func auto(kanten: [Valhalla.Kante], profil: Fahrzeugprofil, abbiegungen: Int) -> [Zeitposten] {
        var km: [Lage: Double] = [:]
        var sek: [Lage: Double] = [:]
        for k in kanten {
            let l = lage(k)
            var v = k.tempo
            if let g = grenze(l, profil: profil) { v = min(v, g) }
            km[l, default: 0] += k.laengeKm
            sek[l, default: 0] += k.laengeKm / max(v, 1) * 3600
        }
        var posten: [Zeitposten] = []
        let namen: [(Lage, String)] = [(.autobahn, "Autobahn"), (.ausserorts, "Außerorts"), (.innerorts, "Innerorts")]
        for (l, name) in namen {
            guard let s = sek[l], s > 0 else { continue }
            var text = "\(name): \(Anzeige.strecke((km[l] ?? 0) * 1000))"
            if let g = grenze(l, profil: profil) { text += ", höchstens \(Int(g)) km/h" }
            posten.append(Zeitposten(text: text, sekunden: s))
        }
        if profil.innerortsAufschlag > 0, let s = sek[.innerorts], s > 0 {
            posten.append(Zeitposten(text: "Aufschlag innerorts \(Int(profil.innerortsAufschlag)) % (Anfahren)",
                                     sekunden: s * profil.innerortsAufschlag / 100))
        }
        if profil.abbiegeAufschlag > 0, abbiegungen > 0 {
            posten.append(Zeitposten(text: "\(abbiegungen) × Abbiegen oder Kreisverkehr à \(Int(profil.abbiegeAufschlag)) s",
                                     sekunden: Double(abbiegungen) * profil.abbiegeAufschlag))
        }
        return posten
    }

    static func rad(abschnitte: [Abschnitt], profil: Fahrzeugprofil) -> [Zeitposten] {
        var fahren = 0.0, schieben = 0.0, treppe = 0.0
        for a in abschnitte {
            switch a.art {
            case .fahren, .radwegPflicht: fahren += a.laengeM
            case .schieben: schieben += a.laengeM
            case .treppe: treppe += a.laengeM
            }
        }
        var posten = [Zeitposten(text: "Fahren: \(Anzeige.strecke(fahren)) bei \(Int(profil.radTempo)) km/h",
                                 sekunden: fahren / 1000 / max(profil.radTempo, 1) * 3600)]
        if schieben > 0 {
            posten.append(Zeitposten(text: "Schieben: \(Anzeige.strecke(schieben)) bei \(Anzeige.zahl(profil.schiebeTempo, stellen: 1)) km/h",
                                     sekunden: schieben / 1000 / max(profil.schiebeTempo, 0.5) * 3600))
        }
        if treppe > 0 {
            // Eine Treppe mit Rad auf der Schulter: halbes Schiebetempo.
            // Gewählt, nicht gemessen.
            posten.append(Zeitposten(text: "Treppen: \(Anzeige.strecke(treppe)), halbes Schiebetempo",
                                     sekunden: treppe / 1000 / max(profil.schiebeTempo / 2, 0.5) * 3600))
        }
        return posten
    }

    static func zuFuss(laengeM: Double, profil: Fahrzeugprofil) -> [Zeitposten] {
        [Zeitposten(text: "Gehen: \(Anzeige.strecke(laengeM)) bei \(Anzeige.zahl(profil.gehTempo, stellen: 1)) km/h",
                    sekunden: laengeM / 1000 / max(profil.gehTempo, 0.5) * 3600)]
    }
}
