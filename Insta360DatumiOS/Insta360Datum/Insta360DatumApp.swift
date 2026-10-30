//  Insta360DatumApp.swift
//
//  Kleine iOS-App: Findet alle Insta360-Exporte (temp_video_…) in der
//  Fotos-Mediathek, liest die echte Aufnahmezeit aus dem Kommentarfeld der
//  MP4-Datei (z. B. "2026-10-28 12:38:37 +0000" = Ortszeit der Kamera,
//  das "+0000" ist falsch und wird ignoriert) und setzt das Datum in Fotos.
//
//  Einzige Swift-Datei der App; die Tests liegen in Insta360DatumTests/.
//  NSPhotoLibraryUsageDescription steht als Build-Einstellung im Projekt.

import SwiftUI
import Photos
import AVFoundation

@main
struct Insta360DatumApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

// MARK: - Datenmodell

struct Kandidat: Identifiable {
    let id: String          // localIdentifier des PHAsset
    let name: String        // Original-Dateiname
    let bisher: Date?
    let neu: Date
    var ausgewaehlt = true
}

@MainActor
final class Modell: ObservableObject {
    @Published var kandidaten: [Kandidat] = []
    @Published var status = ""
    @Published var laeuft = false

    private let erledigtKey = "erledigteAssets"
    private var erledigt: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: erledigtKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: erledigtKey) }
    }

    func scannen() async {
        guard !laeuft else { return }
        laeuft = true
        defer { laeuft = false }
        kandidaten = []

        let auth = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard auth == .authorized else {
            status = "Bitte vollen Zugriff auf Fotos erlauben (Einstellungen › Apps › Insta360Datum › Fotos)."
            return
        }

        // 1. Alle Videos holen und Insta360-Exporte am Dateinamen erkennen
        let optionen = PHFetchOptions()
        optionen.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let videos = PHAsset.fetchAssets(with: .video, options: optionen)
        let schonErledigt = erledigt
        var treffer: [(PHAsset, String)] = []
        videos.enumerateObjects { asset, _, _ in
            guard !schonErledigt.contains(asset.localIdentifier) else { return }
            let ressourcen = PHAssetResource.assetResources(for: asset)
            let name = (ressourcen.first(where: { $0.type == .video }) ?? ressourcen.first)?.originalFilename ?? ""
            if name.lowercased().hasPrefix("temp_video_") {
                treffer.append((asset, name))
            }
        }

        if treffer.isEmpty {
            status = "Keine neuen Insta360-Videos gefunden."
            return
        }

        // 2. Aufnahmezeit aus jeder Datei lesen
        var gefunden: [Kandidat] = []
        var ohneZeit = 0
        for (i, (asset, name)) in treffer.enumerated() {
            status = "Lese Video \(i + 1) von \(treffer.count) …"
            guard let neu = await Leser.aufnahmezeit(von: asset) else {
                ohneZeit += 1
                continue
            }
            if let bisher = asset.creationDate, abs(bisher.timeIntervalSince(neu)) <= 60 {
                erledigt.insert(asset.localIdentifier)   // stimmt schon
                continue
            }
            gefunden.append(Kandidat(id: asset.localIdentifier, name: name,
                                     bisher: asset.creationDate, neu: neu))
        }
        kandidaten = gefunden
        status = gefunden.isEmpty
            ? "Alle Insta360-Videos haben bereits das richtige Datum."
            : "\(gefunden.count) Video(s) mit falschem Datum gefunden."
        if ohneZeit > 0 { status += " \(ohneZeit) ohne Aufnahmezeit übersprungen." }
    }

    func korrigieren() async {
        let auswahl = kandidaten.filter(\.ausgewaehlt)
        guard !auswahl.isEmpty, !laeuft else { return }
        laeuft = true
        defer { laeuft = false }

        let paare: [(String, Date)] = auswahl.map { ($0.id, $0.neu) }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let ids = paare.map(\.0)
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
                let datum = Dictionary(uniqueKeysWithValues: paare)
                assets.enumerateObjects { asset, _, _ in
                    if let neu = datum[asset.localIdentifier] {
                        PHAssetChangeRequest(for: asset).creationDate = neu
                    }
                }
            }
            var e = erledigt
            auswahl.forEach { e.insert($0.id) }
            erledigt = e
            kandidaten.removeAll { $0.ausgewaehlt }
            status = "\(auswahl.count) Video(s) korrigiert."
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }
}

