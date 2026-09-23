import Foundation

/// Der Routendienst fürs Fahrrad: BRouter auf brouter.de, ohne Schlüssel,
/// mit einem EIGENEN Regelwerk (`regelwerk` unten).
///
/// Gemessen am 23.09.2026 (Dortmund, Westenhellweg → Olpe):
/// * Mit Schieben 895 m, davon 12 Abschnitte Fußgängerzone und Gehweg ohne
///   Radfreigabe; ohne Schieben 1345 m über Straßen und freigegebene Wege.
/// * Das mitgelieferte Profil „shortest" war NICHT genug: Es hält eine
///   Fußgängerzone (`highway=pedestrian`) für befahrbar. In Deutschland ist
///   sie für Räder gesperrt, solange kein „Radfahrer frei" dasteht.
/// * Die Antwort nennt je Abschnitt die OSM-Merkmale (`WayTags`) — aber nur
///   die, die das Regelwerk benutzt. Daraus erkennt die App Schiebestrecken.
/// * BRouters eigene Zeitangabe taugt hier nicht: Für das Regelwerk
///   „shortest" rechnete sie 641 s für 895 m, also Schritttempo. Die App
///   rechnet die Zeit selbst (Radtempo, Schiebetempo).
enum BRouter {
    static let name = "BRouter (brouter.de)"
    private static let basis = "https://brouter.de/brouter"

    /// Die Kennung eines hochgeladenen Regelwerks. BRouter hält eigene
    /// Regelwerke nur eine Weile vor; scheitert eine Anfrage daran, wird
    /// neu hochgeladen.
    private static var kennung: String?

    struct Antwort {
        var punkte: [Punkt]
        var abschnitte: [Abschnitt]
        var laengeM: Double
        var belaege: [Belagstueck]
    }

    static func route(von: Punkt, nach: Punkt, profil: Fahrzeugprofil, alternative: Int = 0) async throws -> Antwort {
        do {
            return try await anfrage(von: von, nach: nach, profil: profil,
                                     kennung: try await regelwerkKennung(), alternative: alternative)
        } catch Routenfehler.dienst(_, let text) where text.lowercased().contains("profile") {
            kennung = nil
            return try await anfrage(von: von, nach: nach, profil: profil,
                                     kennung: try await regelwerkKennung(), alternative: alternative)
        }
    }

    /// Die Route und ihre Alternativen. BRouter rechnet sie über
    /// `alternativeidx` (0 bis 3), JE EINE Anfrage. Gemessen am 23.09.2026
    /// (Dortmund, 3,6 km): 3573 m, 4350 m, 4964 m, 4246 m — die vierte ist
    /// also nicht die längste, sortiert wird in der App. Gefragt werden drei;
    /// schlägt eine Alternative fehl, zählt nur die erste als Fehler.
    static func routen(von: Punkt, nach: Punkt, profil: Fahrzeugprofil) async throws -> [Antwort] {
        let erste = try await route(von: von, nach: nach, profil: profil, alternative: 0)
        var weitere: [(Int, Antwort)] = []
        await withTaskGroup(of: (Int, Antwort?).self) { gruppe in
            for i in 1...2 {
                gruppe.addTask { (i, try? await route(von: von, nach: nach, profil: profil, alternative: i)) }
            }
            for await (i, a) in gruppe { if let a { weitere.append((i, a)) } }
        }
        return [erste] + weitere.sorted { $0.0 < $1.0 }.map(\.1)
    }

    private static func regelwerkKennung() async throws -> String {
        if let k = kennung { return k }
        var a = URLRequest(url: URL(string: basis + "/profile")!)
        a.httpMethod = "POST"
        a.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        a.httpBody = Data(regelwerk.utf8)
        let (daten, _) = try await Netz.holen(a)
        guard let json = Netz.objekt(daten), let id = json["profileid"] as? String else {
            throw Routenfehler.unlesbar(name)
        }
        if let f = json["error"] as? String { throw Routenfehler.dienst(name, f) }
        kennung = id
        return id
    }

