import CoreGraphics
import Foundation

// Was ein Block zeigt. Die Bildunterschrift hängt am Foto und ist KEIN
// eigener Block: Sie muss mit dem Bild wandern, und zwei Dinge, die immer
// zusammen verschoben werden, sind eines.
enum Blockinhalt: Codable, Hashable {
    case titel
    case datum
    case text(String)
    case foto(UUID)
    case karte
    case linie

    var istFoto: Bool { if case .foto = self { return true }; return false }
    var istText: Bool {
        switch self {
        case .titel, .datum, .text: return true
        default: return false
        }
    }

    var rolle: Schriftrolle {
        switch self {
        case .titel: return .titel
        case .datum: return .datum
        default: return .flieText
        }
    }

    var name: String {
        switch self {
        case .titel: return "Überschrift"
        case .datum: return "Datum"
        case .text: return "Text"
        case .foto: return "Foto"
        case .karte: return "Karte"
        case .linie: return "Trennlinie"
        }
    }
}

// Wie das Bild IM Rahmen sitzt. Zwei Dinge, die gern verwechselt werden:
// Der Rahmen ist der Platz auf der Seite, der Ausschnitt ist der Teil des
// Bildes, der darin zu sehen ist. Wer ein Foto größer haben will, ändert
// den Rahmen; wer ein Gesicht in die Mitte rücken will, den Ausschnitt.
// Beides muss gehen, sonst ist eines davon nicht zu machen.
struct Bildausschnitt: Codable, Hashable {
    var zoom: Double = 1
    var versatzX: Double = 0
    var versatzY: Double = 0

    static let voll = Bildausschnitt()

    var istVoll: Bool { self == .voll }

    // Wo das Bild liegt, wenn es in diesen Rahmen gesetzt wird.
    //
    // Diese eine Rechnung steht hier und nirgends sonst. Die Seite auf dem
    // Bildschirm und die Seite im PDF werden von zwei verschiedenen
    // Zeichnern gemalt; rechnete jeder für sich, sähe das gedruckte Buch
    // anders aus als die Vorschau — und zwar erst dann anders, wenn es
    // gedruckt ist.
    //
    // Grundlage ist FÜLLEN, nicht Einpassen: Ein Foto, das seinen Rahmen
    // nicht ausfüllt, ließe einen Rest Papier stehen, den niemand bestellt
    // hat. Was dabei über den Rand ragt, wird abgeschnitten — und welcher
    // Teil das ist, entscheidet der Versatz.
    func zielrechteck(bildgroesse: CGSize, rahmen: CGRect) -> CGRect {
        guard bildgroesse.width > 0, bildgroesse.height > 0 else { return rahmen }
        let fuellung = max(rahmen.width / bildgroesse.width, rahmen.height / bildgroesse.height)
        let massstab = fuellung * max(zoom, 0.05)
        let breite = bildgroesse.width * massstab
        let hoehe = bildgroesse.height * massstab
        let mitteX = rahmen.midX + versatzX * rahmen.width
        let mitteY = rahmen.midY + versatzY * rahmen.height
        return CGRect(x: mitteX - breite / 2, y: mitteY - hoehe / 2, width: breite, height: hoehe)
    }

    // Hält den Ausschnitt so, dass der Rahmen gefüllt bleibt. Ohne diese
    // Grenze schöbe man das Bild aus seinem eigenen Rahmen heraus und
    // bekäme einen weißen Keil — was wie ein Fehler der App aussieht und
    // keiner ist.
    func begrenzt(bildgroesse: CGSize, rahmen: CGRect) -> Bildausschnitt {
        var neu = self
        neu.zoom = min(max(zoom, 1), 6)
        let ziel = neu.zielrechteck(bildgroesse: bildgroesse, rahmen: rahmen)
        let luftX = max((ziel.width - rahmen.width) / 2, 0) / max(rahmen.width, 1)
        let luftY = max((ziel.height - rahmen.height) / 2, 0) / max(rahmen.height, 1)
        neu.versatzX = min(max(versatzX, -luftX), luftX)
        neu.versatzY = min(max(versatzY, -luftY), luftY)
        return neu
    }
}

struct Block: Identifiable, Codable, Hashable {
    var id = UUID()
    var inhalt: Blockinhalt
    var rahmen: Rahmen
    var abweichung = Schriftabweichung()
    var ausschnitt = Bildausschnitt()
    var drehung: Double = 0
    var ebene: Int = 0
    // Ein von Hand angefasster Block wird vom Neuanordnen in Ruhe
    // gelassen. Ohne diese Marke wäre jedes automatische Aufräumen ein
    // stiller Rückschritt — und der Nutzer hätte keinen Grund mehr, der
    // Automatik zu trauen.
    var vonHand: Bool = false
    var rand: Farbwert?
    var randbreite: Double = 0
    var schatten: Bool = false
    var grund: Farbwert?

    var istFoto: Bool { inhalt.istFoto }

    var fotoID: UUID? {
        if case let .foto(id) = inhalt { return id }
        return nil
    }

    var text: String? {
        if case let .text(wert) = inhalt { return wert }
        return nil
    }
}

// Eine Seite des Buches. `vonHand` sagt, ob an ihr etwas geändert wurde —
// gefragt wird das vor dem Neuanordnen, und gefragt wird ausdrücklich:
// Eine Automatik, die eine Stunde Handarbeit ohne Rückfrage überschreibt,
// benutzt man genau einmal.
struct Seite: Identifiable, Codable, Hashable {
    var id = UUID()
    var bloecke: [Block] = []
    var papier: Farbwert?

    var vonHand: Bool { bloecke.contains(where: \.vonHand) }

    func block(_ id: UUID) -> Block? { bloecke.first { $0.id == id } }

    mutating func heben(_ id: UUID) {
        let hoechste = (bloecke.map(\.ebene).max() ?? 0) + 1
        guard let stelle = bloecke.firstIndex(where: { $0.id == id }) else { return }
        bloecke[stelle].ebene = hoechste
    }

    var sortiert: [Block] { bloecke.sorted { $0.ebene < $1.ebene } }
}
