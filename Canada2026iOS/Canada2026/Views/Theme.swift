import SwiftUI

// Farbwelt und wiederverwendbare Bausteine im Stil der Canada-2026-PWA.

enum Theme {
    static let canadaRed = Color(red: 0.784, green: 0.145, blue: 0.220)
    static let lakeBlue = Color(red: 0.173, green: 0.373, blue: 0.659)
    static let forestGreen = Color(red: 0.180, green: 0.490, blue: 0.357)
    static let warmBeige = Color(red: 0.957, green: 0.910, blue: 0.827)

    static func memberColor(_ name: String) -> Color {
        Color(hex: TravelData.memberColors[name] ?? "6d7780")
    }

    static func roleColor(_ role: AccessRole) -> Color {
        switch role {
        case .admin: return canadaRed
        case .crew: return lakeBlue
        case .family: return forestGreen
        case .companion: return .orange
        }
    }
}

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MemberChip: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.memberColor(name).opacity(0.18))
            .foregroundStyle(Theme.memberColor(name))
            .clipShape(Capsule())
    }
}

struct RoleBadge: View {
    let role: AccessRole

    var body: some View {
        Text(role.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.roleColor(role).opacity(0.15))
            .foregroundStyle(Theme.roleColor(role))
            .clipShape(Capsule())
    }
}

struct PointsBadge: View {
    let points: Int

    var body: some View {
        Text("\(points) P")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.warmBeige)
            .foregroundStyle(Color(red: 0.45, green: 0.33, blue: 0.12))
            .clipShape(Capsule())
    }
}

/// Kleine Statuszeile für den Sync-Zustand (ersetzt die Firebase-Ampel der PWA).
struct SyncStatusDot: View {
    @EnvironmentObject private var store: AppStore

    private var color: Color {
        switch store.syncStatus {
        case .idle: return store.pendingChanges > 0 ? .orange : .green
        case .syncing: return .yellow
        case .error: return .red
        case .unavailable: return .gray
        }
    }

    var body: some View {
        NavigationLink {
            SyncView()
        } label: {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .accessibilityLabel("Sync-Status anzeigen")
        }
    }
}
