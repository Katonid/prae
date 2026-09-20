import SwiftUI

/// Die Zeile unter einem Liniensymbol, die sagt, was die Quelle sonst noch
/// über diese Linie hinschreibt.
///
/// **Sie beantwortet den Befund vom 09/2026** („RE 1 und S1 sind Züge.
/// Definitiv."). Der Satz stimmt — RE1 und S1 SIND Bahnlinien; was auf ihnen
/// nachts fuhr, war trotzdem ein Bus. Das Verkehrsmittelsymbol aus 1.1.29
/// sagt, WAS fährt; hier steht, WARUM es so heißt, wie es heißt — aber nur
/// dort, wo die Quelle es selbst sagt. Wo sie schweigt, schweigt auch diese
/// Zeile; Erfinden wäre genau das Raten, aus dem der Eindruck entstand.
///
/// **An EINER Stelle gezeichnet**, weil sie an vier Stellen gebraucht wird
/// (Ergebniszeile, Verbindungsabschnitt, Abfahrtszeile, Fahrtlauf) — zwei
/// Fassungen liefen auseinander. Dieselbe Regel wie bei `Mittelkapsel`.
struct Linienzusatz: View {
    let linie: Linienkennung
    /// Ob der Betrieb mitgenannt wird. In der Fahrtansicht steht er schon
    /// in der Kopfzeile; in einer Listenzeile ist er die Unterscheidung
    /// („National Express" neben „DB Regio").
    var mitBetrieb: Bool = false

    var body: some View {
        if let hinweis = Ersatzverkehr.hinweis(linie) {
            Label(hinweis + betriebszusatz, systemImage: "arrow.triangle.swap")
                .font(.caption2)
                .foregroundStyle(.orange)
        } else if let lang = linie.langname {   // ein langer Name ohne Ersatzverkehr
            Text(lang + betriebszusatz)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        } else if mitBetrieb, let betrieb = linie.betrieb {
            Text(betrieb)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var betriebszusatz: String {
        guard mitBetrieb, let betrieb = linie.betrieb else { return "" }
        return " · \(betrieb)"
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        // Der gemessene Fall: ein Bus unter dem Namen einer Bahnlinie, und
        // die Quelle schreibt es dazu.
        Linienzusatz(
            linie: .init(name: "RE1", mittel: .bus, farbe: "9b1b60", schriftfarbe: nil,
                         betrieb: "National Express", langname: "SEV RE 1"),
            mitBetrieb: true
        )
        // Derselbe Fall, aber die Quelle schweigt: Dann trägt der NAME die
        // Auskunft — ein Bus, der „S1" heißt (ab 1.1.31).
        Linienzusatz(
            linie: .init(name: "S1", mittel: .bus, farbe: nil, schriftfarbe: nil,
                         betrieb: "Nahreisezug", langname: nil),
            mitBetrieb: true
        )
        // Und ein gewöhnlicher Bus, der nichts dergleichen ist.
        Linienzusatz(
            linie: .init(name: "SB16", mittel: .bus, farbe: nil, schriftfarbe: nil,
                         betrieb: "Rheinbahn Bus", langname: nil),
            mitBetrieb: true
        )
        // Ein langer Name ganz ohne Ersatzverkehr.
        Linienzusatz(
            linie: .init(name: "FLX30", mittel: .fernzug, farbe: "73d700", schriftfarbe: nil,
                         betrieb: "FlixTrain", langname: "(Dresden-) Berlin - Köln (-Aachen)")
        )
    }
    .padding()
}
