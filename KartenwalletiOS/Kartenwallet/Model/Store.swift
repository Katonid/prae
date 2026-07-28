import Foundation
import UIKit

/// Lokale Ablage aller Karten als JSON im Application-Support-Ordner,
/// Kartenfotos daneben als JPEG-Dateien. Keine Cloud, keine Server.
@MainActor
final class CardStore: ObservableObject {
    @Published private(set) var cards: [Card] = []

    private let fm = FileManager.default

    private var baseURL: URL {
        let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kartenwallet", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var cardsURL: URL { baseURL.appendingPathComponent("cards.json") }

    private var photosURL: URL {
        let url = baseURL.appendingPathComponent("Fotos", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: cardsURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([Card].self, from: data) {
            cards = loaded
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(cards) {
            try? data.write(to: cardsURL, options: .atomic)
        }
    }

    func add(_ card: Card) {
        cards.insert(card, at: 0)
        save()
    }

    func update(_ card: Card) {
        guard let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }
        var updated = card
        updated.revision = cards[idx].revision + 1
        cards[idx] = updated
        save()
    }

    func delete(_ card: Card) {
        if let filename = card.photoFilename {
            try? fm.removeItem(at: photosURL.appendingPathComponent(filename))
        }
        cards.removeAll { $0.id == card.id }
        save()
    }

    // MARK: - Fotos

    /// Speichert das Kartenfoto (verkleinert, als JPEG) und gibt den
    /// Dateinamen zurück.
    func savePhoto(_ image: UIImage, for cardID: UUID) -> String? {
        let resized = image.resized(maxDimension: 1600)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return nil }
        let filename = "\(cardID.uuidString).jpg"
        do {
            try data.write(to: photosURL.appendingPathComponent(filename), options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    func photo(for card: Card) -> UIImage? {
        guard let filename = card.photoFilename else { return nil }
        guard let data = try? Data(contentsOf: photosURL.appendingPathComponent(filename)) else { return nil }
        return UIImage(data: data)
    }
}

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return self }
        let scale = maxDimension / largest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
