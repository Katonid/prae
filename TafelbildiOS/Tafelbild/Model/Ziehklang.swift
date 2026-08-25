import Foundation
import AVFoundation

// Klänge für das Auslosen — echte Aufnahmen, keine Synthese.
//
// Zwei Anläufe davor rechneten die Klänge im Gerät aus, erst nach dem Vorbild
// der Web-App (`js/sfx.js`), dann mit deutlich schärferen Anschlägen. Beides
// klang synthetisch. Gefiltertes Rauschen ergibt kein Kartenmischen; ein
// Kartenstapel hat hundert kleine Eigenheiten, die sich nicht nachrechnen
// lassen.
//
// Jetzt liegen drei Aufnahmen im Bündel (Ordner `Klaenge/`), alle unter
// CC0 — Herkunft und Lizenz stehen in `Klaenge/Klaenge-Lizenz.md`. Geholt und
// zugeschnitten werden sie von `TafelbildiOS/scripts/fetch-sounds.py`.
//
// Damit ändert sich auch, WANN gespielt wird: Früher stieß die App bei jedem
// der 18 Schritte einen kurzen Ton an. Ein Mischgeräusch ist aber
// zusammenhängend — jetzt läuft eine Aufnahme über den ganzen Zug, passend
// auf dessen 1,72 Sekunden geschnitten. Der Abschluss kommt genau dann, wenn
// der Name steht.

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
            return "Ein echter Kartenstapel, der durch die Finger läuft."
        case .trommel:
            return "Ein Wirbel auf der kleinen Trommel, mit Schlag am Ende."
        case .rad:
            return "Das Klacken einer Ratsche, das mit dem Rad langsamer wird."
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

    /// Dateiname im Bündel — nil bei „Ohne Ton".
    var datei: String? {
        switch self {
        case .aus:     return nil
        case .karten:  return "zieh-karten"
        case .trommel: return "zieh-trommel"
        case .rad:     return "zieh-rad"
        }
    }
}

// MARK: - Ablauf des Auslosens

/// Zeitmaß des Auslosens — im Web `SPIN_STEPS`, `SPIN_FAST`, `SPIN_SLOW`.
///
/// Das Ziehen läuft aus wie ein Glücksrad: erst schnell, dann immer langsamer.
/// Insgesamt 1,72 s — genau darauf sind die Klangdateien geschnitten. Wer
/// hier etwas ändert, muss `fetch-sounds.py` erneut laufen lassen.
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

// MARK: - Abspielen

/// Spielt die Ziehklänge. Eine gemeinsame Instanz für die ganze App.
@MainActor
final class Ziehklang {
    static let shared = Ziehklang()

    private var spieler: AVAudioPlayer?
    /// Einmal geladene Dateien bleiben liegen — beim Ziehen soll der Ton
    /// sofort kommen, nicht erst nach dem Einlesen von der Platte.
    private var lager: [SpinSound: AVAudioPlayer] = [:]

    private init() {}

    /// Beginnt den Klang zum Zug. Läuft von selbst aus.
    func starte(_ klang: SpinSound) {
        guard let spieler = hole(klang) else { return }
        stoppe()
        AudioSessionCenter.configure(recording: AudioSessionCenter.isRecording)
        spieler.currentTime = 0
        spieler.play()
        self.spieler = spieler
    }

    /// Hörprobe in den Einstellungen — dasselbe wie beim Ziehen.
    func probe(_ klang: SpinSound) { starte(klang) }

    /// Bricht ab, etwa wenn mitten im Zug etwas anderes passiert.
    func stoppe() {
        spieler?.stop()
        spieler = nil
    }

    private func hole(_ klang: SpinSound) -> AVAudioPlayer? {
        guard let name = klang.datei else { return nil }
        if let fertig = lager[klang] { return fertig }
        guard let adresse = Bundle.main.url(forResource: name, withExtension: "wav"),
              let neu = try? AVAudioPlayer(contentsOf: adresse)
        else {
            // Ton ist Beiwerk: Fehlt die Datei, läuft das Auslosen still
            // weiter statt zu scheitern.
            return nil
        }
        neu.prepareToPlay()
        lager[klang] = neu
        return neu
    }
}
