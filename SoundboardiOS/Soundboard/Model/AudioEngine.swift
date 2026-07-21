import AVFoundation
import Foundation
import MusicKit
import UIKit

/// Spielt die Töne der Felder ab: lokale Dateien (AVAudioPlayer),
/// Deezer-Vorschauen (AVPlayer), Apple-Music-Titel (MusicKit) und
/// öffnet Spotify-Titel in der Spotify-App.
@MainActor
final class AudioEngine: NSObject, ObservableObject {

    weak var store: BoardStore?

    private var filePlayers: [UUID: AVAudioPlayer] = [:]
    private var previewPlayers: [UUID: AVPlayer] = [:]
    private var fadeTasks: [UUID: Task<Void, Never>] = [:]
    private var songCache: [String: Song] = [:]

    /// Feld, dessen Apple-Music-Titel gerade in der Warteschlange liegt.
    @Published private(set) var appleMusicPadID: UUID?
    /// Taktgeber für die Fortschrittsanzeige.
    @Published private(set) var tick: Int = 0

    private var ticker: Timer?

    override init() {
        super.init()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)

        ticker = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.anyActivity { self.tick &+= 1 }
            }
        }
    }

    private var anyActivity: Bool {
        if filePlayers.values.contains(where: { $0.isPlaying || $0.currentTime > 0 }) { return true }
        if previewPlayers.values.contains(where: { $0.timeControlStatus != .paused }) { return true }
        if appleMusicPadID != nil { return true }
        return false
    }

    // MARK: - Zustand für die Anzeige

    func isPlaying(_ pad: SoundPad) -> Bool {
        switch pad.source {
        case .file:
            return filePlayers[pad.id]?.isPlaying ?? false
        case .deezer:
            guard let player = previewPlayers[pad.id] else { return false }
            return player.timeControlStatus == .playing || player.rate > 0
        case .appleMusic:
            return appleMusicPadID == pad.id
                && ApplicationMusicPlayer.shared.state.playbackStatus == .playing
        case .spotify, .empty:
            return false
        }
    }

    /// Aktuelle Position und Gesamtlänge (nil, wenn nichts anzeigbar ist).
    func progress(_ pad: SoundPad) -> (current: TimeInterval, duration: TimeInterval)? {
        switch pad.source {
        case .file:
            guard let player = filePlayers[pad.id] else { return nil }
            return (player.currentTime, player.duration)
        case .deezer:
            guard let player = previewPlayers[pad.id], let item = player.currentItem else { return nil }
            let dur = item.duration.isNumeric ? item.duration.seconds : 30
            return (item.currentTime().seconds, dur)
        case .appleMusic(_, _, _, _, let duration):
            guard appleMusicPadID == pad.id else { return nil }
            return (ApplicationMusicPlayer.shared.playbackTime, duration)
        case .spotify, .empty:
            return nil
        }
    }

    // MARK: - Gesten ausführen

    func perform(_ action: GestureAction, pad: SoundPad) {
        guard action != .none else { return }
        switch pad.source {
        case .empty:
            store?.showStatus("Dieses Feld ist leer – über „Bearbeiten“ einen Ton zuweisen.")
        case .file, .deezer:
            performLocal(action, pad: pad)
        case .appleMusic(let id, _, _, _, _):
            performAppleMusic(action, pad: pad, songID: id)
        case .spotify(let id, _):
            openSpotify(trackID: id)
        }
    }

    /// Stoppt alle Töne und setzt sie auf Anfang (ohne Ausblenden).
    func resetAll() {
        for (id, task) in fadeTasks { task.cancel(); fadeTasks[id] = nil }
        for player in filePlayers.values {
            player.pause()
            player.currentTime = 0
        }
        for player in previewPlayers.values {
            player.pause()
            player.seek(to: .zero)
        }
        if appleMusicPadID != nil {
            ApplicationMusicPlayer.shared.stop()
            appleMusicPadID = nil
        }
        tick &+= 1
    }

    /// Vergisst Player und Zustand eines Feldes (z. B. wenn die Quelle geändert wurde).
    func discard(padID: UUID) {
        fadeTasks[padID]?.cancel()
        fadeTasks[padID] = nil
        filePlayers[padID]?.stop()
        filePlayers[padID] = nil
        previewPlayers[padID]?.pause()
        previewPlayers[padID] = nil
        if appleMusicPadID == padID {
            ApplicationMusicPlayer.shared.stop()
            appleMusicPadID = nil
        }
    }

    /// Lautstärke eines bereits geladenen Players live anpassen.
    func applyVolume(_ pad: SoundPad) {
        filePlayers[pad.id]?.volume = Float(pad.volume)
        previewPlayers[pad.id]?.volume = Float(pad.volume)
    }

    // MARK: - Lokale Dateien & Deezer-Vorschau

    private func performLocal(_ action: GestureAction, pad: SoundPad) {
        cancelFade(pad.id)
        let playing = isPlaying(pad)
        let position = progress(pad)?.current ?? 0

        switch action {
        case .restartOrResume:
            if playing {
                seekToStart(pad)
            } else if position > 0.05 {
                play(pad, fromStart: false)
            } else {
                play(pad, fromStart: true)
            }
        case .restart:
            play(pad, fromStart: true)
        case .startOrReset:
            if playing {
                stopAndReset(pad, fade: true)
            } else {
                play(pad, fromStart: true)
            }
        case .resume:
            if !playing { play(pad, fromStart: false) }
        case .pause:
            pausePlayback(pad)
        case .stopReset:
            stopAndReset(pad, fade: true)
        case .toggle:
            if playing { pausePlayback(pad) } else { play(pad, fromStart: false) }
        case .none:
            break
        }
        tick &+= 1
    }

    private func play(_ pad: SoundPad, fromStart: Bool) {
        switch pad.source {
        case .file(_, let relativePath):
            guard let player = filePlayer(for: pad, relativePath: relativePath) else { return }
            player.volume = Float(pad.volume)
            if fromStart { player.currentTime = 0 }
            if !player.play() {
                store?.showStatus("Abspielen fehlgeschlagen: \(pad.displayLabel)")
            }
        case .deezer(_, _, _, let previewURL, _, _, _):
            guard let player = previewPlayer(for: pad, previewURL: previewURL) else { return }
            player.volume = Float(pad.volume)
            if fromStart { player.seek(to: .zero) }
            player.play()
        default:
            break
        }
    }

    private func pausePlayback(_ pad: SoundPad) {
        filePlayers[pad.id]?.pause()
        previewPlayers[pad.id]?.pause()
    }

    private func seekToStart(_ pad: SoundPad) {
        filePlayers[pad.id]?.currentTime = 0
        previewPlayers[pad.id]?.seek(to: .zero)
    }

    private func stopAndReset(_ pad: SoundPad, fade: Bool) {
        let seconds = fade ? pad.fadeOutSeconds : 0
        guard seconds > 0.05, isPlaying(pad) else {
            pausePlayback(pad)
            seekToStart(pad)
            return
        }
        let padID = pad.id
        let targetVolume = Float(pad.volume)
        let filePlayer = filePlayers[padID]
        let previewPlayer = previewPlayers[padID]
        fadeTasks[padID] = Task { [weak self] in
            let steps = 24
            for step in 0..<steps {
                if Task.isCancelled { return }
                let factor = 1 - Float(step + 1) / Float(steps)
                filePlayer?.volume = targetVolume * factor
                previewPlayer?.volume = targetVolume * factor
                try? await Task.sleep(for: .seconds(seconds / Double(steps)))
            }
            guard !Task.isCancelled else { return }
            filePlayer?.pause()
            filePlayer?.currentTime = 0
            filePlayer?.volume = targetVolume
            previewPlayer?.pause()
            previewPlayer?.seek(to: .zero)
            previewPlayer?.volume = targetVolume
            await MainActor.run { [weak self] in
                self?.fadeTasks[padID] = nil
                self?.tick &+= 1
            }
        }
    }

    private func cancelFade(_ padID: UUID) {
        fadeTasks[padID]?.cancel()
        fadeTasks[padID] = nil
    }

    private func filePlayer(for pad: SoundPad, relativePath: String) -> AVAudioPlayer? {
        if let existing = filePlayers[pad.id] { return existing }
        guard let store else { return nil }
        let url = store.audioFileURL(relativePath: relativePath)
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            filePlayers[pad.id] = player
            return player
        } catch {
            store.showStatus("Tondatei konnte nicht geladen werden: \(pad.displayLabel)")
            return nil
        }
    }

    private func previewPlayer(for pad: SoundPad, previewURL: String) -> AVPlayer? {
        if let existing = previewPlayers[pad.id] { return existing }
        guard let url = URL(string: previewURL) else { return nil }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        previewPlayers[pad.id] = player
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self, weak player] _ in
            player?.pause()
            player?.seek(to: .zero)
            Task { @MainActor [weak self] in self?.tick &+= 1 }
        }
        return player
    }

    // MARK: - Apple Music

    private func performAppleMusic(_ action: GestureAction, pad: SoundPad, songID: String) {
        Task { [weak self] in
            await self?.handleAppleMusic(action, pad: pad, songID: songID)
        }
    }

    private func handleAppleMusic(_ action: GestureAction, pad: SoundPad, songID: String) async {
        let player = ApplicationMusicPlayer.shared
        let isCurrent = appleMusicPadID == pad.id
        let playing = isCurrent && player.state.playbackStatus == .playing

        do {
            switch action {
            case .restartOrResume, .restart, .startOrReset, .resume, .toggle:
                if playing {
                    switch action {
                    case .toggle:
                        player.pause()
                    case .startOrReset:
                        player.stop()
                        appleMusicPadID = nil
                    case .restartOrResume, .restart:
                        player.restartCurrentEntry()
                    default:
                        break
                    }
                } else if isCurrent && action != .restart {
                    try await player.play()
                } else {
                    guard let song = try await song(for: songID) else {
                        store?.showStatus("Titel wurde bei Apple Music nicht gefunden.")
                        return
                    }
                    player.queue = [song]
                    try await player.play()
                    appleMusicPadID = pad.id
                }
            case .pause:
                if isCurrent { player.pause() }
            case .stopReset:
                if isCurrent {
                    player.stop()
                    appleMusicPadID = nil
                }
            case .none:
                break
            }
        } catch {
            store?.showStatus("Apple-Music-Wiedergabe nicht möglich – Anmeldung/Abo prüfen.")
        }
        tick &+= 1
    }

    private func song(for id: String) async throws -> Song? {
        if let cached = songCache[id] { return cached }
        guard await AppleMusicService.ensureAuthorized() else {
            store?.showStatus("Kein Zugriff auf Apple Music erlaubt.")
            return nil
        }
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(id))
        let response = try await request.response()
        if let song = response.items.first { songCache[id] = song }
        return response.items.first
    }

    // MARK: - Spotify

    private func openSpotify(trackID: String) {
        guard let appURL = URL(string: "spotify:track:\(trackID)") else { return }
        UIApplication.shared.open(appURL) { success in
            if !success, let webURL = URL(string: "https://open.spotify.com/track/\(trackID)") {
                UIApplication.shared.open(webURL)
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioEngine: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            player.currentTime = 0
            self?.tick &+= 1
        }
    }
}
