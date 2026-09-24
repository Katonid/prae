import SwiftUI
import UIKit

// DIE BEIDEN LINIEN, NEBENEINANDER ERKLÄRT (ab 1.0.76).
//
// Ansage des Nutzers, 09/2026: „Ich brauche also bei der Ansicht auf dem
// iPad zwei gestrichelte Linien, die um eine Seite herumlaufen. Einmal die
// Schnittlinie und einmal die Linie für den Sicherheitsabstand."
//
// Auf der Seite gibt es beide seit 1.0.73 — rot die Schnittkante, orange
// den Sicherheitsabstand. Was fehlte, ist die Stelle, an der sich
// beantworten lässt, WELCHE welche ist und warum die orange nicht überall
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

            HStack(spacing: 12) {
                zeichenerklaerung(farbe: .red, text: "Schnittkante")
                zeichenerklaerung(farbe: .orange, text: "Sicherheitsabstand")
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

    // Eine Seite: das Papier, die rote Schnittkante — und die orange Linie
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

            Schnittlinien(offen: offen)
                .stroke(Color.red.opacity(0.7),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 3]))

            if gestaltung.hatSicherheitsabstand {
                Rectangle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Color.orange.opacity(0.9))
                    .frame(width: zone.width * massstab,
                           height: zone.height * massstab)
                    .offset(x: zone.minX * massstab, y: zone.minY * massstab)
            }
        }
        .frame(width: seitenbreite, height: hoehe)
    }

    private func zeichenerklaerung(farbe: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(farbe)
                .frame(width: 14, height: 2)
            Text(text)
        }
    }
}
