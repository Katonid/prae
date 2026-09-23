import Foundation
import SwiftUI

/// Das App-Modell: Start, Ziel, Profil — und die Rechnung, die daraus eine
/// Route macht.
///
/// Kein `@AppStorage` hier: Der Wrapper gehört in eine View; in einer
/// `ObservableObject`-Klasse löst er kein `objectWillChange` aus (die Lehre
/// aus der Abfahrtstafel).
@MainActor
final class Planer: ObservableObject {
    @Published var start: Ort? { didSet { if start != oldValue { eigeneSperren = [] } } }
    @Published var ziel: Ort? { didSet { if ziel != oldValue { eigeneSperren = [] } } }
    @Published var profile: [Fahrzeugprofil] { didSet { Profilablage.sichern(profile) } }
    @Published var profilID: UUID {
        didSet { UserDefaults.standard.set(profilID.uuidString, forKey: "gewaehltesProfil") }
    }
    @Published var verkehrBeachten: Bool {
        didSet { UserDefaults.standard.set(verkehrBeachten, forKey: "verkehrBeachten") }
    }
    /// Die Route und ihre Alternativen, die beste zuerst (Auto: nach Zeit
    /// SAMT Stau, Rad und zu Fuß: nach Länge).
    @Published private(set) var routen: [Route] = []
    /// Welche davon gezeigt wird. Eine neue Rechnung setzt auf die beste.
    @Published var gewaehlt = 0
    @Published private(set) var laedt = false
    @Published var fehler: String?
    /// Stellen, die jemand ausdrücklich meiden will (Stau, Baustelle).
    @Published private(set) var eigeneSperren: [Verkehrsmeldung] = []

    private var aufgabe: Task<Void, Never>?

    init() {
        let liste = Profilablage.laden()
        profile = liste
        let gemerkt = UserDefaults.standard.string(forKey: "gewaehltesProfil").flatMap(UUID.init)
        profilID = liste.first { $0.id == gemerkt }?.id ?? liste[0].id
        verkehrBeachten = UserDefaults.standard.object(forKey: "verkehrBeachten") as? Bool ?? true
    }

    var profil: Fahrzeugprofil {
        profile.first { $0.id == profilID } ?? profile.first ?? Fahrzeugprofil.vorlagen[0]
    }

    var bereit: Bool { start != nil && ziel != nil }

    var route: Route? { routen.indices.contains(gewaehlt) ? routen[gewaehlt] : nil }

    /// Schieben erlauben oder ausschließen — gespeichert am gewählten
    /// Profil, denn es ist eine Eigenschaft der Art, wie jemand fährt, und
    /// soll beim nächsten Öffnen noch gelten. Neu gerechnet wird sofort.
    func schiebenSetzen(_ an: Bool) {
        guard let i = profile.firstIndex(where: { $0.id == profil.id }), profile[i].schieben != an else { return }
        profile[i].schieben = an
        berechnen()
    }

    func tauschen() {
        (start, ziel) = (ziel, start)
        berechnen()
    }

    func meiden(_ m: Verkehrsmeldung) {
        guard !eigeneSperren.contains(m) else { return }
        eigeneSperren.append(m)
        berechnen()
    }

    func nichtMehrMeiden(_ m: Verkehrsmeldung) {
        eigeneSperren.removeAll { $0 == m }
        berechnen()
    }

    func berechnen() {
        aufgabe?.cancel()
        guard let start, let ziel else { routen = []; gewaehlt = 0; return }
        let gewaehlt = self.profil
        let verkehr = verkehrBeachten
        let sperren = eigeneSperren
        laedt = true
        fehler = nil
        aufgabe = Task {
            do {
                let r = try await Self.rechnen(von: start, nach: ziel, profil: gewaehlt,
                                               verkehr: verkehr, eigeneSperren: sperren)
                if Task.isCancelled { return }
                self.gewaehlt = 0
                routen = r
            } catch {
                if Task.isCancelled { return }
                // Eine alte Route bleibt NICHT stehen: Sie gälte für andere
                // Punkte oder ein anderes Fahrzeug und sähe trotzdem aus
                // wie die Antwort.
                routen = []
                self.gewaehlt = 0
                fehler = error.localizedDescription
            }
            laedt = false
        }
    }

