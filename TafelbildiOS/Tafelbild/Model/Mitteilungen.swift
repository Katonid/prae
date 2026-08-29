import AVFoundation
import Foundation
import UserNotifications

/// Meldet das Ende eines Timers, auch wenn die App nicht vorn ist.
///
/// **Warum es das braucht.** iOS legt jede App wenige Sekunden nach dem
/// Wegschalten schlafen und beendet sie später ganz. Es gibt keine
/// Berechtigung „bitte weiterlaufen", und den bekannten Trick — eine stille
/// Tonspur abspielen, damit iOS die App für einen Musikplayer hält — lehnt
/// die App-Prüfung ab (Richtlinie 2.5.4). Der vorgesehene Weg ist eine
/// **örtliche Mitteilung**: Sie wird beim Starten des Timers auf die Endzeit
/// vorgemerkt und kommt dann von iOS selbst — im Hintergrund, bei gesperrtem
/// Bildschirm und selbst dann, wenn die App längst beendet wurde.
///
/// **Nicht zu verwechseln mit Push.** Die App hat keinen Server. Hier wird
/// nichts verschickt; die Mitteilung liegt auf dem Gerät und wartet auf ihre
/// Uhrzeit.
///
/// **Im Vordergrund bleibt es still** (siehe `willPresent`): Dann spielt die
/// Tafel den Klang selbst, und ein Mitteilungsbanner mitten über dem
/// Beamerbild wäre im Unterricht störender als hilfreich.
@MainActor
final class Weckdienst: NSObject, ObservableObject {
    static let shared = Weckdienst()

    enum Erlaubnis: Equatable { case unbekannt, erlaubt, verweigert }

    @Published private(set) var erlaubnis: Erlaubnis = .unbekannt

    /// Timer, deren Mitteilung wirklich geklungen hat, während die App weg
    /// war. Ohne diese Liste klänge der Klang beim Zurückkommen ein zweites
    /// Mal — die Tafel sieht den abgelaufenen Timer ja erst dann.
    private var gemeldet: Set<String> = []

    private static let vorsilbe = "timer-"

    /// Was vorgemerkt werden sollte, während noch nach der Erlaubnis
    /// gefragt wurde. Ohne das bliebe der allererste Timer ohne Meldung —
    /// die Antwort kommt ja erst, nachdem er schon läuft.
    private var nachzuholen: (id: String, endet: Date, inhalt: TimerContent,
                              aufschrift: String)?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Erlaubnis

    func pruefeErlaubnis() {
        UNUserNotificationCenter.current().getNotificationSettings { einstellungen in
            let stand: Erlaubnis
            switch einstellungen.authorizationStatus {
            case .authorized, .provisional, .ephemeral: stand = .erlaubt
            case .denied:                               stand = .verweigert
            default:                                    stand = .unbekannt
            }
            Task { @MainActor in self.erlaubnis = stand }
        }
    }

