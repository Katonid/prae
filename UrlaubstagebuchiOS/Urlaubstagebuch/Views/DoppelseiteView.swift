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
// weggeschnitten, und wo er endet, zeigt die rote Schnittkante („…“ →
// „Satzspiegel zeigen"). Ein Abstand dazwischen wäre bequemer zu zeichnen
// und würde eine Lücke behaupten, die das Buch nicht hat.
struct DoppelseiteView: View {
    @ObservedObject var werk: Reisewerk
    let bogen: Reisewerk.Doppelseite
    var massstab: Double

    private var bogenmass: CGSize { werk.reise.gestaltung.bogen(werk.reise.format) }

    // DER UMSCHLAGBOGEN (ab 1.0.50) ist seit 1.0.52 der Bogen mit der
    // Nummer 0 und steht damit außerhalb der Zählung des Buchblocks. Bis
    // dahin wurde er an der Seitennummer 0 erkannt — und genau diese
    // Mitzählung schob die erste wirkliche Buchseite auf die linke Hälfte.
    private var istUmschlagbogen: Bool { bogen.istUmschlag }

    private var rueckentext: String {
        werk.reise.umschlag.rueckenbeschriftung(titel: werk.reise.titel)
    }

    private var rueckenbreite: Double {
        guard istUmschlagbogen else { return 0 }
        return Umschlagmass.rueckenbreitePt(werk.reise.umschlag,
                                            innenseiten: werk.reise.innenseiten)
    }

    var body: some View {
        VStack(spacing: Buehnenmasse.beschriftungsabstand) {
            HStack(alignment: .top, spacing: 0) {
                seite(bogen.links, umschlag: bogen.beginntMitUmschlag, vorn: true)
                if rueckenbreite > 0.5 {
                    Ruecken(text: rueckentext, breite: rueckenbreite,
                            hoehe: bogenmass.height, massstab: massstab)
                }
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
        if istUmschlagbogen {
            let mm = Umschlagmass.rueckenbreite(werk.reise.umschlag,
                                                innenseiten: werk.reise.innenseiten)
            var text = "Umschlag \u{00B7} Rückseite und Titelseite"
            if mm > 0.05 {
                let zahl = String(format: "%.1f", mm).replacingOccurrences(of: ".", with: ",")
                text += " \u{00B7} Rücken \(zahl) mm"
            }
            return text
        }
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

// DER RÜCKEN — der Streifen, der die Dicke des Buches ausmacht.
//
// Ansage des Nutzers, 09/2026: „Vielleicht findest du auch noch eine
// Lösung dafür, dass bei Saal Digital normalerweise beim Umschlag auch
// festgelegt werden kann, was an die Seite des Buches … drauf gedruckt
// werden kann. Bislang habe ich dort immer den Titel des Buches
// untergebracht."
//
// Wie breit er ist, rechnet `Umschlagmass` — dieselbe Funktion, die auch
// das PDF fragt. Gezeichnet wird er zwischen den beiden Umschlagseiten,
// also genau dort, wo er im fertigen Buch liegt.
//
// Die Schrift läuft von OBEN nach UNTEN: Ein Buch, das flach auf dem Tisch
// liegt, soll sich mit dem Titel nach oben lesen lassen — die deutsche
// Gepflogenheit. Gedreht wird mit `rotationEffect`, nicht mit einem
// gedrehten Text pro Buchstabe.
struct Ruecken: View {
    let text: String
    let breite: Double
    let hoehe: Double
    let massstab: Double

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.tertiarySystemGroupedBackground))
            Text(text)
                .font(.system(size: max(6, min(breite * 0.6, 13))))
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .fixedSize()
                .rotationEffect(.degrees(90))
        }
        .frame(width: breite * massstab, height: hoehe * massstab)
        // Ein langer Titel auf einem schmalen Rücken ragte sonst über die
        // Nachbarseiten — auf dem Papier ist der Rücken genau so breit,
        // wie er breit ist.
        .clipped()
        .overlay {
            // Die beiden Falze. Sie sind keine Schnittkanten — der Bogen
            // wird dort GEFALTET —, und deshalb sind sie punktiert und
            // nicht rot gestrichelt wie die Schnittkante.
            HStack(spacing: 0) {
                Rectangle().frame(width: 0.7).foregroundStyle(.quaternary)
                Spacer(minLength: 0)
                Rectangle().frame(width: 0.7).foregroundStyle(.quaternary)
            }
        }
        .allowsHitTesting(false)
    }
}
