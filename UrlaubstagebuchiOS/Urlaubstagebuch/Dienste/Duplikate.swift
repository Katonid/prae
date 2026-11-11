import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

// DOPPELTE FOTOS FINDEN (ab 1.0.128).
//
// Befund des Nutzers, 11/2026: „Durch die Fernweh-App sind offenbar Bilder
// doppelt übergeben worden. Ich möchte, dass ich in der Reisebuch-App nach
// Duplikaten suchen kann und diese automatisch entfernt werden."
//
// Die Einfuhr aus Fernweh erkennt ein Foto, das schon im Buch steht, an
// seiner KENNUNG (`fernwehUebernehmen`, „standen schon im Buch"). Trägt
// dasselbe Bild zwei Kennungen — es hängt an zwei Einträgen, es wurde in
// Fernweh neu exportiert, oder es kam zusätzlich über den Fotowähler
// herein —, ist es zweimal da, und keine Kennung verrät es. Gesucht wird
// deshalb am BILD selbst.
//
// WANN ZWEI FOTOS DASSELBE SIND — drei Bedingungen, alle zugleich:
// 1. Dieselbe AUFNAHMEZEIT bis auf zwei Sekunden — oder um ganze
//    Viertelstunden verschoben (höchstens 14 Stunden): Dasselbe Foto kann
//    einmal mit der Wanduhr aus dem EXIF und einmal mit einer
//    umgerechneten Zeit aus Fernweh ankommen, und Zeitzonen sind
//    Viertelstunden. Fehlt bei einem die Zeit, entscheidet allein das Bild.
// 2. Dasselbe SEITENVERHÄLTNIS (auf zwei Prozent). Die Größe darf
//    verschieden sein — eine verkleinerte Kopie ist dasselbe Bild.
// 3. Dasselbe BILD: beide auf 16 × 16 Graustufen verkleinert, im Mittel
//    höchstens 4 von 255 auseinander und nirgends mehr als 40. Ein
//    nachbearbeitetes Foto (anderer Ausschnitt, andere Farben) fällt damit
//    heraus, und das ist gewollt: Es ist eine Fassung, kein Doppel.
//
// Alle Zahlen sind GEWÄHLT und nicht gemessen. Zwei Bilder einer
// Serienaufnahme in derselben Sekunde ohne Bewegung darin sind nach
// diesen Regeln dasselbe Bild — und sehen auch so aus.
//
// BEHALTEN wird das GRÖSSTE (die meisten Bildpunkte); bei Gleichstand das,
// das schon auf einer Seite steht, dann das zuerst eingelesene. Was das
// andere trägt und ihm fehlt (Bildunterschrift, Ort, Aufnahmezeit), geht
// mit hinüber — siehe `Reisewerk.duplikateEntfernen`.
enum Duplikate {
    enum Grund: Hashable {
        case gleicheDatei
        case gleichesBild

        var satz: String {
            switch self {
            case .gleicheDatei: return "dieselbe Datei"
            case .gleichesBild: return "dasselbe Bild, andere Datei"
            }
        }
    }

    struct Gruppe: Identifiable, Hashable {
        var id: UUID { behalten }
        let behalten: UUID
        let weg: [UUID]
        let grund: Grund
    }

    struct Befund {
        var gruppen: [Gruppe] = []
        var geprueft = 0
        var verglichen = 0
        var nichtLesbar = 0
        var dauer: TimeInterval = 0

        var zuEntfernen: Int { gruppen.reduce(0) { $0 + $1.weg.count } }
    }

    // Die Grenzen — gewählt, nicht gemessen.
    static let zeitspiel: TimeInterval = 2
    static let zonenschritt: TimeInterval = 900
    static let zonenweite: TimeInterval = 14 * 3600
    static let seitenspiel = 0.02
    static let mittelGrenze = 4.0
    static let spitzeGrenze = 40

    // Abseits des Hauptfadens aufrufen: Für jedes Foto in Frage wird ein
    // kleines Vorschaubild aus der Datei gerechnet.
    static func suchen(fotos: [Foto], reise: UUID, benutzt: Set<UUID>,
                       fortschritt: @escaping @Sendable (Int, Int) -> Void) -> Befund
    {
        let anfang = Date()
        var befund = Befund()
        befund.geprueft = fotos.count

        // 1. Paare, die nach Zeit und Seitenverhältnis in Frage kommen.
        let paare = kandidaten(fotos)
        let beteiligt = Array(Set(paare.flatMap { [$0.0, $0.1] })).sorted()

        // 2. Das Bild — nur für die, die in einem Paar stehen.
        var merkmale: [Int: [UInt8]] = [:]
        for (nummer, stelle) in beteiligt.enumerated() {
            fortschritt(nummer, beteiligt.count)
            let ort = Bildarchiv.shared.pfad(reise, datei: fotos[stelle].datei)
            if let m = merkmal(ort) { merkmale[stelle] = m } else { befund.nichtLesbar += 1 }
        }
        fortschritt(beteiligt.count, beteiligt.count)

        // 3. Bestätigte Paare zu Gruppen (Vereinigung über einen Wald).
        var eltern = Array(fotos.indices)
        func wurzel(_ i: Int) -> Int {
            var i = i
            while eltern[i] != i { eltern[i] = eltern[eltern[i]]; i = eltern[i] }
            return i
        }
        for (a, b) in paare {
            befund.verglichen += 1
            guard let ma = merkmale[a], let mb = merkmale[b], gleich(ma, mb) else { continue }
            let ra = wurzel(a), rb = wurzel(b)
            if ra != rb { eltern[rb] = ra }
        }
        var mengen: [Int: [Int]] = [:]
        for i in fotos.indices where merkmale[i] != nil {
            mengen[wurzel(i), default: []].append(i)
        }

        for (_, glieder) in mengen where glieder.count >= 2 {
            let sortiert = glieder.sorted { a, b in
                let pa = fotos[a].breite * fotos[a].hoehe
                let pb = fotos[b].breite * fotos[b].hoehe
                if pa != pb { return pa > pb }
                let ua = benutzt.contains(fotos[a].id), ub = benutzt.contains(fotos[b].id)
                if ua != ub { return ua }
                return a < b
            }
            let erste = sortiert[0]
            let pruefsummen = Set(sortiert.map { pruefsumme(Bildarchiv.shared.pfad(reise, datei: fotos[$0].datei)) })
            let grund: Grund = pruefsummen.count == 1 && pruefsummen.first! != nil ? .gleicheDatei : .gleichesBild
            befund.gruppen.append(Gruppe(behalten: fotos[erste].id,
                                         weg: sortiert.dropFirst().map { fotos[$0].id },
                                         grund: grund))
        }
        // In der Reihenfolge des Buches, damit die Liste nicht springt.
        let stelle = Dictionary(uniqueKeysWithValues: fotos.enumerated().map { ($1.id, $0) })
        befund.gruppen.sort { (stelle[$0.behalten] ?? 0) < (stelle[$1.behalten] ?? 0) }
        befund.dauer = Date().timeIntervalSince(anfang)
        return befund
    }

