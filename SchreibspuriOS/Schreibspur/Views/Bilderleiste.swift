import SwiftUI

/// Ruhige Leiste unter dem Schreibblatt: Bilder, deren Name mit dem
/// Buchstaben beginnt. Nicht antippbar, nicht bewegt — sie soll Lust auf
/// den Buchstaben machen, nicht vom Schreiben ablenken.
struct Bilderleiste: View {
    let zeichen: Zeichen

    var body: some View {
        let bilder = Anlautbilder.bilder(fuer: zeichen)
        HStack(spacing: 12) {
            ForEach(bilder, id: \.self) { bild in
                HStack(spacing: 8) {
                    Text(bild.emoji)
                        .font(.system(size: 40))
                        .shadow(color: .black.opacity(0.22), radius: 3, x: 1, y: 3)
                    wort(bild.wort)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 16).fill(.white)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(bild.wort))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .allowsHitTesting(false)
    }

    /// Das Wort, der geübte Buchstabe darin farbig.
    private func wort(_ w: String) -> Text {
        let ziel = zeichen.id.lowercased()
        guard !zeichen.istFolge, let bereich = w.range(of: ziel, options: [.caseInsensitive]) else {
            return Text(w).foregroundColor(Farben.tinteDunkel)
        }
        return Text(w[..<bereich.lowerBound]).foregroundColor(Farben.tinteDunkel)
            + Text(w[bereich]).foregroundColor(Farben.markierung)
            + Text(w[bereich.upperBound...]).foregroundColor(Farben.tinteDunkel)
    }
}
