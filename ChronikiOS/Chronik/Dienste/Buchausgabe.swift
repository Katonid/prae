import UIKit

// DAS BUCH ALS PDF — Seite für Seite mit dem Seitenzeichner, im
// eingestellten Format, Fotos auf 300 dpi geladen. Kein Beschnitt und keine
// Doppelseiten: Das ist eine Druckdatei für den Heimdrucker und zum
// Ansehen. Für Fotobuchdienste mit eigenen Maßen ist das Reisebuch gebaut.
enum Buchausgabe {
    static func pdf(_ buch: Buch) throws -> URL {
        let seiten = Seitenbau.seiten(buch)
        let groesse = buch.format.groesse
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: buch.titel,
            kCGPDFContextCreator as String: "Kapitelweise – Das Buch",
        ]
        let maler = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: groesse), format: format)
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(dateiname(buch.titel) + ".pdf")
        try? FileManager.default.removeItem(at: ziel)
        try maler.writePDF(to: ziel) { kontext in
            for seite in seiten {
                kontext.beginPage()
                autoreleasepool {
                    Seitenzeichner.zeichnen(seite, buch: buch, aufloesung: Seitenzeichner.druckaufloesung, vorschau: false)
                }
            }
        }
        return ziel
    }

    static func dateiname(_ titel: String) -> String {
        let verboten = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let name = titel.components(separatedBy: verboten).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Kapitelweise" : name
    }
}
