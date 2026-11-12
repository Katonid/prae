import CoreGraphics
import Foundation

// DAS DATENMODELL.
//
// Ein Buch besteht aus drei Dingen, die nebeneinander liegen und erst beim
// Setzen zusammenkommen:
//
// * **Texte** und **Fotos** tragen je einen Zeitstempel. Daraus — und nur
//   daraus — entstehen die Kapitel (`Zeitraster`) und die Reihenfolge auf
//   den Seiten (`Seitenbau`). Kein Inhalt „gehört" fest zu einem Kapitel;
//   wer das Raster von Jahren auf Quartale stellt, bekommt ein neu
//   gegliedertes Buch, ohne etwas umzusortieren.
// * **Freie Seiten** hängen an einer `Einfuegestelle` (nach einem Inhalt,
//   am Kapitelanfang, am Buchanfang oder -ende) und NICHT an einer
//   Seitenzahl. Seitenzahlen verschieben sich bei jedem neuen Foto; der
//   Inhalt, hinter dem die Seite steht, bleibt.
//
// **Neue Felder nur mit Vorgabe anhängen** und beim Lesen mit
// `wert(_:_:)` holen: Eine ältere Datei kennt sie nicht, und ein Fehler
// beim Lesen hieße, dass ein ganzes Buch nicht mehr aufgeht.
struct Buch: Codable, Identifiable, Equatable {
    var id = UUID()
    var titel = "Unser Buch"
    var untertitel = ""
    var erstellt = Date()
    var raster = Zeitraster()
    var format: Seitenformat = .hoch21x28
    var stil: Buchstil = .modern
    var fotosJeSeite = 4
    var leereKapitelZeigen = false
    var titelfoto: UUID?
    var texte: [Texteintrag] = []
    var fotos: [Fotoeintrag] = []
    var freieSeiten: [FreieSeite] = []
    /// Eigene Kapitelüberschriften, nach dem Schlüssel des Kapitels (Datum
    /// seines Beginns). Fehlt ein Eintrag, gilt die Überschrift aus dem Raster.
    var kapitelTitel: [String: String] = [:]

    enum CodingKeys: String, CodingKey {
        case id, titel, untertitel, erstellt, raster, format, stil, fotosJeSeite, leereKapitelZeigen
        case titelfoto, texte, fotos, freieSeiten, kapitelTitel
    }
}

extension Buch {
    // In einer Erweiterung, damit der elementweise Initialisierer bleibt.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let leer = Buch()
        id = c.wert(.id, leer.id)
        titel = c.wert(.titel, leer.titel)
        untertitel = c.wert(.untertitel, leer.untertitel)
        erstellt = c.wert(.erstellt, leer.erstellt)
        raster = c.wert(.raster, leer.raster)
        format = c.wert(.format, leer.format)
        stil = c.wert(.stil, leer.stil)
        fotosJeSeite = c.wert(.fotosJeSeite, leer.fotosJeSeite)
        leereKapitelZeigen = c.wert(.leereKapitelZeigen, leer.leereKapitelZeigen)
        titelfoto = try? c.decode(UUID.self, forKey: .titelfoto)
        // Die Inhalte werden NICHT still verworfen: Lässt sich einer nicht
        // lesen, scheitert das ganze Buch, und die Bibliothek legt die
        // Datei beiseite, statt sie beim nächsten Sichern zu überschreiben.
        texte = try c.decodeIfPresent([Texteintrag].self, forKey: .texte) ?? []
        fotos = try c.decodeIfPresent([Fotoeintrag].self, forKey: .fotos) ?? []
        freieSeiten = try c.decodeIfPresent([FreieSeite].self, forKey: .freieSeiten) ?? []
        kapitelTitel = c.wert(.kapitelTitel, leer.kapitelTitel)
    }

    var anzahlInhalte: Int { texte.count + fotos.count }

    /// Alle Dateien, auf die das Buch zeigt — für das Aufräumen der Ablage.
    var dateien: Set<String> {
        var menge = Set(fotos.map(\.datei))
        for seite in freieSeiten {
            for feld in seite.felder { menge.formUnion(feld.dateien) }
        }
        return menge
    }

    func kapitelTitel(_ kapitel: Kapitel) -> String {
        kapitelTitel[kapitel.schluessel] ?? kapitel.standardTitel
    }
}

extension KeyedDecodingContainer {
    func wert<T: Decodable>(_ schluessel: Key, _ vorgabe: T) -> T {
        (try? decode(T.self, forKey: schluessel)) ?? vorgabe
    }
}

struct Texteintrag: Codable, Identifiable, Equatable {
    var id = UUID()
    var titel = ""
    var text = ""
    /// Frei einstellbar; bestimmt Kapitel und Platz im Buch.
    var zeit = Date()
    /// Die Fassung vor der letzten sprachlichen Überarbeitung — damit sich
    /// ein glattgebügelter Satz zurückholen lässt.
    var vorfassung: String?
}

struct Fotoeintrag: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Dateiname in der Ablage (`Medien`).
    var datei: String
    /// Aufnahmezeit (EXIF, sonst Mediathek, sonst Zeitpunkt der Übernahme);
    /// frei änderbar.
    var zeit: Date
    var unterschrift = ""
    /// Breite und Höhe so, wie das Bild AUFRECHT steht (Orientierung schon
    /// eingerechnet).
    var breite: Double = 0
    var hoehe: Double = 0

    var seitenverhaeltnis: CGFloat {
        breite > 0 && hoehe > 0 ? CGFloat(breite / hoehe) : 1.5
    }
}