    // MARK: - Rechnung

    /// Das Gefährlichste zuerst; innerhalb einer Stufe bleibt die Reihenfolge.
    private static func nachStufe(_ liste: [Hinweis]) -> [Hinweis] {
        liste.enumerated()
            .sorted { $0.element.stufe.rawValue != $1.element.stufe.rawValue
                ? $0.element.stufe.rawValue > $1.element.stufe.rawValue
                : $0.offset < $1.offset }
            .map(\.element)
    }

    private static func rechnen(von: Ort, nach: Ort, profil: Fahrzeugprofil,
                                verkehr: Bool, eigeneSperren: [Verkehrsmeldung]) async throws -> [Route] {
        switch profil.art {
        case .auto: return try await auto(von: von, nach: nach, profil: profil, verkehr: verkehr, eigeneSperren: eigeneSperren)
        case .fahrrad: return try await rad(von: von, nach: nach, profil: profil)
        case .zuFuss: return try await fuss(von: von, nach: nach, profil: profil)
        }
    }

    /// Zwei Vorschläge, die fast gleich lang sind, sind derselbe Weg — oder
    /// einer, der sich nur um eine Ecke unterscheidet. Der zweite fällt weg.
    private static func ohneDoppel(_ liste: [Route]) -> [Route] {
        var ergebnis: [Route] = []
        for r in liste where !ergebnis.contains(where: { abs($0.laengeM - r.laengeM) < max(30, r.laengeM * 0.005) }) {
            ergebnis.append(r)
        }
        return ergebnis
    }

    private static func fuss(von: Ort, nach: Ort, profil: Fahrzeugprofil) async throws -> [Route] {
        let liste = try await Valhalla.routen(von: von.punkt, nach: nach.punkt, profil: profil, alternativen: 2)
        let routen = liste.map { a in
            Route(punkte: a.punkte,
                  abschnitte: [Abschnitt(art: .fahren, punkte: a.punkte, laengeM: a.laengeM, wegart: nil)],
                  laengeM: a.laengeM,
                  posten: Fahrzeit.zuFuss(laengeM: a.laengeM, profil: profil),
                  zeitDienstS: a.zeitS,
                  anweisungen: a.anweisungen,
                  hinweise: [Hinweis(stufe: .info, text: "Fußwege aus OpenStreetMap. Treppen und Wege ohne Belag sind möglich; eine barrierefreie Route ist das nicht.")],
                  meldungen: [], umfahren: [], angekuendigt: [],
                  quelle: Valhalla.name, verkehrGeprueft: false)
        }
        return ohneDoppel(routen.sorted { $0.laengeM < $1.laengeM })
    }

    private static func rad(von: Ort, nach: Ort, profil: Fahrzeugprofil) async throws -> [Route] {
        do {
            let liste = try await BRouter.routen(von: von.punkt, nach: nach.punkt, profil: profil)
            let routen = liste.map { a in
                radRoute(abschnitte: a.abschnitte, punkte: a.punkte, laenge: a.laengeM, anweisungen: [],
                         quelle: BRouter.name, belaege: a.belaege, vorab: [], profil: profil)
            }
            return ohneDoppel(routen.sorted { $0.laengeM < $1.laengeM })
        } catch Routenfehler.keinWeg(let text) {
            throw Routenfehler.keinWeg(text)
        } catch {
            // Rückfall: Valhalla fährt nur, wo Räder erlaubt sind, und kennt
            // kein Schieben. Das steht dann auch da.
            let liste = try await Valhalla.routen(von: von.punkt, nach: nach.punkt, profil: profil, alternativen: 2)
            let warnung = Hinweis(stufe: .warnung, text: "BRouter hat nicht geantwortet (\(error.localizedDescription)). Diese Route kommt von Valhalla: ohne Schiebestrecken, und eine Radwegpflicht neben der Fahrbahn ist dort nicht geprüft.")
            let routen = liste.map { a in
                radRoute(abschnitte: [Abschnitt(art: .fahren, punkte: a.punkte, laengeM: a.laengeM, wegart: nil)],
                         punkte: a.punkte, laenge: a.laengeM, anweisungen: a.anweisungen,
                         quelle: Valhalla.name, belaege: [], vorab: [warnung], profil: profil)
            }
            return ohneDoppel(routen.sorted { $0.laengeM < $1.laengeM })
        }
    }

