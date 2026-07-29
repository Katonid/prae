import Foundation

/// Datenpaket, das das iPhone an die Watch schickt.
/// (Gegenstück in der iOS-App: WatchLink.swift – beide Definitionen
/// müssen inhaltlich identisch bleiben.)
struct WatchState: Codable {
    struct Board: Codable, Identifiable {
        var id: UUID
        var name: String
        var color: String
        var icon: String
        var pads: [Pad]
    }
    struct Pad: Codable, Identifiable {
        var id: UUID
        var label: String
        var color: String
        var playing: Bool
        var current: Double
        var duration: Double
    }
    var boards: [Board]
}

func watchFormatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    return "\(total / 60):" + String(format: "%02d", total % 60)
}
