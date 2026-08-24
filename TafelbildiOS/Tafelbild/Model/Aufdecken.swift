import Foundation

// Schrittweises Aufdecken eines gezogenen Namens.
//
// Die Maße stehen hier statt im Element, weil auch die Werkzeugleiste sie
// braucht: Sie zeigt das Auge „Ganz aufdecken" nur, solange überhaupt noch
// etwas verdeckt ist. Die Zahlen sind die der Web-App
// (`js/widgets/randomizer.js`).

enum MosaikMasse {
    static let spalten = 28
    static let zeilen = 10
    static var kacheln: Int { spalten * zeilen }
    /// So viele Tipps bis zum ganzen Namen.
    static let schritte = 12
    /// So viele Kacheln verschwinden pro Tipp.
    static var proTipp: Int { Int(ceil(Double(kacheln) / Double(schritte))) }
}

extension NamePickerContent {
    /// Zeichen, die verdeckt werden können (Buchstaben und Ziffern).
    static func verdeckbareStellen(_ name: String) -> [Int] {
        Array(name).enumerated().compactMap { position, zeichen in
            zeichen.isLetter || zeichen.isNumber ? position : nil
        }
    }

    /// So viele Teile hat das Aufdecken beim eingestellten Verfahren.
    func aufdeckSchritte(name: String) -> Int {
        switch reveal {
        case .instant: return 0
        case .mosaik:  return MosaikMasse.kacheln
        case .blur:    return RevealLayout.blurSteps
        case .letters: return max(1, Self.verdeckbareStellen(name).count)
        }
    }

    /// Steht gerade ein Name da, der noch nicht ganz zu sehen ist?
    func istVerdeckt(name: String) -> Bool {
        guard currentID != nil, reveal != .instant else { return false }
        return revealParts.count < aufdeckSchritte(name: name)
    }

    /// Deckt den Namen vollständig auf.
    mutating func alleAufdecken(name: String) {
        revealParts = Array(0..<aufdeckSchritte(name: name))
    }
}
