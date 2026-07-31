import Foundation
import Testing
@testable import PhotoSpotCore

struct RouteAnalyzerTests {
    @Test func infersEastboundCourseAndRejectsSpotBehind() {
        let analyzer = RouteAnalyzer()
        let samples = [
            MovementSample(point: .init(latitude: 50, longitude: 7), timestamp: .now.addingTimeInterval(-60), horizontalAccuracy: 10),
            MovementSample(point: .init(latitude: 50, longitude: 7.01), timestamp: .now, horizontalAccuracy: 10)
        ]
        let course = analyzer.inferredCourse(samples: samples)
        #expect(course != nil)
        let ahead = analyzer.assess(current: samples[1].point, course: course, spot: .init(latitude: 50, longitude: 7.02))
        let behind = analyzer.assess(current: samples[1].point, course: course, spot: .init(latitude: 50, longitude: 6.99))
        #expect(ahead.isAhead)
        #expect(!behind.isAhead)
    }

    @Test func ignoresMovementInsideAccuracyNoise() {
        let analyzer = RouteAnalyzer()
        let samples = [
            MovementSample(point: .init(latitude: 50, longitude: 7), timestamp: .now.addingTimeInterval(-5), horizontalAccuracy: 80),
            MovementSample(point: .init(latitude: 50.0001, longitude: 7.0001), timestamp: .now, horizontalAccuracy: 80)
        ]
        #expect(analyzer.inferredCourse(samples: samples) == nil)
    }
}