    private static func radRoute(abschnitte: [Abschnitt], punkte: [Punkt], laenge: Double,
                                 anweisungen: [Anweisung], quelle: String, belaege: [Belagstueck],
                                 vorab: [Hinweis], profil: Fahrzeugprofil) -> Route {
        var hinweise = vorab
        let schiebe = abschnitte.filter { $0.art == .schieben || $0.art == .treppe }
        if !schiebe.isEmpty {
            let summe = schiebe.reduce(0) { $0 + $1.laengeM }
            hinweise.append(Hinweis(stufe: .warnung, text: "\(schiebe.count) Schiebestrecke(n), zusammen \(Anzeige.strecke(summe)) — auf der Karte gestrichelt orange."))
        } else if quelle == BRouter.name && profil.schieben {
            hinweise.append(Hinweis(stufe: .info, text: "Keine Schiebestrecke: Dieser Weg führt nur über Straßen und freigegebene Wege."))
        } else if !profil.schieben {
            hinweise.append(Hinweis(stufe: .info, text: "Schieben ist ausgeschlossen: Gehwege, Fußgängerzonen und Treppen ohne Radfreigabe werden umfahren. Der Weg kann dadurch länger sein."))
        }
        let pflicht = abschnitte.filter { $0.art == .radwegPflicht }
        if !pflicht.isEmpty {
            let summe = pflicht.reduce(0) { $0 + $1.laengeM }
            hinweise.append(Hinweis(stufe: .warnung, text: "\(pflicht.count) Stück(e) mit Radwegpflicht, zusammen \(Anzeige.strecke(summe)): Die Fahrbahn ist dort für Räder verboten, es gibt einen Radweg daneben. Den Radweg nehmen oder auf dem Gehweg schieben — auf der Karte gestrichelt lila."))
        }
        hinweise.append(Hinweis(stufe: .info, text: "Kürzester ERLAUBTER Weg: Autobahnen, Kraftfahrstraßen und Wege mit Radverbot sind ausgeschlossen. Belag und Steigung zählen bewusst nicht. Die Alternativen sind länger — dafür führen sie woanders entlang."))
        return Route(punkte: punkte, abschnitte: abschnitte, laengeM: laenge,
                     posten: Fahrzeit.rad(abschnitte: abschnitte, profil: profil),
                     zeitDienstS: nil, anweisungen: anweisungen, hinweise: nachStufe(hinweise),
                     meldungen: [], umfahren: [], angekuendigt: [],
                     quelle: quelle, verkehrGeprueft: false, belaege: belaege)
    }

    /// Ab so viel Zeitverlust sucht die App eigens einen Weg um den Stau
    /// herum. Gewählt, nicht gemessen — darunter lohnt die Umfahrung selten
    /// den Umweg über Landstraßen, zumal mit Anhänger.
    static let stauSchwelleMin: Double = 10

