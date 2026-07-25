//
//  SharedPlace.swift
//  Himmelskompass
//
//  Zuletzt verwendeter Ort, den sich App und Widgets über die App Group
//  teilen. Die Widgets rechnen damit offline alle Himmelsdaten selbst.
//

import Foundation

struct SharedPlace: Codable {
    var lat: Double
    var lng: Double
    var timeZoneID: String
    var name: String?

    static let appGroupID = "group.de.familie.himmelskompass"
    private static let key = "hk-shared-place"

    // Fallback (Berlin), solange die App noch nie einen Ort gespeichert hat
    static var fallback: SharedPlace {
        SharedPlace(lat: 52.52, lng: 13.405, timeZoneID: TimeZone.current.identifier, name: nil)
    }

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    static func load() -> SharedPlace {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: key),
              let place = try? JSONDecoder().decode(SharedPlace.self, from: data) else {
            return fallback
        }
        return place
    }

    static func save(_ place: SharedPlace) {
        guard let data = try? JSONEncoder().encode(place) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: key)
    }
}