    private static func anfrage(von: Punkt, nach: Punkt, profil: Fahrzeugprofil, kennung: String,
                                alternative: Int) async throws -> Antwort {
        var teile = URLComponents(string: basis)!
        teile.queryItems = [
            URLQueryItem(name: "lonlats", value: "\(von.laenge),\(von.breite)|\(nach.laenge),\(nach.breite)"),
            URLQueryItem(name: "profile", value: kennung),
            URLQueryItem(name: "alternativeidx", value: String(alternative)),
            URLQueryItem(name: "format", value: "geojson"),
            URLQueryItem(name: "profile:schieben", value: profil.schieben ? "1" : "0"),
        ]
        let (daten, status) = try await Netz.holen(URLRequest(url: teile.url!))
        guard status == 200, let json = Netz.objekt(daten) else {
            // BRouter antwortet bei Fehlern mit reinem Text.
            let text = String(decoding: daten.prefix(300), as: UTF8.self)
            if text.contains("not mapped") || text.contains("no track found") {
                throw Routenfehler.keinWeg("Für diese Punkte gibt es auf erlaubten Wegen keinen Radweg. Liegt ein Punkt abseits jeder Straße, hilft ein anderer Punkt; ist Schieben aus, hilft es vielleicht, das Schieben zu erlauben.")
            }
            throw Routenfehler.dienst(name, text.isEmpty ? "HTTP \(status)" : text)
        }
        guard let features = json["features"] as? [[String: Any]], let f = features.first,
              let geometrie = f["geometry"] as? [String: Any],
              let koordinaten = geometrie["coordinates"] as? [[Any]],
              let eigenschaften = f["properties"] as? [String: Any]
        else { throw Routenfehler.unlesbar(name) }

        let punkte = koordinaten.compactMap { k -> Punkt? in
            guard k.count >= 2, let lo = Wert.zahl(k[0]), let la = Wert.zahl(k[1]) else { return nil }
            return Punkt(breite: la, laenge: lo)
        }
        let meldungen = (eigenschaften["messages"] as? [[Any]]) ?? []
        let stuecke = stellen(punkte: punkte, meldungen: meldungen)
        let abschnitte = zerlegen(punkte: punkte, stellen: stuecke)
        let belaege = belagZerlegen(punkte: punkte, stellen: stuecke)
        let laenge = Wert.zahl(eigenschaften["track-length"]) ?? Geo.laenge(punkte)
        return Antwort(punkte: punkte, abschnitte: abschnitte, laengeM: laenge, belaege: belaege)
    }

    /// Ordnet jedem Stück der Linie seine Art zu. Jede Zeile der `messages`
    /// beschreibt das Stück, das an ihrer Koordinate ENDET; die erste Zeile
    /// ist die Überschrift.
    private static func zerlegen(punkte: [Punkt], stellen: [(ende: Int, merkmale: [String: String])]) -> [Abschnitt] {
        guard punkte.count > 1 else { return [] }
        var ergebnis: [Abschnitt] = []
        var anfang = 0
        func anhaengen(bis ende: Int, art: Abschnittsart, wegart: String?) {
            guard ende > anfang else { return }
            let stueck = Array(punkte[anfang...ende])
            let laenge = Geo.laenge(stueck)
            if var letzter = ergebnis.last, letzter.art == art, letzter.wegart == wegart {
                letzter.punkte.append(contentsOf: stueck.dropFirst())
                letzter.laengeM += laenge
                ergebnis[ergebnis.count - 1] = letzter
            } else {
                ergebnis.append(Abschnitt(art: art, punkte: stueck, laengeM: laenge, wegart: wegart))
            }
            anfang = ende
        }
        for s in stellen {
            let (art, wegart) = einordnen(s.merkmale)
            anhaengen(bis: s.ende, art: art, wegart: wegart)
        }
        // Was übrig bleibt, gehört zum letzten Stück; fand sich gar nichts,
        // ist es eine gewöhnliche Strecke — das sagt die Liste darunter.
        if anfang < punkte.count - 1 {
            anhaengen(bis: punkte.count - 1, art: ergebnis.last?.art ?? .fahren, wegart: ergebnis.last?.wegart)
        }
        return ergebnis
    }

