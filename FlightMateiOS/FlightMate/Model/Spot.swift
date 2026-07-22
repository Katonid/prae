//
//  Spot.swift
//  FlightMate
//
//  Gespeicherte Foto-Spots (PRD F4). Spots liegen ausschließlich lokal
//  auf dem Gerät — der Server kennt keine Verknüpfung Nutzer ↔ Orte
//  (PRD Kap. 11, „Keine Bewegungsprofile").
//

import Foundation
import CoreLocation

struct Spot: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var createdAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(name: String, coordinate: CLLocationCoordinate2D) {
        self.id = UUID()
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.createdAt = Date()
    }

    /// Free-Tier-Grenze aus dem PRD (Kap. 13): mehr Spots sind ein
    /// Pro-Feature. Die Grenze ist eine Produktentscheidung, kein Bug.
    static let freeTierLimit = 3
}
