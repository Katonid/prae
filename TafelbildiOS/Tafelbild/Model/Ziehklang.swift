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
// zusammenhängend — jetzt läuft eine Aufnahme über den ganzen Zug.
//
// Die Aufnahmen sind rund 1,72 s lang, ein Zug dauert aber verschieden lang:
// zwei Sekunden beim einzelnen Namen, eine Sekunde je Kärtchen beim Auslosen
// von Gruppen — bei einer ganzen Klasse also eine halbe Minute. Deshalb
// nimmt `starte` die gewünschte Dauer entgegen, wiederholt die Aufnahme so
// oft, wie sie hineinpasst, und **schiebt den Beginn so weit nach hinten,
// dass der letzte Durchlauf genau am Ende des Zuges ausklingt**. Der
// Trommelschlag am Schluss fällt damit auf den Augenblick, in dem der Name
// steht.

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
/// Die Kurve steht seit der Web-App fest; neu ist, dass die Schritte auf eine
/// **feste Gesamtdauer** normiert werden. Ein Zug soll ein kleiner Auftritt
/// sein, und dafür braucht er Zeit: zwei Sekunden, bis der Name steht.
enum ZiehLauf {
    static let schritte = 18
    /// So lange dauert ein Zug beim einzelnen Namen.
    static let gesamt = 2.0
    private static let schnell = 45.0   // Millisekunden
    private static let langsam = 210.0

    /// Wartezeit vor dem nächsten Schritt, in Sekunden.
    static func pause(schritt: Int) -> Double {
        guard rohsumme > 0 else { return gesamt / Double(max(1, schritte)) }
        return roh(fortschritt: fortschritt(schritt: schritt)) * gesamt / rohsumme
    }

    /// 0 beim ersten, 1 beim letzten Schritt.
    static func fortschritt(schritt: Int) -> Double {
        guard schritte > 1 else { return 1 }
        return Double(schritt) / Double(schritte - 1)
    }

    /// Summe der ungewichteten Kurve — daran werden die Pausen normiert.
    private static let rohsumme: Double = (0..<schritte)
        .map { roh(fortschritt: fortschritt(schritt: $0)) }
        .reduce(0, +)

    private static func roh(fortschritt: Double) -> Double {
        (schnell + pow(fortschritt, 2.4) * (langsam - schnell)) / 1000
    }
}

/// Zeitmaß beim Auslosen von Gruppen.
enum Gruppenlauf {
    /// Ein Kärtchen je Sekunde. Ein Sitzplan für eine ganze Klasse dauert
    /// damit eine halbe Minute — das ist gewollt: Es ist ein Auftritt, kein
    /// Rechenvorgang, und die Klasse soll mitfiebern.
    static let proKarte = 1.0
    /// Wie oft die noch offenen Kärtchen neu durchmischt werden.
    static let taktrate = 0.09

    static func dauer(kaertchen: Int) -> Double {
        Double(max(1, kaertchen)) * proKarte
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

    /// Beginnt den Klang zum Zug.
    ///
    /// - Parameter dauer: Wie lange der Zug dauert. Die Aufnahme wird so oft
    ///   wiederholt, wie sie ganz hineinpasst, und so spät begonnen, dass der
    ///   letzte Durchlauf mit dem Zug endet. Bei 0 (Hörprobe) läuft sie
    ///   einmal, sofort.
    func starte(_ klang: SpinSound, dauer: Double = 0) {
        guard let spieler = hole(klang) else { return }
        stoppe()
        AudioSessionCenter.configure(recording: AudioSessionCenter.isRecording)

        let laenge = spieler.duration
        var wiederholungen = 1
        var verzoegerung = 0.0
        if dauer > 0, laenge > 0.05 {
            wiederholungen = max(1, Int((dauer / laenge).rounded(.down)))
            verzoegerung = max(0, dauer - Double(wiederholungen) * laenge)
        }
        spieler.numberOfLoops = wiederholungen - 1
        spieler.currentTime = 0
        if verzoegerung > 0.01 {
            spieler.play(atTime: spieler.deviceCurrentTime + verzoegerung)
        } else {
            spieler.play()
        }
        self.spieler = spieler
    }

    /// Hörprobe in den Einstellungen — die Aufnahme, einmal.
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
