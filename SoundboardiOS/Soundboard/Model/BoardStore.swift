import Foundation
import SwiftUI

/// Verwaltet Boards und Felder, speichert alles im Documents-Verzeichnis
/// (JSON-Datei + Audiodateien + Hintergrundbilder) und stellt Import/Export bereit.
@MainActor
final class BoardStore: ObservableObject {

    @Published var boards: [SoundBoard] = []
    @Published var activeBoardID: UUID?
    @Published var editMode: Bool = false
    @Published var statusMessage: String?

    /// Zeitpunkt der letzten Nutzeränderung (für den iCloud-Abgleich).
    private(set) var savedAt: Date?
    /// Wird nach jedem Speichern einer Nutzeränderung aufgerufen (iCloud-Push).
    var onUserSave: (() -> Void)?

    private var saveTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?

    // MARK: - Pfade

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var dataFileURL: URL { documentsURL.appendingPathComponent("soundboard.json") }
    static var audioDirURL: URL { documentsURL.appendingPathComponent("Audio", isDirectory: true) }
    static var backgroundsDirURL: URL { documentsURL.appendingPathComponent("Backgrounds", isDirectory: true) }

    init() {
        try? FileManager.default.createDirectory(at: Self.audioDirURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: Self.backgroundsDirURL, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Zugriff

    var visibleBoards: [SoundBoard] {
        let visible = boards.filter { !$0.hidden }
        return visible.isEmpty ? Array(boards.prefix(1)) : visible
    }

    var activeBoard: SoundBoard? {
        boards.first { $0.id == activeBoardID } ?? visibleBoards.first
    }

    var activeBoardIndex: Int? {
        boards.firstIndex { $0.id == activeBoard?.id }
    }

    func pad(_ padID: UUID) -> SoundPad? {
        for board in boards {
            if let pad = board.pads.first(where: { $0.id == padID }) { return pad }
        }
        return nil
    }

    func updatePad(_ padID: UUID, _ change: (inout SoundPad) -> Void) {
        for b in boards.indices {
            if let p = boards[b].pads.firstIndex(where: { $0.id == padID }) {
                change(&boards[b].pads[p])
                scheduleSave()
                return
            }
        }
    }

    func updateBoard(_ boardID: UUID, _ change: (inout SoundBoard) -> Void) {
        if let b = boards.firstIndex(where: { $0.id == boardID }) {
            change(&boards[b])
            scheduleSave()
        }
    }

    func selectBoard(_ boardID: UUID) {
        activeBoardID = boardID
        scheduleSave()
    }

    func movePad(inBoard boardID: UUID, from source: UUID, to target: UUID) {
        guard let b = boards.firstIndex(where: { $0.id == boardID }),
              let fromIndex = boards[b].pads.firstIndex(where: { $0.id == source }),
              let toIndex = boards[b].pads.firstIndex(where: { $0.id == target }),
              fromIndex != toIndex else { return }
        withAnimation(.spring(duration: 0.3)) {
            let pad = boards[b].pads.remove(at: fromIndex)
            boards[b].pads.insert(pad, at: toIndex)
        }
        scheduleSave()
    }

    func moveBoards(fromOffsets: IndexSet, toOffset: Int) {
        boards.move(fromOffsets: fromOffsets, toOffset: toOffset)
        scheduleSave()
    }

    // MARK: - Statusmeldungen (Toast)

    func showStatus(_ message: String) {
        statusMessage = message
        statusTask?.cancel()
        statusTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            if !Task.isCancelled { statusMessage = nil }
        }
    }

    // MARK: - Laden & Speichern

    private func load() {
        if let data = try? Data(contentsOf: Self.dataFileURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: data),
           !decoded.boards.isEmpty {
            boards = decoded.boards
            activeBoardID = decoded.activeBoardID ?? decoded.boards.first?.id
            // Ältere Datenstände ohne Zeitstempel bekommen das Dateidatum,
            // damit vorhandene Inhalte beim iCloud-Abgleich nicht unterliegen.
            savedAt = decoded.savedAt
                ?? (try? FileManager.default.attributesOfItem(atPath: Self.dataFileURL.path)[.modificationDate] as? Date)
                ?? nil
        } else {
            boards = BoardDefaults.makeBoards()
            activeBoardID = boards.first?.id
            saveNow(markUserChange: false)
        }
        if let active = activeBoard, active.hidden, let firstVisible = visibleBoards.first {
            activeBoardID = firstVisible.id
        }
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            if !Task.isCancelled { saveNow() }
        }
    }