// MARK: - Aufnahmezeit aus der Videodatei lesen

enum Leser {
    static func aufnahmezeit(von asset: PHAsset) async -> Date? {
        guard let url = await videoURL(von: asset) else { return nil }

        // a) Über AVFoundation: Kommentarfeld (©cmt)
        let av = AVURLAsset(url: url)
        if let items = try? await av.load(.metadata) {
            for item in items {
                let kennung = item.identifier?.rawValue.lowercased() ?? ""
                guard kennung.contains("cmt") || kennung.contains("comment") else { continue }
                if let text = try? await item.load(.stringValue), let d = datum(aus: text) {
                    return d
                }
            }
        }
        // b) Rückfall: Metadatenblock (moov) direkt aus der Datei lesen
        if let moov = moovLesen(url),
           let text = String(data: moov, encoding: .isoLatin1),
           let d = datum(aus: text) {
            return d
        }
        return nil
    }

    /// Lädt das Original-Video (bei Bedarf aus iCloud) und liefert dessen Datei-URL.
    static func videoURL(von asset: PHAsset) async -> URL? {
        await withCheckedContinuation { fortsetzung in
            let o = PHVideoRequestOptions()
            o.version = .original
            o.deliveryMode = .highQualityFormat
            o.isNetworkAccessAllowed = true
            PHImageManager.default().requestAVAsset(forVideo: asset, options: o) { av, _, _ in
                fortsetzung.resume(returning: (av as? AVURLAsset)?.url)
            }
        }
    }

    /// "2026-10-28 12:38:37 +0000" → 28.10.2026 12:38:37 Ortszeit
    /// (die Zeitzone ist nur für die Tests einstellbar).
    static func datum(aus text: String, zeitzone: TimeZone = .current) -> Date? {
        guard let r = text.range(of: #"20\d\d-\d\d-\d\d[ T]\d\d:\d\d:\d\d"#,
                                 options: .regularExpression) else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = zeitzone
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: String(text[r]).replacingOccurrences(of: "T", with: " "))
    }

    /// Sucht den 'moov'-Block der MP4-Datei und liest nur diesen (wenige KB).
    static func moovLesen(_ url: URL) -> Data? {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fh.close() }
        guard let groesse = try? fh.seekToEnd() else { return nil }
        var pos: UInt64 = 0
        while pos + 8 <= groesse {
            try? fh.seek(toOffset: pos)
            guard let kopf = try? fh.read(upToCount: 16), kopf.count >= 8 else { return nil }
            let b = [UInt8](kopf)
            var laenge = b[0..<4].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
            let typ = String(bytes: b[4..<8], encoding: .ascii) ?? ""
            var kopfLaenge: UInt64 = 8
            if laenge == 1 {
                guard b.count >= 16 else { return nil }
                laenge = b[8..<16].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
                kopfLaenge = 16
            } else if laenge == 0 {
                laenge = groesse - pos
            }
            // Kaputte Längenangabe: sonst Unterlauf bzw. Endlosschleife
            guard laenge >= kopfLaenge else { return nil }
            if typ == "moov" {
                // Nie mehr lesen, als die Datei hergibt, und höchstens 64 MB
                let inhalt = min(laenge, groesse - pos) - kopfLaenge
                try? fh.seek(toOffset: pos + kopfLaenge)
                return try? fh.read(upToCount: Int(min(inhalt, 64 << 20)))
            }
            guard laenge <= groesse - pos else { return nil }
            pos += laenge
        }
        return nil
    }
}

// MARK: - Oberfläche

struct ContentView: View {
    @StateObject private var modell = Modell()

    private static let format: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                if !modell.status.isEmpty {
                    Text(modell.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach($modell.kandidaten) { $k in
                    Toggle(isOn: $k.ausgewaehlt) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(k.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("bisher: " + (k.bisher.map { Self.format.string(from: $0) } ?? "–"))
                            Text("neu: " + Self.format.string(from: k.neu))
                                .bold()
                        }
                    }
                }
            }
            .navigationTitle("Insta360-Datum")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Suchen") { Task { await modell.scannen() } }
                        .disabled(modell.laeuft)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Korrigieren") { Task { await modell.korrigieren() } }
                        .disabled(modell.laeuft || !modell.kandidaten.contains { $0.ausgewaehlt })
                }
            }
            .overlay {
                if modell.laeuft { ProgressView() }
            }
            .task { await modell.scannen() }
        }
    }
}
