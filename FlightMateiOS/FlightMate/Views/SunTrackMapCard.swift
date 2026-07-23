//
//  SunTrackMapCard.swift
//  FlightMate
//
//  Sonnenverlauf auf der Karte (Roadmap-Punkt 5): Azimut-Linien für
//  Auf- und Untergang direkt am Spot — für die Bildplanung. Die Linie
//  zeigt vom Spot IN RICHTUNG Sonne: Kamera entlang der Linie =
//  Gegenlicht/Silhouette, Kamera von der Linie weg = angestrahltes
//  Motiv. Azimut wird on-device berechnet (SunCalculator), gilt für
//  den im Briefing gewählten Tag.
//

import SwiftUI
import MapKit

struct SunTrackMapCard: View {
    let coordinate: CLLocationCoordinate2D
    let sunDay: SunDay
    let timeZone: TimeZone

    private var sunriseAzimuth: Double? {
        sunDay.sunrise.map {
            SunCalculator.position(at: $0, latitude: coordinate.latitude,
                                   longitude: coordinate.longitude).azimuth
        }
    }

    private var sunsetAzimuth: Double? {
        sunDay.sunset.map {
            SunCalculator.position(at: $0, latitude: coordinate.latitude,
                                   longitude: coordinate.longitude).azimuth
        }
    }

    /// Zielpunkt in `distanceM` Metern Richtung `azimuth` (0° = Nord).
    private func destination(azimuth: Double, distanceM: Double) -> CLLocationCoordinate2D {
        let rad = azimuth * .pi / 180
        let dLat = distanceM * cos(rad) / 111_320
        let dLon = distanceM * sin(rad) / (111_320 * cos(coordinate.latitude * .pi / 180))
        return CLLocationCoordinate2D(latitude: coordinate.latitude + dLat,
                                      longitude: coordinate.longitude + dLon)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sonne auf der Karte")
                .font(.headline)

            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.028, longitudeDelta: 0.028)
            )), interactionModes: []) {
                Annotation("", coordinate: coordinate) {
                    Image(systemName: "camera.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, .blue)
                }
                if let azimuth = sunriseAzimuth, let sunrise = sunDay.sunrise {
                    MapPolyline(coordinates: [coordinate, destination(azimuth: azimuth, distanceM: 1_100)])
                        .stroke(.orange, style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
                    Annotation("", coordinate: destination(azimuth: azimuth, distanceM: 1_250)) {
                        Label("\(Theme.time(sunrise, in: timeZone))", systemImage: "sunrise.fill")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.9), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                if let azimuth = sunsetAzimuth, let sunset = sunDay.sunset {
                    MapPolyline(coordinates: [coordinate, destination(azimuth: azimuth, distanceM: 1_100)])
                        .stroke(.purple, style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
                    Annotation("", coordinate: destination(azimuth: azimuth, distanceM: 1_250)) {
                        Label("\(Theme.time(sunset, in: timeZone))", systemImage: "sunset.fill")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.purple.opacity(0.9), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }
            .mapStyle(.hybrid)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text(captionText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .flightCard(cornerRadius: 16)
    }

    private var captionText: String {
        var parts: [String] = []
        if let azimuth = sunriseAzimuth {
            parts.append("Orange: Aufgang aus \(Theme.compassDirection(azimuth)) (\(Int(azimuth))°)")
        }
        if let azimuth = sunsetAzimuth {
            parts.append("Violett: Untergang im \(Theme.compassDirection(azimuth)) (\(Int(azimuth))°)")
        }
        parts.append("Die Linie zeigt zur Sonne — Blick entlang der Linie ist Gegenlicht (Silhouetten), Motive auf der Gegenseite werden angestrahlt.")
        return parts.joined(separator: " · ")
    }
}
