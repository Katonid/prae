import SwiftUI

// Der Regler für die Größe der Wettertabelle (ab 1.0.117). EINE Ansicht an
// zwei Stellen — unter „Ränder und Druckzugaben → Aussehen" und im
// Tagesmenü neben der Tabelle, wo die Frage entsteht.
//
// Gesetzt wird beim LOSLASSEN (`onEditingChanged`), nicht bei jedem
// Bildpunkt: Dahinter steckt ein Neusatz aller Tage mit Tabelle, und je
// Bildpunkt wäre das ein Sicherungslauf je Bildpunkt (die Lehre aus
// 1.0.92). Die Quittung steht hier, weil das Band der Bühne unter dem Blatt
// liegt.
struct WettergroesseRegler: View {
    @ObservedObject var werk: Reisewerk
    @State private var wert: Double?
    @State private var quittung = ""

    private var angezeigt: Double { wert ?? werk.reise.gestaltung.wettergroesse }

    var body: some View {
        VStack(alignment: .leading) {
            LabeledContent("Größe der Wettertabelle",
                           value: "\(Int((angezeigt * 100).rounded())) %")
            Slider(value: Binding(get: { angezeigt }, set: { wert = $0 }),
                   in: 0.3...1.5, step: 0.05,
                   onEditingChanged: { ziehtNoch in
                       guard !ziehtNoch, let neu = wert else { return }
                       quittung = werk.wettergroesseSetzen(neu)
                       wert = nil
                   })
        }
        Text("Gilt für alle Tage. Eine einzelne Tabelle lässt sich außerdem an den Griffen ihres Blocks größer und kleiner ziehen — sie passt sich in Höhe und Breite ein, ohne verzerrt zu werden.")
            .font(.caption)
            .foregroundStyle(.secondary)
        if !quittung.isEmpty {
            Text(quittung)
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
