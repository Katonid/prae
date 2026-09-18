import Foundation

/// Der letzte geglückte Stand je Haltestelle — damit die Tafel ohne Netz
/// nicht leer ist.
///
/// **Was er NICHT ist: ein Zwischenspeicher zur Beschleunigung.** Er wird nur
/// gelesen, wenn ALLE Quellen ausgefallen sind, und was er herausgibt, trägt
/// seinen Zeitstempel bis in die Oberfläche (`Fahrplanfehler.veralteterStand`).
/// Eine Abfahrt von vor zehn Minuten als frische auszugeben wäre keine
/// Auskunft, sondern eine Falschauskunft — jemand ginge zu einem Bus, der weg
/// ist.
///
/// Ein `actor`, weil von mehreren Aufgaben gleichzeitig geschrieben wird
/// (Tafel, Haltestellenansicht, Nachladelauf). Ohne ihn stünden zwei
/// Schreibvorgänge auf derselben Datei.
actor Abfahrtsspeicher {

    struct Stand: Codable {
        let abfahrten: [Abfahrt]
        let geholtUm: Date
    }

    /// Wie alt ein Stand höchstens sein darf, um noch gezeigt zu werden.
    ///
    /// Zwei Stunden: Danach ist von einer Abfahrtstafel nichts mehr übrig, was
    /// noch bevorsteht — sie zeigt ja nur die nächste Stunde. Ein älterer
    /// Stand wäre eine Liste von Fahrten, die alle schon weg sind, und das
    /// sieht aus wie ein kaputtes Programm.
    private let hoechstalter: TimeInterval = 2 * 60 * 60
    /// Wie viele Haltestellen vorgehalten werden. Mehr brauchte niemand, und
    /// eine unbegrenzte Ablage wüchse still.
    private let hoechstzahl = 12

    private let ordner: URL
    private let dateiverwaltung = FileManager.default

    init(ordner: URL? = nil) {
        if let ordner {
            self.ordner = ordner
        } else {
            // In die Caches und NICHT in die Dokumente: Es ist ein Abfall-
            // produkt, das iOS bei Platzmangel wegräumen darf. Was der Nutzer
            // selbst angelegt hat (die Merkliste), liegt woanders.
            let wurzel = (try? FileManager.default.url(
                for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )) ?? FileManager.default.temporaryDirectory
            self.ordner = wurzel.appendingPathComponent("Abfahrtsstaende", isDirectory: true)
        }
        try? dateiverwaltung.createDirectory(at: self.ordner, withIntermediateDirectories: true)
    }

    func sichern(_ abfahrten: [Abfahrt], fuer haltestelle: Haltestelle, umkreis: Int) {
        guard !abfahrten.isEmpty else { return }
        let stand = Stand(abfahrten: abfahrten, geholtUm: Date())
        guard let daten = try? JSONEncoder().encode(stand) else { return }
        try? daten.write(to: datei(haltestelle, umkreis), options: .atomic)
        aufraeumen()
    }

    func lesen(fuer haltestelle: Haltestelle, umkreis: Int) -> Stand? {
        guard let daten = try? Data(contentsOf: datei(haltestelle, umkreis)),
              let stand = try? JSONDecoder().decode(Stand.self, from: daten)
        else { return nil }
        guard Date().timeIntervalSince(stand.geholtUm) <= hoechstalter else { return nil }
        // Was schon abgefahren ist, wird gar nicht erst herausgegeben. Sonst
        // stünde nach einer Stunde ohne Netz eine Liste aus lauter
        // Vergangenheit da.
        let grenze = Date().addingTimeInterval(-60)
        let uebrig = stand.abfahrten.filter { $0.tatsaechlich >= grenze }
        guard !uebrig.isEmpty else { return nil }
        return Stand(abfahrten: uebrig, geholtUm: stand.geholtUm)
    }

    /// Der Dateiname enthält den UMKREIS, weil dieselbe Haltestelle mit 200 m
    /// und mit 2 km zwei verschiedene Tafeln ergibt. Ohne ihn überschriebe die
    /// eine die andere, und nach dem Umstellen stünde ein Stand da, der zur
    /// Einstellung nicht passt.
    private func datei(_ haltestelle: Haltestelle, _ umkreis: Int) -> URL {
        // Die Kennungen tragen Doppelpunkte und Schrägstriche — als Dateiname
        // unbrauchbar. Gehasht wird deshalb, nicht ersetzt: Ein Ersetzen führte
        // zwei verschiedene Kennungen auf denselben Namen zusammen.
        var streuwert: UInt64 = 1469598103934665603
        for byte in Array("\(haltestelle.id)#\(umkreis)".utf8) {
            streuwert = (streuwert ^ UInt64(byte)) &* 1099511628211
        }
        return ordner.appendingPathComponent("stand-\(String(streuwert, radix: 16)).json")
    }

    private func aufraeumen() {
        guard let dateien = try? dateiverwaltung.contentsOfDirectory(
            at: ordner,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        guard dateien.count > hoechstzahl else { return }
        let sortiert = dateien.sorted { links, rechts in
            let a = (try? links.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let b = (try? rechts.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return a > b
        }
        for datei in sortiert.dropFirst(hoechstzahl) {
            try? dateiverwaltung.removeItem(at: datei)
        }
    }
}
