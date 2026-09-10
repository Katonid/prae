//  Eigenklang.swift
//  Ein selbst mitgebrachter Alarmton — geprüft, umgerechnet, leise gemacht.
//
//  Drei Dinge muss diese Datei tun, und jedes einzelne ist ein Fall, in dem
//  iOS sonst stillschweigend etwas anderes spielt als gemeint:
//
//  1. **Format.** Als Mitteilungston nimmt iOS nur lineares PCM, MA4, µ-law
//     oder a-law in WAV, AIFF oder CAF. Eine MP3 oder M4A wird nicht etwa
//     abgelehnt — sie wird durch den Standardton ERSETZT, ohne Fehler. Also
//     wird hier alles, was AVFoundation lesen kann, in 16-Bit-PCM-WAV
//     umgerechnet.
//  2. **Länge.** Über 30 Sekunden spielt iOS den Ton gar nicht ab. Lieber hier
//     mit einem klaren Satz abweisen als auf dem Gerät schweigen.
//  3. **Lautstärke.** Kritische Hinweise spielen mit `withAudioVolume: 1.0`,
//     unabhängig vom Lautstärkeregler. Eine mitgebrachte Datei bringt ihre
//     eigene Aussteuerung mit — meist bis Vollausschlag. Ungebremst wäre der
//     erste selbst hochgeladene Ton auf dreißig iPads unerwartet laut, und
//     zwar genau in der Situation, für die die leisen Töne gebaut wurden.
//     Deshalb wird jede Datei auf dieselbe Spitze normiert wie die
//     eingebauten leisen Töne.
//
//  Die fertige Datei liegt in Application Support und ist die VORLAGE. In
//  `Library/Sounds/signal.wav` kopiert sie `Klanginstallation` — dieselbe
//  Mechanik wie bei den vier eingebauten Tönen.

import AVFoundation
import Foundation

enum Eigenklang {

    /// Dieselbe Spitze wie „Holzton". Wer einen eigenen Ton mitbringt, will
    /// ihn an derselben Stelle einsetzen wie die leisen — sonst hätte er den
    /// Alarm genommen.
    static let spitze: Float = 0.32

    /// Länger spielt iOS gar nicht ab.
    static let hoechstdauer: Double = 30

    private static let nameSchluessel = "alarmklang.eigen.name"

    // MARK: - Wo die Datei liegt

