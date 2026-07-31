import SwiftUI

/// The app's visual language in one place: a warm "golden hour" gradient as the signature
/// accent, image-first cards and soft glass chips. Views compose these instead of styling ad hoc.
enum Theme {
    /// Sunset orange — primary accent and global tint.
    static let accent = Color(red: 0.98, green: 0.45, blue: 0.21)
    /// Dusk pink and deep violet complete the golden-hour ramp.
    static let accentPink = Color(red: 0.93, green: 0.28, blue: 0.45)
    static let accentViolet = Color(red: 0.45, green: 0.2, blue: 0.65)

    static let gradient = LinearGradient(
        colors: [accent, accentPink, accentViolet],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Subdued variant for placeholder artwork behind spots without a photo.
    static let placeholderGradient = LinearGradient(
        colors: [accent.opacity(0.55), accentPink.opacity(0.5), accentViolet.opacity(0.6)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Bottom scrim that keeps white text readable on top of any photo.
    static let photoScrim = LinearGradient(
        stops: [.init(color: .clear, location: 0.35),
                .init(color: .black.opacity(0.25), location: 0.62),
                .init(color: .black.opacity(0.78), location: 1)],
        startPoint: .top, endPoint: .bottom
    )
}

/// Small glass capsule used on top of photos (category, distance, source).
struct GlassChip: View {
    let label: String
    let symbol: String

    var body: some View {
        Label(label, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.black.opacity(0.35), in: .capsule)
            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
            .lineLimit(1)
    }
}

/// Forces a subtree (used for the MapKit views) into light or dark, independent of the
/// app-wide appearance; `nil` leaves the inherited scheme untouched.
struct ForcedColorScheme: ViewModifier {
    let scheme: ColorScheme?

    func body(content: Content) -> some View {
        if let scheme {
            content.environment(\.colorScheme, scheme)
        } else {
            content
        }
    }
}

/// Prominent call-to-action with the signature gradient.
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.gradient, in: .capsule)
            .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 5)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