    /// Fragt einmalig nach. Gerufen beim ersten Start eines Timers — dort
    /// ist die Frage im Zusammenhang verständlich, anders als beim ersten
    /// Öffnen der App, wo niemand wüsste, wofür.
    func frageErlaubnis() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { gewaehrt, _ in
                Task { @MainActor in
                    self.erlaubnis = gewaehrt ? .erlaubt : .verweigert
                    guard gewaehrt, let offen = self.nachzuholen else {
                        self.nachzuholen = nil
                        return
                    }
                    self.nachzuholen = nil
                    self.merkeVor(timerID: offen.id, endet: offen.endet,
                                  inhalt: offen.inhalt, aufschrift: offen.aufschrift)
                }
            }
    }

    // MARK: - Vormerken und zurücknehmen

    /// Merkt die Meldung für diesen Timer auf die genannte Zeit vor.
    ///
    /// Eine schon vorgemerkte Meldung desselben Timers wird dabei ersetzt —
    /// die Kennung ist der Timer selbst. Das ist genau richtig, wenn jemand
    /// während des Laufs eine Minute zulegt.
    func merkeVor(timerID: String, endet: Date, inhalt: TimerContent, aufschrift: String) {
        guard inhalt.soundOnEnd else { nimmZurueck(timerID: timerID); return }

        switch erlaubnis {
        case .verweigert:
            return
        case .unbekannt:
            // Fragen — und die Vormerkung so lange aufheben. Die Antwort
            // kommt erst nach dem Tippen, und bis dahin läuft der Timer
            // schon; ohne das Aufheben bliebe ausgerechnet der erste Timer
            // ohne Meldung.
            nachzuholen = (timerID, endet, inhalt, aufschrift)
            frageErlaubnis()
            return
        case .erlaubt:
            break
        }

        let rest = endet.timeIntervalSinceNow
        // Unter einer Sekunde lohnt es nicht — und iOS nimmt eine Zeitspanne
        // von null gar nicht erst an.
        guard rest > 1 else { return }

        gemeldet.remove(timerID)

        let text = UNMutableNotificationContent()
        text.title = aufschrift.nonEmpty ?? "Timer"
        text.body = "Die Zeit ist um."
        text.sound = klang(fuer: inhalt)
        text.interruptionLevel = .timeSensitive

        let anstoss = UNTimeIntervalNotificationTrigger(timeInterval: rest, repeats: false)
        let auftrag = UNNotificationRequest(identifier: Self.vorsilbe + timerID,
                                            content: text, trigger: anstoss)
        UNUserNotificationCenter.current().add(auftrag)
    }

    /// Nimmt die Meldung zurück — beim Anhalten, Zurücksetzen und sobald die
    /// Tafel das Ende selbst bemerkt hat.
    func nimmZurueck(timerID: String) {
        let kennung = Self.vorsilbe + timerID
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [kennung])
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [kennung])
        gemeldet.remove(timerID)
    }

    /// Hat dieser Timer schon von selbst geklungen? Fragt die Tafel, bevor
    /// sie den Klang beim Zurückkommen noch einmal abspielt. Die Antwort
    /// gilt nur einmal.
    func hatGemeldet(_ timerID: String) -> Bool {
        gemeldet.remove(timerID) != nil
    }

    /// Beim Zurückkommen nachsehen, welche Meldungen iOS zugestellt hat.
    ///
    /// Nur was hier ankommt, hat auch wirklich geklungen. Sich beim
    /// Vormerken schon zu merken „das wird klingen" wäre falsch: Der Timer
    /// kann angehalten worden sein, und ein Gerät im Flugzeugmodus meldet
    /// trotzdem — ein Gerät mit stummgeschaltetem Ton aber nicht hörbar.
    func sammleZugestellte() {
        UNUserNotificationCenter.current().getDeliveredNotifications { meldungen in
            let ids = meldungen
                .map(\.request.identifier)
                .filter { $0.hasPrefix(Self.vorsilbe) }
                .map { String($0.dropFirst(Self.vorsilbe.count)) }
            guard !ids.isEmpty else { return }
            Task { @MainActor in self.gemeldet.formUnion(ids) }
        }
    }

    // MARK: - Klang der Meldung

    /// Welchen Ton iOS spielen soll.
    ///
    /// Die mitgelieferten Klänge liegen als WAV im Bündel und dürfen direkt
    /// genannt werden. Ein selbst aufgenommener Klang ist eine m4a-Datei —
    /// die nimmt iOS für Mitteilungen nicht an, also wird sie einmal
    /// umgewandelt (siehe `alsMitteilungsklang`).
    private func klang(fuer inhalt: TimerContent) -> UNNotificationSound {
        let gewaehlt = Endklang.aus(inhalt.endklang)

        if gewaehlt == .eigener, let datei = inhalt.endklangDatei,
           let name = Self.alsMitteilungsklang(datei) {
            return UNNotificationSound(named: UNNotificationSoundName(name))
        }
        if let datei = gewaehlt.datei {
            return UNNotificationSound(named: UNNotificationSoundName(datei + ".wav"))
        }
        return .default
    }

    /// Legt einen eigenen Klang als Mitteilungston ab und gibt seinen Namen
    /// zurück — nil, wenn das nicht gelingt.
    ///
    /// iOS spielt als Mitteilungston nur Dateien aus dem Bündel oder aus
    /// `Library/Sounds`, und nur unkomprimiert (CAF, WAV, AIFF). Eine
    /// Aufnahme der App liegt als AAC in einer m4a-Datei; sie wird deshalb
    /// einmal nach CAF ausgepackt und dort abgelegt. Beim nächsten Mal steht
    /// sie schon da.
    ///
    /// **Höchstens 30 Sekunden** — darüber ersetzt iOS den Ton
    /// stillschweigend durch den Standardton. Lieber selbst kürzen, dann
    /// klingt wenigstens der Anfang.
    private static func alsMitteilungsklang(_ dateiname: String) -> String? {
        let quelle = MediaStore.url(dateiname)
        guard FileManager.default.fileExists(atPath: quelle.path) else { return nil }

        guard let ordner = try? FileManager.default.url(
            for: .libraryDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true).appendingPathComponent("Sounds")
        else { return nil }
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)

        let name = (dateiname as NSString).deletingPathExtension + ".caf"
        let ziel = ordner.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: ziel.path) { return name }

        do {
            let lesen = try AVAudioFile(forReading: quelle)
            let format = lesen.processingFormat
            let einstellungen: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            let schreiben = try AVAudioFile(forWriting: ziel, settings: einstellungen)

            let hoechstens = AVAudioFramePosition(format.sampleRate * 30)
            let block = AVAudioFrameCount(format.sampleRate)
            var geschrieben: AVAudioFramePosition = 0
            while lesen.framePosition < lesen.length, geschrieben < hoechstens {
                guard let puffer = AVAudioPCMBuffer(pcmFormat: format,
                                                    frameCapacity: block) else { break }
                try lesen.read(into: puffer)
                if puffer.frameLength == 0 { break }
                try schreiben.write(from: puffer)
                geschrieben += AVAudioFramePosition(puffer.frameLength)
            }
            return name
        } catch {
            // Ton ist Beiwerk: Klappt die Umwandlung nicht, meldet sich der
            // Timer mit dem Standardton statt gar nicht.
            try? FileManager.default.removeItem(at: ziel)
            return nil
        }
    }
}

extension Weckdienst: UNUserNotificationCenterDelegate {
    /// Im Vordergrund nichts zeigen und nichts spielen.
    ///
    /// Die Tafel bemerkt das Ende dann selbst und spielt den Klang über die
    /// eigenen Lautsprecher — dieselbe Lautstärke wie die übrigen Klänge der
    /// App. Ein Banner mitten über dem Beamerbild wäre im Unterricht
    /// störender als hilfreich.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }
}
