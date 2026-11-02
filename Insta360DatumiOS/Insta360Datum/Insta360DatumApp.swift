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
    @Published var laeuft = false       // Suche, Download oder Korrektur
    @Published var sucht = false        // Suche oder Download — abbrechbar
    @Published var nochOffen = 0        // Videos, die erst aus iCloud kommen müssen

    private var offen: [(PHAsset, String)] = [] {
        didSet { nochOffen = offen.count }
    }
    private var arbeit: Task<Void, Never>?

    private let erledigtKey = "erledigteAssets"
    private var erledigt: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: erledigtKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: erledigtKey) }
    }
    // Videos ohne Aufnahmezeit im Kommentar — nicht bei jeder Suche neu laden
    private let ohneZeitKey = "ohneZeitAssets"
    private var ohneZeit: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: ohneZeitKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: ohneZeitKey) }
    }

    func suchenStarten() {
        guard !laeuft else { return }
        arbeit = Task { await scannen() }
    }

    func iCloudLaden() {
        guard !laeuft, !offen.isEmpty else { return }
        arbeit = Task { await ausICloudLesen() }
    }

    func abbrechen() { arbeit?.cancel() }

    private func scannen() async {
        laeuft = true
        sucht = true
        defer { laeuft = false; sucht = false }
        kandidaten = []
        offen = []

        let auth = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard auth == .authorized else {
            status = "Bitte vollen Zugriff auf Fotos erlauben (Einstellungen › Apps › Insta360Datum › Fotos)."
            return
        }

        // 1. Alle Videos holen und Insta360-Exporte am Dateinamen erkennen
        let optionen = PHFetchOptions()
        optionen.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let videos = PHAsset.fetchAssets(with: .video, options: optionen)
        let ueberspringen = erledigt.union(ohneZeit)
        var treffer: [(PHAsset, String)] = []
        videos.enumerateObjects { asset, _, _ in
            guard !ueberspringen.contains(asset.localIdentifier) else { return }
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

        // 2. Erst nur, was schon auf dem Gerät liegt — das geht schnell. Videos,
        //    die nur in iCloud liegen (360°-Videos: oft mehrere GB), lädt
        //    erst der Knopf „aus iCloud laden“.
        let bilanz = await lesen(treffer, ausICloud: false)
        offen = bilanz.offen
        status = bericht(bilanz)
    }

    private func ausICloudLesen() async {
        laeuft = true
        sucht = true
        defer { laeuft = false; sucht = false }
        let bilanz = await lesen(offen, ausICloud: true)
        offen = bilanz.offen
        status = bericht(bilanz)
    }

    private struct Bilanz {
        var ohneZeit = 0
        var fehler = 0
        var offen: [(PHAsset, String)] = []
        var abgebrochen = false
    }

    /// Liest die Aufnahmezeiten der Reihe nach; Treffer erscheinen sofort in der Liste.
    private func lesen(_ liste: [(PHAsset, String)], ausICloud: Bool) async -> Bilanz {
        var b = Bilanz()
        for (i, (asset, name)) in liste.enumerated() {
            if Task.isCancelled {
                b.abgebrochen = true
                b.offen.append(contentsOf: liste[i...])
                break
            }
            let kopf = ausICloud
                ? "Lade Video \(i + 1) von \(liste.count) aus iCloud"
                : "Lese Video \(i + 1) von \(liste.count)"
            status = kopf + " …"
            let ergebnis = await Leser.aufnahmezeit(von: asset, ausICloud: ausICloud) { anteil in
                Task { @MainActor [weak self] in
                    guard let self, self.status.hasPrefix(kopf) else { return }
                    self.status = "\(kopf) … \(Int(anteil * 100)) %"
                }
            }
            switch ergebnis {
            case .datum(let neu):
                if let bisher = asset.creationDate, abs(bisher.timeIntervalSince(neu)) <= 60 {
                    erledigt.insert(asset.localIdentifier)   // stimmt schon
                } else {
                    kandidaten.append(Kandidat(id: asset.localIdentifier, name: name,
                                               bisher: asset.creationDate, neu: neu))
                }
            case .keinDatum:
                b.ohneZeit += 1
                ohneZeit.insert(asset.localIdentifier)
            case .nurInICloud, .fehlgeschlagen:
                if Task.isCancelled {
                    b.abgebrochen = true
                } else if ausICloud {
                    b.fehler += 1
                }
                b.offen.append((asset, name))
            }
        }
        return b
    }

    private func bericht(_ b: Bilanz) -> String {
        var s = b.abgebrochen ? "Abgebrochen. " : ""
        if !kandidaten.isEmpty {
            s += "\(kandidaten.count) Video(s) mit falschem Datum gefunden."
        } else if b.offen.isEmpty {
            s += "Alle Insta360-Videos haben bereits das richtige Datum."
        } else {
            s += "Auf dem Gerät keine Videos mit falschem Datum."
        }
        if b.ohneZeit > 0 { s += " \(b.ohneZeit) ohne Aufnahmezeit übersprungen." }
        if b.fehler > 0 { s += " \(b.fehler) ließen sich nicht aus iCloud laden." }
        return s
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
    enum Ergebnis { case datum(Date), keinDatum, nurInICloud, fehlgeschlagen }
    enum Laden { case datei(URL), nurInICloud, fehlgeschlagen }

    /// So lange darf ein iCloud-Download ohne jeden Fortschritt bleiben.
    static let geduld: TimeInterval = 120

    static func aufnahmezeit(von asset: PHAsset, ausICloud: Bool,
                             fortschritt: @escaping @Sendable (Double) -> Void = { _ in }) async -> Ergebnis {
        switch await videoURL(von: asset, ausICloud: ausICloud, fortschritt: fortschritt) {
        case .nurInICloud: return .nurInICloud
        case .fehlgeschlagen: return .fehlgeschlagen
        case .datei(let url):
            if let d = await aufnahmezeit(aus: url) { return .datum(d) }
            return .keinDatum
        }
    }

    static func aufnahmezeit(aus url: URL) async -> Date? {
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

    /// Liefert die Datei-URL des Original-Videos. Ohne `ausICloud` nur, wenn es
    /// schon auf dem Gerät liegt; sonst wird es geladen — abbrechbar, und ein
    /// Download, der `geduld` Sekunden lang nicht vorankommt, wird aufgegeben.
    static func videoURL(von asset: PHAsset, ausICloud: Bool,
                         fortschritt: @escaping @Sendable (Double) -> Void) async -> Laden {
        let anfrage = Anfrage()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (fortsetzung: CheckedContinuation<Laden, Never>) in
                guard anfrage.beginnen(fortsetzung) else { return }
                let o = PHVideoRequestOptions()
                o.version = .original
                o.deliveryMode = .highQualityFormat
                o.isNetworkAccessAllowed = ausICloud
                o.progressHandler = { anteil, _, _, _ in
                    anfrage.lebt()
                    fortschritt(anteil)
                }
                let id = PHImageManager.default().requestAVAsset(forVideo: asset, options: o) { av, _, info in
                    if let url = (av as? AVURLAsset)?.url {
                        anfrage.beenden(.datei(url))
                    } else if (info?[PHImageResultIsInCloudKey] as? Bool) == true {
                        anfrage.beenden(.nurInICloud)
                    } else {
                        anfrage.beenden(.fehlgeschlagen)
                    }
                }
                anfrage.merken(id)
                guard ausICloud else { return }
                Task.detached {
                    while !anfrage.vorbei {
                        try? await Task.sleep(for: .seconds(5))
                        if anfrage.stillSeit > Leser.geduld { anfrage.abbrechen() }
                    }
                }
            }
        } onCancel: {
            anfrage.abbrechen()
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

/// Eine Video-Anfrage an Fotos, die genau einmal endet: mit dem Ergebnis,
/// durch Abbrechen oder weil der iCloud-Download hängen bleibt.
private final class Anfrage: @unchecked Sendable {
    private let sperre = NSLock()
    private var fortsetzung: CheckedContinuation<Leser.Laden, Never>?
    private var id: PHImageRequestID?
    private var beendet = false
    private var letzterFortschritt = Date()

    /// false, wenn schon abgebrochen wurde, bevor die Anfrage begann.
    func beginnen(_ f: CheckedContinuation<Leser.Laden, Never>) -> Bool {
        let schonVorbei: Bool = sperre.withLock {
            if !beendet {
                fortsetzung = f
                letzterFortschritt = Date()
            }
            return beendet
        }
        if schonVorbei { f.resume(returning: .fehlgeschlagen) }
        return !schonVorbei
    }

    func merken(_ neu: PHImageRequestID) {
        let schonVorbei: Bool = sperre.withLock {
            id = neu
            return beendet
        }
        if schonVorbei { PHImageManager.default().cancelImageRequest(neu) }
    }

    func lebt() { sperre.withLock { letzterFortschritt = Date() } }
    var vorbei: Bool { sperre.withLock { beendet } }
    var stillSeit: TimeInterval { sperre.withLock { Date().timeIntervalSince(letzterFortschritt) } }

    func beenden(_ ergebnis: Leser.Laden) {
        let f: CheckedContinuation<Leser.Laden, Never>? = sperre.withLock {
            beendet = true
            defer { fortsetzung = nil }
            return fortsetzung
        }
        f?.resume(returning: ergebnis)
    }

    func abbrechen() {
        let laufend: PHImageRequestID? = sperre.withLock { id }
        if let laufend { PHImageManager.default().cancelImageRequest(laufend) }
        beenden(.fehlgeschlagen)
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
                if modell.nochOffen > 0 && !modell.laeuft {
                    VStack(alignment: .leading, spacing: 4) {
                        Button("\(modell.nochOffen) Video(s) aus iCloud laden") { modell.iCloudLaden() }
                        Text("Liegen nicht auf diesem Gerät. Jedes Video wird ganz geladen – 360°-Videos sind oft mehrere GB groß, besser im WLAN.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                    if modell.sucht {
                        Button("Abbrechen") { modell.abbrechen() }
                    } else {
                        Button("Suchen") { modell.suchenStarten() }
                            .disabled(modell.laeuft)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Korrigieren") { Task { await modell.korrigieren() } }
                        .disabled(modell.laeuft || !modell.kandidaten.contains { $0.ausgewaehlt })
                }
            }
            .overlay {
                if modell.laeuft && modell.kandidaten.isEmpty { ProgressView() }
            }
            .task { modell.suchenStarten() }
        }
    }
}