    func saveNow(markUserChange: Bool = true) {
        if markUserChange { savedAt = Date() }
        let data = AppData(boards: boards, activeBoardID: activeBoardID, savedAt: savedAt)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let json = try encoder.encode(data)
            try json.write(to: Self.dataFileURL, options: .atomic)
            if markUserChange { onUserSave?() }
        } catch {
            showStatus("Speichern fehlgeschlagen – Speicher voll?")
        }
    }

    /// Übernimmt einen kompletten Datenstand aus iCloud (Mediendateien liegen bereits lokal).
    func adopt(data: AppData) {
        boards = data.boards
        activeBoardID = data.activeBoardID ?? boards.first?.id
        savedAt = data.savedAt
        if let active = activeBoard, active.hidden, let firstVisible = visibleBoards.first {
            activeBoardID = firstVisible.id
        }
        saveNow(markUserChange: false)
    }

    // MARK: - Audiodateien

    /// Kopiert eine gewählte Audiodatei in das App-Verzeichnis und liefert die neue Quelle.
    func importAudioFile(from url: URL) -> PadSource? {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
        let relativePath = UUID().uuidString + "." + ext
        let target = Self.audioDirURL.appendingPathComponent(relativePath)
        do {
            try FileManager.default.copyItem(at: url, to: target)
            return .file(fileName: url.lastPathComponent, relativePath: relativePath)
        } catch {
            showStatus("Datei konnte nicht übernommen werden.")
            return nil
        }
    }

    /// Löscht die zu einer Quelle gehörende lokale Datei (falls vorhanden).
    func deleteStoredAudio(of source: PadSource) {
        if case .file(_, let relativePath) = source {
            try? FileManager.default.removeItem(at: Self.audioDirURL.appendingPathComponent(relativePath))
        }
    }

    func audioFileURL(relativePath: String) -> URL {
        Self.audioDirURL.appendingPathComponent(relativePath)
    }

    // MARK: - Hintergrundbilder

    func setBackgroundImage(data: Data, for boardID: UUID) {
        let name = UUID().uuidString + ".jpg"
        let target = Self.backgroundsDirURL.appendingPathComponent(name)
        do {
            try data.write(to: target, options: .atomic)
            updateBoard(boardID) { board in
                if let old = board.backgroundImagePath {
                    try? FileManager.default.removeItem(at: Self.backgroundsDirURL.appendingPathComponent(old))
                }
                board.backgroundImagePath = name
            }
        } catch {
            showStatus("Hintergrundbild konnte nicht gespeichert werden.")
        }
    }

    func removeBackgroundImage(for boardID: UUID) {
        updateBoard(boardID) { board in
            if let old = board.backgroundImagePath {
                try? FileManager.default.removeItem(at: Self.backgroundsDirURL.appendingPathComponent(old))
            }
            board.backgroundImagePath = nil
        }
    }

    func backgroundImageURL(for board: SoundBoard) -> URL? {
        guard let path = board.backgroundImagePath else { return nil }
        return Self.backgroundsDirURL.appendingPathComponent(path)
    }

    // MARK: - Export / Import

    struct ExportFile: Codable {
        var format: String = "soundboard-ios-export-v1"
        var exportedAt: Date = Date()
        var boards: [SoundBoard]
        /// relativePath -> Audiodaten (Base64 im JSON)
        var audioFiles: [String: Data]
        /// Dateiname -> Bilddaten
        var backgrounds: [String: Data]
    }

    /// Erstellt die Exportdatei mit allen Boards, Tönen und Bildern.
    func makeExportData() throws -> Data {
        var audio: [String: Data] = [:]
        var backgrounds: [String: Data] = [:]
        for board in boards {
            for pad in board.pads {
                if case .file(_, let relativePath) = pad.source {
                    audio[relativePath] = try? Data(contentsOf: audioFileURL(relativePath: relativePath))
                }
            }
            if let path = board.backgroundImagePath {
                backgrounds[path] = try? Data(contentsOf: Self.backgroundsDirURL.appendingPathComponent(path))
            }
        }
        let file = ExportFile(
            boards: boards,
            audioFiles: audio.compactMapValues { $0 },
            backgrounds: backgrounds.compactMapValues { $0 }
        )
        return try JSONEncoder().encode(file)
    }

    /// Ersetzt alle Daten durch den Inhalt einer Exportdatei
    /// (eigenes iOS-Format oder Export der Theater-Soundboard-PWA).
    func importData(from url: URL) {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            if let file = try? JSONDecoder().decode(ExportFile.self, from: data),
               file.format.hasPrefix("soundboard-ios-export") {
                importIOSExport(file)
            } else if let pwa = try? JSONDecoder().decode(PWAExport.self, from: data),
                      pwa.format == "soundboard-export-v1" {
                importPWAExport(pwa)
            } else {
                showStatus("Unbekanntes Dateiformat.")
            }
        } catch {
            showStatus("Import fehlgeschlagen.")
        }
    }

    private func clearMediaDirectories() {
        try? FileManager.default.removeItem(at: Self.audioDirURL)
        try? FileManager.default.removeItem(at: Self.backgroundsDirURL)
        try? FileManager.default.createDirectory(at: Self.audioDirURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: Self.backgroundsDirURL, withIntermediateDirectories: true)
    }

    private func importIOSExport(_ file: ExportFile) {
        clearMediaDirectories()
        for (path, bytes) in file.audioFiles {
            try? bytes.write(to: Self.audioDirURL.appendingPathComponent(path))
        }
        for (path, bytes) in file.backgrounds {
            try? bytes.write(to: Self.backgroundsDirURL.appendingPathComponent(path))
        }
        boards = file.boards
        activeBoardID = visibleBoards.first?.id
        saveNow()
        showStatus("Import abgeschlossen.")
    }

    // MARK: - Import aus der Theater-Soundboard-PWA ("soundboard-export-v1")

    struct PWAExport: Decodable {
        struct State: Decodable {
            var activeBoardId: Int?
            var boards: [Board]
        }
        struct Board: Decodable {
            var id: Int
            var order: Int?
            var name: String?
            var color: String?
            var hidden: Bool?
            var pads: [Pad]?
        }
        struct Pad: Decodable {
            struct Gestures: Decodable {
                var tap: String?
                var doubleTap: String?
                var longPress: String?
            }
            var id: Int
            var order: Int?
            var label: String?
            var color: String?
            var fileName: String?
            var volume: Double?
            var fadeOutDuration: Double?
            var hidden: Bool?
            var gestures: Gestures?
        }
        struct AudioItem: Decodable {
            var boardId: Int
            var padId: Int
            var fileName: String?
            var mimeType: String?
            var dataBase64: String?
        }
        struct BackgroundItem: Decodable {
            var boardId: Int
            var fileName: String?
            var mimeType: String?
            var dataBase64: String?
        }
        var format: String
        var state: State
        var audio: [AudioItem]?
        var backgrounds: [BackgroundItem]?
    }

    private func importPWAExport(_ pwa: PWAExport) {
        clearMediaDirectories()

        var newBoards: [SoundBoard] = []
        // PWA-Reihenfolge respektieren (Feld "order", dann id).
        let sortedBoards = pwa.state.boards.sorted {
            ($0.order ?? $0.id, $0.id) < ($1.order ?? $1.id, $1.id)
        }

        // Audio- und Hintergrunddaten nach Board/Feld auflösen.
        var audioByKey: [String: PWAExport.AudioItem] = [:]
        for item in pwa.audio ?? [] {
            audioByKey["\(item.boardId)-\(item.padId)"] = item
        }
        var backgroundByBoard: [Int: PWAExport.BackgroundItem] = [:]
        for item in pwa.backgrounds ?? [] {
            backgroundByBoard[item.boardId] = item
        }

        var importedAudio = 0
        for board in sortedBoards {
            var newBoard = SoundBoard(
                name: board.name ?? "Board \(board.id)",
                colorHex: board.color ?? BoardDefaults.boardColors[(board.id - 1) % BoardDefaults.boardColors.count],
                hidden: board.hidden ?? false
            )

            if let bg = backgroundByBoard[board.id],
               let base64 = bg.dataBase64,
               let bytes = Data(base64Encoded: base64) {
                let name = UUID().uuidString + ".jpg"
                try? bytes.write(to: Self.backgroundsDirURL.appendingPathComponent(name))
                newBoard.backgroundImagePath = name
            }

            let sortedPads = (board.pads ?? []).sorted {
                ($0.order ?? $0.id, $0.id) < ($1.order ?? $1.id, $1.id)
            }
            var newPads: [SoundPad] = []
            for pad in sortedPads {
                var newPad = SoundPad(
                    label: pad.label ?? "",
                    colorHex: pad.color ?? BoardDefaults.padColors[(pad.id - 1) % BoardDefaults.padColors.count]
                )
                newPad.volume = min(max(pad.volume ?? 1, 0), 1)
                newPad.fadeOutSeconds = min(max(pad.fadeOutDuration ?? 0.5, 0), 10)
                newPad.hidden = pad.hidden ?? false
                // Die Gesten-Namen der PWA sind identisch mit den hiesigen.
                newPad.singleTap = GestureAction(rawValue: pad.gestures?.tap ?? "") ?? .restartOrResume
                newPad.doubleTap = GestureAction(rawValue: pad.gestures?.doubleTap ?? "") ?? .pause
                newPad.longPress = GestureAction(rawValue: pad.gestures?.longPress ?? "") ?? .stopReset

                if let item = audioByKey["\(board.id)-\(pad.id)"],
                   let base64 = item.dataBase64,
                   let bytes = Data(base64Encoded: base64) {
                    let originalName = item.fileName ?? "audio-\(board.id)-\(pad.id)"
                    let ext = Self.audioExtension(fileName: originalName, mimeType: item.mimeType)
                    let relativePath = UUID().uuidString + "." + ext
                    try? bytes.write(to: Self.audioDirURL.appendingPathComponent(relativePath))
                    newPad.source = .file(fileName: originalName, relativePath: relativePath)
                    importedAudio += 1
                }
                newPads.append(newPad)
            }
            // Auf 16 Felder auffüllen, falls der Export weniger enthielt.
            while newPads.count < BoardDefaults.padCount {
                newPads.append(SoundPad(colorHex: BoardDefaults.padColors[newPads.count % BoardDefaults.padColors.count]))
            }
            newBoard.pads = newPads
            newBoards.append(newBoard)
        }

        guard !newBoards.isEmpty else {
            showStatus("Die PWA-Datei enthielt keine Boards.")
            return
        }

        boards = newBoards
        activeBoardID = visibleBoards.first?.id
        saveNow()
        showStatus("PWA-Import abgeschlossen: \(importedAudio) Tondatei(en) übernommen.")
    }

    private static func audioExtension(fileName: String, mimeType: String?) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        if !ext.isEmpty { return ext }
        switch (mimeType ?? "").lowercased() {
        case let m where m.contains("mpeg") || m.contains("mp3"): return "mp3"
        case let m where m.contains("mp4") || m.contains("m4a") || m.contains("aac"): return "m4a"
        case let m where m.contains("wav"): return "wav"
        case let m where m.contains("ogg"): return "ogg"
        case let m where m.contains("aiff"): return "aiff"
        default: return "m4a"
        }
    }
}
