import Foundation
import AVFoundation

// Klänge für das Auslosen — vollständig im Gerät erzeugt. Es gibt keine
// Klangdateien: Die App braucht dafür kein Netz, nichts wird nachgeladen, und
// das Bündel wird nicht größer.
//
// Diese Fassung geht bewusst NICHT mehr Zeichen für Zeichen nach der Web-App
// (`js/sfx.js`). Deren Töne schwellen in 6 Millisekunden an — für ein
// Kartenschnippen oder einen Ratschenklick ist das eine Ewigkeit. Echte
// Anschläge stehen in weniger als einer Millisekunde. Genau daran lag es,
// dass die erste Fassung „wie ein Zischen" klang und nicht wie ein Geräusch.
//
// Was stattdessen gilt:
//   * Anstieg 0,4 ms, danach exponentiell abfallend — perkussiv statt weich.
//   * Kartenmischen sind viele winzige Klicks (4 ms), nicht wenige lange
//     Rauschstöße. Erst die Dichte macht das Rascheln eines Stapels.
//   * Die Trommel hat einen Körper aus zwei Teiltönen (Fell) und darüber
//     helles Rauschen (Schnarrsaiten) — nicht nur einen dumpfen Stoß.
//   * Die Ratsche ist ein 3,5-ms-Anschlag mit holzigem Nachklang statt eines
//     20-ms-Tons, der wie ein Piepser wirkte.

/// Klang beim Ziehen — dieselben vier Möglichkeiten wie in der Web-App.
enum SpinSound: String, Codable, CaseIterable, Identifiable {
    case karten
    case trommel
    case rad
    case aus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .karten:  return "Kartenmischen"
        case .trommel: return "Trommelwirbel"
        case .rad:     return "Glücksrad"
        case .aus:     return "Ohne Ton"
        }
    }

    var hint: String {
        switch self {
        case .karten:
            return "Helles Rascheln, wie ein Kartenstapel, der durch die Finger läuft."
        case .trommel:
            return "Tiefe, schnelle Schläge, die zum Schluss lauter werden."
        case .rad:
            return "Trockenes Klacken, das mit dem Rad langsamer wird."
        case .aus:
            return "Beim Ziehen bleibt es still."
        }
    }

    var symbol: String {
        switch self {
        case .karten:  return "rectangle.on.rectangle"
        case .trommel: return "metronome"
        case .rad:     return "circle.dotted"
        case .aus:     return "speaker.slash"
        }
    }
}

// MARK: - Ablauf des Auslosens

/// Zeitmaß des Auslosens — im Web `SPIN_STEPS`, `SPIN_FAST`, `SPIN_SLOW`.
///
/// Das Ziehen läuft aus wie ein Glücksrad: erst schnell, dann immer langsamer.
enum ZiehLauf {
    static let schritte = 18
    private static let schnell = 45.0   // Millisekunden
    private static let langsam = 210.0

    /// Wartezeit vor dem nächsten Schritt, in Sekunden.
    static func pause(schritt: Int) -> Double {
        sekunden(fortschritt: fortschritt(schritt: schritt))
    }

    /// 0 beim ersten, 1 beim letzten Schritt.
    static func fortschritt(schritt: Int) -> Double {
        guard schritte > 1 else { return 1 }
        return Double(schritt) / Double(schritte - 1)
    }

    private static func sekunden(fortschritt: Double) -> Double {
        (schnell + pow(fortschritt, 2.4) * (langsam - schnell)) / 1000
    }
}

// MARK: - Klangerzeugung

/// Spielt die Ziehklänge. Eine gemeinsame Instanz für die ganze App.
@MainActor
final class Ziehklang {
    static let shared = Ziehklang()

    private let rate = 44_100.0
    private let motor = AVAudioEngine()
    private let spieler = AVAudioPlayerNode()
    private var bereit = false

    private init() {}

    /// Ein Schritt des Auslosens. `fortschritt` läuft von 0 bis 1.
    func tick(_ klang: SpinSound, fortschritt: Double) {
        guard klang != .aus else { return }
        spiele(tickStimmen(klang, fortschritt: fortschritt, ab: 0))
    }

