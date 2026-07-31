import Foundation
import PhotoSpotCore

/// One preparable travel route. `path` stores the thinned route polyline after
/// "Route berechnen", so the corridor can be drawn and reloaded without asking
/// MapKit for directions again.
struct TripRoute: Identifiable, Codable, Hashable {
    var id = UUID()
    var start = ""
    /// Optional intermediate stop; routing runs start → via → destination, which is
    /// also the way to nudge the corridor onto a different road.
    var via = ""
    var destination = ""
    /// Radius of every coverage circle along the route in meters.
    var corridorRadius = 20_000
    var path: [GeoPoint] = []
    var preparedAt: Date?
    var spotCount = 0

    var title: String {
        let from = start.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if from.isEmpty && to.isEmpty { return "Neue Route" }
        return "\(from.isEmpty ? "?" : from) → \(to.isEmpty ? "?" : to)"
    }

    static let supportedCorridorRadii = [10_000, 20_000, 30_000, 50_000]
}
