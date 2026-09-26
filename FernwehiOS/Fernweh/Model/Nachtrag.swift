import Foundation
import Photos
import CoreLocation

// EINE REISE IM NACHHINEIN FÜLLEN (ab 1.0.17, Ansage des Nutzers 09/2026:
// „Reisen auch im Nachhinein anlegen können: Fotos importieren, die
// Zeitstempel und Ortsangabe hinterlassen").
//
// Aus den Fotos im Zeitraum der Reise wird JE TAG EIN Eintrag: Zeitpunkt des
// ersten Fotos, Ort und Name der Stelle mit den meisten Fotos, die übrigen
// Stellen als „Orte des Tages" mit Uhrzeit, dazu das Wetter jenes Tages.
// Texte schreibt man danach in Ruhe — in den Eintrag und zu jedem Foto.
//
// **Der Tag eines Fotos ist der Tag AM ORT**, nicht der auf diesem Gerät:
// Ein Abendfoto aus Toronto ist daheim schon der nächste Morgen. Die Zone
// kommt aus Apples Ortsdienst, eine Anfrage je halbem Grad (gut 50 km) —
// eine Reise hat davon meist eine Handvoll. Ein Foto ohne Ort nimmt die Zone
// des zeitlich nächsten Fotos mit Ort; gibt es keines, die des Geräts.

@MainActor
enum Nachtrag {
    struct Tagesgruppe: Identifiable {
        let schluessel: String
        let zone: TimeZone
        var assets: [PHAsset]
        var id: String { schluessel }
        var datum: Date? { Tag.datum(schluessel: schluessel) }
    }

    /// Die Fotos der Reise, nach Tag in Ortszeit — ohne die, die schon in
    /// ihr stehen.
    static func fotos(fuer reise: Reise) async -> [Tagesgruppe] {
        // Einen Tag Rand auf jeder Seite: Die Zone am Ort kann bis zu 14
        // Stunden von der des Geräts abweichen.
        let von = reise.anfang.addingTimeInterval(-86_400)
        let bis = Tag.ende(reise.schluss).addingTimeInterval(86_400)
        let vorhanden = Set(reise.eintragListe.flatMap(\.fotoListe).compactMap(\.assetID))
        let alle = Fotodienst.shared.fotos(von: von, bis: bis).filter { !vorhanden.contains($0.localIdentifier) }
        let zonen = await zonen(fuer: alle)
        let gueltig = Set(reise.bisherigeTage.map(Tag.schluessel))

        var jeTag: [String: [(PHAsset, TimeZone)]] = [:]
        for (asset, zone) in zip(alle, zonen) {
            guard let d = asset.creationDate else { continue }
            let t = Tag.schluessel(d, zone: zone)
            if gueltig.contains(t) { jeTag[t, default: []].append((asset, zone)) }
        }
        return jeTag.keys.sorted().map { t in
            let liste = jeTag[t] ?? []
            // Die Zone des Tages: die häufigste seiner Fotos.
            var zaehler: [String: Int] = [:]
            for (_, z) in liste { zaehler[z.identifier, default: 0] += 1 }
            let zone = zaehler.max { $0.value < $1.value }.flatMap { TimeZone(identifier: $0.key) } ?? .current
            return Tagesgruppe(schluessel: t, zone: zone, assets: liste.map(\.0))
        }
    }

    private static func zonen(fuer assets: [PHAsset]) async -> [TimeZone] {
        var jeZelle: [String: TimeZone] = [:]
        var ergebnis: [TimeZone?] = []
        for a in assets {
            guard let k = a.location?.coordinate else { ergebnis.append(nil); continue }
            let zelle = "\(Int((k.latitude * 2).rounded(.down)))|\(Int((k.longitude * 2).rounded(.down)))"
            if jeZelle[zelle] == nil {
                let name = await Ortsnamen.shared.name(fuer: k)
                jeZelle[zelle] = name.flatMap { TimeZone(identifier: $0.zeitzone) } ?? .current
            }
            ergebnis.append(jeZelle[zelle])
        }
        // Ohne Ort: die Zone des zeitlich nächsten Fotos mit Ort.
        let mitOrt = assets.indices.filter { ergebnis[$0] != nil }
        return assets.indices.map { i in
            if let z = ergebnis[i] { return z }
            let zeit = assets[i].creationDate ?? .distantPast
            let naechstes = mitOrt.min {
                abs((assets[$0].creationDate ?? .distantPast).timeIntervalSince(zeit))
                    < abs((assets[$1].creationDate ?? .distantPast).timeIntervalSince(zeit))
            }
            return naechstes.flatMap { ergebnis[$0] } ?? .current
        }
    }

    /// Eine Stelle, an der fotografiert wurde: alle Fotos im Umkreis von
    /// 300 m um das erste.
    private struct Stelle {
        var mitte: CLLocation
        var zeit: Date
        var anzahl: Int
    }