    /// Abschluss: Der Stapel wird aufgestoßen bzw. der Wirbel endet.
    func schluss(_ klang: SpinSound) {
        guard klang != .aus else { return }
        spiele(schlussStimmen(klang, ab: 0))
    }

    /// Hörprobe für die Einstellungen — dieselbe Abfolge wie beim Ziehen,
    /// aber in einem Stück ausgerechnet. Das trifft die Zeiten genauer als
    /// Zeitgeber, die nebenher laufen.
    func probe(_ klang: SpinSound) {
        guard klang != .aus else { return }
        // Zwölf Schritte — kürzer als ein echter Zug, aber lang genug, um
        // den Klang zu erkennen.
        let schritte = 12
        var stimmen: [Stimme] = []
        var zeit = 0.0
        for i in 0..<schritte {
            let fortschritt = schritte > 1 ? Double(i) / Double(schritte - 1) : 1
            stimmen += tickStimmen(klang, fortschritt: fortschritt, ab: zeit)
            zeit += (45 + pow(fortschritt, 2.4) * 165) / 1000
        }
        stimmen += schlussStimmen(klang, ab: zeit)
        spiele(stimmen)
    }

    // MARK: Bausteine

    /// Eine Stimme im Gemisch: gefiltertes Rauschen oder eine gedämpfte
    /// Schwingung. Beide mit perkussiver Hüllkurve.
    private struct Stimme {
        enum Quelle {
            /// Gefiltertes Rauschen — das Geräuschhafte am Anschlag.
            case rauschen(filter: Filterart, frequenz: Double, q: Double)
            /// Gedämpfte Schwingung — der Körper. `biegung` zieht die
            /// Tonhöhe über die Dauer nach unten (wie ein Fell, das nachgibt).
            case resonanz(frequenz: Double, biegung: Double)
        }
        var quelle: Quelle
        var dauer: Double
        var pegel: Double
        var ab: Double
        /// Anstiegszeit. 0,4 ms — kürzer als jedes Ohr auflöst, also ein
        /// Anschlag und kein Anschwellen.
        var anstieg: Double = 0.0004
    }

    fileprivate enum Filterart { case bandpass, highpass }

    private func rauschen(_ dauer: Double, _ pegel: Double, filter: Filterart,
                          frequenz: Double, q: Double, ab: Double,
                          anstieg: Double = 0.0004) -> Stimme {
        Stimme(quelle: .rauschen(filter: filter, frequenz: frequenz, q: q),
               dauer: dauer, pegel: pegel, ab: ab, anstieg: anstieg)
    }

    private func resonanz(_ frequenz: Double, _ dauer: Double, _ pegel: Double,
                          biegung: Double = 0, ab: Double) -> Stimme {
        Stimme(quelle: .resonanz(frequenz: frequenz, biegung: biegung),
               dauer: dauer, pegel: pegel, ab: ab, anstieg: 0.0003)
    }

    // MARK: Die einzelnen Klangarten

    /// Kartenstapel, der durch die Finger läuft: viele winzige Klicks.
    /// Ein einzelner langer Rauschstoß klingt wie Zischen — erst die Dichte
    /// vieler kurzer Anschläge ergibt das Rascheln. Gegen Ende läuft der
    /// Stapel langsamer, also kommen weniger Klicks.
    private func kartenTick(_ fortschritt: Double, ab: Double) -> [Stimme] {
        let anzahl = max(2, Int(9 - fortschritt * 5))
        var stimmen: [Stimme] = []
        var zeit = ab
        for _ in 0..<anzahl {
            stimmen.append(rauschen(0.004 + Double.random(in: 0..<0.004),
                                    (0.5 - fortschritt * 0.1) * Double.random(in: 0.7..<1.2),
                                    filter: .highpass,
                                    frequenz: 1400 + Double.random(in: 0..<1400),
                                    q: 0.7, ab: zeit))
            zeit += 0.0022 + Double.random(in: 0..<0.0035)
        }
        return stimmen
    }