    /// Dieselben Stellen, nach dem Belag zusammengefasst. Eine eigene Liste
    /// und nicht ein Feld am `Abschnitt`: Sonst zerfiele jede Schiebestrecke
    /// in der Detailansicht an jedem Belagwechsel in mehrere Zeilen.
    private static func belagZerlegen(punkte: [Punkt], stellen: [(ende: Int, merkmale: [String: String])]) -> [Belagstueck] {
        guard punkte.count > 1 else { return [] }
        var ergebnis: [Belagstueck] = []
        var anfang = 0
        func anhaengen(bis ende: Int, belag: Belag) {
            guard ende > anfang else { return }
            let stueck = Array(punkte[anfang...ende])
            let laenge = Geo.laenge(stueck)
            if var letzter = ergebnis.last, letzter.belag == belag {
                letzter.punkte.append(contentsOf: stueck.dropFirst())
                letzter.laengeM += laenge
                ergebnis[ergebnis.count - 1] = letzter
            } else {
                ergebnis.append(Belagstueck(belag: belag, punkte: stueck, laengeM: laenge))
            }
            anfang = ende
        }
        for s in stellen {
            anhaengen(bis: s.ende, belag: Belag.aus(s.merkmale["surface"]))
        }
        if anfang < punkte.count - 1 {
            anhaengen(bis: punkte.count - 1, belag: .unbekannt)
        }
        return ergebnis
    }

    /// Jede Zeile der `messages` beschreibt das Stück, das an ihrer
    /// Koordinate ENDET; die erste Zeile ist die Überschrift. Gesucht wird
    /// die Koordinate in der Linie ab der Stelle, an der das letzte Stück
    /// endete — eine Mikrograd Spiel für Rundung.
    private static func stellen(punkte: [Punkt], meldungen: [[Any]]) -> [(ende: Int, merkmale: [String: String])] {
        guard punkte.count > 1 else { return [] }
        let mikro = punkte.map { (Int(($0.laenge * 1e6).rounded()), Int(($0.breite * 1e6).rounded())) }
        var ergebnis: [(ende: Int, merkmale: [String: String])] = []
        var letzte = 0
        for zeile in meldungen.dropFirst() {
            guard zeile.count > 9,
                  let lo = Wert.text(zeile[0]).flatMap(Int.init),
                  let la = Wert.text(zeile[1]).flatMap(Int.init)
            else { continue }
            var j = letzte + 1
            var gefunden: Int?
            while j < mikro.count {
                if abs(mikro[j].0 - lo) <= 1 && abs(mikro[j].1 - la) <= 1 { gefunden = j; break }
                j += 1
            }
            guard let ende = gefunden else { continue }
            ergebnis.append((ende, merkmaleLesen(Wert.text(zeile[9]) ?? "")))
            letzte = ende
        }
        return ergebnis
    }

    static func merkmaleLesen(_ text: String) -> [String: String] {
        var m: [String: String] = [:]
        for teil in text.split(separator: " ") {
            let paar = teil.split(separator: "=", maxSplits: 1)
            if paar.count == 2 { m[String(paar[0])] = String(paar[1]) }
        }
        return m
    }

    /// Dieselbe Regel wie im Regelwerk, auf der Seite der App noch einmal.
    /// Liefen beide auseinander, stünde ein Abschnitt als „fahren" da, über
    /// den der Router nur schiebend geführt hat.
    static func einordnen(_ m: [String: String]) -> (Abschnittsart, String?) {
        let highway = m["highway"] ?? ""
        let wegart = wegname(highway)
        if radErlaubt(m) { return (.fahren, nil) }
        if m["bicycle"] == "use_sidepath" { return (.radwegPflicht, wegart) }
        if highway == "steps" { return (.treppe, wegart) }
        return (.schieben, wegart)
    }

    static func radErlaubt(_ m: [String: String]) -> Bool {
        let highway = m["highway"] ?? ""
        var grund = true
        if m["motorroad"] == "yes" || highway == "motorway" || highway == "motorway_link" { grund = false }
        if let access = m["access"] { grund = !(access == "private" || access == "no") && grund }
        if let bicycle = m["bicycle"] {
            return !["private", "no", "dismount", "use_sidepath"].contains(bicycle)
        }
        if m["bicycle_road"] == "yes" { return true }
        if let vehicle = m["vehicle"] { return !(vehicle == "private" || vehicle == "no") }
        if nurFuss.contains(highway) { return false }
        return grund
    }

