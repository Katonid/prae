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

    /// Seit wann die App vorn ist.
    ///
    /// Daran entscheidet sich, ob die Tafel beim Zurückkommen noch klingen
    /// soll: Was **vorher** ablief, hat iOS schon gemeldet. Vorher wurde
    /// dafür beim Aktivwerden nachgesehen, welche Meldungen zugestellt
    /// wurden — das war ein Wettlauf. Die Antwort kam über einen Rückruf,
    /// der Zeittakt der Tafel war schneller, und der Klang lief doppelt.
    /// Ein Vergleich zweier Zeitpunkte kann nicht zu spät kommen.
    private var aktivSeit = Date()

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

        let text = UNMutableNotificationContent()
        text.title = aufschrift.nonEmpty ?? "Timer"
        text.body = "Die Zeit ist um."
        text.sound = klang(fuer: inhalt)

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
    }

    /// Die App ist wieder vorn.
    func wurdeAktiv() {
        aktivSeit = Date()
        pruefeErlaubnis()
    }

    /// Hat iOS diesen Ablauf schon gemeldet?
    ///
    /// Ja, wenn er zu einer Zeit lag, als die App nicht vorn war — dann hat
    /// die vorgemerkte Meldung geklungen, und die Tafel schweigt beim
    /// Zurückkommen. Sind Mitteilungen nicht erlaubt, kann nichts geklungen
    /// haben; dann klingt die Tafel wie früher nach.
    func hatGemeldet(ablauf: Date) -> Bool {
        erlaubnis == .erlaubt && ablauf < aktivSeit
    }

    // MARK: - Klang der Meldung

    /// Welchen Ton iOS spielen soll.
    ///
    /// **Alles geht über `Library/Sounds`, auch die mitgelieferten Klänge.**
    /// `UNNotificationSound(named:)` sucht nur an zwei Stellen: ganz oben im
    /// App-Bündel und in `Library/Sounds`. Wo im Bündel eine Datei landet,
    /// entscheidet bei einem synchronisierten Ordner aber Xcode — liegt sie
    /// in einem Unterordner, findet iOS sie nicht und spielt **gar nichts**,
    /// ohne Fehlermeldung. Genau das war in 1.1.5 der Fall: Die Meldung kam,
    /// blieb aber stumm. Ein Ordner, den die App selbst füllt, ist die
    /// einzige Ablage, auf die Verlass ist.
    private func klang(fuer inhalt: TimerContent) -> UNNotificationSound {
        let gewaehlt = Endklang.aus(inhalt.endklang)

        if gewaehlt == .eigener, let datei = inhalt.endklangDatei,
           let name = Self.alsMitteilungsklang(datei) {
            return UNNotificationSound(named: UNNotificationSoundName(name))
        }
        if let datei = gewaehlt.datei, let name = Self.ausDemBuendel(datei) {
            return UNNotificationSound(named: UNNotificationSoundName(name))
        }
        return .default
    }

    /// Der Ordner, aus dem iOS Mitteilungstöne nimmt. Wird angelegt, wenn es
    /// ihn noch nicht gibt.
    private static func klangordner() -> URL? {
        guard let bibliothek = try? FileManager.default.url(
            for: .libraryDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true) else { return nil }
        let ordner = bibliothek.appendingPathComponent("Sounds")
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        return ordner
    }

    /// Legt einen mitgelieferten Klang einmalig in `Library/Sounds` ab und
    /// gibt seinen Namen zurück. Beim nächsten Mal steht er schon da.
    private static func ausDemBuendel(_ datei: String) -> String? {
        let name = datei + ".wav"
        guard let ordner = klangordner() else { return nil }
        let ziel = ordner.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: ziel.path) { return name }
        guard let quelle = Bundle.main.url(forResource: datei, withExtension: "wav")
        else { return nil }
        do {
            try FileManager.default.copyItem(at: quelle, to: ziel)
            return name
        } catch {
            return nil
        }
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

        guard let ordner = klangordner() else { return nil }

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
