import Foundation
@preconcurrency import AVFoundation
import Speech

/// Diktieren in den Tagebuchtext.
///
/// **Zwei Motoren, und welcher läuft, steht in der Oberfläche:**
/// * **Ab iOS 26 `SpeechAnalyzer` mit `SpeechTranscriber`** — Apples neues
///   Sprachmodell, das mit der Tastatur-Diktierfunktion nichts mehr zu tun
///   hat: auf dem Gerät, ohne Zeitgrenze, für lange Sätze gebaut. Das Modell
///   lädt iOS beim ersten Mal herunter.
/// * **Davor `SFSpeechRecognizer`** — die ältere Erkennung, auf dem Gerät,
///   wo das geht, damit es keine Minutengrenze gibt.
///
/// **Was beide bekommen, und was die Tastatur nicht kann: die Orte des
/// Tages als Hinweise.** Die häufigsten Fehler in einem Reisetagebuch sind
/// Ortsnamen — „Alfama", „Sintra", „Hallstatt". Stehen sie als erwartete
/// Wörter in der Anfrage, trifft die Erkennung sie deutlich öfter.
///
/// Fremde Dienste (Whisper u. ä.) sind NICHT gebaut: Sie brauchen einen
/// Schlüssel und schicken jede Aufnahme vom Gerät — für ein privates
/// Tagebuch die falsche Voreinstellung. Wer es trotzdem will, sagt es.
@MainActor
final class Diktat: ObservableObject {
    @Published private(set) var laeuft = false
    @Published private(set) var bereitet = false
    /// Was gerade gehört wird, noch nicht fest.
    @Published private(set) var zwischentext = ""
    @Published var fehler: String?

    /// Wohin der feste Text geht.
    var anhaengen: (String) -> Void = { _ in }

    private let mikrofon = Mikrofon()
    private var neu: AnyObject?
    private var alt: AlteErkennung?

    var motor: String {
        if #available(iOS 26.0, *) { return "Apples neue Spracherkennung, auf dem Gerät" }
        return "Apples Spracherkennung"
    }

    func umschalten(hinweise: [String]) async {
        if laeuft { await stoppen() } else { await starten(hinweise: hinweise) }
    }

    func starten(hinweise: [String]) async {
        fehler = nil
        guard await Self.erlaubnis() else {
            fehler = "Mikrofon oder Spracherkennung sind nicht erlaubt — in den iOS-Einstellungen unter Fernweh änderbar."
            return
        }
        bereitet = true
        defer { bereitet = false }
        let hinweise = Array(Set(hinweise.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })).prefix(80)
        do {
            if #available(iOS 26.0, *) {
                let erkennung = NeueErkennung()
                try await erkennung.starten(hinweise: Array(hinweise), mikrofon: mikrofon,
                                            zwischen: { [weak self] t in Task { @MainActor in self?.zwischentext = t } },
                                            fest: { [weak self] t in Task { @MainActor in self?.festHinzu(t) } })
                neu = erkennung
            } else {
                let erkennung = AlteErkennung()
                try erkennung.starten(hinweise: Array(hinweise), mikrofon: mikrofon,
                                      zwischen: { [weak self] t in Task { @MainActor in self?.zwischentext = t } })
                alt = erkennung
            }
            laeuft = true
        } catch {
            mikrofon.anhalten()
            fehler = "Diktieren nicht möglich: \(error.localizedDescription)"
        }
    }

    func stoppen() async {
        guard laeuft else { return }
        laeuft = false
        if #available(iOS 26.0, *), let erkennung = neu as? NeueErkennung {
            await erkennung.stoppen(mikrofon: mikrofon)
        }
        if let alt {
            // Die alte Erkennung liefert den ganzen Text am Stück; was
            // zuletzt zu hören war, ist das Ergebnis.
            let text = await alt.stoppen(mikrofon: mikrofon)
            festHinzu(text.isEmpty ? zwischentext : text)
        }
        neu = nil
        alt = nil
        zwischentext = ""
    }

    private func festHinzu(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        zwischentext = ""
        guard !t.isEmpty else { return }
        anhaengen(t)
    }

    private static func erlaubnis() async -> Bool {
        let mikro = await AVAudioApplication.requestRecordPermission()
        guard mikro else { return false }
        let sprache: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { fortsetzung in
            SFSpeechRecognizer.requestAuthorization { fortsetzung.resume(returning: $0) }
        }
        return sprache == .authorized
    }
}

/// Das Mikrofon: liefert Puffer an genau einen Abnehmer.
final class Mikrofon: @unchecked Sendable {
    private let maschine = AVAudioEngine()

    var format: AVAudioFormat { maschine.inputNode.outputFormat(forBus: 0) }

    func starten(_ abnehmer: @escaping (AVAudioPCMBuffer) -> Void) throws {
        let sitzung = AVAudioSession.sharedInstance()
        try sitzung.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try sitzung.setActive(true, options: .notifyOthersOnDeactivation)
        let eingang = maschine.inputNode
        eingang.removeTap(onBus: 0)
        eingang.installTap(onBus: 0, bufferSize: 4096, format: eingang.outputFormat(forBus: 0)) { puffer, _ in
            abnehmer(puffer)
        }
        maschine.prepare()
        try maschine.start()
    }