    static let nurFuss: Set<String> = ["footway", "pedestrian", "steps", "bridleway", "corridor", "platform"]

    static func wegname(_ highway: String) -> String? {
        switch highway {
        case "footway": return "Gehweg"
        case "pedestrian": return "Fußgängerzone"
        case "steps": return "Treppe"
        case "bridleway": return "Reitweg"
        case "path": return "Pfad"
        case "": return nil
        default: return "Straße (\(highway))"
        }
    }

    /// Das Regelwerk, das hochgeladen wird. Grundlage ist BRouters
    /// „shortest", mit zwei Änderungen: Fußgängerzone, Gehweg, Treppe und
    /// Reitweg gelten für Räder als gesperrt, solange nichts anderes
    /// eingetragen ist; und Schieben lässt sich abschalten (`schieben`).
    /// Kosten sind überall 1 — es gewinnt der kürzeste Weg, egal wie der
    /// Belag ist. Autobahn, Kraftfahrstraße (`motorroad=yes`), `bicycle=no`
    /// und Straßen mit Radwegpflicht sind nicht fahrbar.
    static let regelwerk = """
    ---context:global
    assign downhillcost 0
    assign downhillcutoff 1.5
    assign uphillcost 0
    assign uphillcutoff 1.5
    assign turnInstructionMode = 1
    assign validForBikes 1
    assign schieben = true # %schieben% | Gehwege schiebend benutzen | boolean

    ---context:way
    assign turncost 0
    assign initialclassifier = if route=ferry then 1 else 0
    assign initialcost switch route=ferry 10000 0

    assign defaultaccess
           switch access=
                  ( if motorroad=yes then false
                    else if highway=motorway|motorway_link then false
                    else true )
                  switch or access=private access=no false true

    assign nurFuss = highway=footway|pedestrian|steps|bridleway|corridor|platform

    assign bikeaccess
           switch bicycle=
                  switch bicycle_road=yes
                     true
                     switch vehicle=
                            ( if nurFuss then false else defaultaccess )
                            not vehicle=private|no
                  not or bicycle=private or bicycle=no or bicycle=dismount bicycle=use_sidepath

    assign footaccess
           or bicycle=dismount
              switch foot=
                     ( if highway=cycleway then false else defaultaccess )
                     not or foot=private or foot=no foot=use_sidepath

    assign accesspenalty
           if bikeaccess then 0
           else if and schieben footaccess then 0
           else 100000

    assign costfactor
      add accesspenalty
      switch and highway= not route=ferry 100000
      switch route=ferry 5.67
      switch or highway=motorway highway=motorway_link 100000
      switch or highway=proposed highway=abandoned|construction 100000
      1

    assign priorityclassifier =
      if highway=motorway|motorway_link|trunk|trunk_link then 28
      else if highway=primary|primary_link then 26
      else if highway=secondary|secondary_link then 24
      else if highway=tertiary|tertiary_link then 22
      else if highway=unclassified then 20
      else if highway=residential|living_street|service|cycleway then 6
      else if highway=track|path|footway|bridleway then 4
      else if highway=steps|pedestrian then 2
      else 0
    assign isroundabout = junction=roundabout
    assign islinktype = highway=motorway_link|trunk_link|primary_link|secondary_link|tertiary_link
    assign isgoodforcars = greater priorityclassifier 6
    assign classifiermask add multiply isroundabout 4 add multiply islinktype 8 multiply isgoodforcars 16
    assign dummyUsage = or smoothness= surface=

    ---context:node
    assign defaultaccess
           switch access=
                  1
                  switch or access=private access=no 0 1
    assign bikeaccess
           or nodeaccessgranted=yes
              switch bicycle=
                     switch vehicle= defaultaccess switch or vehicle=private vehicle=no 0 1
                     switch or bicycle=private or bicycle=no bicycle=dismount 0 1
    assign footaccess
           or bicycle=dismount
              switch foot= defaultaccess switch or foot=private foot=no 0 1
    assign initialcost
           if bikeaccess then 0
           else if and schieben footaccess then 0
           else 1000000

    """
}
