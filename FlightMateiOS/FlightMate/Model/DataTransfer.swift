//
//  DataTransfer.swift
//  FlightMate
//
//  Daten-Export und -Import (Nutzerwunsch): eine JSON-Sicherung mit
//  Spots, Drohnenmodell und Score-Rückmeldungen — zum Verwahren,
//  Umziehen oder Weitergeben. Bewusst NICHT enthalten: die
//  API-Schlüssel (die gehören nicht in eine Klartext-Datei; sie
//  synchronisieren sicher über den iCloud-Schlüsselbund).
//

import Foundation

struct FlightMateBackup: Codable {
    var exportedAt: Date
    var droneProfileID: String?
    var spots: [Spot]
    var scoreFeedback: [ScoreFeedback]
}

enum DataTransfer {

    /// Schreibt die Sicherung als JSON-Datei ins Temp-Verzeichnis
    /// (fürs Teilen-Blatt: Dateien, AirDrop, Mail …).
    @MainActor
    static func exportFile(state: AppState) throws -> URL {
        let backup = FlightMateBackup(
            exportedAt: Date(),
            droneProfileID: state.droneProfileID,
            spots: state.spots,
            scoreFeedback: ScoreValidation.all()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlightMate-Sicherung.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Liest eine Sicherung ein und führt sie mit dem lokalen Stand
    /// zusammen (Spots: Vereinigung nach ID — nichts wird gelöscht).
    /// Liefert die Anzahl neu übernommener Spots.
    @MainActor
    static func importFile(at url: URL, into state: AppState) throws -> Int {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(FlightMateBackup.self, from: data)

        let known = Set(state.spots.map(\.id))
        let newSpots = backup.spots.filter { !known.contains($0.id) }
        if !newSpots.isEmpty {
            state.spots.append(contentsOf: newSpots)
        }
        if state.droneProfileID == nil, let profile = backup.droneProfileID {
            state.droneProfileID = profile
        }
        ScoreValidation.merge(backup.scoreFeedback)
        return newSpots.count
    }
}
