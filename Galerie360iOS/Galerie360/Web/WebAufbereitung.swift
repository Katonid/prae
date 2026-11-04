import AVFoundation
import ImageIO
import Photos
import UIKit
import UniformTypeIdentifiers

/// Bereitet Aufnahmen aus der Fotos-Mediathek für die Web-Galerie auf (seit 1.0.21). Alle Dateien
/// entstehen in einem Arbeitsordner unter `tmp/`, werden hochgeladen und gleich wieder gelöscht —
/// gespeichert bleibt nur die Fotos-Mediathek.
///
/// Fotos: JPEG (Qualität 0,9) in der vollen Größe und, wie die Web-App, zusätzlich 4096 und 8192
/// px breit (Handys bzw. Grafikkarten mit kleiner Texturgrenze). Neu gerechnet, OHNE Metadaten —
/// damit steht kein GPS-Ort in den Dateien, die Gäste sehen.
/// Videos: H.264 in 4K (3840 × 1920, 50 Mbit/s) — spielt in jedem Browser; wahlweise dazu das
/// Original ohne Neukodierung (schärfer auf Apple-Geräten, doppelte Datenmenge). Beides mit dem
/// Verzeichnis vorn (fürs Streamen) und ohne Orts-Metadaten.
enum WebAufbereitung {
    static let videoBreite = 3840
    static let videoBitrate = 50_000_000

    struct Ergebnis {
        let aufnahme: WebFormat.Aufnahme
        /// Pfad im Albumordner → lokale Datei
        let dateien: [(pfad: String, datei: URL)]
    }

    static func arbeitsordner() throws -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("Web-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    /// Dateiname ohne Endung: lesbarer Teil + 8 Zufallszeichen (wie die Web-App).
    static func basisname(_ a: PHAsset) -> String {
        let original = PHAssetResource.assetResources(for: a).first?.originalFilename ?? "aufnahme"
        let lesbar = WebFormat.lesbar((original as NSString).deletingPathExtension, hoechstens: 30)
        return (lesbar.isEmpty ? "aufnahme" : lesbar) + "-" + WebFormat.zufall(8)
    }

    // MARK: Foto

    static func foto(_ a: PHAsset, basis: String, in ordner: URL, fortschritt: @escaping (Double) -> Void) async throws -> Ergebnis {
        let daten: Data = try await withCheckedThrowingContinuation { f in
            let o = PHImageRequestOptions()
            o.deliveryMode = .highQualityFormat
            o.version = .current
            o.isNetworkAccessAllowed = true
            o.progressHandler = { p, _, _, _ in fortschritt(p * 0.6) }
            PHImageManager.default().requestImageDataAndOrientation(for: a, options: o) { d, _, _, _ in
                if let d { f.resume(returning: d) } else { f.resume(throwing: MediathekFehler.nichtGeladen) }
            }
        }
        guard let quelle = CGImageSourceCreateWithData(daten as CFData, nil),
              let eig = CGImageSourceCopyPropertiesAtIndex(quelle, 0, nil) as? [CFString: Any] else { throw MediathekFehler.nichtGeladen }
        let b = (eig[kCGImagePropertyPixelWidth] as? Int) ?? a.pixelWidth
        let h = (eig[kCGImagePropertyPixelHeight] as? Int) ?? a.pixelHeight
        let gross = max(b, h)
        var stufen = [gross]
        if gross > 8192 { stufen.append(8192) }
        if gross > 4096 { stufen.append(4096) }
        var bilder: [WebFormat.Bild] = []
        var dateien: [(String, URL)] = []
        for (i, s) in stufen.enumerated() {
            try Task.checkCancellation()
            let pfad = s == gross ? "media/fotos/\(basis).jpg" : "media/fotos/web/\(basis)-\(s).jpg"
            let ziel = ordner.appendingPathComponent(pfad)
            try FileManager.default.createDirectory(at: ziel.deletingLastPathComponent(), withIntermediateDirectories: true)
            let maße: (Int, Int) = try autoreleasepool {
                let o: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                          kCGImageSourceCreateThumbnailWithTransform: true,
                                          kCGImageSourceThumbnailMaxPixelSize: s]
                guard let bild = CGImageSourceCreateThumbnailAtIndex(quelle, 0, o as CFDictionary) else { throw MediathekFehler.nichtGeladen }
                try jpeg(bild, nach: ziel)
                return (bild.width, bild.height)
            }
            bilder.append(.init(src: pfad, breite: maße.0, hoehe: maße.1))
            dateien.append((pfad, ziel))
            fortschritt(0.6 + 0.4 * Double(i + 1) / Double(stufen.count))
        }
        bilder.sort { $0.breite < $1.breite }
        let groesstes = bilder.last!
        let f = WebFormat.Foto(id: a.localIdentifier, titel: "", beschreibung: "", datum: WebFormat.datum(a.creationDate),
                               vorschau: "", blick: .init(yaw: 0, pitch: 0, fov: 75), datei: groesstes.src,
                               breite: groesstes.breite, hoehe: groesstes.hoehe, bilder: bilder)
        return Ergebnis(aufnahme: .foto(f), dateien: dateien)
    }

