import Foundation
import AVFoundation
import UIKit
import AudioToolbox
import SwiftUI

// Alles rund um Ton: gemeinsame Audio-Sitzung, Lautstärkemessung über das
// Mikrofon und das Abspielen der hinterlegten Klangdateien.

// MARK: - Audio-Sitzung

/// Hält die AVAudioSession in dem Modus, den die gerade aktiven Elemente
/// brauchen: Sobald ein Lautstärke-Element misst, wird aufgenommen UND
/// abgespielt, sonst reicht reine Wiedergabe.
enum AudioSessionCenter {
    private static var recording = false

    static func configure(recording needsInput: Bool) {
        recording = needsInput
        let session = AVAudioSession.sharedInstance()
        do {
            if needsInput {
                try session.setCategory(.playAndRecord,
                                        mode: .default,
                                        options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers])
            } else {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            }
            try session.setActive(true)
        } catch {
            // Ohne Sitzung bleibt die Anzeige leer bzw. der Ton stumm —
            // die Oberfläche meldet das an der betroffenen Stelle.
        }
    }

    static var isRecording: Bool { recording }
}

// MARK: - Lautstärkemessung

/// Misst den Geräuschpegel über das Mikrofon. Eine gemeinsame Instanz für
/// die ganze App: Mehrere Lautstärke-Elemente teilen sich eine Messung.
@MainActor
final class NoiseMeter: ObservableObject {
    static let shared = NoiseMeter()

    enum Permission: Equatable {
        case unknown, granted, denied
    }

    /// Geglätteter Pegel 0 … 1.
    @Published private(set) var level: Double = 0
    /// Spitzenwert der letzten Sekunden (für die Skala).
    @Published private(set) var peak: Double = 0
    @Published private(set) var permission: Permission = .unknown
    @Published private(set) var running = false

    private let engine = AVAudioEngine()
    private var clients = 0
    private var peakDecayTask: Task<Void, Never>?

    /// Ruhepegel und Vollausschlag in Dezibel (dBFS) — passt für ein iPad,
    /// das vorn im Klassenraum steht.
    private let quietDb: Double = -52
    private let loudDb: Double = -8

    /// Die Messung war an, als die App in den Hintergrund ging.
    private var pausedByBackground = false

    private init() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: permission = .granted
        case .denied: permission = .denied
        default: permission = .unknown
        }
        observeAppState()
    }

    /// Das Mikrofon läuft nur, solange die App vorn ist.
    ///
    /// Sonst bliebe die Aufnahmeanzeige des Geräts an, während jemand längst
    /// etwas anderes tut — das will niemand, und Strom kostet es auch. Die
    /// Web-App macht es seit Fassung 1.5.4 genauso. Beim Zurückkommen läuft
    /// die Messung von selbst weiter.
    private func observeAppState() {
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                           object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.running else { return }
                self.pausedByBackground = true
                self.stop()
            }
        }
        center.addObserver(forName: UIApplication.willEnterForegroundNotification,
                           object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.pausedByBackground else { return }
                self.pausedByBackground = false
                if self.clients > 0 { self.start() }
            }
        }
    }

    /// Ein Lautstärke-Element ist auf dem Bildschirm erschienen.
    func retain() {
        clients += 1
        if clients == 1 { start() }
    }

    /// Ein Lautstärke-Element ist verschwunden.
    func release() {
        clients = max(0, clients - 1)
        if clients == 0 { stop() }
    }

    func requestPermission() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                self.permission = granted ? .granted : .denied
                if granted && self.clients > 0 { self.start() }
            }
        }
    }

    private func start() {
        guard !running else { return }
        guard AVAudioApplication.shared.recordPermission == .granted else {
            if permission == .unknown { requestPermission() }
            return
        }
        permission = .granted
        AudioSessionCenter.configure(recording: true)

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }
            var sum: Float = 0
            for index in 0..<count {
                let sample = channel[index]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(count))
            let db = 20 * log10(max(Double(rms), 0.000_001))
            Task { @MainActor [weak self] in self?.consume(db: db) }
        }

        do {
            engine.prepare()
            try engine.start()
            running = true
            startPeakDecay()
        } catch {
            running = false
        }
    }

    private func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
        level = 0
        peak = 0
        peakDecayTask?.cancel()
        AudioSessionCenter.configure(recording: false)
    }

    /// Dezibel → 0…1, mit schnellem Anstieg und langsamem Abfall.
    private func consume(db: Double) {
        let normalized = min(max((db - quietDb) / (loudDb - quietDb), 0), 1)
        let smoothing = normalized > level ? 0.55 : 0.12
        level += (normalized - level) * smoothing
        if level > peak { peak = level }
    }

    private func startPeakDecay() {
        peakDecayTask?.cancel()
        peakDecayTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, self.running else { continue }
                self.peak = max(self.level, self.peak - 0.05)
            }
        }
    }
}

