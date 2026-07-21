import MusicKit
import SwiftUI

enum StreamingServiceKind: String, Identifiable {
    case appleMusic
    case deezer
    case spotify

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .deezer:     return "Deezer"
        case .spotify:    return "Spotify"
        }
    }
}

/// Auswahl eines Musiktitels aus einem Streamingdienst für ein Feld.
struct StreamingPickerView: View {
    let service: StreamingServiceKind
    var onPick: (PadSource) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch service {
                case .appleMusic:
                    AppleMusicSearchView { source in
                        onPick(source)
                        dismiss()
                    }
                case .deezer:
                    DeezerSearchView { source in
                        onPick(source)
                        dismiss()
                    }
                case .spotify:
                    SpotifyLinkView { source in
                        onPick(source)
                        dismiss()
                    }
                }
            }
            .navigationTitle(service.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Apple Music

private struct AppleMusicSearchView: View {
    var onPick: (PadSource) -> Void

    @State private var searchTerm = ""
    @State private var songs: [Song] = []
    @State private var searching = false
    @State private var deniedAccess = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if deniedAccess {
                Section {
                    Label("Kein Zugriff auf Apple Music. Bitte in den iOS-Einstellungen unter „Soundboard“ den Medienzugriff erlauben.",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(songs) { song in
                    Button {
                        onPick(.appleMusic(
                            id: song.id.rawValue,
                            title: song.title,
                            artist: song.artistName,
                            artworkURL: song.artwork?.url(width: 120, height: 120)?.absoluteString,
                            duration: song.duration ?? 0
                        ))
                    } label: {
                        TrackRow(
                            title: song.title,
                            subtitle: song.artistName,
                            artworkURL: song.artwork?.url(width: 120, height: 120),
                            duration: song.duration
                        )
                    }
                }
            } footer: {
                if !songs.isEmpty {
                    Text("Wiedergabe in voller Länge mit aktivem Apple-Music-Abo.")
                }
            }
        }
        .overlay {
            if searching { ProgressView() }
        }
        .searchable(text: $searchTerm, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Titel oder Interpret suchen")
        .onSubmit(of: .search) { Task { await search() } }
        .task {
            deniedAccess = !(await AppleMusicService.ensureAuthorized())
        }
    }

    private func search() async {
        guard !searchTerm.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        searching = true
        errorMessage = nil
        defer { searching = false }
        guard await AppleMusicService.ensureAuthorized() else {
            deniedAccess = true
            return
        }
        deniedAccess = false
        do {
            songs = try await AppleMusicService.searchSongs(term: searchTerm)
            if songs.isEmpty { errorMessage = "Keine Titel gefunden." }
        } catch {
            // Den echten Grund anzeigen – meist fehlt die MusicKit-Freischaltung
            // der App-ID im Apple-Developer-Portal (Fehler 401/403).
            let details = error.localizedDescription
            if details.contains("401") || details.contains("403")
                || details.lowercased().contains("unauthorized")
                || details.lowercased().contains("permission") {
                errorMessage = "Apple Music lehnt die Anfrage ab. Für die App-ID de.familie.soundboard muss im Apple-Developer-Portal unter „Identifiers“ → „App Services“ der Dienst MusicKit aktiviert sein. Danach die App neu starten (die Freischaltung kann einige Minuten dauern)."
            } else {
                errorMessage = "Suche fehlgeschlagen: \(details)"
            }
        }
    }
}

// MARK: - Deezer

private struct DeezerSearchView: View {
    var onPick: (PadSource) -> Void

    @State private var searchTerm = ""
    @State private var tracks: [DeezerTrack] = []
    @State private var searching = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(tracks) { track in
                    Button {
                        onPick(.deezer(
                            id: track.id,
                            title: track.title,
                            artist: track.artist.name,
                            previewURL: track.preview,
                            link: track.link ?? "https://www.deezer.com/track/\(track.id)",
                            artworkURL: track.album?.cover_medium,
                            duration: track.duration ?? 0
                        ))
                    } label: {
                        TrackRow(
                            title: track.title,
                            subtitle: track.artist.name,
                            artworkURL: track.album?.cover_medium.flatMap(URL.init(string:)),
                            duration: track.duration
                        )
                    }
                }
            } footer: {
                if !tracks.isEmpty {
                    Text("In der App wird die 30-Sekunden-Vorschau angespielt – ideal zum Anspielen von Titeln.")
                }
            }
        }
        .overlay {
            if searching { ProgressView() }
        }
        .searchable(text: $searchTerm, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Titel oder Interpret suchen")
        .onSubmit(of: .search) { Task { await search() } }
    }

    private func search() async {
        guard !searchTerm.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        searching = true
        errorMessage = nil
        defer { searching = false }
        do {
            tracks = try await DeezerService.search(term: searchTerm)
            if tracks.isEmpty { errorMessage = "Keine Titel gefunden." }
        } catch {
            errorMessage = "Suche fehlgeschlagen – Internetverbindung prüfen."
        }
    }
}

// MARK: - Spotify

private struct SpotifyLinkView: View {
    var onPick: (PadSource) -> Void

    @State private var linkText = ""
    @State private var titleText = ""
    @State private var invalidLink = false

    var body: some View {
        Form {
            Section {
                TextField("https://open.spotify.com/track/…", text: $linkText, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Anzeigename (optional)", text: $titleText)
            } header: {
                Text("Titel-Link")
            } footer: {
                Text("In Spotify beim gewünschten Titel „Teilen“ → „Link kopieren“ wählen und hier einfügen. Beim Antippen des Feldes wird der Titel in der Spotify-App abgespielt (Anmeldung in der Spotify-App vorausgesetzt).")
            }

            if invalidLink {
                Section {
                    Label("Das ist kein gültiger Spotify-Titel-Link.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    if let id = SpotifyLink.trackID(from: linkText) {
                        onPick(.spotify(id: id, title: titleText))
                    } else {
                        invalidLink = true
                    }
                } label: {
                    Label("Übernehmen", systemImage: "checkmark.circle.fill")
                }
                .disabled(linkText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// MARK: - Gemeinsame Titelzeile

private struct TrackRow: View {
    let title: String
    let subtitle: String
    let artworkURL: URL?
    let duration: Double?

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let duration, duration > 0 {
                Text(formatTime(duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
