import Photos
import SwiftUI

/// Zwei Bereiche mit verschiebbarer Trennlinie — hochkant übereinander,
/// quer nebeneinander. Doppeltipp auf den Griff wechselt zwischen „Foto
/// groß“ und „Karte groß“.
struct GeteilteAnsicht<Erster: View, Zweiter: View>: View {
    let anteil: Double
    let quer: Bool
    let geaendert: (Double) -> Void
    @ViewBuilder let erster: () -> Erster
    @ViewBuilder let zweiter: () -> Zweiter

    @State private var startAnteil: Double?

    static var minimum: Double { 0.1 }
    static var maximum: Double { 0.85 }
    private let griff: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let gesamt = max(1, (quer ? geo.size.width : geo.size.height) - griff)
            let a = min(max(anteil, Self.minimum), Self.maximum)
            let layout = quer ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
            layout {
                erster()
                    .frame(width: quer ? gesamt * a : nil, height: quer ? nil : gesamt * a)
                    .frame(maxWidth: quer ? nil : .infinity, maxHeight: quer ? .infinity : nil)
                    .clipped()
                Griff(quer: quer)
                    .frame(width: quer ? griff : nil, height: quer ? nil : griff)
                    .frame(maxWidth: quer ? nil : .infinity, maxHeight: quer ? .infinity : nil)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { wert in
                                let start = startAnteil ?? a
                                if startAnteil == nil { startAnteil = a }
                                let weg = quer ? wert.translation.width : wert.translation.height
                                geaendert(min(max(start + weg / gesamt, Self.minimum), Self.maximum))
                            }
                            .onEnded { _ in startAnteil = nil }
                    )
                    .onTapGesture(count: 2) {
                        geaendert(a > 0.45 ? 0.25 : 0.6)
                    }
                    .accessibilityElement()
                    .accessibilityLabel("Aufteilung zwischen Foto und Karte")
                    .accessibilityValue("\(Int(a * 100)) Prozent Foto")
                    .accessibilityAdjustableAction { richtung in
                        switch richtung {
                        case .increment: geaendert(min(a + 0.1, Self.maximum))
                        case .decrement: geaendert(max(a - 0.1, Self.minimum))
                        @unknown default: break
                        }
                    }
                zweiter()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private struct Griff: View {
        let quer: Bool

        var body: some View {
            ZStack {
                Color(.secondarySystemBackground)
                Capsule()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: quer ? 5 : 44, height: quer ? 44 : 5)
            }
            .contentShape(Rectangle())
        }
    }
}

/// Das große Vorschaubild des Fotos (nicht das Original).
struct VorschauBild: View {
    let asset: PHAsset
    @State private var lader = VorschauLader()

    var body: some View {
        ZStack {
            if let bild = lader.bild {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if lader.fehler {
                VStack(spacing: 6) {
                    Image(systemName: "icloud.slash")
                        .font(.largeTitle)
                    Text("Vorschau nicht verfügbar")
                        .font(.footnote)
                }
                .foregroundStyle(.white.opacity(0.7))
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let wert = lader.cloudFortschritt {
                HStack(spacing: 6) {
                    Image(systemName: "icloud.and.arrow.down")
                    Text("\(Int(wert * 100)) %")
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(8)
            }
        }
        .onAppear { lader.laden(asset) }
        .onChange(of: asset.localIdentifier) { _, _ in lader.laden(asset) }
        .onDisappear { lader.beenden() }
    }
}

/// Kleine Schaltfläche mit Symbol und ein bis zwei Zeilen Text.
struct Vorschlagsknopf: View {
    let symbol: String
    let titel: String
    var untertitel: String?
    var farbe: Color = .accentColor
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                VStack(alignment: .leading, spacing: 0) {
                    Text(titel)
                        .font(.caption.weight(.semibold))
                    if let untertitel {
                        Text(untertitel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(farbe.opacity(0.15), in: Capsule())
            .foregroundStyle(farbe)
        }
        .buttonStyle(.plain)
    }
}

/// Kurz eingeblendete Bestätigung („Standort gespeichert“).
struct Hinweisblase: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }
}
