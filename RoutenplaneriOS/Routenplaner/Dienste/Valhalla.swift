import Foundation

/// Der Routendienst für Auto und zu Fuß: Valhalla auf dem öffentlichen
/// Server der FOSSGIS, ohne Schlüssel.
///
/// Gemessen am 23.09.2026 (Dortmund → Wuppertal):
/// * Das **Pkw**-Profil (`auto`) nimmt `height` und `width` an — mit 9 m
///   Höhe und 6 m Breite wählt es einen anderen Weg (49,9 statt 48,1 km).
///   Das Lkw-Profil wäre der naheliegende Weg und der falsche: Es meidet
///   auch Lkw-Verbote, die für ein Gespann gar nicht gelten.
/// * `top_speed` wirkt (44,5 → 45,1 min mit 100 km/h).
/// * `exclude_polygons` umfährt eine Fläche (48,1 → 49,9 km).
/// * `trace_attributes` gibt je Straßenstück Klasse, Tempo, Tempolimit,
///   Bebauungsdichte und Tunnel heraus — daraus rechnet die App ihre Zeit.
/// * Mit dem Rad fährt Valhalla NIE über einen Gehweg ohne Radfreigabe; es
///   kennt kein Schieben. Deshalb ist es beim Rad nur der Rückfall.
enum Valhalla {
    static let name = "Valhalla (FOSSGIS)"
    private static let basis = URL(string: "https://valhalla1.openstreetmap.de")!

    struct Antwort {
        var punkte: [Punkt]
        var shape: String
        var laengeM: Double
        var zeitS: Double
        var anweisungen: [Anweisung]
        var abbiegungen: Int
        var strassen: Set<String>
    }

    static func route(von: Punkt, nach: Punkt, profil: Fahrzeugprofil,
                      sperrflaechen: [[Punkt]] = []) async throws -> Antwort {
        let costing: String
        var optionen: [String: Any] = [:]
        switch profil.art {
        case .auto:
            costing = "auto"
            if let h = profil.hoeheM { optionen["height"] = h }
            if let b = profil.breiteM { optionen["width"] = b }
            if let t = profil.tempoGrenze { optionen["top_speed"] = Int(t) }
        case .zuFuss:
            costing = "pedestrian"
        case .fahrrad:
            costing = "bicycle"
            optionen["shortest"] = true
        }
        var koerper: [String: Any] = [
            "locations": [
                ["lat": von.breite, "lon": von.laenge],
                ["lat": nach.breite, "lon": nach.laenge],
            ],
            "costing": costing,
            "units": "kilometers",
            "language": "de-DE",
        ]
        if !optionen.isEmpty { koerper["costing_options"] = [costing: optionen] }
        if !sperrflaechen.isEmpty {
            // GeoJSON-Reihenfolge: Länge zuerst.
            koerper["exclude_polygons"] = sperrflaechen.map { flaeche in
                flaeche.map { [$0.laenge, $0.breite] }
            }
        }
        let (daten, status) = try await Netz.jsonPost(basis.appendingPathComponent("route"), koerper)
        guard let json = Netz.objekt(daten) else { throw Routenfehler.unlesbar(name) }
        if status != 200 || json["trip"] == nil { throw fehler(json, status: status) }

        guard let trip = json["trip"] as? [String: Any],
              let legs = trip["legs"] as? [[String: Any]], let leg = legs.first,
              let shape = leg["shape"] as? String,
              let summary = trip["summary"] as? [String: Any]
        else { throw Routenfehler.unlesbar(name) }

        var anweisungen: [Anweisung] = []
        var abbiegungen = 0
        var strassen = Set<String>()
        for m in (leg["maneuvers"] as? [[String: Any]]) ?? [] {
            let typ = Int(Wert.zahl(m["type"]) ?? 0)
            // Volle Abbiegungen und Kreisverkehre: Dort wird gebremst und
            // wieder angefahren. Leichtes Abbiegen und Auffahrten nicht.
            if [10, 11, 12, 13, 14, 15, 26].contains(typ) { abbiegungen += 1 }
            for s in (m["street_names"] as? [String]) ?? [] { strassen.insert(s) }
            if let text = m["instruction"] as? String {
                anweisungen.append(Anweisung(text: text, laengeM: (Wert.zahl(m["length"]) ?? 0) * 1000))
            }
        }
        return Antwort(punkte: Geo.polylinie(shape, genauigkeit: 6),
                       shape: shape,
                       laengeM: (Wert.zahl(summary["length"]) ?? 0) * 1000,
                       zeitS: Wert.zahl(summary["time"]) ?? 0,
                       anweisungen: anweisungen,
                       abbiegungen: abbiegungen,
                       strassen: strassen)
    }

    struct Kante {
        var laengeKm: Double
        var tempo: Double
        var tempolimit: Double?
        var klasse: String
        var dichte: Int
        var tunnel: Bool
        var namen: [String]
    }

    /// Die Straßenstücke unter einer Route. Braucht eine zweite Abfrage; die
    /// Route selbst sagt nicht, auf welcher Straßenart sie liegt.
    static func kanten(shape: String, profil: Fahrzeugprofil) async throws -> [Kante] {
        let costing = profil.art == .zuFuss ? "pedestrian" : "auto"
        let koerper: [String: Any] = [
            "encoded_polyline": shape,
            "costing": costing,
            "shape_match": "edge_walk",
            "filters": [
                "attributes": ["edge.names", "edge.length", "edge.speed", "edge.speed_limit",
                               "edge.road_class", "edge.density", "edge.tunnel"],
                "action": "include",
            ],
        ]
        let (daten, status) = try await Netz.jsonPost(basis.appendingPathComponent("trace_attributes"), koerper)
        guard status == 200, let json = Netz.objekt(daten),
              let kanten = json["edges"] as? [[String: Any]]
        else { throw Routenfehler.unlesbar(name) }
        return kanten.map { k in
            Kante(laengeKm: Wert.zahl(k["length"]) ?? 0,
                  tempo: max(Wert.zahl(k["speed"]) ?? 50, 1),
                  // „unlimited" wird hier zu nil — für die Rechnung gilt dann
                  // das Tempo, das der Dienst für die Kante annimmt.
                  tempolimit: Wert.zahl(k["speed_limit"]),
                  klasse: (k["road_class"] as? String) ?? "",
                  dichte: Int(Wert.zahl(k["density"]) ?? 0),
                  tunnel: Wert.wahr(k["tunnel"]),
                  namen: (k["names"] as? [String]) ?? [])
        }
    }

    private static func fehler(_ json: [String: Any], status: Int) -> Routenfehler {
        let code = Int(Wert.zahl(json["error_code"]) ?? 0)
        let text = (json["error"] as? String) ?? "HTTP \(status)"
        switch code {
        case 442, 443:
            return .keinWeg("Für diese Punkte gibt es mit diesen Regeln keinen Weg. Liegt eine Engstelle, eine Sperrung oder ein Verbot zwischen ihnen, hilft ein anderer Punkt oder ein anderes Profil.")
        case 170, 171:
            return .keinAnschluss("Ein Punkt liegt zu weit von jeder befahrbaren Straße entfernt. Bitte einen Ort näher an einer Straße wählen.")
        default:
            return .dienst(name, text)
        }
    }
}
