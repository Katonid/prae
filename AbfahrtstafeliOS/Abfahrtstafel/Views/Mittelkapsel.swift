import SwiftUI

/// Eine Kapsel der Verkehrsmittel-Filterleiste.
///
/// **Sie steht hier und nicht zweimal** (ab 1.1.27). Es gibt jetzt zwei
/// Filterleisten — die der Tafel („welche der geladenen Abfahrten zeige ich?")
/// und die der Verbindungsauskunft („wonach soll überhaupt gesucht werden?")
/// —, und das sind zwei verschiedene Fragen mit derselben Bedienung. Genau so
/// soll es sein: Zwei Aussehen für dieselbe Geste wären zwei Dinge zu lernen.
/// Zwei Fassungen desselben Aussehens liefen dagegen irgendwann auseinander.
struct Mittelkapsel: View {
    let mittel: Verkehrsmittel
    let an: Bool
    let tippen: () -> Void

    var body: some View {
        Button(action: tippen) {
            HStack(spacing: 5) {
                Image(systemName: mittel.symbol)
                Text(mittel.mehrzahl)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            // **Die Rückfallfarbe des Verkehrsmittels, nicht die einer Linie.**
            // Hier geht es wirklich um die Art des Verkehrsmittels — das ist
            // die eine Stelle, an der diese Farbe noch etwas bedeutet, seit
            // die Linienfarben seit 1.1.9 aus den Daten oder aus der eigenen
            // Palette kommen.
            .background(
                Capsule().fill(an ? mittel.rueckfallfarbe.opacity(0.9) : Color.secondary.opacity(0.13))
            )
            .foregroundStyle(an ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mittel.mehrzahl)
        .accessibilityValue(an ? "ausgewählt" : "nicht ausgewählt")
    }
}
