import SwiftUI
import UIKit

// DIE BEIDEN LINIEN, NEBENEINANDER ERKLÄRT (ab 1.0.76).
//
// Ansage des Nutzers, 09/2026: „Ich brauche also bei der Ansicht auf dem
// iPad zwei gestrichelte Linien, die um eine Seite herumlaufen. Einmal die
// Schnittlinie und einmal die Linie für den Sicherheitsabstand."
//
// Auf der Seite gibt es beide seit 1.0.73 — rot die Schnittkante, seit
// 1.0.80 blau den Sicherheitsabstand. Was fehlte, ist die Stelle, an der sich
// beantworten lässt, WELCHE welche ist und warum die blaue nicht überall
// gleich weit innen läuft. Deshalb steht sie dort, wo die Zahlen
// eingestellt werden, und zeigt zwei gegenüberliegende Seiten: Am Bund in
// der Mitte ist der Streifen breiter, an den Außenkanten schmaler.
//
// Gezeichnet wird mit DERSELBEN Rechnung wie die Seite selbst
// (`Gestaltung.schutzzone(_:bund:)`) — eine zweite Fassung zeigte hier
// etwas anderes als das Blatt daneben.
struct Schutzzonenskizze: View {
    let gestaltung: Gestaltung
    let format: Seitenformat

    // Wie hoch die Skizze wird. Klein genug, um in ein Formular zu passen,
    // groß genug, dass sich zwei Millimeter Unterschied sehen lassen.
    private let hoehe: CGFloat = 132

    private var massstab: CGFloat {
        let groesse = format.groesse
        guard groesse.height > 1 else { return 1 }
        return hoehe / groesse.height
    }

    private var seitenbreite: CGFloat {
        format.groesse.width * massstab
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                seite(bund: .rechts)
                seite(bund: .links)
            }
            .frame(maxWidth: .infinity)

            // Die Legende holt Farbe und Namen aus `Seitenlinie` — dieselbe
            // Stelle, aus der die Seite und die Fanglinie sie holen.
            HStack(spacing: 12) {
                ForEach([Seitenlinie.schnitt, .sicherheit]) { art in
                    zeichenerklaerung(art)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Text("Zwei gegenüberliegende Seiten. In der Mitte liegt der Bund — dort wird gefalzt oder gebunden und nicht geschnitten, deshalb läuft die rote Linie nicht herum.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    // Eine Seite: das Papier, die rote Schnittkante — und die blaue Linie
    // an der Stelle, an der sie für DIESE Seite läuft.
    //
    // **Am Bund fehlt die rote Linie** (ab 1.0.78): Dort wird gefalzt oder
    // gebunden und nicht geschnitten. Gezeichnet wird deshalb dasselbe
    // `Schnittlinien`, das auch auf der Seite liegt — zwei Fassungen
    // zeigten hier etwas anderes als das Blatt daneben.
    private func seite(bund: Bundlage) -> some View {
        let zone = gestaltung.schutzzone(format, bund: bund)
        // Der Bund liegt in der Mitte der Skizze: Bei der linken Seite
        // rechts, bei der rechten links — also genau die Kante, an der die
        // Nachbarseite anstößt.
        let offen: Bogenkante = bund == .rechts ? .rechts : .links
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(uiColor: .secondarySystemBackground))

            Hilfslinie(art: .schnitt, offen: offen, dunkel: false)

            if gestaltung.hatSicherheitsabstand {
                Hilfslinie(art: .sicherheit, dunkel: false)
                    .frame(width: zone.width * massstab,
                           height: zone.height * massstab)
                    .offset(x: zone.minX * massstab, y: zone.minY * massstab)
            }
        }
        .frame(width: seitenbreite, height: hoehe)
    }

    private func zeichenerklaerung(_ art: Seitenlinie) -> some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(art.farbe(aufDunklem: false))
                .frame(width: 14, height: 2)
            Text(art.name)
        }
    }
}

// DIE LEGENDE ÜBER DER BÜHNE (ab 1.0.80).
//
// Gefragt 09/2026: „Auf dem Beispielbild sind noch weitere Linien zu sehen.
// Welche sind das denn eigentlich?" Es waren drei, und zwei davon sahen
// einander ähnlich — die Antwort darauf steht in `Seitenlinie`. Was fehlte,
// ist die Stelle, an der sich die Frage beantworten lässt, OHNE ein Menü zu
// öffnen: Wer die Linien sieht, sieht sie auf der Bühne.
//
// Sie steht nur, solange die Linien an sind, und verschwindet mit dem
// Schalter — ein Band, das dauernd Platz nähme, wäre für den, der die
// Linien kennt, nur im Weg.
struct Linienlegende: View {
    var body: some View {
        HStack(spacing: 14) {
            ForEach(Seitenlinie.stehende) { art in
                HStack(spacing: 5) {
                    // Das STRICHBILD steht mit da und nicht nur die Farbe:
                    // Ein farbfehlsichtiger Mensch unterscheidet Rot und
                    // Blau nicht sicher, die langen von den kurzen Strichen
                    // aber schon.
                    Path { pfad in
                        pfad.move(to: CGPoint(x: 0, y: 1))
                        pfad.addLine(to: CGPoint(x: 22, y: 1))
                    }
                    .stroke(art.farbe(aufDunklem: false),
                            style: StrokeStyle(lineWidth: art.breite + 0.6,
                                               dash: art.strich))
                    .frame(width: 22, height: 2)
                    Text(art.name)
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .padding(.top, 8)
        .allowsHitTesting(false)
    }
}