    private static var ordner: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory,
                                 in: .userDomainMask).first
    }

    /// Die umgerechnete Vorlage — oder `nil`, wenn keine hinterlegt ist.
    static var datei: URL? {
        guard let url = ordner?.appendingPathComponent("eigenklang.wav") else { return nil }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Wie die Datei hieß, als sie gewählt wurde. Nur zum Anzeigen.
    static var name: String? {
        UserDefaults.standard.string(forKey: nameSchluessel)
    }

    // MARK: - Übernehmen

    /// Liest, prüft, rechnet um, normiert und legt ab.
    ///
    /// Wirft mit einem Satz, den die Lehrkraft lesen kann — der rohe
    /// AVFoundation-Fehler steht dahinter, denn „geht nicht" ist keine
    /// Auskunft.
    static func uebernehmen(von quelle: URL) throws {
        guard let ordner else {
            throw Klangfehler("Auf diesem Gerät ist kein Ablageort zu finden.")
        }

        // Ein Dokument aus der Dateien-App gehört nicht dieser App. Ohne diese
        // Klammer schlägt schon das Öffnen fehl, und zwar mit einem Fehler,
        // der nach einem kaputten Format aussieht.
        let geoeffnet = quelle.startAccessingSecurityScopedResource()
        defer { if geoeffnet { quelle.stopAccessingSecurityScopedResource() } }

        let datei: AVAudioFile
        do {
            datei = try AVAudioFile(forReading: quelle)
        } catch {
            throw Klangfehler("Diese Datei ließ sich nicht lesen. Erlaubt sind "
                            + "Tondateien wie WAV, AIFF, CAF, MP3 oder M4A.",
                              roh: error.localizedDescription)
        }

        let format = datei.processingFormat
        let dauer = Double(datei.length) / format.sampleRate
        guard dauer > 0.2 else {
            throw Klangfehler("Diese Datei ist zu kurz — sie enthält praktisch "
                            + "keinen Ton.")
        }
        guard dauer <= hoechstdauer else {
            let sekunden = String(format: "%.0f", dauer)
            throw Klangfehler("Der Ton ist \(sekunden) Sekunden lang. iOS spielt "
                            + "einen Mitteilungston über 30 Sekunden GAR NICHT "
                            + "ab — bitte vorher kürzen.")
        }

        guard let puffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(datei.length)) else {
            throw Klangfehler("Der Ton passt nicht in den Speicher.")
        }
        do { try datei.read(into: puffer) } catch {
            throw Klangfehler("Der Ton ließ sich nicht einlesen.",
                              roh: error.localizedDescription)
        }

        normieren(puffer)

        // Erst neben das Ziel schreiben, dann tauschen: Bricht das Umrechnen
        // ab, bleibt der bisherige Ton stehen. Ein halb geschriebener
        // Alarmton wäre schlimmer als der alte.
        let ziel = ordner.appendingPathComponent("eigenklang.wav")
        let vorlaeufig = ordner.appendingPathComponent("eigenklang-neu.wav")
        do {
            try FileManager.default.createDirectory(at: ordner,
                                                    withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: vorlaeufig.path) {
                try FileManager.default.removeItem(at: vorlaeufig)
            }
            // Die Endung entscheidet über den Behälter; die Einstellungen
            // über den Inhalt. 16-Bit-PCB in einer WAV ist das Format, mit
            // dem iOS nie streitet — dieselbe Wahl wie in make-sounds.py.
            let einstellungen: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            let ausgabe = try AVAudioFile(forWriting: vorlaeufig, settings: einstellungen)
            try ausgabe.write(from: puffer)

            if FileManager.default.fileExists(atPath: ziel.path) {
                try FileManager.default.removeItem(at: ziel)
            }
            try FileManager.default.moveItem(at: vorlaeufig, to: ziel)
        } catch {
            try? FileManager.default.removeItem(at: vorlaeufig)
            throw Klangfehler("Der Ton ließ sich nicht umrechnen.",
                              roh: error.localizedDescription)
        }

        UserDefaults.standard.set(quelle.deletingPathExtension().lastPathComponent,
                                  forKey: nameSchluessel)
    }

    static func entfernen() {
        if let datei { try? FileManager.default.removeItem(at: datei) }
        UserDefaults.standard.removeObject(forKey: nameSchluessel)
    }

    // MARK: - Lautstärke

    /// Skaliert auf eine feste Spitze — nach OBEN wie nach unten.
    ///
    /// Auch das Anheben ist Absicht: Eine sehr leise Aufnahme wäre im
    /// Ernstfall wertlos, und „ich habe doch etwas eingestellt" ist die
    /// gefährlichste Sorte Fehler in dieser App.
    private static func normieren(_ puffer: AVAudioPCMBuffer) {
        guard let kanaele = puffer.floatChannelData else { return }
        let laenge = Int(puffer.frameLength)
        let anzahl = Int(puffer.format.channelCount)

        var hoch: Float = 0
        for kanal in 0..<anzahl {
            let werte = kanaele[kanal]
            for i in 0..<laenge { hoch = max(hoch, abs(werte[i])) }
        }
        guard hoch > 0.0001 else { return }

        let faktor = spitze / hoch
        for kanal in 0..<anzahl {
            let werte = kanaele[kanal]
            for i in 0..<laenge { werte[i] *= faktor }
        }
    }
}

/// Ein Fehler mit einem Satz für die Lehrkraft und dem Rohtext dahinter.
struct Klangfehler: LocalizedError {
    let satz: String
    let roh: String?

    init(_ satz: String, roh: String? = nil) {
        self.satz = satz
        self.roh = roh
    }

    var errorDescription: String? {
        guard let roh else { return satz }
        return "\(satz)\n\n(\(roh))"
    }
}