    // Wer mit wem in Frage kommt. Mit Zeit: über Fächer nach der Sekunde
    // innerhalb der Viertelstunde, damit nicht jedes Foto gegen jedes
    // geprüft wird. Ohne Zeit: gegen alle mit passendem Seitenverhältnis.
    static func kandidaten(_ fotos: [Foto]) -> [(Int, Int)] {
        var paare: [(Int, Int)] = []
        var faecher: [Int: [Int]] = [:]
        var ohneZeit: [Int] = []
        let schritt = Int(zonenschritt)
        for (i, foto) in fotos.enumerated() {
            guard let zeit = foto.aufnahme else { ohneZeit.append(i); continue }
            let sekunde = Int(zeit.timeIntervalSinceReferenceDate.rounded())
            let fach = ((sekunde % schritt) + schritt) % schritt
            faecher[fach, default: []].append(i)
        }
        var gesehen = Set<Int>()
        for (fach, liste) in faecher {
            var nachbarn: [Int] = []
            for d in -Int(zeitspiel)...Int(zeitspiel) {
                nachbarn += faecher[((fach + d) % schritt + schritt) % schritt] ?? []
            }
            for a in liste {
                for b in nachbarn where a < b {
                    let schluessel = a * fotos.count + b
                    guard !gesehen.contains(schluessel), passt(fotos[a], fotos[b]) else { continue }
                    gesehen.insert(schluessel)
                    paare.append((a, b))
                }
            }
        }
        for a in ohneZeit {
            for b in fotos.indices where b != a {
                // Zwei ohne Zeit nur einmal.
                if fotos[b].aufnahme == nil, b < a { continue }
                guard fotos[a].grafik == fotos[b].grafik, gleichesFormat(fotos[a], fotos[b]) else { continue }
                paare.append((min(a, b), max(a, b)))
            }
        }
        return paare
    }

    static func passt(_ a: Foto, _ b: Foto) -> Bool {
        guard a.grafik == b.grafik, gleichesFormat(a, b),
              let za = a.aufnahme, let zb = b.aufnahme else { return false }
        let abstand = abs(za.timeIntervalSince(zb))
        guard abstand <= zonenweite + zeitspiel else { return false }
        let rest = abstand.truncatingRemainder(dividingBy: zonenschritt)
        return rest <= zeitspiel || zonenschritt - rest <= zeitspiel
    }

    static func gleichesFormat(_ a: Foto, _ b: Foto) -> Bool {
        let va = a.seitenverhaeltnis, vb = b.seitenverhaeltnis
        return abs(va - vb) <= seitenspiel * max(va, vb)
    }

    // 16 × 16 Graustufen. Gedreht wie angezeigt
    // (`kCGImageSourceCreateThumbnailWithTransform`) — sonst wäre ein
    // hochkant gespeichertes Doppel ein anderes Bild.
    static func merkmal(_ ort: URL) -> [UInt8]? {
        guard let quelle = CGImageSourceCreateWithURL(ort as CFURL, nil) else { return nil }
        let wunsch: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 96,
        ]
        guard let bild = CGImageSourceCreateThumbnailAtIndex(quelle, 0, wunsch as CFDictionary)
        else { return nil }
        let seite = 16
        var pixel = [UInt8](repeating: 0, count: seite * seite)
        let raum = CGColorSpaceCreateDeviceGray()
        let gezeichnet = pixel.withUnsafeMutableBytes { roh -> Bool in
            guard let feld = CGContext(data: roh.baseAddress, width: seite, height: seite,
                                       bitsPerComponent: 8, bytesPerRow: seite, space: raum,
                                       bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return false }
            feld.interpolationQuality = .medium
            feld.draw(bild, in: CGRect(x: 0, y: 0, width: seite, height: seite))
            return true
        }
        return gezeichnet ? pixel : nil
    }

    static func gleich(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        guard a.count == b.count, !a.isEmpty else { return false }
        var summe = 0
        for i in a.indices {
            let d = abs(Int(a[i]) - Int(b[i]))
            if d > spitzeGrenze { return false }
            summe += d
        }
        return Double(summe) / Double(a.count) <= mittelGrenze
    }

    static func pruefsumme(_ ort: URL) -> String? {
        guard let daten = try? Data(contentsOf: ort, options: .mappedIfSafe) else { return nil }
        return SHA256.hash(data: daten).map { String(format: "%02x", $0) }.joined()
    }
}
