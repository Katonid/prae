//
//  FlightSessionView.swift
//  FlightMateWatch
//
//  Der eine Bildschirm, der beim Fliegen zählt: großer Timer,
//  Akku-Balken gegen die nutzbare Zeit (80 % der Schätzung, 20 %
//  RTH-Reserve), Wind/Böen-Zeile und die drei Handgriffe
//  Start / Akku gewechselt / Landung.
//

import SwiftUI

struct FlightSessionView: View {
    @EnvironmentObject private var session: FlightSessionModel

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if session.flying {
                    flyingContent
                } else {
                    idleContent
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("FlightMate")
    }

    // MARK: Vor dem Flug

    private var idleContent: some View {
        VStack(spacing: 10) {
            weatherLine
            Text("≈ \(Int(session.batteryEstimateMinutes.rounded())) min je Akku · nutzbar \(Int((session.usableBatterySeconds / 60).rounded())) min (20 % RTH-Reserve)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                session.startFlight()
            } label: {
                Label("Flug starten", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            if let sync = session.syncText {
                Text(sync)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Text(session.profileFromPhone
                 ? session.profileName
                 : "\(session.profileName) (Werkswerte — iPhone noch nicht verbunden)")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Im Flug

    private var flyingContent: some View {
        VStack(spacing: 8) {
            Text(timeText(session.elapsedS))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()

            // Akku-Balken: Farbe kippt mit dem Verbrauch.
            VStack(spacing: 3) {
                ProgressView(value: session.batteryFraction)
                    .tint(batteryColor)
                HStack {
                    Text("Akku \(session.batteryCount)")
                    Spacer()
                    Text(remainingText)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            weatherLine

            if let alert = session.alertText {
                Text(alert)
                    .font(.footnote.bold())
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            Button {
                session.swapBattery()
            } label: {
                Label("Akku gewechselt", systemImage: "battery.100.bolt")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                session.stopFlight()
            } label: {
                Label("Landung", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }

    // MARK: Bausteine

    private var weatherLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "wind")
            if let wind = session.windKmh, let gusts = session.gustsKmh {
                Text("\(Int(wind)) km/h · Böen \(Int(gusts))")
                    .foregroundStyle(gustColor(gusts))
            } else if session.weatherFailed {
                Text("Wetter nicht abrufbar")
                    .foregroundStyle(.secondary)
            } else {
                Text("Wetter wird geladen …")
                    .foregroundStyle(.secondary)
            }
            if let temperature = session.temperatureC {
                Text("· \(Int(temperature.rounded())) °C")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
    }

    private var batteryColor: Color {
        switch session.batteryFraction {
        case ..<0.6: return .green
        case ..<0.85: return .orange
        default: return .red
        }
    }

    private func gustColor(_ gusts: Double) -> Color {
        if gusts >= session.maxWindKmh { return .red }
        if gusts >= session.maxWindKmh * 0.8 { return .orange }
        return .green
    }

    private var remainingText: String {
        let remaining = session.usableBatterySeconds - session.batteryElapsedS
        if remaining <= 0 { return "RTH-Reserve!" }
        return "noch \(timeText(remaining))"
    }

    private func timeText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
