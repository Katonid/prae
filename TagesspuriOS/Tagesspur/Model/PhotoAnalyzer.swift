import Foundation
import Photos
import Vision
import SwiftData
import UIKit

/// On-Device-Fotoanalyse (opt-in): klassifiziert Aufnahmen lokal mit
/// Apples Vision-Framework und speichert pro Aufnahme nur Stichwörter
/// (MediaTag) — niemals Bilddaten. Kein Netzwerk, keine Cloud-Analyse.
enum PhotoAnalyzer {
    private static let enabledKey = "tagesspur.photoAnalysisEnabled"
    private static let minConfidence: Float = 0.4
    private static let maxLabelsPerPhoto = 10

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Analysiert die Aufnahmen eines Tages (still, z. B. beim Öffnen
    /// eines Tagesdetails). Liefert die Zahl neu analysierter Aufnahmen.
    @discardableResult
    static func analyzeDay(dayKey: String, container: ModelContainer) async -> Int {
        guard isEnabled else { return 0 }
        let items = PhotoMatcher.items(forDayKey: dayKey)
        return await analyze(items: items, container: container, progress: nil)
    }

    /// Analysiert alle Aufnahmen der übergebenen Tage (Einstellungen).
    @discardableResult
    static func analyzeDays(_ dayKeys: [String], container: ModelContainer, progress: (@MainActor (Int, Int) -> Void)?) async -> Int {
        guard isEnabled else { return 0 }
        var items: [MediaItem] = []
        for key in dayKeys.sorted(by: >) {
            items.append(contentsOf: PhotoMatcher.items(forDayKey: key))
        }
        return await analyze(items: items, container: container, progress: progress)
    }

    private static func analyze(items: [MediaItem], container: ModelContainer, progress: (@MainActor (Int, Int) -> Void)?) async -> Int {
        guard !items.isEmpty else { return 0 }

        let context = ModelContext(container)
        let known = Set(((try? context.fetch(FetchDescriptor<MediaTag>())) ?? []).map(\.assetId))
        let pending = items.filter { !known.contains($0.id) }
        guard !pending.isEmpty else { return 0 }

        let deviceId = DeviceInfo.deviceId
        var done = 0
        for item in pending {
            let labels = await classify(asset: item.asset)
            let tag = MediaTag(
                assetId: item.id,
                deviceId: deviceId,
                dayKey: DayKey.key(for: item.date),
                labels: labels.joined(separator: ",")
            )
            context.insert(tag)
            done += 1
            if done % 10 == 0 { try? context.save() }
            if let progress {
                let current = done
                let total = pending.count
                await progress(current, total)
            }
        }
        try? context.save()
        return done
    }

    /// Klassifiziert eine Aufnahme (bei Videos das Vorschaubild).
    private static func classify(asset: PHAsset) async -> [String] {
        guard let cgImage = await requestCGImage(for: asset) else { return [] }
        return await Task.detached(priority: .utility) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            let observations = request.results ?? []
            return observations
                .filter { $0.confidence >= minConfidence }
                .prefix(maxLabelsPerPhoto)
                .map { $0.identifier.lowercased() }
        }.value
    }

    private static func requestCGImage(for asset: PHAsset) async -> CGImage? {
        await withCheckedContinuation { continuation in
            var resumed = false
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 512, height: 512),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image?.cgImage)
            }
        }
    }
}
