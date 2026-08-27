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
// Zwei Fälle, zwei Arten von Klang:
//
// **Einzelner Name.** Ein Zug dauert zwei Sekunden, die Aufnahme rund 1,72 s.
// `starte` schiebt den Beginn so weit nach hinten, dass die Aufnahme genau am
// Ende des Zuges ausklingt — der Trommelschlag am Schluss fällt auf den
// Augenblick, in dem der Name steht.
//
// **Gruppen.** Jedes Kärtchen bekommt seinen eigenen kurzen Klang
// (`kartenSchlag`), und zwar einen **Ausschnitt aus dem Vorgang selbst**, der
// genau dann endet, wenn das Kärtchen einrastet: ein Durchlauf des
// Kartenstapels, ein Ratschen, ein Stück Wirbel. Mehrere Ausschnitte im
// Wechsel, damit keiner wie der vorige klingt; das letzte Kärtchen bekommt
// den vollen Pegel.
//
// Zwei Anläufe davor gingen daneben, beide aus demselben Grund:
//
// * Eine Aufnahme von 1,72 s siebzehnmal in Schleife über den ganzen Zug —
//   die Wiederholung klang künstlich und hatte mit dem Bild nichts zu tun.
// * Einzelne Anschläge (Kartenklaps, Klick, Wirbelende) — auf dem iPad war
//   davon nichts zu erkennen. Nachgemessen lagen diese Aufnahmen bei −27 bis
//   −29 dBFS, die Kassenglocke und der Wisch, die beide ankamen, bei −14 und
//   −11. Fünfzehn Dezibel sind ein Viertel der empfundenen Lautstärke.
//
// Deshalb werden jetzt **alle** Dateien auf dieselbe Lautheit gebracht
// (−14 dBFS, nachgemessen) statt auf denselben Spitzenwert. Der Spitzenwert
// sagt nichts darüber, wie laut etwas ankommt.

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
            return "Ein echter Kartenstapel, der durch die Finger läuft. "
                 + "Bei Gruppen läuft er vor jedem Kärtchen kurz durch."
        case .trommel:
            return "Ein Wirbel auf der kleinen Trommel. Bei Gruppen wirbelt "
                 + "es vor jedem Kärtchen kurz an."
        case .rad:
            return "Das Klacken einer echten Ratsche. Bei Gruppen ratscht es "
                 + "vor jedem Kärtchen, bis es einrastet."
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

    /// Kurze Klänge für „ein Kärtchen rastet ein" — mehrere Fassungen,
    /// damit sich nichts wiederholt.
    ///
    /// **Alle drei sind Ausschnitte aus einem Vorgang, kein Anschlag.**
    /// Karten werden gemischt, ein Rad ratscht, eine Trommel wirbelt — das
    /// sind Abläufe. Jeder Ausschnitt endet genau dann, wenn das Kärtchen
    /// einrastet; der Ton läuft also auf das Bild zu und hört mit ihm auf.
    var kartenDateien: [String] {
        switch self {
        case .aus:     return []
        case .karten:  return (1...4).map { "karte-karten-\($0)" }
        case .rad:     return (1...3).map { "karte-rad-\($0)" }
        case .trommel: return (1...3).map { "karte-trommel-\($0)" }
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
    /// Kurze Klänge je Datei, zwei Spieler, damit sie sich überlappen dürfen.
    private var kartenLager: [String: [AVAudioPlayer]] = [:]
    private var kartenZaehler = 0

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

    /// Ein Kärtchen bleibt stehen.
    ///
    /// Beim Auslosen von Gruppen läuft **kein** langer Mitschnitt mehr.
    /// Eine Aufnahme von 1,72 s siebzehnmal hintereinander ist genau das,
    /// was künstlich klingt — und sie hat mit dem Bild nichts zu tun.
    /// Stattdessen bekommt jedes Kärtchen im Augenblick, in dem es stehen
    /// bleibt, seinen eigenen kurzen Klang: wechselnde Fassungen, dazu ein
    /// Hauch Streuung in Tonhöhe und Pegel — so klingt kein Anschlag wie
    /// der vorige.
    /// - Parameter landetIn: In wie vielen Sekunden das Kärtchen einrastet.
    ///   Der Ausschnitt wird so früh begonnen, dass er genau dann endet.
    ///   Vorausgeplant statt im Takt der Bildschleife angestoßen — dadurch
    ///   sitzt der Ton auf die Millisekunde.
    func kartenSchlag(_ klang: SpinSound, landetIn: Double = 0, betont: Bool = false) {
        let dateien = klang.kartenDateien
        guard !dateien.isEmpty else { return }
        AudioSessionCenter.configure(recording: AudioSessionCenter.isRecording)
        let name = dateien[kartenZaehler % dateien.count]
        kartenZaehler &+= 1
        guard let spieler = freierSpieler(name) else { return }
        spieler.currentTime = 0
        spieler.enableRate = true
        // Nur ein Hauch Streuung: Die Aufnahmen sind auf gleiche Lautheit
        // gebracht (siehe fetch-sounds.py), da soll nichts mehr leise
        // untergehen — hörbar sein war das ganze Problem.
        spieler.rate = Float.random(in: 0.97...1.04)
        spieler.volume = betont ? 1.0 : Float.random(in: 0.9...1.0)

        let vorlauf = spieler.duration / Double(spieler.rate)
        let wartezeit = max(0, landetIn - vorlauf)
        if wartezeit > 0.01 {
            spieler.play(atTime: spieler.deviceCurrentTime + wartezeit)
        } else {
            spieler.play()
        }
    }

    /// Der Zähler in der Zählansicht.
    ///
    /// Hoch die Glocke einer Registrierkasse, runter der Wisch über die
    /// Tafel. Beides sind Handgriffe im Unterricht, die man nicht ansieht —
    /// wer auf ein Kärtchen tippt, schaut die Klasse an, nicht das iPad.
    /// Der Ton sagt, dass es angekommen ist.
    func zaehlerKlang(hoch: Bool) {
        AudioSessionCenter.configure(recording: AudioSessionCenter.isRecording)
        guard let spieler = freierSpieler(hoch ? "zaehler-hoch" : "zaehler-runter")
        else { return }
        spieler.currentTime = 0
        spieler.enableRate = true
        spieler.rate = 1
        spieler.volume = hoch ? 0.9 : 0.8
        spieler.play()
    }

    /// Bricht die vorausgeplanten Kärtchen-Klänge ab — beim Überspringen
    /// soll nichts nachklappern.
    func stoppeKaertchen() {
        for spieler in kartenLager.values.flatMap({ $0 }) { spieler.stop() }
    }

    /// Hörprobe in den Einstellungen — die Aufnahme, einmal.
    func probe(_ klang: SpinSound) { starte(klang) }

    /// Bricht ab, etwa wenn mitten im Zug etwas anderes passiert.
    func stoppe() {
        spieler?.stop()
        spieler = nil
    }

    /// Ein Spieler, der gerade nicht läuft. Zwei je Datei genügen: Die
    /// Kärtchen liegen eine Sekunde auseinander, die Klänge sind kürzer —
    /// nur beim Neuauslosen ab einer Stelle kann sich etwas überlappen.
    private func freierSpieler(_ name: String) -> AVAudioPlayer? {
        if let vorhanden = kartenLager[name] {
            return vorhanden.first { !$0.isPlaying } ?? vorhanden.first
        }
        guard let adresse = Bundle.main.url(forResource: name, withExtension: "wav")
        else { return nil }
        let neue = (0..<2).compactMap { _ -> AVAudioPlayer? in
            guard let spieler = try? AVAudioPlayer(contentsOf: adresse) else { return nil }
            spieler.enableRate = true
            spieler.prepareToPlay()
            return spieler
        }
        guard !neue.isEmpty else { return nil }
        kartenLager[name] = neue
        return neue[0]
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
