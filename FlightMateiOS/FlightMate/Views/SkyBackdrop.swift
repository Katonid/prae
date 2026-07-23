//
//  SkyBackdrop.swift
//  FlightMate
//
//  Der lebendige Hintergrund des Heute-Tabs: Ein Farbverlauf, der dem
//  echten Sonnenstand am Standort folgt — tiefes Nachtblau, Morgenrot
//  um den Sonnenaufgang, Tagblau, goldene Stunde vor dem Untergang,
//  violette Dämmerung danach. Deterministisch aus den ohnehin
//  berechneten Sonnenzeiten, keine Zufallselemente. Der Verlauf blendet
//  nach unten in den System-Hintergrund aus, damit Karten und Texte
//  ihre gewohnte Lesbarkeit behalten.
//

import SwiftUI
import UIKit

struct SkyBackdrop: View {
    var sunrise: Date?
    var sunset: Date?
    var reference: Date = Date()

    @Environment(\.colorScheme) private var colorScheme

    private typealias RGB = (r: Double, g: Double, b: Double)
    private typealias Sky = (top: RGB, mid: RGB, low: RGB, glow: RGB, glowStrength: Double)

    // Farbwelten der fünf Himmelsphasen (oben → Horizont) plus ein
    // weicher Lichtschein (Sonne bzw. Mond) rechts oben.
    private static let night: Sky = ((0.05, 0.07, 0.18), (0.10, 0.13, 0.30), (0.16, 0.21, 0.40),
                                     (0.75, 0.80, 0.95), 0.18)
    private static let dawn: Sky = ((0.14, 0.15, 0.36), (0.52, 0.34, 0.44), (0.94, 0.58, 0.38),
                                    (1.00, 0.72, 0.45), 0.35)
    private static let day: Sky = ((0.22, 0.48, 0.83), (0.45, 0.66, 0.92), (0.72, 0.84, 0.97),
                                   (1.00, 0.98, 0.90), 0.30)
    private static let golden: Sky = ((0.25, 0.36, 0.62), (0.80, 0.52, 0.34), (0.97, 0.72, 0.42),
                                      (1.00, 0.80, 0.45), 0.40)
    private static let dusk: Sky = ((0.09, 0.10, 0.28), (0.42, 0.24, 0.42), (0.82, 0.44, 0.34),
                                    (0.95, 0.62, 0.45), 0.30)

    var body: some View {
        let sky = currentSky
        // Im Dark Mode gedimmt, damit der Verlauf nicht heller strahlt
        // als der Rest des Systems.
        let dim = colorScheme == .dark ? 0.62 : 1.0

        LinearGradient(stops: [
            .init(color: color(sky.top, dim), location: 0.0),
            .init(color: color(sky.mid, dim), location: 0.20),
            .init(color: color(sky.low, dim), location: 0.40),
            .init(color: Color(uiColor: .systemBackground), location: 0.78),
        ], startPoint: .top, endPoint: .bottom)
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(RadialGradient(
                    colors: [color(sky.glow, 1.0).opacity(sky.glowStrength), .clear],
                    center: .center, startRadius: 0, endRadius: 180))
                .frame(width: 360, height: 360)
                .offset(x: 70, y: -50)
        }
        .ignoresSafeArea()
    }

    /// Phase samt weicher Überblendung an den Übergängen. Minuten
    /// relativ zu Auf- und Untergang; ohne Sonnenzeiten: Tag.
    private var currentSky: Sky {
        guard let sunrise, let sunset else { return Self.day }
        let sinceRise = reference.timeIntervalSince(sunrise) / 60
        let sinceSet = reference.timeIntervalSince(sunset) / 60

        if sinceSet >= 60 { return Self.night }
        if sinceSet >= 20 { return blend(Self.dusk, Self.night, (sinceSet - 20) / 40) }
        if sinceSet >= 0 { return blend(Self.golden, Self.dusk, sinceSet / 20) }
        if sinceSet >= -75 { return blend(Self.day, Self.golden, (sinceSet + 75) / 75) }
        if sinceRise >= 30 { return Self.day }
        if sinceRise >= 0 { return blend(Self.dawn, Self.day, sinceRise / 30) }
        if sinceRise >= -50 { return blend(Self.night, Self.dawn, (sinceRise + 50) / 50) }
        return Self.night
    }

    private func blend(_ a: Sky, _ b: Sky, _ rawT: Double) -> Sky {
        let t = min(max(rawT, 0), 1)
        func mix(_ x: RGB, _ y: RGB) -> RGB {
            (x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t)
        }
        return (mix(a.top, b.top), mix(a.mid, b.mid), mix(a.low, b.low),
                mix(a.glow, b.glow), a.glowStrength + (b.glowStrength - a.glowStrength) * t)
    }

    private func color(_ rgb: RGB, _ dim: Double) -> Color {
        Color(red: rgb.r * dim, green: rgb.g * dim, blue: rgb.b * dim)
    }
}
