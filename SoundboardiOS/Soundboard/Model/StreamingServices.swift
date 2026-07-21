import Foundation
import MusicKit

// MARK: - Apple Music (MusicKit)

enum AppleMusicService {

    /// Fragt bei Bedarf die MusicKit-Berechtigung an.
    static func ensureAuthorized() async -> Bool {
        switch MusicAuthorization.currentStatus {
        case .authorized:
            return true
        case .notDetermined:
            return await MusicAuthorization.request() == .authorized
        default:
            return false
        }
    }

    /// Sucht Titel im Apple-Music-Katalog.
    static func searchSongs(term: String, limit: Int = 25) async throws -> [Song] {
        var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
        request.limit = limit
        let response = try await request.response()
        return Array(response.songs)
    }
}

// MARK: - Deezer (öffentliche Such-API, ohne Anmeldung)

struct DeezerTrack: Decodable, Identifiable {
    struct Artist: Decodable {
        let name: String
    }
    struct Album: Decodable {
        let cover_medium: String?
    }

    let id: Int64
    let title: String
    let duration: Double?
    /// URL der 30-Sekunden-Vorschau (MP3).
    let preview: String
    let link: String?
    let artist: Artist
    let album: Album?
}

enum DeezerService {
    private struct SearchResponse: Decodable {
        let data: [DeezerTrack]
    }

    static func search(term: String, limit: Int = 25) async throws -> [DeezerTrack] {
        var components = URLComponents(string: "https://api.deezer.com/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: term),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(SearchResponse.self, from: data).data
    }
}

// MARK: - Spotify (per Titel-Link, Wiedergabe in der Spotify-App)

enum SpotifyLink {

    /// Liest die Track-ID aus einem Spotify-Link oder einer Spotify-URI.
    /// Unterstützt z. B.:
    /// - https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC
    /// - https://open.spotify.com/intl-de/track/4uLU6hMCjMI75M1A2tKUQC?si=…
    /// - spotify:track:4uLU6hMCjMI75M1A2tKUQC
    static func trackID(from input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.lowercased().hasPrefix("spotify:track:") {
            let id = String(text.dropFirst("spotify:track:".count))
            return validID(id)
        }

        if let url = URL(string: text),
           let host = url.host?.lowercased(),
           host.contains("spotify.com") {
            let parts = url.pathComponents
            if let trackIndex = parts.firstIndex(of: "track"), trackIndex + 1 < parts.count {
                return validID(parts[trackIndex + 1])
            }
        }
        return nil
    }

    private static func validID(_ raw: String) -> String? {
        let id = raw.components(separatedBy: "?").first ?? raw
        let allowed = CharacterSet.alphanumerics
        guard !id.isEmpty, id.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return id
    }
}