    func anhalten() {
        maschine.inputNode.removeTap(onBus: 0)
        maschine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Ab iOS 26

@available(iOS 26.0, *)
final class NeueErkennung: @unchecked Sendable {
    enum Fehler: LocalizedError {
        case sprache, format
        var errorDescription: String? {
            switch self {
            case .sprache: return "Deutsch wird von der neuen Spracherkennung auf diesem Gerät nicht unterstützt."
            case .format: return "Das Audioformat der Spracherkennung ließ sich nicht bestimmen."
            }
        }
    }

    private var analyse: SpeechAnalyzer?
    private var eingabe: AsyncStream<AnalyzerInput>.Continuation?
    private var ergebnisse: Task<Void, Never>?

    func starten(hinweise: [String], mikrofon: Mikrofon,
                 zwischen: @escaping (String) -> Void, fest: @escaping (String) -> Void) async throws {
        guard let sprache = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "de-DE")) else {
            throw Fehler.sprache
        }
        let umschrift = SpeechTranscriber(locale: sprache,
                                          transcriptionOptions: [],
                                          reportingOptions: [.volatileResults],
                                          attributeOptions: [])
        // Das Sprachmodell liegt nicht immer schon auf dem Gerät.
        if let laden = try await AssetInventory.assetInstallationRequest(supporting: [umschrift]) {
            try await laden.downloadAndInstall()
        }
        let analyse = SpeechAnalyzer(modules: [umschrift])
        guard let zielformat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [umschrift]) else {
            throw Fehler.format
        }
        if !hinweise.isEmpty {
            let kontext = AnalysisContext()
            kontext.contextualStrings[.general] = hinweise
            try? await analyse.setContext(kontext)
        }

        let (folge, eingabe) = AsyncStream.makeStream(of: AnalyzerInput.self)
        self.analyse = analyse
        self.eingabe = eingabe

        ergebnisse = Task {
            do {
                for try await ergebnis in umschrift.results {
                    let text = String(ergebnis.text.characters)
                    if ergebnis.isFinal { fest(text) } else { zwischen(text) }
                }
            } catch {}
        }
        try await analyse.start(inputSequence: folge)

        guard let wandler = AVAudioConverter(from: mikrofon.format, to: zielformat) else { throw Fehler.format }
        try mikrofon.starten { puffer in
            let verhaeltnis = zielformat.sampleRate / puffer.format.sampleRate
            let platz = AVAudioFrameCount(Double(puffer.frameLength) * verhaeltnis) + 16
            guard let aus = AVAudioPCMBuffer(pcmFormat: zielformat, frameCapacity: platz) else { return }
            var gegeben = false
            var fehler: NSError?
            wandler.convert(to: aus, error: &fehler) { _, zustand in
                if gegeben {
                    zustand.pointee = .noDataNow
                    return nil
                }
                gegeben = true
                zustand.pointee = .haveData
                return puffer
            }
            if fehler == nil, aus.frameLength > 0 { eingabe.yield(AnalyzerInput(buffer: aus)) }
        }
    }

    func stoppen(mikrofon: Mikrofon) async {
        mikrofon.anhalten()
        eingabe?.finish()
        try? await analyse?.finalizeAndFinishThroughEndOfInput()
        await ergebnisse?.value
    }
}

// MARK: - Vor iOS 26

final class AlteErkennung: @unchecked Sendable {
    enum Fehler: LocalizedError {
        case nichtVerfuegbar
        var errorDescription: String? { "Die Spracherkennung ist gerade nicht verfügbar." }
    }

    private var anfrage: SFSpeechAudioBufferRecognitionRequest?
    private var aufgabe: SFSpeechRecognitionTask?
    private var letzter = ""
    private var ende: CheckedContinuation<String, Never>?
    private let sperre = NSLock()

    func starten(hinweise: [String], mikrofon: Mikrofon, zwischen: @escaping (String) -> Void) throws {
        guard let erkenner = SFSpeechRecognizer(locale: Locale(identifier: "de-DE")), erkenner.isAvailable else {
            throw Fehler.nichtVerfuegbar
        }
        let anfrage = SFSpeechAudioBufferRecognitionRequest()
        anfrage.shouldReportPartialResults = true
        anfrage.addsPunctuation = true
        anfrage.taskHint = .dictation
        anfrage.contextualStrings = hinweise
        // Auf dem Gerät gibt es keine Minutengrenze.
        if erkenner.supportsOnDeviceRecognition { anfrage.requiresOnDeviceRecognition = true }
        self.anfrage = anfrage
        aufgabe = erkenner.recognitionTask(with: anfrage) { [weak self] ergebnis, fehler in
            guard let self else { return }
            if let ergebnis {
                let text = ergebnis.bestTranscription.formattedString
                self.sperre.lock(); self.letzter = text; self.sperre.unlock()
                zwischen(text)
            }
            if fehler != nil || (ergebnis?.isFinal ?? false) { self.beenden() }
        }
        try mikrofon.starten { puffer in anfrage.append(puffer) }
    }

    private func beenden() {
        sperre.lock()
        let f = ende
        ende = nil
        let text = letzter
        sperre.unlock()
        f?.resume(returning: text)
    }

    func stoppen(mikrofon: Mikrofon) async -> String {
        mikrofon.anhalten()
        return await withCheckedContinuation { fortsetzung in
            sperre.lock()
            ende = fortsetzung
            sperre.unlock()
            anfrage?.endAudio()
            // Spätestens nach zwei Sekunden gilt, was bis dahin da ist.
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.aufgabe?.finish()
                self?.beenden()
            }
        }
    }
}
