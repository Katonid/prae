import SwiftUI

// Zwei Seiten, wie sie im aufgeschlagenen Buch nebeneinanderliegen.
//
// Gewünscht 09/2026: „Ein Buch hat ja Seiten mit Vorder- und Rückseite. Und
// auf das Titelblatt kommt ja zunächst einmal die Innenseite des Hardcovers,
// bevor die erste wirkliche Buchseite anfängt."
//
// Gezeichnet wird mit `spacing: 0`: Im gebundenen Buch stoßen zwei
// gegenüberliegende Seiten am Bund aneinander. Was dazwischen als heller
// Streifen stehen bleibt, ist der ANSCHNITT beider Seiten — der wird
// weggeschnitten, und wo er endet, zeigt die rote Schnittkante (Anordnen →
// „Satzspiegel zeigen"). Ein Abstand dazwischen wäre bequemer zu zeichnen
// und würde eine Lücke behaupten, die das Buch nicht hat.
struct DoppelseiteView: View {
    @ObservedObject var werk: Reisewerk
    let bogen: Reisewerk.Doppelseite
    var massstab: Double

    private var bogenmass: CGSize { werk.reise.gestaltung.bogen(werk.reise.format) }

    var body: some View {
        VStack(spacing: Buehnenmasse.beschriftungsabstand) {
            HStack(alignment: .top, spacing: 0) {
                seite(bogen.links, umschlag: bogen.beginntMitUmschlag, vorn: true)
                seite(bogen.rechts, umschlag: bogen.endetMitUmschlag, vorn: false)
            }
            beschriftung
        }
    }

    @ViewBuilder
    private func seite(_ buchseite: Buchseite?, umschlag: Bool, vorn: Bool) -> some View {
        if let buchseite {
            SeitenflaecheView(werk: werk, buchseite: buchseite, massstab: massstab)
        } else if umschlag {
            UmschlagInnenseite(groesse: bogenmass, massstab: massstab, vorn: vorn)
        } else {
            // Keine Seite und kein Umschlag: Das gibt es nach der Bauweise
            // von `doppelseiten` nicht. Der Platz bleibt trotzdem stehen,
            // damit der Bund in der Mitte bleibt.
            Color.clear
                .frame(width: bogenmass.width * massstab, height: bogenmass.height * massstab)
        }
    }

    private var beschriftung: some View {
        // FESTE Höhe — `Zoomanker` rechnet mit ihr, damit der Zoom um den
        // Mittelpunkt der Geste nicht auf einer Schätzung steht.
        Text(zeile)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(height: Buehnenmasse.beschriftung)
    }

    private var zeile: String {
        let links = bogen.links.map { "\($0.nummer)" }
        let rechts = bogen.rechts.map { "\($0.nummer)" }
        switch (links, rechts) {
        case let (nil, .some(r)):
            return "Umschlag innen \u{00B7} Seite \(r)"
        case let (.some(l), nil):
            return "Seite \(l) \u{00B7} Umschlag innen"
        case let (.some(l), .some(r)):
            return "Seiten \(l) und \(r)"
        default:
            return ""
        }
    }
}

// Die Innenseite des Umschlags — gezeigt, aber nicht gedruckt.
//
// Beim Hardcover ist das das Vorsatzpapier, und das liefert die Druckerei;
// es steht in keinem PDF und zählt in keiner Seitenzahl. Gezeigt wird es
// trotzdem, weil sonst die Seite 1 links läge und damit falsch: Sie ist
// eine RECHTE Seite. Und es steht dabei, was es ist — eine leere graue
// Fläche ohne ein Wort hielte man für einen Fehler.
struct UmschlagInnenseite: View {
    let groesse: CGSize
    let massstab: Double
    let vorn: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.secondarySystemGroupedBackground))
            VStack(spacing: 6) {
                Image(systemName: "book.closed")
                    .font(.system(size: 22))
                Text(vorn ? "Innenseite des Umschlags" : "Innenseite des Rückens")
                Text("Kommt von der Druckerei \u{2013} nicht im PDF")
                    .font(.caption2)
            }
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(.tertiary)
            .padding(12)
        }
        .frame(width: groesse.width * massstab, height: groesse.height * massstab)
        .overlay {
            Rectangle()
                .strokeBorder(style: StrokeStyle(lineWidth: 0.8, dash: [5, 4]))
                .foregroundStyle(.quaternary)
        }
        .allowsHitTesting(false)
    }
}