    private static func auto(von: Ort, nach: Ort, profil: Fahrzeugprofil,
                             verkehr: Bool, eigeneSperren: [Verkehrsmeldung]) async throws -> [Route] {
        var umfahren: [Verkehrsmeldung] = eigeneSperren
        var vorab: [Hinweis] = []
        var kandidaten = try await Valhalla.routen(von: von.punkt, nach: nach.punkt, profil: profil,
                                                   sperrflaechen: umfahren.compactMap(\.sperrflaeche),
                                                   alternativen: 2)
        var alle: [Verkehrsmeldung] = []
        var fehlgeschlagen: [String] = []
        var geprueft = false

        func meldungenHolen(_ liste: [Valhalla.Antwort]) async {
            let strassen = Autobahnverkehr.autobahnen(in: liste.reduce(into: Set<String>()) { $0.formUnion($1.strassen) })
            let (m, fehl) = await Autobahnverkehr.meldungen(fuer: strassen)
            geprueft = true
            alle = m
            fehlgeschlagen = fehl
        }

        if verkehr {
            // Bis zu vier Runden: Routen holen, Meldungen darauf suchen, was
            // dieses Fahrzeug nicht durchlässt, meiden, noch einmal fragen.
            // Geprüft werden ALLE Vorschläge — eine Sperrung auf der zweiten
            // Alternative sperrt genauso.
            for runde in 0..<4 {
                await meldungenHolen(kandidaten)
                var neu: [Verkehrsmeldung] = []
                for k in kandidaten {
                    for m in Autobahnverkehr.aufDerRoute(alle, route: k.punkte)
                    where m.sperrt(breite: profil.breiteM) && !umfahren.contains(m) && !neu.contains(m) {
                        neu.append(m)
                    }
                }
                if neu.isEmpty || runde == 3 { break }
                do {
                    let naechste = try await Valhalla.routen(
                        von: von.punkt, nach: nach.punkt, profil: profil,
                        sperrflaechen: (umfahren + neu).compactMap(\.sperrflaeche), alternativen: 2)
                    umfahren += neu
                    kandidaten = naechste
                } catch Routenfehler.keinWeg {
                    vorab.append(Hinweis(stufe: .gefahr, text: "Um die Sperrung herum gibt es keinen Weg. Die Route führt deshalb HINDURCH — vor der Fahrt die Lage prüfen."))
                    break
                }
            }
        }

        var routen = await auswerten(kandidaten, alle: alle, umfahren: umfahren, staumeidung: [],
                                     profil: profil, verkehr: verkehr, geprueft: geprueft,
                                     fehlgeschlagen: fehlgeschlagen, vorab: vorab)

        // Stau umfahren: Liegt auf dem bisher schnellsten Vorschlag ein
        // Stau über der Schwelle, fragt die App eigens nach einem Weg, der
        // die Mitte des Staus meidet. Ob er sich lohnt, entscheidet danach
        // dieselbe Rechnung wie für alle anderen — samt dem Stau, in den er
        // vielleicht selbst gerät.
        if verkehr, let beste = routen.min(by: { $0.zeitS < $1.zeitS }) {
            let staus = beste.meldungen.filter { $0.art == .stau && ($0.verzoegerungMin ?? 0) >= stauSchwelleMin }
            if !staus.isEmpty,
               let um = try? await Valhalla.routen(
                   von: von.punkt, nach: nach.punkt, profil: profil,
                   sperrflaechen: (umfahren + staus).compactMap(\.sperrflaeche), alternativen: 0) {
                // Neue Straßen können dazukommen — ihre Meldungen gehören in
                // dieselbe Rechnung.
                await meldungenHolen(kandidaten + um)
                routen = await auswerten(kandidaten, alle: alle, umfahren: umfahren, staumeidung: [],
                                         profil: profil, verkehr: verkehr, geprueft: geprueft,
                                         fehlgeschlagen: fehlgeschlagen, vorab: vorab)
                routen += await auswerten(um, alle: alle, umfahren: umfahren, staumeidung: staus,
                                          profil: profil, verkehr: verkehr, geprueft: geprueft,
                                          fehlgeschlagen: fehlgeschlagen, vorab: vorab)
            }
        }
        // Die schnellste zuerst — und zwar MIT dem Zeitverlust aus den
        // Staumeldungen. Das ist der Unterschied zur Reihenfolge des Dienstes,
        // der ohne Verkehrslage rechnet.
        return ohneDoppel(routen.sorted { $0.zeitS < $1.zeitS })
    }

