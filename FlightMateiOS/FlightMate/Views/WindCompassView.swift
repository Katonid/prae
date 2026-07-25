//
//  WindCompassView.swift
//  FlightMate
//
//  Kompass-Rose für Windanzeigen (Nutzerwunsch nach App-Vorbild):
//  Ziffernblatt aus Strichen mit den Himmelsrichtungen N/O/S/W und
//  einem kräftigen Pfeil in der Mitte. Der Pfeil zeigt, WOHIN der
//  Wind weht (meteorologische Richtung + 180°) — die Farbe trägt
//  wie überall die Bewertung gegen die Windtoleranz, ist aber nie
//  die einzige Information (Zahl daneben bleibt).
//

import SwiftUI

struct WindCompassView: View {
    /// Meteorologische Windrichtung in Grad (WOHER der Wind kommt).
    let directionDeg: Double
    var size: CGFloat = 44
    var arrowColor: Color = .primary

    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { index in
                let angle = Double(index) * 22.5
                if index % 4 == 0 {
                    Text(["N", "O", "S", "W"][index / 4])
                        .font(.system(size: size * 0.20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .offset(y: -size * 0.40)
                        .rotationEffect(.degrees(angle))
                } else {
                    Capsule()
                        .fill(Color.secondary.opacity(0.55))
                        .frame(width: max(1, size * 0.035),
                               height: size * (index % 2 == 0 ? 0.12 : 0.08))
                        .offset(y: -size * 0.40)
                        .rotationEffect(.degrees(angle))
                }
            }
            Image(systemName: "arrow.up")
                .font(.system(size: size * 0.40, weight: .bold))
                .rotationEffect(.degrees(directionDeg + 180))
                .foregroundStyle(arrowColor)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Wind aus \(Theme.compassDirection(directionDeg))")
    }
}
