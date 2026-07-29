import SwiftUI
import UIKit

/// Frei wählbare Spurfarben je Gerät/Person. Gespeichert im
/// iCloud-Schlüssel-Wert-Speicher — die Wahl gilt damit automatisch
/// auf allen eigenen Geräten gleich (plus lokaler Spiegel für
/// Offline-Starts). Schlüssel ist die stabile deviceId der Spur.
final class TrackColorStore: ObservableObject {
    static let shared = TrackColorStore()
    private static let key = "tagesspur.trackColors"

    @Published private(set) var map: [String: String]

    private init() {
        let kvs = NSUbiquitousKeyValueStore.default
        map = (kvs.dictionary(forKey: Self.key) as? [String: String])
            ?? (UserDefaults.standard.dictionary(forKey: Self.key) as? [String: String])
            ?? [:]
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.map = (kvs.dictionary(forKey: Self.key) as? [String: String]) ?? [:]
            UserDefaults.standard.set(self.map, forKey: Self.key)
        }
        kvs.synchronize()
    }

    func hex(forId id: String) -> String? {
        map[id]
    }

    /// Farbe einer Spur: Wunschfarbe, sonst Standardpalette nach Index.
    func color(forId id: String, fallbackIndex: Int) -> Color {
        if let hex = map[id], let color = Color(hexRGB: hex) {
            return color
        }
        return Theme.trackColors[abs(fallbackIndex) % Theme.trackColors.count]
    }

    func setColor(_ color: Color, forId id: String) {
        guard let hex = color.hexRGB else { return }
        map[id] = hex
        persist()
    }

    func resetAll() {
        map = [:]
        persist()
    }

    private func persist() {
        let kvs = NSUbiquitousKeyValueStore.default
        kvs.set(map, forKey: Self.key)
        kvs.synchronize()
        UserDefaults.standard.set(map, forKey: Self.key)
    }
}

extension Color {
    /// "RRGGBB" → Color.
    init?(hexRGB: String) {
        var value: UInt64 = 0
        guard hexRGB.count == 6, Scanner(string: hexRGB).scanHexInt64(&value) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// Color → "RRGGBB".
    var hexRGB: String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "%02X%02X%02X",
                      Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }
}