    /// Ein Schlag auf die kleine Trommel: Fell (zwei Teiltöne, die absacken)
    /// und darüber die Schnarrsaiten als helles Rauschen.
    private func trommelSchlag(_ pegel: Double, ab: Double) -> [Stimme] {
        [resonanz(188, 0.075, 0.16 * pegel, biegung: -0.22, ab: ab),
         resonanz(331, 0.045, 0.09 * pegel, biegung: -0.25, ab: ab),
         rauschen(0.085, 0.34 * pegel, filter: .highpass, frequenz: 1600, q: 0.6, ab: ab)]
    }

    /// Wirbel: mehrere Schläge dicht hintereinander, gegen Ende lauter.
    private func trommelTick(_ fortschritt: Double, ab: Double) -> [Stimme] {
        let schlaege = fortschritt < 0.55 ? 3 : 2
        var stimmen: [Stimme] = []
        for i in 0..<schlaege {
            let wann = ab + Double(i) * (0.026 + Double.random(in: 0..<0.008))
            let pegel = (0.55 + fortschritt * 0.6) * (1 - Double(i) * 0.18)
                * Double.random(in: 0.85..<1.15)
            stimmen += trommelSchlag(pegel, ab: wann)
        }
        return stimmen
    }

    /// Ratsche: ein sehr kurzer Anschlag mit holzigem Nachklang.
    private func radTick(ab: Double) -> [Stimme] {
        [rauschen(0.0035, 0.55, filter: .highpass, frequenz: 3000, q: 0.7, ab: ab),
         resonanz(1450 + Double.random(in: 0..<260), 0.016, 0.20, biegung: -0.3, ab: ab),
         resonanz(520, 0.028, 0.12, biegung: -0.15, ab: ab)]
    }

    private func tickStimmen(_ klang: SpinSound, fortschritt: Double, ab: Double) -> [Stimme] {
        switch klang {
        case .aus:     return []
        case .trommel: return trommelTick(fortschritt, ab: ab)
        case .rad:     return radTick(ab: ab)
        case .karten:  return kartenTick(fortschritt, ab: ab)
        }
    }

    private func schlussStimmen(_ klang: SpinSound, ab: Double) -> [Stimme] {
        switch klang {
        case .aus:
            return []
        case .trommel:
            // Letzter Schlag und ein Becken, das ausklingt.
            return trommelSchlag(1.5, ab: ab)
                + [rauschen(0.9, 0.30, filter: .highpass, frequenz: 4200, q: 0.5,
                            ab: ab, anstieg: 0.001)]
        case .rad:
            return radTick(ab: ab) + [resonanz(900, 0.12, 0.16, biegung: -0.1, ab: ab)]
        case .karten:
            // Der Stapel wird auf dem Tisch gerade geklopft — drei Schläge.
            return (0..<3).map { i in
                rauschen(0.03, 0.45 - Double(i) * 0.1, filter: .bandpass,
                         frequenz: 700, q: 1.1, ab: ab + Double(i) * 0.055)
            }
        }
    }

    // MARK: Ausrechnen und abspielen

    private func spiele(_ stimmen: [Stimme]) {
        guard !stimmen.isEmpty, let puffer = rechne(stimmen) else { return }
        guard starteMotor() else { return }
        spieler.scheduleBuffer(puffer, at: nil, options: [])
        if !spieler.isPlaying { spieler.play() }
    }

    /// Mischt alle Stimmen in einen Puffer.
    private func rechne(_ stimmen: [Stimme]) -> AVAudioPCMBuffer? {
        // Etwas Luft am Ende, damit nichts abgeschnitten klingt.
        let laenge = (stimmen.map { $0.ab + $0.dauer }.max() ?? 0) + 0.05
        let rahmen = AVAudioFrameCount(laenge * rate)
        guard rahmen > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let puffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: rahmen),
              let ziel = puffer.floatChannelData?[0]
        else { return nil }
        puffer.frameLength = rahmen
        for i in 0..<Int(rahmen) { ziel[i] = 0 }

