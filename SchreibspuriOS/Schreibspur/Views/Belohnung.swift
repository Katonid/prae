import SwiftUI

/// Lob nach einem geschafften Zeichen: Sterne je nach Fehlerzahl. Ist mit
/// drei Sternen die nächste Stufe aufgegangen, steht sie vorn.
struct Belohnung: View {
    let sterne: Int
    let neueStufe: Stufe?
    let hatWeiter: Bool
    let nochmal: () -> Void
    let stufeWeiter: () -> Void
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
                        .opacity(i < sichtbar ? 1 : 0)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(sterne) von 3 Sternen"))

            Text(lob)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Farben.blatt)

            if let neueStufe {
                Text("Stufe \(neueStufe.rawValue) ist offen: \(neueStufe.titel)")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Button(action: nochmal) {
                    Label("Nochmal", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(RundKnopf(farbe: Farben.blatt))

                if let neueStufe {
                    Button(action: stufeWeiter) {
                        Label("Stufe \(neueStufe.rawValue)", systemImage: "arrow.up.forward")
                    }
                    .buttonStyle(RundKnopf(farbe: Farben.markierung))
                } else if hatWeiter {
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
        // Die Sterne erscheinen nacheinander und leise — kein Hüpfen,
        // kein Drehen (Ansage des Nutzers: Animation nur sparsam).
        .task {
            for i in 1...3 {
                try? await Task.sleep(for: .seconds(0.2))
                withAnimation(.easeOut(duration: 0.25)) { sichtbar = i }
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
