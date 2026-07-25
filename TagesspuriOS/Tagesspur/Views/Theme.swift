import SwiftUI

/// Zentrale Designsprache: Markenfarben, Verläufe, Kartenhintergründe.
enum Theme {
    static let deepBlue = Color(red: 0.06, green: 0.16, blue: 0.29)
    static let petrol = Color(red: 0.17, green: 0.55, blue: 0.70)
    static let accent = Color(red: 0.09, green: 0.32, blue: 0.46)

    static let heroGradient = LinearGradient(
        colors: [deepBlue, petrol],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Track-Farben, eine je Gerät.
    static let trackColors: [Color] = [.blue, .orange, .purple, .green, .red, .teal]
}

/// Hero-Hintergrund: Markenverlauf mit sanft wanderndem Licht-Schimmer.
struct HeroCardBackground: View {
    var cornerRadius: CGFloat = 18
    @State private var drift = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Theme.heroGradient)
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: drift ? 130 : -130, y: drift ? -50 : 40)
                .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: drift)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear { drift = true }
    }
}

/// Gebrandeter Marker für Aufenthalte.
struct VisitMarkerView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 26, height: 26)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            Circle()
                .fill(Theme.heroGradient)
                .frame(width: 19, height: 19)
            Image(systemName: "mappin")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

/// Start- und Ziel-Marker auf dem Tages-Track.
struct TrackEndpointMarker: View {
    var isStart: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 20, height: 20)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            if isStart {
                Circle()
                    .fill(.green)
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}