    static func jpeg(_ bild: CGImage, nach ziel: URL, qualitaet: Double = 0.9) throws {
        guard let d = CGImageDestinationCreateWithURL(ziel as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw MediathekFehler.nichtGeladen
        }
        CGImageDestinationAddImage(d, bild, [kCGImageDestinationLossyCompressionQuality: qualitaet] as CFDictionary)
        guard CGImageDestinationFinalize(d) else { throw MediathekFehler.nichtGeladen }
    }

    // MARK: Video

    static func video(_ a: PHAsset, basis: String, in ordner: URL, mitOriginal: Bool,
                      fortschritt: @escaping (Double) -> Void) async throws -> Ergebnis {
        // Das Original ganz aufs Gerät holen (aus iCloud, wenn nötig).
        let av: AVAsset = try await withCheckedThrowingContinuation { f in
            let o = PHVideoRequestOptions()
            o.deliveryMode = .highQualityFormat
            o.version = .current
            o.isNetworkAccessAllowed = true
            o.progressHandler = { p, _, _, _ in fortschritt(p * 0.25) }
            PHImageManager.default().requestAVAsset(forVideo: a, options: o) { av, _, _ in
                if let av { f.resume(returning: av) } else { f.resume(throwing: MediathekFehler.nichtGeladen) }
            }
        }
        guard let spur = try await av.loadTracks(withMediaType: .video).first else { throw MediathekFehler.nichtGeladen }
        let groesse = try await spur.load(.naturalSize).applying(try await spur.load(.preferredTransform))
        let qb = Int(abs(groesse.width)), qh = Int(abs(groesse.height))
        let dauer = try await av.load(.duration).seconds
        var quellen: [WebFormat.Quelle] = []
        var dateien: [(String, URL)] = []
        try FileManager.default.createDirectory(at: ordner.appendingPathComponent("media/videos"), withIntermediateDirectories: true)

        let originalKennung = try await kennung(spur)
        let originalIstH264 = originalKennung?.hasPrefix("avc") == true && qb <= 4096
        if mitOriginal || originalIstH264 {
            let pfad = "media/videos/\(basis).mp4"
            let ziel = ordner.appendingPathComponent(pfad)
            try await umpacken(av, nach: ziel) { fortschritt(0.25 + $0 * 0.25) }
            if let k = try await kennung(dateiSpur(ziel)) {
                quellen.append(.init(src: pfad, codec: k, breite: qb, hoehe: qh))
                dateien.append((pfad, ziel))
            }
        }
        if !originalIstH264 {
            let pfad = "media/videos/\(basis)-4k.mp4"
            let ziel = ordner.appendingPathComponent(pfad)
            let b = min(videoBreite, qb - qb % 2)
            let h = (b * qh / max(qb, 1)) & ~1
            try await h264(av, nach: ziel, breite: b, hoehe: h) { fortschritt(0.5 + $0 * 0.5) }
            let k = (try await kennung(dateiSpur(ziel))) ?? "avc1.640033"
            quellen.append(.init(src: pfad, codec: k, breite: b, hoehe: h))
            dateien.append((pfad, ziel))
        }
        // Poster: ein Bild aus dem Anfang, höchstens 4096 breit.
        let posterPfad = "media/poster/\(basis).jpg"
        let posterZiel = ordner.appendingPathComponent(posterPfad)
        try FileManager.default.createDirectory(at: posterZiel.deletingLastPathComponent(), withIntermediateDirectories: true)
        let gen = AVAssetImageGenerator(asset: av)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 4096, height: 4096)
        let (bild, _) = try await gen.image(at: CMTime(seconds: min(0.5, dauer / 2), preferredTimescale: 600))
        try jpeg(bild, nach: posterZiel, qualitaet: 0.85)
        dateien.append((posterPfad, posterZiel))
        let v = WebFormat.Video(id: a.localIdentifier, titel: "", beschreibung: "", datum: WebFormat.datum(a.creationDate),
                                vorschau: "", poster: posterPfad, blick: .init(yaw: 0, pitch: 0, fov: 75),
                                dauer: (dauer * 10).rounded() / 10, quellen: quellen)
        fortschritt(1)
        return Ergebnis(aufnahme: .video(v), dateien: dateien)
    }

    private static func dateiSpur(_ u: URL) async throws -> AVAssetTrack {
        guard let s = try await AVURLAsset(url: u).loadTracks(withMediaType: .video).first else { throw MediathekFehler.nichtGeladen }
        return s
    }

    /// RFC-6381-Kennung („hvc1.1.6.L153.B0“, „avc1.640033“) aus der Spurbeschreibung.
    static func kennung(_ spur: AVAssetTrack) async throws -> String? {
        guard let fd = try await spur.load(.formatDescriptions).first else { return nil }
        let typ = CMFormatDescriptionGetMediaSubType(fd)
        let art = String(bytes: [UInt8(typ >> 24 & 0xFF), UInt8(typ >> 16 & 0xFF), UInt8(typ >> 8 & 0xFF), UInt8(typ & 0xFF)], encoding: .ascii) ?? ""
        let atome = CMFormatDescriptionGetExtension(fd, extensionKey: kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms) as? [String: Any]
        if art.hasPrefix("avc"), let d = atome?["avcC"] as? Data { return WebFormat.avcKennung(d, art: art) }
        if art == "hvc1" || art == "hev1", let d = atome?["hvcC"] as? Data { return WebFormat.hevcKennung(d, art: art) }
        return art.isEmpty ? nil : art
    }

    /// Ohne Neukodierung in eine MP4 mit Verzeichnis vorn; Ortsangaben werden entfernt.
    static func umpacken(_ av: AVAsset, nach ziel: URL, fortschritt: @escaping (Double) -> Void) async throws {
        guard let s = AVAssetExportSession(asset: av, presetName: AVAssetExportPresetPassthrough) else { throw MediathekFehler.nichtGeladen }
        try? FileManager.default.removeItem(at: ziel)
        s.outputURL = ziel
        s.outputFileType = .mp4
        s.shouldOptimizeForNetworkUse = true
        s.metadataItemFilter = .forSharing()
        let kiste = Kiste(s)
        let uhr = Task { while !Task.isCancelled { fortschritt(Double(kiste.s.progress)); try? await Task.sleep(for: .milliseconds(400)) } }
        defer { uhr.cancel() }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (f: CheckedContinuation<Void, Error>) in
                kiste.s.exportAsynchronously {
                    if kiste.s.status == .completed { f.resume() } else { f.resume(throwing: kiste.s.error ?? MediathekFehler.nichtGeladen) }
                }
            }
        } onCancel: { kiste.s.cancelExport() }
    }

    private final class Kiste: @unchecked Sendable {
        let s: AVAssetExportSession
        init(_ s: AVAssetExportSession) { self.s = s }
    }

    /// H.264 in fester, hoher Datenrate (50 Mbit/s) — gegen „Pumpen“ und Artefakte, die bei 360°
    /// besonders auffallen, weil man einen kleinen Ausschnitt stark vergrößert sieht.
    static func h264(_ av: AVAsset, nach ziel: URL, breite: Int, hoehe: Int, fortschritt: @escaping (Double) -> Void) async throws {
        try? FileManager.default.removeItem(at: ziel)
        let dauer = try await av.load(.duration).seconds
        let leser = try AVAssetReader(asset: av)
        let komposition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: av)
        komposition.renderSize = CGSize(width: breite, height: hoehe)
        let videoSpuren = try await av.loadTracks(withMediaType: .video)
        let bildAus = AVAssetReaderVideoCompositionOutput(videoTracks: videoSpuren, videoSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        ])
        bildAus.videoComposition = komposition
        bildAus.alwaysCopiesSampleData = false
        leser.add(bildAus)

        let schreiber = try AVAssetWriter(outputURL: ziel, fileType: .mp4)
        schreiber.shouldOptimizeForNetworkUse = true
        let fps = try await videoSpuren.first?.load(.nominalFrameRate) ?? 30
        let bildEin = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: breite, AVVideoHeightKey: hoehe,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalDurationKey: 2,
                AVVideoExpectedSourceFrameRateKey: Int(fps.rounded()),
            ] as [String: Any],
        ])
        bildEin.expectsMediaDataInRealTime = false
        schreiber.add(bildEin)

        var tonAus: AVAssetReaderAudioMixOutput?
        var tonEin: AVAssetWriterInput?
        let tonSpuren = try await av.loadTracks(withMediaType: .audio)
        if !tonSpuren.isEmpty {
            // Mischt auch Raumklang (4 Kanäle) auf Stereo herunter.
            let aus = AVAssetReaderAudioMixOutput(audioTracks: tonSpuren, audioSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ])
            if leser.canAdd(aus) {
                leser.add(aus)
                let ein = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192_000,
                ])
                ein.expectsMediaDataInRealTime = false
                if schreiber.canAdd(ein) { schreiber.add(ein); tonAus = aus; tonEin = ein }
            }
        }

        guard leser.startReading() else { throw leser.error ?? MediathekFehler.nichtGeladen }
        guard schreiber.startWriting() else { throw schreiber.error ?? MediathekFehler.nichtGeladen }
        schreiber.startSession(atSourceTime: .zero)

        let paket = Pumpe(leser: leser, schreiber: schreiber)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (f: CheckedContinuation<Void, Error>) in
                let gruppe = DispatchGroup()
                gruppe.enter()
                bildEin.requestMediaDataWhenReady(on: DispatchQueue(label: "web.bild")) {
                    while bildEin.isReadyForMoreMediaData {
                        guard paket.leser.status == .reading, let p = bildAus.copyNextSampleBuffer() else {
                            bildEin.markAsFinished(); gruppe.leave(); return
                        }
                        if dauer > 0 { fortschritt(min(1, CMSampleBufferGetPresentationTimeStamp(p).seconds / dauer)) }
                        if !bildEin.append(p) { paket.leser.cancelReading(); bildEin.markAsFinished(); gruppe.leave(); return }
                    }
                }
                if let tonEin, let tonAus {
                    gruppe.enter()
                    tonEin.requestMediaDataWhenReady(on: DispatchQueue(label: "web.ton")) {
                        while tonEin.isReadyForMoreMediaData {
                            guard paket.leser.status == .reading, let p = tonAus.copyNextSampleBuffer() else {
                                tonEin.markAsFinished(); gruppe.leave(); return
                            }
                            if !tonEin.append(p) { tonEin.markAsFinished(); gruppe.leave(); return }
                        }
                    }
                }
                gruppe.notify(queue: .global()) {
                    if paket.leser.status == .failed || paket.schreiber.status == .failed || paket.leser.status == .cancelled {
                        paket.schreiber.cancelWriting()
                        f.resume(throwing: paket.schreiber.error ?? paket.leser.error ?? CancellationError())
                        return
                    }
                    paket.schreiber.finishWriting {
                        if paket.schreiber.status == .completed { f.resume() } else { f.resume(throwing: paket.schreiber.error ?? MediathekFehler.nichtGeladen) }
                    }
                }
            }
        } onCancel: { paket.leser.cancelReading() }
    }

    private final class Pumpe: @unchecked Sendable {
        let leser: AVAssetReader
        let schreiber: AVAssetWriter
        init(leser: AVAssetReader, schreiber: AVAssetWriter) { self.leser = leser; self.schreiber = schreiber }
    }

    // MARK: Vorschau (Karte)

    /// Vorschaubild 800 × 500 in der Startansicht (wie `G.vorschauBild`), aus PhotoKits Bild — das
    /// Original muss dafür nicht geladen werden; bei geänderter Startansicht entsteht es neu.
    static func vorschau(_ a: PHAsset, blick: Blick, nach ziel: URL) async throws {
        guard let quelle = await Vorschau.bild(a, CGSize(width: 4096, height: 2048), modus: .aspectFit)?.cgImage else {
            throw MediathekFehler.nichtGeladen
        }
        let bild = try await Task.detached(priority: .userInitiated) { () -> CGImage in
            guard let b = Ausschnitt.ansicht(aus: quelle, blick: blick, breite: 800, hoehe: 500) else { throw MediathekFehler.nichtGeladen }
            return b
        }.value
        try FileManager.default.createDirectory(at: ziel.deletingLastPathComponent(), withIntermediateDirectories: true)
        try jpeg(bild, nach: ziel, qualitaet: 0.85)
    }
}
