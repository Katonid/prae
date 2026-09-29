import SwiftUI

/// Lob nach einem geschafften Zeichen: Sterne je nach Fehlerzahl.
struct Belohnung: View {
    let sterne: Int
    let nochmal: () -> Void
    let hatWeiter: Bool
    let weiter: () -> Void
    let fertig: () -> Void

    @State private var sichtbar = 0

    private var lob: String {
        switch sterne {
        case 3: "Super geschrieben!"
        case 2: "Gut gemacht!"
        default: "Geschafft!"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < sterne ? "star.fill" : "star")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(i < sterne ? Farben.stern : Color.gray.opacity(0.4))
                        .scaleEffect(i < sichtbar ? 1 : 0.2)
                        .opacity(i < sichtbar ? 1 : 0)
                        .rotationEffect(.degrees(i < sichtbar ? 0 : -60))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(sterne) von 3 Sternen"))

            Text(lob)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Farben.blatt)

            HStack(spacing: 16) {
                Button(action: nochmal) {
                    Label("Nochmal", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(RundKnopf(farbe: Farben.blatt))

                if hatWeiter {
                    Button(action: weiter) {
                        Label("Weiter", systemImage: "arrow.right")
                    }
                    .buttonStyle(RundKnopf(farbe: Farben.markierung))
                } else {
                    Button(action: fertig) {
                        Label("Fertig", systemImage: "checkmark")
                    }
                    .buttonStyle(RundKnopf(farbe: Farben.markierung))
                }
            }
        }
        .padding(32)
        .background(RoundedRectangle(cornerRadius: 32).fill(.white).shadow(radius: 12))
        .padding(24)
        .task {
            for i in 1...3 {
                try? await Task.sleep(for: .seconds(0.25))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { sichtbar = i }
            }
        }
    }
}

struct RundKnopf: ButtonStyle {
    let farbe: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title2, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
            .background(Capsule().fill(farbe))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}
