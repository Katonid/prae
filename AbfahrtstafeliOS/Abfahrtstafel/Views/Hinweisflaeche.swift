import SwiftUI

/// Die Fläche für „hier ist gerade nichts" und „hier ist etwas schiefgegangen".
///
/// Sie hat IMMER einen Knopf oder wenigstens einen Satz, der sagt, was zu tun
/// ist. Eine leere Fläche mit einem Symbol darauf teilt dem Menschen davor
/// mit, dass die App aufgegeben hat, und lässt ihn ratlos zurück.
struct Hinweisflaeche: View {
    let symbol: String
    let titel: String
    let text: String
    var knopf: String?
    var tat: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text(titel)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let knopf, let tat {
                Button(knopf, action: tat)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 2)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Das Band über der Tafel, wenn etwas nicht ging, aber noch Zeiten dastehen.
///
/// Es ersetzt die Liste NICHT. Alte Zeiten mit dem Hinweis „von 08:14" sind
/// mehr wert als eine leere Fläche — solange dabeisteht, dass sie alt sind.
struct Meldungsband: View {
    let text: String
    var schliessen: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let schliessen {
                Button(action: schliessen) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.orange.opacity(0.13))
    }
}

#Preview {
    VStack(spacing: 0) {
        Meldungsband(text: "Keine Verbindung. Die Zeiten unten sind von 08:14.", schliessen: {})
        Hinweisflaeche(
            symbol: "tram",
            titel: "Hier fährt gerade nichts",
            text: "Im Umkreis von 500 m hat der Fahrplandienst keine Abfahrten in der nächsten Stunde.",
            knopf: "Umkreis vergrößern",
            tat: {}
        )
    }
}
