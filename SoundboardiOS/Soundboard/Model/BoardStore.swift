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
        } else {
            boards = BoardDefaults.makeBoards()
            activeBoardID = boards.first?.id
            saveNow()
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

    func saveNow() {
        let data = AppData(boards: boards, activeBoardID: activeBoardID)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let json = try encoder.encode(data)
            try json.write(to: Self.dataFileURL, options: .atomic)
        } catch {
            showStatus("Speichern fehlgeschlagen – Speicher voll?")
        }
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

    /// Ersetzt alle Daten durch den Inhalt einer Exportdatei.
    func importData(from url: URL) {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(ExportFile.self, from: data)
            guard file.format.hasPrefix("soundboard-ios-export") else {
                showStatus("Unbekanntes Dateiformat.")
                return
            }
            // Alte Mediendateien entfernen
            try? FileManager.default.removeItem(at: Self.audioDirURL)
            try? FileManager.default.removeItem(at: Self.backgroundsDirURL)
            try? FileManager.default.createDirectory(at: Self.audioDirURL, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: Self.backgroundsDirURL, withIntermediateDirectories: true)
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
        } catch {
            showStatus("Import fehlgeschlagen.")
        }
    }
}
