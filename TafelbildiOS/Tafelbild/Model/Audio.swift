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

    /// Geglätteter Pegel 0 … 1 (für das Band).
    @Published private(set) var level: Double = 0
    /// Geschätzter Schalldruckpegel in dB(A).
    ///
    /// Das Mikrofon eines iPads ist kein geeichter Schallpegelmesser: Es
    /// liefert nur einen Pegel bezogen auf die Vollaussteuerung (dBFS).
    /// Daraus wird hier ein Schätzwert, indem ein fester Abgleich addiert
    /// wird — die Vorgabe 95 trifft ein iPad, das vorn im Klassenraum steht,
    /// gut genug für eine Ampel. Wer es genauer haben will, gleicht mit einer
    /// Schallpegel-App ab (Einstellungen des Elements).
    @Published private(set) var dezibel: Double = NoiseSkala.leise
    /// Spitzenwert der letzten Sekunden (für die Skala).
    @Published private(set) var peak: Double = 0
    @Published private(set) var permission: Permission = .unknown
    @Published private(set) var running = false

    private let engine = AVAudioEngine()
    private var clients = 0
    private var peakDecayTask: Task<Void, Never>?

    /// Abgleich zwischen Mikrofonpegel (dBFS) und geschätztem
    /// Schalldruckpegel: dB(A) ≈ dBFS + Abgleich.
    @Published var abgleich: Double = NoiseMeter.gespeicherterAbgleich {
        didSet {
            let sauber = min(max(abgleich, NoiseSkala.abgleichMin), NoiseSkala.abgleichMax)
            if sauber != abgleich { abgleich = sauber; return }
            UserDefaults.standard.set(abgleich, forKey: Self.abgleichSchluessel)
        }
    }

    private static let abgleichSchluessel = "noiseAbgleichDb"

    private static var gespeicherterAbgleich: Double {
        let wert = UserDefaults.standard.object(forKey: abgleichSchluessel) as? Double
        return wert ?? NoiseSkala.abgleichVorgabe
    }

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
        dezibel = NoiseSkala.leise
        peakDecayTask?.cancel()
        AudioSessionCenter.configure(recording: false)
    }

    /// Mikrofonpegel → geschätzte dB(A) und Bandausschlag 0…1.
    ///
    /// Geglättet wird in Dezibel, nicht im Ausschlag: Lautstärke wird
    /// logarithmisch empfunden, und nur so bleibt die Zahl ruhig. Anstieg
    /// schnell, Abfall langsam — ein kurzer Ausruf soll sichtbar sein, das
    /// Zurückfallen aber nicht flackern.
    private func consume(db: Double) {
        let geschaetzt = min(max(db + abgleich, NoiseSkala.stille), NoiseSkala.schmerz)
        let smoothing = geschaetzt > dezibel ? 0.55 : 0.12
        dezibel += (geschaetzt - dezibel) * smoothing
        level = NoiseSkala.ausschlag(dezibel)
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

    /// Wie weit ist das Feld durchgelaufen? 0 … 1.
    ///
    /// nil, solange nichts läuft oder die Länge nicht feststeht — bei einem
    /// Klang aus dem Netz weiß man sie erst, wenn genug geladen ist.
    func fortschritt(_ buttonID: String) -> Double? {
        if let spieler = players[buttonID] {
            guard spieler.duration > 0 else { return nil }
            return min(1, max(0, spieler.currentTime / spieler.duration))
        }
        if let strom = streams[buttonID], let stueck = strom.currentItem {
            let dauer = stueck.duration.seconds
            guard dauer.isFinite, dauer > 0 else { return nil }
            return min(1, max(0, stueck.currentTime().seconds / dauer))
        }
        return nil
    }

    /// Wie lange läuft es noch? In Sekunden.
    func restzeit(_ buttonID: String) -> Double? {
        if let spieler = players[buttonID] {
            guard spieler.duration > 0 else { return nil }
            return max(0, spieler.duration - spieler.currentTime)
        }
        if let strom = streams[buttonID], let stueck = strom.currentItem {
            let dauer = stueck.duration.seconds
            guard dauer.isFinite, dauer > 0 else { return nil }
            return max(0, dauer - stueck.currentTime().seconds)
        }
        return nil
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

    // MARK: Signal am Ende eines Timers

    /// Der laufende Endklang. Muss festgehalten werden: Ein `AVAudioPlayer`,
    /// den niemand hält, wird abgeräumt und verstummt mitten im Ton.
    private var wecker: AVAudioPlayer?

    /// Signal am Ende eines Timers — der eingestellte Klang.
    ///
    /// Drei Stufen, jede mit einem Rückfall auf die nächste: die eigene
    /// Datei, der mitgelieferte Klang, zuletzt der Systemton. Ton ist
    /// Beiwerk; fehlt eine Datei, soll der Timer trotzdem Bescheid geben.
    func spieleEndklang(_ inhalt: TimerContent) {
        let klang = Endklang.aus(inhalt.endklang)

        let lautstaerke = Float(min(max(inhalt.endklangLautstaerke, 0), 1))

        if klang == .eigener, let name = inhalt.endklangDatei {
            let adresse = MediaStore.url(name)
            if FileManager.default.fileExists(atPath: adresse.path),
               starte(adresse, lautstaerke: lautstaerke) {
                return
            }
        }

        if let datei = klang.datei,
           let adresse = Bundle.main.url(forResource: datei, withExtension: "wav"),
           starte(adresse, lautstaerke: lautstaerke) {
            return
        }

        // Der Systemton lässt sich nicht in der Lautstärke stellen — er ist
        // ohnehin nur der letzte Rückfall, wenn keine Datei zu finden war.
        Self.systemton()
    }

    /// Hörprobe in den Einstellungen.
    func probeEndklang(_ inhalt: TimerContent) { spieleEndklang(inhalt) }

    private func starte(_ adresse: URL, lautstaerke: Float) -> Bool {
        if !AudioSessionCenter.isRecording {
            AudioSessionCenter.configure(recording: false)
        }
        guard let spieler = try? AVAudioPlayer(contentsOf: adresse) else { return false }
        wecker?.stop()
        spieler.volume = lautstaerke
        spieler.prepareToPlay()
        guard spieler.play() else { return false }
        wecker = spieler
        return true
    }

    /// Der Systemton von früher — jetzt nur noch als letzter Rückfall.
    private static func systemton() {
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

// MARK: - Klang einer Feier

/// Spielt die Klänge einer Geburtstagsfeier — mehrere nacheinander, mit
/// Verzögerung.
///
/// Eigene Spieler je Klang, weil sie sich überlappen sollen: Der Applaus
/// setzt ein, während der Tusch noch ausklingt. Ein einzelner Spieler
/// schnitte den vorigen ab.
@MainActor
enum Feierklang {
    /// Was gerade läuft — festgehalten, damit die Spieler nicht mitten im
    /// Ton abgeräumt werden.
    private static var spieler: [AVAudioPlayer] = []
    private static var geplant: [Task<Void, Never>] = []

    static func spiele(_ art: Feierart) {
        stoppe()
        if !AudioSessionCenter.isRecording {
            AudioSessionCenter.configure(recording: false)
        }
        for klang in art.klaenge {
            if klang.nach <= 0 {
                starte(klang.datei)
            } else {
                geplant.append(Task { @MainActor in
                    try? await Task.sleep(for: .seconds(klang.nach))
                    guard !Task.isCancelled else { return }
                    starte(klang.datei)
                })
            }
        }
    }

    static func stoppe() {
        for auftrag in geplant { auftrag.cancel() }
        geplant.removeAll()
        for wer in spieler { wer.stop() }
        spieler.removeAll()
    }

    private static func starte(_ datei: String) {
        guard let adresse = Bundle.main.url(forResource: datei, withExtension: "wav"),
              let wer = try? AVAudioPlayer(contentsOf: adresse) else { return }
        wer.prepareToPlay()
        wer.play()
        spieler.append(wer)
    }
}

// MARK: - Maßstab der Lautstärkemessung

/// Was in einer Grundschulklasse laut ist — und ab wann es zu laut wird.
///
/// Die Zahlen stammen nicht aus dem Gefühl, sondern aus der Fachliteratur:
///
/// * **Stillarbeit** liegt selbst in einer ruhigen Klasse bei mindestens
///   50 dB(A) — völlige Stille gibt es in einem Raum mit 25 Kindern nicht.
/// * **Unterrichtsgespräch und Gruppenarbeit** werden mit 70 bis 75 dB(A)
///   gemessen (Lärmforscher Peter Becker; das entspricht einem Staubsauger
///   im selben Zimmer). Andere Erhebungen nennen im Mittel 60 bis 70 dB(A),
///   in Grundschulen eher das obere Ende.
/// * **Über 80 dB(A)** gelten als Extremsituation.
/// * **Ab 85 dB(A)** drohen bei Dauerbelastung Gehörschäden; die
///   Auslösewerte der Lärm- und Vibrations-Arbeitsschutzverordnung liegen
///   bei 80 und 85 dB(A) für einen Achtstundentag. In Schulen werden sie im
///   Tagesmittel meist nicht erreicht — der Lärm wirkt dort vor allem als
///   Störung und Stress, nicht als Gehörgefahr.
/// * Zum Vergleich: Die Arbeitsstättenregel ASR A3.7 lässt für
///   **Hintergrundgeräusche** technischer Geräte im Klassenraum höchstens
///   35 dB(A) zu.
///
/// Daraus folgen die Vorgaben dieser App: Das Band reicht von 40 bis
/// 90 dB(A), und „zu laut“ beginnt bei 75 dB(A) — dem oberen Rand dessen,
/// was bei Gruppenarbeit normal ist. Vorher stand die Schwelle rechnerisch
/// bei etwa 67 dB(A) und schlug damit schon beim gewöhnlichen
/// Unterrichtsgespräch an.
enum NoiseSkala {
    /// Anfang und Ende des Bandes in dB(A).
    static let leise: Double = 40
    static let laut: Double = 90
    /// Grenzen, in denen sich der Messwert bewegen darf.
    static let stille: Double = 25
    static let schmerz: Double = 110

    /// Abgleich zwischen dBFS und geschätztem Schalldruckpegel.
    static let abgleichVorgabe: Double = 95
    static let abgleichMin: Double = 80
    static let abgleichMax: Double = 110

    /// Wo die Schwelle stehen darf.
    static let schwelleMin: Double = 50
    static let schwelleMax: Double = 90
    /// Vorgabe: oberer Rand dessen, was bei Gruppenarbeit üblich ist.
    static let schwelleVorgabe: Double = 75

    static func ausschlag(_ dezibel: Double) -> Double {
        min(max((dezibel - leise) / (laut - leise), 0), 1)
    }

    /// Fertige Schwellen für die Arbeitsformen des Unterrichts.
    struct Vorschlag: Identifiable {
        let id: String
        let titel: String
        let dezibel: Double
        let hinweis: String
    }

    static let vorschlaege: [Vorschlag] = [
        Vorschlag(id: "still", titel: "Stillarbeit", dezibel: 58,
                  hinweis: "Auch ruhige Klassen liegen bei 50 dB und mehr."),
        Vorschlag(id: "partner", titel: "Partnerarbeit", dezibel: 66,
                  hinweis: "Gespräch zu zweit, ohne die Nachbarn zu übertönen."),
        Vorschlag(id: "gruppe", titel: "Gruppenarbeit", dezibel: 75,
                  hinweis: "Üblich sind 70 bis 75 dB — darüber wird es Krach."),
        Vorschlag(id: "krach", titel: "Nur bei Krach", dezibel: 84,
                  hinweis: "Erst über 80 dB, also in Extremsituationen.")
    ]
}
