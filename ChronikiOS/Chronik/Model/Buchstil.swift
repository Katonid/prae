import UIKit

// DIE GESTALTUNG DES BUCHES (ab 1.0.2).
//
// Befund des Nutzers 11/2026 zu 1.0.1, mit Bildschirmfoto: „Diese nüchterne
// Aufteilung ist meilenweit von einem Wow-Effekt entfernt. Da waren wir in
// den anderen Apps doch schon weiter." Er hatte recht: Jede Fotoseite war
// ein 2×2-Raster mit gleich breitem weißen Rand, jedes Bild auf dasselbe
// Hochformat beschnitten, die Kapitelseite eine Jahreszahl auf leerem
// Papier. Dieselbe Lehre wie im Reisebuch 1.0.35/1.0.36: Ein Automat, der
// nur rechtwinklige gleich große Kacheln kennt, macht ein Formular, kein
// Buch.
//
// Ein Stil legt fest, WIE gezeichnet wird (Papier, Schriften, Akzent,
// randlose Bilder ja/nein, Fotos als Abzüge mit weißem Rand), der
// Seitenbau entscheidet, WAS auf welche Seite kommt — und fragt den Stil
// nur, wie viel Platz der Text neben den Bildern hat.
enum Buchstil: String, Codable, CaseIterable, Identifiable {
    /// Randlose Aufmacher, Kapitelseiten als ganzseitiges Foto, schmale Fugen.
    case modern
    /// Cremefarbenes Papier, Fotos als Abzüge mit weißem Rand, leicht gedreht.
    case album
    /// Weißer Satzspiegel, Fotos innerhalb der Ränder, Serifenschrift.
    case klassisch

    var id: String { rawValue }

    var name: String {
        switch self {
        case .modern: return "Modern"
        case .album: return "Album"
        case .klassisch: return "Klassisch"
        }
    }

    var beschreibung: String {
        switch self {
        case .modern:
            return "Große Fotos bis an den Seitenrand, Kapitel und Titel als ganzseitiges Bild mit großer Schrift darauf, Fotos im Blocksatz mit schmaler Fuge."
        case .album:
            return "Wie ein eingeklebtes Album: Fotos mit weißem Rand, leicht gedreht und mit Schatten, Bildunterschriften in Handschrift, cremefarbenes Papier."
        case .klassisch:
            return "Ruhig und zeitlos: weiße Ränder, Fotos im Satzspiegel, Serifenschrift."
        }
    }

    /// Randlose Bilder (Aufmacher, Kapitel, Titel)?
    var randlos: Bool { self == .modern }

    var papier: UIColor {
        switch self {
        case .modern: return .white
        case .album: return UIColor(red: 0.957, green: 0.937, blue: 0.894, alpha: 1)
        case .klassisch: return UIColor(red: 1.0, green: 0.996, blue: 0.976, alpha: 1)
        }
    }

    var akzent: UIColor {
        switch self {
        case .modern: return UIColor(red: 0.722, green: 0.420, blue: 0.243, alpha: 1)
        case .album: return UIColor(red: 0.42, green: 0.30, blue: 0.22, alpha: 1)
        case .klassisch: return UIColor(white: 0.35, alpha: 1)
        }
    }

    // MARK: Schriften (alle auf iPhone und iPad vorhanden)

    var titelschrift: String {
        switch self {
        case .modern: return "Didot-Bold"
        case .album: return "Noteworthy-Bold"
        case .klassisch: return "Georgia-Bold"
        }
    }

    var grundschrift: String {
        switch self {
        case .modern: return "Charter-Roman"
        case .album, .klassisch: return "Georgia"
        }
    }

    var kleinschrift: String {
        switch self {
        case .modern: return "AvenirNext-Medium"
        case .album: return "Noteworthy-Light"
        case .klassisch: return "Georgia-Italic"
        }
    }

    var unterschriftschrift: String {
        switch self {
        case .modern: return "AvenirNext-Regular"
        case .album: return "Noteworthy-Light"
        case .klassisch: return "Georgia-Italic"
        }
    }

    /// Fuge zwischen Fotos in Seitenpunkten.
    var fuge: CGFloat {
        switch self {
        case .modern: return 4
        case .album: return 16
        case .klassisch: return 9
        }
    }

    /// Wie viele Fotos ein Text auf seine erste Seite mitnimmt.
    var fotosBeimText: Int { self == .klassisch ? 2 : 3 }
}
