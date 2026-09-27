import SwiftUI

// Der Schalter für die zweite Überschrift (ab 1.0.116). EINE Ansicht, an
// zwei Stellen gezeigt — im Schrift-Blatt bei der Rolle „Zweite
// Überschrift" und unter „Ränder und Druckzugaben" neben der Datumszeile.
// Gesucht wird er an beiden; zwei Fassungen desselben Schalters liefen
// auseinander (die Regel aus 1.0.10).
//
// Die Quittung steht HIER und nicht in `werk.meldung`: Das Band hängt an
// der Bühne, und dieser Schalter liegt in einem Blatt darüber (dieselbe
// Lehre wie bei der Punktwahl in 1.0.52).
struct ZweiteUeberschriftSchalter: View {
    @ObservedObject var werk: Reisewerk
    @State private var quittung = ""

    var body: some View {
        Toggle("Zweite Überschrift zeigen", isOn: Binding(
            get: { werk.reise.gestaltung.unterueberschriftZeigen },
            set: { quittung = werk.unterueberschriftZeigen($0) }
        ))
        Text(erklaerung)
            .font(.caption)
            .foregroundStyle(.secondary)
        if !quittung.isEmpty {
            Text(quittung)
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var erklaerung: String {
        werk.reise.gestaltung.unterueberschriftZeigen
            ? "Unter der Überschrift steht die zweite — der Ort oder das Schlagwort, beim Einlesen aus Fernweh der Name einer Wanderung oder eines Fotoortes. Ausgeschaltet bleibt nur die Hauptüberschrift, für das ganze Buch."
            : "Nur die Hauptüberschrift steht auf der Seite. Die zweite bleibt an jedem Tag gespeichert und kommt mit dem Einschalten zurück."
    }
}