    /// Macht aus den Antworten des Dienstes Routen samt eigener Fahrzeit,
    /// Stauverlust und Hinweisen. Die Straßenarten werden je Vorschlag
    /// nebenläufig geholt.
    private static func auswerten(_ kandidaten: [Valhalla.Antwort], alle: [Verkehrsmeldung],
                                  umfahren: [Verkehrsmeldung], staumeidung: [Verkehrsmeldung],
                                  profil: Fahrzeugprofil, verkehr: Bool, geprueft: Bool,
                                  fehlgeschlagen: [String], vorab: [Hinweis]) async -> [Route] {
        var kanten: [Int: [Valhalla.Kante]] = [:]
        await withTaskGroup(of: (Int, [Valhalla.Kante]?).self) { gruppe in
            for (i, k) in kandidaten.enumerated() {
                gruppe.addTask { (i, try? await Valhalla.kanten(shape: k.shape, profil: profil)) }
            }
            for await (i, liste) in gruppe { if let liste { kanten[i] = liste } }
        }
        return kandidaten.enumerated().map { i, k in
            autoRoute(k, kanten: kanten[i], aufRoute: geprueft ? Autobahnverkehr.aufDerRoute(alle, route: k.punkte) : [],
                      umfahren: umfahren, staumeidung: staumeidung, profil: profil, verkehr: verkehr,
                      geprueft: geprueft, fehlgeschlagen: fehlgeschlagen, vorab: vorab)
        }
    }