    private static func stellen(_ assets: [PHAsset]) -> [Stelle] {
        var liste: [Stelle] = []
        for a in assets {
            guard let ort = a.location else { continue }
            if let i = liste.firstIndex(where: { $0.mitte.distance(from: ort) < 300 }) {
                liste[i].anzahl += 1
            } else {
                liste.append(Stelle(mitte: ort, zeit: a.creationDate ?? Date(), anzahl: 1))
            }
        }
        return liste
    }

    /// Legt je Tag einen Eintrag an. `fortschritt` meldet (fertige Fotos,
    /// alle Fotos). Gibt die Zahl der neuen Einträge zurück.
    static func uebernehmen(_ gruppen: [Tagesgruppe], in reise: Reise,
                            fortschritt: @escaping (Int, Int) -> Void) async -> Int {
        let persistenz = Persistenz.shared
        let gesamt = gruppen.reduce(0) { $0 + $1.assets.count }
        var fertig = 0
        var neu = 0
        for gruppe in gruppen where !gruppe.assets.isEmpty {
            let assets = gruppe.assets.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
            let e = persistenz.anlegen(Eintrag.self, bei: reise)
            e.kennung = UUID()
            e.erstellt = Date()
            e.geaendert = Date()
            e.autor = Geraet.name
            e.reise = reise
            e.zeitzone = gruppe.zone.identifier
            e.datum = assets.first?.creationDate ?? gruppe.datum

            // Die meistfotografierte Stelle ist der Ort des Eintrags; bis zu
            // fünf weitere werden „Orte des Tages" — mehr fragt der Ortsdienst
            // nicht gern auf einmal.
            let alle = stellen(assets)
            let wichtig = alle.sorted { $0.anzahl > $1.anzahl }.prefix(6)
            var orte: [Tagesort] = []
            for s in wichtig {
                guard let name = await Ortsnamen.shared.name(fuer: s.mitte.coordinate), !name.titel.isEmpty else { continue }
                let t = Tagesort(name: name.titel, breite: s.mitte.coordinate.latitude,
                                 laenge: s.mitte.coordinate.longitude, zeit: s.zeit)
                if e.hatOrt == false {
                    e.breite = t.breite
                    e.laenge = t.laenge
                    e.hatOrt = true
                    e.ortsname = name.titel
                    e.land = name.land
                }
                if !orte.contains(where: { $0.name == t.name }) { orte.append(t) }
            }
            if orte.count > 1 { e.ortListe = orte.sorted { ($0.zeit ?? .distantPast) < ($1.zeit ?? .distantPast) } }
            if let k = e.koordinate, let tag = gruppe.datum {
                e.tageswetter = try? await Wetterdienst.wetter(am: tag, bei: k)
            }
            persistenz.sichern()
            neu += 1

            let schon = fertig
            await Fotodienst.shared.uebernehmen(assets, in: e) { n in fortschritt(schon + n, gesamt) }
            fertig += assets.count
            fortschritt(fertig, gesamt)
        }
        persistenz.sichern()
        return neu
    }
}

// MARK: - Wanderung als Eintrag

extension Nachtrag {
    /// Legt eine Wanderung als Eintrag an — in der Reise oder, ohne Reise,
    /// privat im Lebenstagebuch. Der Ort ist ihr Startpunkt, das Wetter das
    /// jenes Tages.
    static func anlegen(_ w: Wanderung, titel: String, text: String, in reise: Reise?, zone: TimeZone) async -> Eintrag {
        let persistenz = Persistenz.shared
        let e = persistenz.anlegen(Eintrag.self, bei: reise)
        e.kennung = UUID()
        e.erstellt = Date()
        e.geaendert = Date()
        e.autor = Geraet.name
        e.reise = reise
        e.eintragsart = .wanderung
        e.zeitzone = zone.identifier
        e.datum = w.beginn
        e.titel = titel.trimmingCharacters(in: .whitespacesAndNewlines)
        e.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        e.quelle = w.quelle
        e.sportart = w.sportart
        e.strecke = Spurpunkt.packen(w.punkte)
        e.streckeMeter = w.meter
        e.hoehenmeter = w.hoehenmeter
        e.dauer = w.dauer
        if let start = w.punkte.first {
            e.breite = start.breite
            e.laenge = start.laenge
            e.hatOrt = true
            if let name = await Ortsnamen.shared.name(fuer: start.koordinate) {
                e.ortsname = name.titel
                e.land = name.land
            }
            if let tag = Tag.datum(schluessel: Tag.schluessel(w.beginn, zone: zone)) {
                e.tageswetter = try? await Wetterdienst.wetter(am: tag, bei: start.koordinate)
            }
        }
        persistenz.sichern()
        return e
    }
}