        for stimme in stimmen {
            misch(stimme, in: ziel, rahmen: Int(rahmen))
        }
        // Begrenzen: Bei den Kartenklicks liegen mehrere Stimmen übereinander,
        // das kann sonst über 1,0 gehen und knacken.
        for i in 0..<Int(rahmen) {
            ziel[i] = max(-1, min(1, ziel[i]))
        }
        return puffer
    }

    private func misch(_ stimme: Stimme, in ziel: UnsafeMutablePointer<Float>, rahmen: Int) {
        let start = Int(stimme.ab * rate)
        let dauer = Int(stimme.dauer * rate)
        guard dauer > 0, start < rahmen else { return }
        let anstieg = max(Int(stimme.anstieg * rate), 1)

        switch stimme.quelle {
        case let .rauschen(filter, frequenz, q):
            var werk = Biquad()
            werk.stelle(art: filter, frequenz: frequenz, q: q, rate: rate)
            for n in 0..<dauer {
                let i = start + n
                if i >= rahmen { break }
                let wert = werk.rechne(Double.random(in: -1...1))
                    * huelle(n, anstieg: anstieg, dauer: dauer, faktor: 5)
                    * stimme.pegel
                ziel[i] += Float(wert)
            }

        case let .resonanz(frequenz, biegung):
            var phase = 0.0
            for n in 0..<dauer {
                let i = start + n
                if i >= rahmen { break }
                let t = Double(n) / Double(dauer)
                phase += 2 * .pi * (frequenz * (1 + biegung * t)) / rate
                let wert = sin(phase)
                    * huelle(n, anstieg: anstieg, dauer: dauer, faktor: 6)
                    * stimme.pegel
                ziel[i] += Float(wert)
            }
        }
    }

    /// Hüllkurve eines Anschlags: in `anstieg` Abtastwerten linear hoch,
    /// danach exponentiell abfallend.
    private func huelle(_ n: Int, anstieg: Int, dauer: Int, faktor: Double) -> Double {
        if n < anstieg { return Double(n) / Double(anstieg) }
        return exp(-faktor * Double(n - anstieg) / Double(max(dauer - anstieg, 1)))
    }

    private func starteMotor() -> Bool {
        if bereit && motor.isRunning { return true }
        // Nur Wiedergabe anmelden — misst gerade ein Lautstärke-Element,
        // lässt `configure` die Aufnahme stehen.
        AudioSessionCenter.configure(recording: AudioSessionCenter.isRecording)
        if !bereit {
            motor.attach(spieler)
            guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)
            else { return false }
            motor.connect(spieler, to: motor.mainMixerNode, format: format)
            bereit = true
        }
        do {
            if !motor.isRunning { try motor.start() }
        } catch {
            // Ton ist Beiwerk: Spielt das Gerät ihn nicht, läuft das
            // Auslosen trotzdem weiter.
            return false
        }
        return true
    }
}

// MARK: - Filter

/// Biquad-Filter nach dem „Audio EQ Cookbook".
private struct Biquad {
    private var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    mutating func stelle(art: Ziehklang.Filterart, frequenz: Double, q: Double, rate: Double) {
        let w0 = 2 * Double.pi * min(max(frequenz, 20), rate / 2 - 100) / rate
        let cos0 = cos(w0), sin0 = sin(w0)
        let alpha = sin0 / (2 * max(q, 0.0001))
        let a0: Double
        switch art {
        case .bandpass:
            b0 = alpha; b1 = 0; b2 = -alpha
            a0 = 1 + alpha; a1 = -2 * cos0; a2 = 1 - alpha
        case .highpass:
            b0 = (1 + cos0) / 2; b1 = -(1 + cos0); b2 = (1 + cos0) / 2
            a0 = 1 + alpha; a1 = -2 * cos0; a2 = 1 - alpha
        }
        b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0
    }

    mutating func rechne(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x
        y2 = y1; y1 = y
        return y
    }
}
