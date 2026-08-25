import Foundation
import AVFoundation

// Klänge für das Auslosen — vollständig im Gerät erzeugt, wie in der Web-App
// (`js/sfx.js`). Es gibt keine Klangdateien: Die App braucht dafür kein Netz,
// nichts wird nachgeladen, und das Bündel wird nicht größer.
//
// Grundlage ist gefiltertes Rauschen. Ein kurzer Rauschstoß klingt je nach
// Filter wie eine Karte, die über die Daumenkante läuft, wie ein Trommelschlag
// oder wie das Klacken eines Glücksrads.
//
// Die Web-App baut dafür einen Web-Audio-Graphen und lässt den Browser
// rechnen. iOS hat kein Gegenstück dazu, das ebenso beiläufig zu benutzen
// wäre — hier werden die Töne deshalb als PCM-Puffer ausgerechnet und dann
// abgespielt. Die Zahlen sind dieselben wie im Web.

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
        spiele(bauTick(klang, fortschritt: fortschritt))
    }

    /// Abschluss: Der Stapel wird aufgestoßen bzw. der Wirbel endet.
    func schluss(_ klang: SpinSound) {
        guard klang != .aus else { return }
        spiele(bauSchluss(klang))
    }

    /// Hörprobe für die Einstellungen — dieselbe Abfolge wie beim Ziehen,
    /// aber in einem Stück ausgerechnet. Das trifft die Zeiten genauer als
    /// Zeitgeber, die nebenher laufen.
    func probe(_ klang: SpinSound) {
        guard klang != .aus else { return }
        // Zwölf Schritte wie im Web — kürzer als ein echter Zug, aber lang
        // genug, um den Klang zu erkennen.
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

    /// Eine einzelne Stimme im Gemisch: entweder Rauschen oder ein Ton.
    private struct Stimme {
        enum Quelle {
            /// Gefiltertes Rauschen. `wandern` verschiebt die Filterfrequenz
            /// über die Dauer (im Web `sweep`).
            case rauschen(frequenz: Double, q: Double, art: Filterart, wandern: Double)
            case ton(frequenz: Double, art: Wellenform, biegung: Double)
        }
        var quelle: Quelle
        var dauer: Double
        var pegel: Double
        var ab: Double
    }

    fileprivate enum Filterart { case bandpass, highpass }
    private enum Wellenform { case sinus, dreieck, rechteck }

    /// Kurzer gefilterter Rauschstoß (im Web `noiseBurst`).
    private func rauschstoss(dauer: Double = 0.06, pegel: Double = 0.12,
                             frequenz: Double = 2400, q: Double = 1,
                             art: Filterart = .bandpass, ab: Double = 0,
                             wandern: Double = 0) -> Stimme {
        Stimme(quelle: .rauschen(frequenz: max(60, frequenz), q: q, art: art, wandern: wandern),
               dauer: dauer, pegel: pegel, ab: ab)
    }

    /// Kurzer Ton mit Hüllkurve (im Web `tone`) — der Körper von Trommel
    /// und Klacken.
    private func ton(frequenz: Double = 200, dauer: Double = 0.08,
                     pegel: Double = 0.08, art: Wellenform = .sinus,
                     ab: Double = 0, biegung: Double = 0) -> Stimme {
        Stimme(quelle: .ton(frequenz: frequenz, art: art, biegung: biegung),
               dauer: dauer, pegel: pegel, ab: ab)
    }

    // MARK: Die einzelnen Klangarten

    /// Karten, die über die Daumenkante laufen. Ein einzelner Rauschstoß
    /// klingt zu dünn — erst ein Bündel dicht aufeinanderfolgender Stöße
    /// ergibt das Rascheln eines Stapels, der durch die Finger läuft.
    private func kartenTick(_ fortschritt: Double, ab: Double) -> [Stimme] {
        let stoesse = fortschritt < 0.75 ? 4 : 2
        var zeit = ab
        return (0..<stoesse).map { i in
            let stimme = rauschstoss(dauer: 0.028,
                                     pegel: (0.34 - fortschritt * 0.06) * (1 - Double(i) * 0.12),
                                     frequenz: 1500 + Double.random(in: 0..<1800),
                                     q: 0.8, ab: zeit, wandern: -700)
            zeit += 0.011 + Double.random(in: 0..<0.006)
            return stimme
        }
    }

    /// Trommelwirbel: tiefe Schläge. Solange der Wirbel schnell läuft, sitzen
    /// zwei Schläge dicht beieinander — so klingt es nach Wirbel und nicht
    /// nach Klopfen.
    private func trommelTick(_ fortschritt: Double, ab: Double) -> [Stimme] {
        let schlaege = fortschritt < 0.6 ? 2 : 1
        var stimmen: [Stimme] = []
        for i in 0..<schlaege {
            let wann = ab + Double(i) * 0.028
            let daempfung = 1 - Double(i) * 0.25
            stimmen.append(rauschstoss(dauer: 0.05,
                                       pegel: (0.16 + fortschritt * 0.12) * daempfung,
                                       frequenz: 240, q: 1.3, ab: wann))
            stimmen.append(ton(frequenz: 110, dauer: 0.05,
                               pegel: (0.07 + fortschritt * 0.05) * daempfung,
                               art: .dreieck, ab: wann, biegung: -35))
        }
        return stimmen
    }

    /// Glücksrad: trockenes Klacken einer Ratsche.
    private func radTick(ab: Double) -> [Stimme] {
        [rauschstoss(dauer: 0.02, pegel: 0.42, frequenz: 3200, q: 3.5, ab: ab),
         ton(frequenz: 900, dauer: 0.02, pegel: 0.1, art: .rechteck, ab: ab, biegung: -260)]
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
            return [rauschstoss(dauer: 0.5, pegel: 0.16, frequenz: 3200, q: 0.5,
                                art: .highpass, ab: ab),
                    ton(frequenz: 90, dauer: 0.22, pegel: 0.1, art: .dreieck,
                        ab: ab, biegung: -40)]
        case .rad:
            return [rauschstoss(dauer: 0.05, pegel: 0.45, frequenz: 2600, q: 2.5, ab: ab)]
        case .karten:
            // Zwei kurze Stöße — der Stapel wird auf dem Tisch gerade geklopft.
            return [rauschstoss(dauer: 0.07, pegel: 0.34, frequenz: 900, q: 0.9, ab: ab),
                    rauschstoss(dauer: 0.09, pegel: 0.26, frequenz: 700, q: 0.9, ab: ab + 0.085)]
        }
    }

    private func bauTick(_ klang: SpinSound, fortschritt: Double) -> [Stimme] {
        tickStimmen(klang, fortschritt: fortschritt, ab: 0)
    }

    private func bauSchluss(_ klang: SpinSound) -> [Stimme] {
        schlussStimmen(klang, ab: 0)
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
        // Sicherheitshalber begrenzen: Bei den Kartenstößen liegen mehrere
        // Stimmen übereinander, das kann sonst über 1,0 gehen und knacken.
        for i in 0..<Int(rahmen) {
            ziel[i] = max(-1, min(1, ziel[i]))
        }
        return puffer
    }

    private func misch(_ stimme: Stimme, in ziel: UnsafeMutablePointer<Float>, rahmen: Int) {
        let start = Int(stimme.ab * rate)
        let dauer = Int(stimme.dauer * rate)
        guard dauer > 0, start < rahmen else { return }

        switch stimme.quelle {
        case let .rauschen(frequenz, q, art, wandern):
            var filter = Biquad()
            for n in 0..<dauer {
                let i = start + n
                if i >= rahmen { break }
                let t = Double(n) / Double(dauer)
                // Wandernde Filterfrequenz wie `exponentialRampToValueAtTime`.
                let f = wandern == 0 ? frequenz
                                     : frequenz * pow(max(60, frequenz + wandern) / frequenz, t)
                filter.stelle(art: art, frequenz: f, q: q, rate: rate)
                let roh = Double.random(in: -1...1)
                let wert = filter.rechne(roh) * huelle(t, dauer: stimme.dauer) * stimme.pegel
                ziel[i] += Float(wert)
            }

        case let .ton(frequenz, art, biegung):
            var phase = 0.0
            for n in 0..<dauer {
                let i = start + n
                if i >= rahmen { break }
                let t = Double(n) / Double(dauer)
                let f = biegung == 0 ? frequenz
                                     : frequenz * pow(max(40, frequenz + biegung) / frequenz, t)
                phase += 2 * .pi * f / rate
                if phase > 2 * .pi { phase -= 2 * .pi }
                let wert = welle(art, phase: phase) * huelle(t, dauer: stimme.dauer) * stimme.pegel
                ziel[i] += Float(wert)
            }
        }
    }

    /// Hüllkurve wie im Web: sehr schnell auf, dann exponentiell abfallend.
    /// Die Web-App rampt von 0,0001 auf den Pegel und wieder zurück — genau
    /// dieser Abfall macht den trockenen, kurzen Anschlag.
    private func huelle(_ t: Double, dauer: Double) -> Double {
        let anstieg = min(0.006 / max(dauer, 0.001), 0.5)
        let leise = 0.0001
        if t < anstieg {
            return leise * pow(1 / leise, t / anstieg)
        }
        let rest = (t - anstieg) / max(1 - anstieg, 0.0001)
        return pow(leise, rest)
    }

    private func welle(_ art: Wellenform, phase: Double) -> Double {
        switch art {
        case .sinus:
            return sin(phase)
        case .dreieck:
            return 2 / .pi * asin(sin(phase))
        case .rechteck:
            return sin(phase) >= 0 ? 1 : -1
        }
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

/// Biquad-Filter nach dem „Audio EQ Cookbook" — dasselbe, was hinter
/// `BiquadFilterNode` im Browser steckt.
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
            // Fassung mit konstantem Spitzenwert (0 dB), wie im Browser.
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