// MARK: - Klangfelder

/// Spielt die Tondateien der Klang-Elemente ab.
@MainActor
final class SoundPlayer: NSObject, ObservableObject {
    static let shared = SoundPlayer()

    /// IDs der Felder, die gerade klingen (für die Hervorhebung).
    @Published private(set) var playingIDs: Set<String> = []

    private var players: [String: AVAudioPlayer] = [:]
    /// Klänge, die von einer Adresse im Netz kommen, laufen über AVPlayer —
    /// AVAudioPlayer kann nur örtliche Dateien.
    private var streams: [String: AVPlayer] = [:]
    private var streamEnds: [String: NSObjectProtocol] = [:]

    /// Spielt das Feld ab: erst die Datei auf dem Gerät, sonst den Link.
    /// `toggle` = erneutes Antippen stoppt.
    func play(_ button: SoundButton) {
        let id = button.id
        let wasPlaying = isPlaying(id)
        stop(buttonID: id)
        if wasPlaying && button.toggle { return }

        if !AudioSessionCenter.isRecording {
            AudioSessionCenter.configure(recording: false)
        }
        let volume = Float(min(max(button.volume, 0), 1))

        if let fileName = button.fileName {
            let url = MediaStore.url(fileName)
            if FileManager.default.fileExists(atPath: url.path),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.delegate = self
                player.volume = volume
                player.prepareToPlay()
                player.play()
                players[id] = player
                playingIDs.insert(id)
                return
            }
        }

        guard let address = button.url.nonEmpty, let remote = URL(string: address) else { return }
        let item = AVPlayerItem(url: remote)
        let stream = AVPlayer(playerItem: item)
        stream.volume = volume
        streamEnds[id] = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.stop(buttonID: id) }
        }
        stream.play()
        streams[id] = stream
        playingIDs.insert(id)
    }

    func stop(buttonID: String) {
        players[buttonID]?.stop()
        players[buttonID] = nil
        streams[buttonID]?.pause()
        streams[buttonID] = nil
        if let token = streamEnds[buttonID] {
            NotificationCenter.default.removeObserver(token)
            streamEnds[buttonID] = nil
        }
        playingIDs.remove(buttonID)
    }

    func stopAll() {
        for (_, player) in players { player.stop() }
        players.removeAll()
        for (_, stream) in streams { stream.pause() }
        streams.removeAll()
        for (_, token) in streamEnds { NotificationCenter.default.removeObserver(token) }
        streamEnds.removeAll()
        playingIDs.removeAll()
    }

    func isPlaying(_ buttonID: String) -> Bool { playingIDs.contains(buttonID) }

    /// Signal am Ende eines Timers.
    static func playAlarm() {
        AudioServicesPlaySystemSound(1005)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            AudioServicesPlaySystemSound(1005)
        }
    }
}

extension SoundPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            let finished = self.players.first { $0.value === player }?.key
            if let finished {
                self.players[finished] = nil
                self.playingIDs.remove(finished)
            }
        }
    }
}

// MARK: - Aufnahme

/// Nimmt kurze Ansagen direkt in der App auf (für Klangfelder).
@MainActor
final class VoiceRecorder: ObservableObject {
    @Published private(set) var recording = false
    @Published private(set) var seconds: Double = 0

    private var recorder: AVAudioRecorder?
    private var tickTask: Task<Void, Never>?
    private var url: URL?

    func start() {
        guard AVAudioApplication.shared.recordPermission == .granted else {
            AVAudioApplication.requestRecordPermission { granted in
                Task { @MainActor in if granted { self.start() } }
            }
            return
        }
        AudioSessionCenter.configure(recording: true)
        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        guard let recorder = try? AVAudioRecorder(url: target, settings: settings) else { return }
        recorder.record()
        self.recorder = recorder
        self.url = target
        recording = true
        seconds = 0
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, self.recording else { continue }
                self.seconds += 0.2
            }
        }
    }

    /// Beendet die Aufnahme und liefert die aufgenommenen Daten.
    func stop() -> Data? {
        tickTask?.cancel()
        recorder?.stop()
        recording = false
        recorder = nil
        AudioSessionCenter.configure(recording: NoiseMeter.shared.running)
        guard let url else { return nil }
        let data = try? Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        self.url = nil
        return data
    }

    func cancel() {
        _ = stop()
    }
}
