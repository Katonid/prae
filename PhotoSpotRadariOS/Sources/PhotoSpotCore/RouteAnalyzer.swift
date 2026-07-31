import Foundation

public struct MovementSample: Sendable {
    public let point: GeoPoint
    public let timestamp: Date
    public let horizontalAccuracy: Double

    public init(point: GeoPoint, timestamp: Date, horizontalAccuracy: Double) {
        self.point = point; self.timestamp = timestamp; self.horizontalAccuracy = horizontalAccuracy
    }
}

public struct RouteAssessment: Sendable {
    public let distance: Double
    public let headingDifference: Double
    public let isAhead: Bool
    public let estimatedDetour: Double
}

/// Infers direction only from meaningful displacement, avoiding continuous GPS.
public struct RouteAnalyzer: Sendable {
    public init() {}

    public func inferredCourse(samples: [MovementSample]) -> Double? {
        let valid = samples.suffix(6).filter { $0.horizontalAccuracy <= 100 }
        guard let first = valid.first, let last = valid.last,
              GeoMath.distance(from: first.point, to: last.point) >= max(50, first.horizontalAccuracy + last.horizontalAccuracy) else { return nil }
        return GeoMath.bearing(from: first.point, to: last.point)
    }

    public func assess(current: GeoPoint, course: Double?, spot: GeoPoint) -> RouteAssessment {
        let distance = GeoMath.distance(from: current, to: spot)
        guard let course else {
            // Notification policy requires proof of approach; an unknown direction is not assumed forward.
            return .init(distance: distance, headingDifference: 0, isAhead: false, estimatedDetour: distance)
        }
        let difference = GeoMath.angularDifference(course, GeoMath.bearing(from: current, to: spot))
        // A 75° forward cone is deliberately conservative: side roads remain eligible,
        // while locations behind the traveler are rejected.
        return .init(
            distance: distance,
            headingDifference: difference,
            isAhead: difference <= 75,
            estimatedDetour: distance * sin(min(difference, 90) * .pi / 180)
        )
    }
}
