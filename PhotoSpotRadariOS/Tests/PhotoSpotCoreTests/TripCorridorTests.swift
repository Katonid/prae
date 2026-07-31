import Foundation
import Testing
@testable import PhotoSpotCore

struct TripCorridorTests {
    /// Straight northbound line with points every ~1.1 km.
    private func line(count: Int) -> [GeoPoint] {
        (0..<count).map { GeoPoint(latitude: 50 + Double($0) * 0.01, longitude: 7) }
    }

    @Test func samplesKeepStartEndAndSpacing() {
        let path = line(count: 100)
        let centers = TripCorridor.sampleCenters(along: path, spacing: 10_000, maximumCount: 20)
        #expect(centers.first == path.first)
        #expect(centers.last == path.last)
        #expect(centers.count <= 20)
        for index in 1..<centers.count {
            let gap = GeoMath.distance(from: centers[index - 1], to: centers[index])
            #expect(gap >= 5_000)
        }
    }

    @Test func skipsEndpointAlreadyCoveredByLastSample() {
        // 4.4 km total: well within 5 km of the first sample, so no extra endpoint.
        let centers = TripCorridor.sampleCenters(along: line(count: 5), spacing: 50_000, maximumCount: 20)
        #expect(centers.count == 1)
    }

    @Test func emptyAndInvalidInputsYieldNothing() {
        #expect(TripCorridor.sampleCenters(along: [], spacing: 10_000, maximumCount: 20).isEmpty)
        #expect(TripCorridor.sampleCenters(along: line(count: 3), spacing: 0, maximumCount: 20).isEmpty)
        #expect(TripCorridor.sampleCenters(along: line(count: 3), spacing: 10_000, maximumCount: 0).isEmpty)
    }

    @Test func thinningPreservesEndpointsAndCap() {
        let path = line(count: 500)
        let thinned = TripCorridor.thin(path, to: 50)
        #expect(thinned.count == 50)
        #expect(thinned.first == path.first)
        #expect(thinned.last == path.last)
        #expect(TripCorridor.thin(path, to: 1_000).count == 500)
    }
}