    private static func autoRoute(_ ergebnis: Valhalla.Antwort, kanten: [Valhalla.Kante]?,
                                  aufRoute: [Verkehrsmeldung], umfahren: [Verkehrsmeldung],
                                  staumeidung: [Verkehrsmeldung], profil: Fahrzeugprofil,
                                  verkehr: Bool, geprueft: Bool, fehlgeschlagen: [String],
                                  vorab: [Hinweis]) -> Route {
        var hinweise = vorab
        var posten: [Zeitposten]
        if let kanten, !kanten.isEmpty {
            posten = Fahrzeit.auto(kanten: kanten, profil: profil, abbiegungen: ergebnis.abbiegungen)
        } else {
            posten = [Zeitposten(text: "Fahrzeit laut Routendienst (Straßenarten nicht abrufbar, Anhängertempo NICHT eingerechnet)", sekunden: ergebnis.zeitS)]
            if profil.abbiegeAufschlag > 0 && ergebnis.abbiegungen > 0 {
                posten.append(Zeitposten(text: "\(ergebnis.abbiegungen) × Abbiegen à \(Int(profil.abbiegeAufschlag)) s",
                                         sekunden: Double(ergebnis.abbiegungen) * profil.abbiegeAufschlag))
            }
        }

        let gueltig = aufRoute.filter { !$0.zukuenftig }
        let angekuendigt = aufRoute.filter { $0.zukuenftig }
        let stau = gueltig.compactMap { $0.art == .stau ? $0.verzoegerungMin : nil }.reduce(0, +)
        if stau > 0 {
            posten.append(Zeitposten(text: "Zeitverlust laut Staumeldungen auf dieser Route", sekunden: stau * 60))
        }
        let ohneAngabe = gueltig.filter { $0.art == .stau && $0.verzoegerungMin == nil }.count
        if ohneAngabe > 0 {
            hinweise.append(Hinweis(stufe: .warnung, text: "\(ohneAngabe) Verkehrsmeldung(en) auf der Route ohne Angabe des Zeitverlusts — sie sind in der Fahrzeit NICHT enthalten."))
        }
        if !staumeidung.isEmpty {
            let namen = staumeidung.map { "\($0.titel) (+\(Int(($0.verzoegerungMin ?? 0).rounded())) min)" }
            hinweise.append(Hinweis(stufe: .info, text: "Diese Route meidet mit Absicht den Stau \(namen.joined(separator: ", ")). Gemieden wird ein Kästchen um die Mitte des Staus, in BEIDEN Richtungen — ob der Umweg sich lohnt, zeigt der Zeitvergleich mit den anderen Vorschlägen."))
        }

        // Hinweise, das Gefährlichste zuerst.
        for m in gueltig where m.sperrt(breite: profil.breiteM) {
            hinweise.append(Hinweis(stufe: .gefahr, text: "Weiterhin auf der Route: \(m.art.name) \(m.titel)."))
        }
        for m in gueltig where m.art == .baustelle && !m.sperrt(breite: profil.breiteM) {
            if let h = m.hoechstbreiteM, let b = profil.breiteM {
                hinweise.append(Hinweis(stufe: b + 0.3 > h ? .warnung : .info,
                                        text: "Baustelle \(m.titel): Durchfahrtsbreite \(Anzeige.zahl(h)) m bei \(Anzeige.zahl(b)) m Fahrzeugbreite."))
            }
        }
        for m in gueltig where m.art == .anschlussGesperrt {
            hinweise.append(Hinweis(stufe: .warnung, text: "\(m.titel): Auf- oder Abfahrt gesperrt. Ob die Route sie benutzt, lässt sich aus der Meldung nicht sicher lesen."))
        }
        if let kanten {
            let tunnel = Set(kanten.filter(\.tunnel).map { $0.namen.first ?? "ohne Namen" })
            if !tunnel.isEmpty {
                hinweise.append(Hinweis(stufe: profil.hoeheM == nil ? .info : .warnung,
                                        text: "Tunnel auf der Route: \(tunnel.sorted().joined(separator: ", "))."))
            }
        }
        if profil.hoeheM != nil || profil.breiteM != nil {
            var masse: [String] = []
            if let h = profil.hoeheM { masse.append("Höhe \(Anzeige.zahl(h)) m") }
            if let b = profil.breiteM { masse.append("Breite \(Anzeige.zahl(b)) m") }
            hinweise.append(Hinweis(stufe: .info, text: "\(masse.joined(separator: " und ")) sind berücksichtigt, SOWEIT die Durchfahrtshöhe oder -breite in OpenStreetMap eingetragen ist. Eine Unterführung ohne Eintrag gilt als frei — vor Ort auf die Schilder achten. Das Gewicht wird nicht geprüft."))
        }
        if profil.mitAnhaenger {
            hinweise.append(Hinweis(stufe: .info, text: "Mit Anhänger gerechnet: Autobahn \(profil.tempo100 ? 100 : 80) km/h, außerorts 80 km/h — auch auf Kraftfahrstraßen, wo mit Tempo-100-Zulassung teils 100 erlaubt wären. Außerhalb Deutschlands gelten andere Grenzen."))
        }
        if verkehr {
            hinweise.append(Hinweis(stufe: .info, text: "Staus zählen in die Fahrzeit und in die Reihenfolge der Vorschläge; ab \(Int(stauSchwelleMin)) Minuten Zeitverlust sucht die App eigens einen Weg drumherum. Meldungen gibt es aber nur für AUTOBAHNEN (Autobahn GmbH) — Staus auf Bundes-, Landes- und Stadtstraßen kennt die App nicht."))
            if !fehlgeschlagen.isEmpty {
                hinweise.append(Hinweis(stufe: .warnung, text: "Für \(fehlgeschlagen.joined(separator: ", ")) ließen sich keine Meldungen holen — dort ist die Lage unbekannt."))
            }
        } else {
            hinweise.append(Hinweis(stufe: .info, text: "Verkehrsmeldungen sind ausgeschaltet — Staus zählen NICHT in die Fahrzeit."))
        }

        return Route(punkte: ergebnis.punkte,
                     abschnitte: [Abschnitt(art: .fahren, punkte: ergebnis.punkte, laengeM: ergebnis.laengeM, wegart: nil)],
                     laengeM: ergebnis.laengeM,
                     posten: posten,
                     zeitDienstS: ergebnis.zeitS,
                     anweisungen: ergebnis.anweisungen,
                     hinweise: nachStufe(hinweise),
                     meldungen: gueltig,
                     umfahren: umfahren,
                     angekuendigt: angekuendigt,
                     quelle: Valhalla.name + (geprueft ? ", " + Autobahnverkehr.name : ""),
                     verkehrGeprueft: geprueft,
                     staumeidung: staumeidung,
                     stauS: stau * 60)
    }
}
