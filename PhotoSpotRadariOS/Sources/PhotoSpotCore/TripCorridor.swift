import Foundation

/// Deterministic corridor planning for prepared trips: turns a route polyline into the
/// evenly spaced coverage centers that get loaded offline, and thins dense polylines
/// down to a storable size. Shared by the engine (loading) and the UI (drawing), so the
/// map shows exactly the coverage that will actually be fetched.
public enum TripCorridor {
    /// Coverage-circle centers along `path`: the start, one point roughly every `spacing`
    /// meters and the endpoint (unless a sample already sits within 5 km of it).
    /// `maximumCount` caps the result to protect rate-limited providers — long routes
    /// then contain honest gaps rather than silently shrinking the corridor.
    public static func sampleCenters(along path: [GeoPoint], spacing: Double,
                                     maximumCount: Int) -> [GeoPoint] {
        guard let first = path.first, spacing > 0, maximumCount > 0 else { return [] }
        var sampled: [GeoPoint] = [first]
        var previous = first
        var accumulated = 0.0
        for point in path.dropFirst() {
            accumulated += GeoMath.distance(from: previous, to: point)
            if accumulated >= spacing {
                sampled.append(point)
                accumulated = 0
            }
            previous = point
        }
        if let last = path.last, let tail = sampled.last,
           GeoMath.distance(from: tail, to: last) > 5_000 {
            sampled.append(last)
        }
        return thin(sampled, to: maximumCount)
    }

    /// Uniformly reduces a polyline to at most `maximumCount` points while keeping the
    /// first and last point, so routes stay drawable and storable without detail bloat.
    public static func thin(_ path: [GeoPoint], to maximumCount: Int) -> [GeoPoint] {
        guard path.count > maximumCount, maximumCount > 1 else { return path }
        let scale = Double(path.count - 1) / Double(maximumCount - 1)
        return (0..<maximumCount).map { path[Int((Double($0) * scale).rounded())] }
    }
}
