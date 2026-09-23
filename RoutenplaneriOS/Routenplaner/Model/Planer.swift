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
    @Published private(set) var route: Route?
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
        guard let start, let ziel else { route = nil; return }
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
                route = r
            } catch {
                if Task.isCancelled { return }
                // Eine alte Route bleibt NICHT stehen: Sie gälte für andere
                // Punkte oder ein anderes Fahrzeug und sähe trotzdem aus
                // wie die Antwort.
                route = nil
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
                                verkehr: Bool, eigeneSperren: [Verkehrsmeldung]) async throws -> Route {
        switch profil.art {
        case .auto: return try await auto(von: von, nach: nach, profil: profil, verkehr: verkehr, eigeneSperren: eigeneSperren)
        case .fahrrad: return try await rad(von: von, nach: nach, profil: profil)
        case .zuFuss: return try await fuss(von: von, nach: nach, profil: profil)
        }
    }

    private static func fuss(von: Ort, nach: Ort, profil: Fahrzeugprofil) async throws -> Route {
        let a = try await Valhalla.route(von: von.punkt, nach: nach.punkt, profil: profil)
        return Route(punkte: a.punkte,
                     abschnitte: [Abschnitt(art: .fahren, punkte: a.punkte, laengeM: a.laengeM, wegart: nil)],
                     laengeM: a.laengeM,
                     posten: Fahrzeit.zuFuss(laengeM: a.laengeM, profil: profil),
                     zeitDienstS: a.zeitS,
                     anweisungen: a.anweisungen,
                     hinweise: [Hinweis(stufe: .info, text: "Fußwege aus OpenStreetMap. Treppen und Wege ohne Belag sind möglich; eine barrierefreie Route ist das nicht.")],
                     meldungen: [], umfahren: [], angekuendigt: [],
                     quelle: Valhalla.name, verkehrGeprueft: false)
    }

    private static func rad(von: Ort, nach: Ort, profil: Fahrzeugprofil) async throws -> Route {
        var hinweise: [Hinweis] = []
        let weg: (abschnitte: [Abschnitt], punkte: [Punkt], laenge: Double)
        var anweisungen: [Anweisung] = []
        var quelle = BRouter.name
        do {
            let a = try await BRouter.route(von: von.punkt, nach: nach.punkt, profil: profil)
            weg = (a.abschnitte, a.punkte, a.laengeM)
        } catch Routenfehler.keinWeg(let text) {
            throw Routenfehler.keinWeg(text)
        } catch {
            // Rückfall: Valhalla fährt nur, wo Räder erlaubt sind, und kennt
            // kein Schieben. Das steht dann auch da.
            let a = try await Valhalla.route(von: von.punkt, nach: nach.punkt, profil: profil)
            weg = ([Abschnitt(art: .fahren, punkte: a.punkte, laengeM: a.laengeM, wegart: nil)], a.punkte, a.laengeM)
            anweisungen = a.anweisungen
            quelle = Valhalla.name
            hinweise.append(Hinweis(stufe: .warnung, text: "BRouter hat nicht geantwortet (\(error.localizedDescription)). Diese Route kommt von Valhalla: ohne Schiebestrecken, und eine Radwegpflicht neben der Fahrbahn ist dort nicht geprüft."))
        }
        let abschnitte = weg.abschnitte
        let schiebe = abschnitte.filter { $0.art == .schieben || $0.art == .treppe }
        if !schiebe.isEmpty {
            let summe = schiebe.reduce(0) { $0 + $1.laengeM }
            hinweise.append(Hinweis(stufe: .warnung, text: "\(schiebe.count) Schiebestrecke(n), zusammen \(Anzeige.strecke(summe)) — auf der Karte gestrichelt orange."))
        } else if quelle == BRouter.name && profil.schieben {
            hinweise.append(Hinweis(stufe: .info, text: "Keine Schiebestrecke: Der kürzeste Weg führt nur über Straßen und freigegebene Wege."))
        }
        let pflicht = abschnitte.filter { $0.art == .radwegPflicht }
        if !pflicht.isEmpty {
            let summe = pflicht.reduce(0) { $0 + $1.laengeM }
            hinweise.append(Hinweis(stufe: .warnung, text: "\(pflicht.count) Stück(e) mit Radwegpflicht, zusammen \(Anzeige.strecke(summe)): Die Fahrbahn ist dort für Räder verboten, es gibt einen Radweg daneben. Den Radweg nehmen oder auf dem Gehweg schieben — auf der Karte gestrichelt lila."))
        }
        hinweise.append(Hinweis(stufe: .info, text: "Kürzester ERLAUBTER Weg: Autobahnen, Kraftfahrstraßen und Wege mit Radverbot sind ausgeschlossen. Belag und Steigung zählen bewusst nicht."))
        return Route(punkte: weg.punkte, abschnitte: abschnitte, laengeM: weg.laenge,
                     posten: Fahrzeit.rad(abschnitte: abschnitte, profil: profil),
                     zeitDienstS: nil, anweisungen: anweisungen, hinweise: hinweise,
                     meldungen: [], umfahren: [], angekuendigt: [],
                     quelle: quelle, verkehrGeprueft: false)
    }

    private static func auto(von: Ort, nach: Ort, profil: Fahrzeugprofil,
                             verkehr: Bool, eigeneSperren: [Verkehrsmeldung]) async throws -> Route {
        var umfahren: [Verkehrsmeldung] = eigeneSperren
        var hinweise: [Hinweis] = []
        var ergebnis = try await Valhalla.route(von: von.punkt, nach: nach.punkt, profil: profil,
                                                sperrflaechen: umfahren.compactMap(\.sperrflaeche))
        var aufRoute: [Verkehrsmeldung] = []
        var fehlgeschlagen: [String] = []
        var geprueft = false

        if verkehr {
            // Bis zu drei Runden: Route holen, Meldungen darauf suchen, was
            // dieses Fahrzeug nicht durchlässt, meiden, noch einmal fragen.
            for runde in 0..<4 {
                let strassen = Autobahnverkehr.autobahnen(in: ergebnis.strassen)
                let (alle, fehl) = await Autobahnverkehr.meldungen(fuer: strassen)
                geprueft = true
                fehlgeschlagen = fehl
                aufRoute = Autobahnverkehr.aufDerRoute(alle, route: ergebnis.punkte)
                let neu = aufRoute.filter { $0.sperrt(breite: profil.breiteM) && !umfahren.contains($0) }
                if neu.isEmpty || runde == 3 { break }
                do {
                    let naechste = try await Valhalla.route(
                        von: von.punkt, nach: nach.punkt, profil: profil,
                        sperrflaechen: (umfahren + neu).compactMap(\.sperrflaeche))
                    umfahren += neu
                    ergebnis = naechste
                } catch Routenfehler.keinWeg {
                    hinweise.append(Hinweis(stufe: .gefahr, text: "Um die Sperrung herum gibt es keinen Weg. Die Route führt deshalb HINDURCH — vor der Fahrt die Lage prüfen."))
                    break
                }
            }
        }

        let kanten = try? await Valhalla.kanten(shape: ergebnis.shape, profil: profil)
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
            posten.append(Zeitposten(text: "Zeitverlust laut Verkehrsmeldungen", sekunden: stau * 60))
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
            hinweise.append(Hinweis(stufe: .info, text: "Verkehrsmeldungen gibt es nur für Autobahnen (Autobahn GmbH). Staus und Sperrungen auf Bundes-, Landes- und Stadtstraßen sind NICHT berücksichtigt, und ein Stau verlängert die Zeit, verlegt aber die Route nicht."))
            if !fehlgeschlagen.isEmpty {
                hinweise.append(Hinweis(stufe: .warnung, text: "Für \(fehlgeschlagen.joined(separator: ", ")) ließen sich keine Meldungen holen — dort ist die Lage unbekannt."))
            }
        } else {
            hinweise.append(Hinweis(stufe: .info, text: "Verkehrsmeldungen sind ausgeschaltet."))
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
                     verkehrGeprueft: geprueft)
    }
}