/// Wo eine freie Seite im Buch steht.
enum Einfuegestelle: Codable, Hashable {
    case buchAnfang
    /// Gleich nach der Kapitelseite (Schlüssel des Kapitels).
    case kapitelAnfang(String)
    /// Nach der Seite, auf der dieser Text oder dieses Foto endet.
    case nachInhalt(UUID)
    case buchEnde
}

struct FreieSeite: Codable, Identifiable, Equatable {
    var id = UUID()
    var stelle: Einfuegestelle = .buchEnde
    var vorlage: Vorlage = .eins
    var felder: [Feldinhalt] = [.leer]

    func feld(_ i: Int) -> Feldinhalt { i < felder.count ? felder[i] : .leer }
}

enum Feldinhalt: Codable, Equatable {
    case leer
    case text(String)
    /// Dateiname in der Ablage.
    case foto(String)
    /// Dateiname und Seitenzahl (ab 1).
    case pdf(String, Int)

    var dateien: [String] {
        switch self {
        case .foto(let d): return [d]
        case .pdf(let d, _): return [d]
        case .leer, .text: return []
        }
    }

    var name: String {
        switch self {
        case .leer: return "leer"
        case .text: return "Text"
        case .foto: return "Foto"
        case .pdf(_, let n): return "PDF, Seite \(n)"
        }
    }
}

/// Die Aufteilung einer freien Seite.
enum Vorlage: String, Codable, CaseIterable, Identifiable {
    case eins, zweiUntereinander, zweiNebeneinander, dreiGrossOben, vierRaster

    var id: String { rawValue }

    var name: String {
        switch self {
        case .eins: return "Ein Feld"
        case .zweiUntereinander: return "Zwei untereinander"
        case .zweiNebeneinander: return "Zwei nebeneinander"
        case .dreiGrossOben: return "Eins groß, zwei klein"
        case .vierRaster: return "Vier im Raster"
        }
    }

    var symbol: String {
        switch self {
        case .eins: return "rectangle"
        case .zweiUntereinander: return "rectangle.split.1x2"
        case .zweiNebeneinander: return "rectangle.split.2x1"
        case .dreiGrossOben: return "rectangle.split.3x1"
        case .vierRaster: return "rectangle.split.2x2"
        }
    }

    var anzahl: Int {
        switch self {
        case .eins: return 1
        case .zweiUntereinander, .zweiNebeneinander: return 2
        case .dreiGrossOben: return 3
        case .vierRaster: return 4
        }
    }

    func rechtecke(in r: CGRect, abstand a: CGFloat) -> [CGRect] {
        switch self {
        case .eins:
            return [r]
        case .zweiUntereinander:
            return Seitengeometrie.untereinander(r, abstand: a, anteil: 0.5)
        case .zweiNebeneinander:
            return Seitengeometrie.nebeneinander(r, abstand: a, anteil: 0.5)
        case .dreiGrossOben:
            let teile = Seitengeometrie.untereinander(r, abstand: a, anteil: 0.58)
            return [teile[0]] + Seitengeometrie.nebeneinander(teile[1], abstand: a, anteil: 0.5)
        case .vierRaster:
            let teile = Seitengeometrie.untereinander(r, abstand: a, anteil: 0.5)
            return Seitengeometrie.nebeneinander(teile[0], abstand: a, anteil: 0.5)
                + Seitengeometrie.nebeneinander(teile[1], abstand: a, anteil: 0.5)
        }
    }
}

/// Gerechnet wird in SEITENPUNKTEN (1/72 Zoll). Bildschirm und PDF legen
/// nur einen Maßstab darüber.
enum Seitenformat: String, Codable, CaseIterable, Identifiable {
    case hoch21x28, a4Hoch, quadrat21, quadrat30, quer28x21, a4Quer

    var id: String { rawValue }

    var zentimeter: (breite: Double, hoehe: Double) {
        switch self {
        case .hoch21x28: return (21, 28)
        case .a4Hoch: return (21, 29.7)
        case .quadrat21: return (21, 21)
        case .quadrat30: return (30, 30)
        case .quer28x21: return (28, 21)
        case .a4Quer: return (29.7, 21)
        }
    }

    var name: String {
        let z = zentimeter
        let art: String
        switch self {
        case .hoch21x28, .a4Hoch: art = "Hochformat"
        case .quadrat21, .quadrat30: art = "quadratisch"
        case .quer28x21, .a4Quer: art = "Querformat"
        }
        let a4 = (self == .a4Hoch || self == .a4Quer) ? "A4, " : ""
        return "\(a4)\(Self.zahl(z.breite)) × \(Self.zahl(z.hoehe)) cm, \(art)"
    }

    var groesse: CGSize {
        let z = zentimeter
        return CGSize(width: (z.breite * 72 / 2.54).rounded(), height: (z.hoehe * 72 / 2.54).rounded())
    }

    private static func zahl(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d).replacingOccurrences(of: ".", with: ",")
    }
}
