import Foundation

public struct NotificationContext: Sendable {
    public let visited: Bool
    public let lastNotifiedAt: Date?
    public let score: Int
    public let minimumScore: Int
    public let radius: Double
    public let assessment: RouteAssessment
    public let notificationsEnabled: Bool

    public init(visited: Bool, lastNotifiedAt: Date?, score: Int, minimumScore: Int,
                radius: Double, assessment: RouteAssessment, notificationsEnabled: Bool) {
        self.visited = visited; self.lastNotifiedAt = lastNotifiedAt; self.score = score
        self.minimumScore = minimumScore; self.radius = radius
        self.assessment = assessment; self.notificationsEnabled = notificationsEnabled
    }
}

public struct NotificationPolicy: Sendable {
    public init() {}

    public func shouldNotify(_ context: NotificationContext) -> Bool {
        guard context.notificationsEnabled, !context.visited,
              context.score >= context.minimumScore,
              context.assessment.distance <= context.radius,
              context.assessment.isAhead,
              context.assessment.estimatedDetour <= min(context.radius * 0.5, 5_000),
              context.lastNotifiedAt == nil else { return false }
        return true
    }
}
