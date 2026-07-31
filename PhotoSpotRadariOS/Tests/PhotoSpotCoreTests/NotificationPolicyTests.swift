import Foundation
import Testing
@testable import PhotoSpotCore

struct NotificationPolicyTests {
    private let assessment = RouteAssessment(distance: 500, headingDifference: 10, isAhead: true, estimatedDetour: 50)

    @Test func acceptsEligibleSpot() {
        let context = NotificationContext(visited: false, lastNotifiedAt: nil, score: 80, minimumScore: 50,
                                          radius: 1_000, assessment: assessment, notificationsEnabled: true)
        #expect(NotificationPolicy().shouldNotify(context))
    }

    @Test func blocksVisitedSpot() {
        let context = NotificationContext(visited: true, lastNotifiedAt: nil, score: 80, minimumScore: 50,
                                          radius: 1_000, assessment: assessment, notificationsEnabled: true)
        #expect(!NotificationPolicy().shouldNotify(context))
    }

    @Test func blocksWhenDisabled() {
        let context = NotificationContext(visited: false, lastNotifiedAt: nil, score: 80, minimumScore: 50,
                                          radius: 1_000, assessment: assessment, notificationsEnabled: false)
        #expect(!NotificationPolicy().shouldNotify(context))
    }

    @Test func enforcesCooldown() {
        let context = NotificationContext(visited: false, lastNotifiedAt: .now, score: 80, minimumScore: 50,
                                          radius: 1_000, assessment: assessment, notificationsEnabled: true)
        #expect(!NotificationPolicy().shouldNotify(context))
    }
}
