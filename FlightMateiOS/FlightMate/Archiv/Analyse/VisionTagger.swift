//
//  VisionTagger.swift
//  FlightMate
//
//  Drone Media Explorer, M5 (Architektur Kap. 8): Szenen-Erkennung
//  komplett on-device mit Apples Vision-Framework — kein Upload,
//  kein Schlüssel. Läuft als Hintergrund-Batch nach dem Import
//  (Product-Owner-Entscheidung Kap. 12.5) über die Vorschaubilder
//  (480 px reicht für Szenenklassen wie Wasserfall/Sonnenuntergang;
//  ehrliche Grenze: bei Videos wird EIN Einzelbild bewertet, keine
//  ganze Zeitleiste).
//

import Foundation
import Vision
import SwiftData

@MainActor
enum VisionTagger {

    /// Verschlagwortet alle noch ungetaggten Medien (Batch, max.
    /// `limit` pro Lauf). Liefert die Zahl neu getaggter Medien.
    static func tagUntagged(limit: Int = 300) async -> Int {
        guard let container = ArchivStore.shared.container else { return 0 }
        var descriptor = FetchDescriptor<MediaAsset>(
            predicate: #Predicate { $0.visionTaggedAt == nil })
        descriptor.fetchLimit = limit
        guard let pending = try? container.mainContext.fetch(descriptor),
              !pending.isEmpty else { return 0 }

        var tagged = 0
        for asset in pending {
            // Ohne Vorschaubild (noch) nichts zu erkennen — nicht als
            // erledigt markieren, der nächste Lauf versucht es erneut.
            guard let thumbnail = ThumbnailStore.thumbnail(for: asset.contentHash),
                  let cgImage = thumbnail.cgImage else { continue }
            let labels = await Task.detached(priority: .utility) {
                classify(cgImage)
            }.value
            asset.aiTagsRaw = labels
                .map { "\($0.0)|\(String(format: "%.2f", $0.1))" }
                .joined(separator: "\n")
            asset.visionTaggedAt = Date()
            tagged += 1
            await Task.yield()
        }
        try? container.mainContext.save()
        return tagged
    }

    /// Vision-Klassifikation eines Bildes — liefert die stärksten
    /// Szenen-Labels (englische Bezeichner der Apple-Taxonomie).
    nonisolated private static func classify(_ image: CGImage) -> [(String, Double)] {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
        let observations = request.results ?? []
        return observations
            .filter { $0.confidence >= 0.25 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(8)
            .map { ($0.identifier, Double($0.confidence)) }
    }
}
