import Foundation
import CoreGraphics

// Datenmodell der Tafelbild-App.
//
// Eine „Tafel" (Board) ist ein frei gestalteter Bildschirm für eine Klasse:
// Hintergrund + beliebig viele Elemente (Widgets), die auf einer festen
// Arbeitsfläche von 1600 × 1000 Punkten liegen. Die Ansicht skaliert diese
// Fläche auf das jeweilige Gerät — dadurch sieht eine Tafel auf iPad, Mac
// und iPhone identisch aus, und Positionen bleiben beim Gerätewechsel gültig.

enum Layout {
    /// Feste Arbeitsfläche einer Tafel (16:10) — als Double für die
    /// Modellrechnung und als CGSize für die Ansicht.
    static let canvasWidth: Double = 1600
    /// Höhe der Vorgabe 16:10. Wo eine Tafel bekannt ist, gilt `Board.hoehe`;
    /// dieser Wert ist der Rückfall für Stellen ohne Tafel.
    static let canvasHeight: Double = 1000
    static let canvas = CGSize(width: canvasWidth, height: canvasHeight)
    /// Fangraster beim Verschieben und beim Ändern der Größe.
    static let grid: Double = 20
    /// Kleinstmögliche Elementgröße in Tafelpunkten.
    static let minWidth: Double = 160
    static let minHeight: Double = 120
}

// MARK: - Zeit- und Text-Hilfen

extension Date {
    static var nowMs: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nonEmpty: String? { trimmed.isEmpty ? nil : trimmed }
}


// MARK: - Nachsichtiges Einlesen

/// Fehlt ein Feld im JSON (weil es aus einer älteren App-Fassung stammt),
/// soll der Standardwert einspringen — statt dass der ganze Datensatz
/// unlesbar wird und stumm verschwindet. Swift macht das von sich aus
/// nicht, deshalb dieser kleine Helfer und die Codable-Erweiterungen unten.
extension KeyedDecodingContainer {
    func wert<T: Decodable>(_ key: Key, _ standard: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? standard
    }

    func optional<T: Decodable>(_ key: Key, _ typ: T.Type) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }
}

// MARK: - Entitäten für die Synchronisation

enum EntityKind: String, Codable, CaseIterable {
    case board
    case nameList
    /// Medien (Bilder, Tondateien) — je Datei ein Record mit CKAsset.
    case media
}

// MARK: - Elementtypen

enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case namePicker
    case timer
    case clock
    case trafficLight
    case noise
    case checklist
    case text
    case image
    case sounds
    case symbols
    case video
    case kamera
    case geburtstag
    case sitzplan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .namePicker:   return "Zufälliger Name"
        case .timer:        return "Timer"
        case .clock:        return "Uhr"
        case .trafficLight: return "Ampel"
        case .noise:        return "Lautstärke"
        case .checklist:    return "Tagesablauf"
        case .text:         return "Text"
        case .image:        return "Bild"
        case .sounds:       return "Klänge"
        case .symbols:      return "Arbeitssymbol"
        case .video:        return "Video"
        case .kamera:       return "Dokumentenkamera"
        case .geburtstag:   return "Geburtstag"
        case .sitzplan:     return "Sitzplan"
        }
    }

    var subtitle: String {
        switch self {
        case .namePicker:   return "Aus einer Namensliste ziehen"
        case .timer:        return "Countdown oder Stoppuhr"
        case .clock:        return "Analog oder digital"
        case .trafficLight: return "Arbeitsphase anzeigen"
        case .noise:        return "Geräuschpegel im Raum messen"
        case .checklist:    return "Ablauf zum Abhaken"
        case .text:         return "Überschrift oder Arbeitsauftrag"
        case .image:        return "Foto oder Grafik"
        case .sounds:       return "Tonfelder zum Antippen"
        case .symbols:      return "Arbeitsform groß anzeigen"
        case .video:        return "Film vom Gerät oder aus dem Netz"
        case .kamera:       return "Heft oder Blatt zeigen"
        case .geburtstag:   return "Wer heute feiert"
        case .sitzplan:     return "Wer wo sitzt — ausgelost nach Regeln"
        }
    }

    var systemImage: String {
        switch self {
        case .namePicker:   return "dice"
        case .timer:        return "hourglass"
        case .clock:        return "clock"
        case .trafficLight: return "light.beacon.max"
        case .noise:        return "waveform"
        case .checklist:    return "checklist"
        case .text:         return "textformat"
        case .image:        return "photo"
        case .sounds:       return "speaker.wave.2"
        case .symbols:      return "person.2"
        case .video:        return "play.rectangle"
        case .kamera:       return "doc.viewfinder"
        case .geburtstag:   return "gift"
        case .sitzplan:     return "square.grid.3x3"
        }
    }

    /// Startgröße in Tafelpunkten — dieselbe wie die vorgesehene Größe der
    /// Web-App (`webSize` in WebMasse.swift). Damit zeichnet ein frisch
    /// angelegtes Element im Maßstab 1, also genau wie dort.
    var defaultSize: CGSize { webSize }
}

// MARK: - Inhalte der einzelnen Elemente

struct TextContent: Codable, Equatable {
    var text: String = "Guten Morgen!"
    /// Schriftgröße in Tafelpunkten.
    var fontSize: Double = 64
    /// Schriftgröße automatisch an das Feld anpassen.
    var autoSize: Bool = true
    var colorHex: String = "#0f172a"
    /// Zweite Farbe der Schrift. Leer heißt: einfarbig (siehe Fuellung).
    var colorHex2: String = ""
    var backgroundHex: String = "#ffffff"
    /// Zweite Farbe des Hintergrunds. Leer heißt: einfarbig.
    var backgroundHex2: String = ""
    var backgroundOpacity: Double = 0.0
    var bold: Bool = true
    var alignment: TextAlign = .center
    var rounded: Bool = true

    enum TextAlign: String, Codable, CaseIterable, Identifiable {
        case leading, center, trailing
        var id: String { rawValue }
        var title: String {
            switch self {
            case .leading: return "Links"
            case .center: return "Mittig"
            case .trailing: return "Rechts"
            }
        }
    }
}

struct ImageContent: Codable, Equatable {
    /// Dateiname unter Documents/Media/ (nil = noch kein Bild gewählt).
    var fileName: String? = nil
    var fill: Bool = true
    var cornerRadius: Double = 28
    var caption: String = ""
}

struct ClockContent: Codable, Equatable {
    var style: ClockStyle = .analog
    /// Zifferblatt der analogen Uhr.
    var face: ClockFace = .modern
    var showSeconds: Bool = true
    var showDate: Bool = false
    var twentyFourHour: Bool = true
    var faceHex: String = "#ffffff"
    /// Zweite Farbe des Zifferblatts. Leer heißt: einfarbig.
    var faceHex2: String = ""
    var accentHex: String = "#0f9b8e"

    enum ClockStyle: String, Codable, CaseIterable, Identifiable {
        case analog, digital, both
        var id: String { rawValue }
        var title: String {
            switch self {
            case .analog: return "Analog"
            case .digital: return "Digital"
            case .both: return "Beides"
            }
        }
    }
}

/// Zifferblätter der analogen Uhr — wie in der Web-App.
enum ClockFace: String, Codable, CaseIterable, Identifiable {
    /// Ruhig, mit dünnem Rand und kräftigen Zeigern.
    case modern
    /// Kräftiger Rand und Striche im Akzentton.
    case klassisch
    /// Lernuhr: Stunden blau, Minuten orange, mit Minutenzahlen außen.
    case lernuhr
    /// Nur 12/3/6/9 und die Fünf-Minuten-Striche.
    case minimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .modern:    return "Modern"
        case .klassisch: return "Klassisch"
        case .lernuhr:   return "Lernuhr"
        case .minimal:   return "Minimal"
        }
    }
}

struct TimerContent: Codable, Equatable {
    var mode: TimerMode = .countdown
    /// Eingestellte Dauer in Sekunden (Countdown).
    var duration: Double = 300
    /// Zeitpunkt, zu dem der laufende Timer endet bzw. gestartet wurde.
    var endsAtMs: Int64? = nil
    var startedAtMs: Int64? = nil
    /// Restzeit bei Pause (Countdown) bzw. gelaufene Zeit (Stoppuhr).
    var pausedValue: Double? = nil
    var soundOnEnd: Bool = true

    /// Welcher Klang am Ende erklingt — der **Rohwert** eines `Endklang`.
    ///
    /// Bewusst als Zeichenkette und nicht als Aufzählung gespeichert:
    /// Verschwindet hier je ein Fall, liest eine alte Tafel weiter und
    /// bekommt die Vorgabe. Ein erzeugter Leser würde stattdessen die ganze
    /// Tafel verwerfen — samt allem, was sonst noch darauf steht.
    var endklang: String = Endklang.vorgabe.rawValue
    /// Dateiname unter Documents/Media/ — gilt nur bei `Endklang.eigener`.
    var endklangDatei: String? = nil
    /// Lautstärke des Endklangs, 0 … 1.
    ///
    /// Gilt für den Klang, den die **App** spielt. Meldet sich der Timer aus
    /// dem Hintergrund über eine Mitteilung, bestimmt die Lautstärke des
    /// Systems — daran kommt keine App heran.
    var endklangLautstaerke: Double = 1.0
    var accentHex: String = "#2dd4bf"
    /// Alte Einstellung „Bedienknöpfe zeigen“. Wird nicht mehr gelesen;
    /// sie stand bei allen auf „an“, weil das die Vorgabe war.
    var showControls: Bool = true
    /// Die vier runden Knöpfe unter dem Ring.
    ///
    /// Standardmäßig aus: Ein Timer wird angetippt (Tipp = Start und Pause,
    /// Doppeltipp = zurücksetzen, langes Drücken = Dauer). Die Knöpfe
    /// nahmen dem Ring Platz weg, ohne etwas zu können, was der Tipp nicht
    /// kann. Bewusst ein NEUES Feld: So heißt „nicht gesetzt“ auch wirklich
    /// „nie ausgewählt“ — der alte Wert war nie eine Entscheidung.
    var knoepfe: Bool = false

    // MARK: Aussehen

    /// Ring mit Zahl (bisher) oder ablaufende Scheibe wie beim Time Timer.
    var darstellung: TimerDarstellung = .ring
    /// Wie viele Minuten der volle Kreis der Scheibe fasst. 0 = automatisch:
    /// die nächstgrößere übliche Marke oberhalb der eingestellten Dauer.
    var skalaMinuten: Int = 0
    /// Was auf dem Ziffernblatt steht.
    var ziffernblatt: Timerblatt = .zahlen
    /// Farbe der ablaufenden Fläche (zweite Farbe leer = einfarbig).
    var scheibeHex: String = "#e11d48"
    var scheibeHex2: String = ""
    /// Grundfarbe des Ziffernblatts.
    var blattHex: String = "#f8fafc"
    /// Zeiger auf der Scheibe.
    var zeiger: Bool = true
    /// Die Zeit zusätzlich als Zahl unter der Scheibe.
    var zeitZeigen: Bool = true

    enum TimerMode: String, Codable, CaseIterable, Identifiable {
        case countdown, stopwatch
        var id: String { rawValue }
        var title: String {
            switch self {
            case .countdown: return "Countdown"
            case .stopwatch: return "Stoppuhr"
            }
        }
    }

    var isRunning: Bool { endsAtMs != nil || startedAtMs != nil }

    /// Übliche Marken für das Ziffernblatt.
    static let skalen = [5, 10, 15, 20, 30, 45, 60, 90, 120]

    /// Wie viele Minuten der volle Kreis fasst — auch bei „automatisch“.
    var skala: Double {
        if skalaMinuten > 0 { return Double(skalaMinuten) }
        let minuten = duration / 60
        return Double(TimerContent.skalen.first { Double($0) >= minuten - 0.001 } ?? 60)
    }
}

/// Wie ein Timer aussieht.
enum TimerDarstellung: String, Codable, CaseIterable, Identifiable {
    /// Ring mit der Zeit in der Mitte — die bisherige Darstellung.
    case ring
    /// Ablaufende Farbfläche auf einem Ziffernblatt, wie die Uhren, die in
    /// vielen Klassenzimmern stehen. Kinder sehen daran ohne Rechnen, wie
    /// viel Zeit noch übrig ist.
    case scheibe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ring:    return "Ring"
        case .scheibe: return "Scheibe"
        }
    }
}

/// Was auf dem Ziffernblatt der Scheibe steht.
enum Timerblatt: String, Codable, CaseIterable, Identifiable {
    case zahlen
    case striche
    case ohne

    var id: String { rawValue }

    var title: String {
        switch self {
        case .zahlen:  return "Zahlen"
        case .striche: return "Nur Striche"
        case .ohne:    return "Ohne"
        }
    }

    var zeigtStriche: Bool { self != .ohne }
    var zeigtZahlen: Bool { self == .zahlen }
}

struct TrafficLightContent: Codable, Equatable {
    var state: LightState = .green
    var horizontal: Bool = false
    var showLabels: Bool = true
    var redLabel: String = "Stopp"
    var yellowLabel: String = "Flüstern"
    var greenLabel: String = "Gespräch"

    enum LightState: String, Codable, CaseIterable, Identifiable {
        case off, red, yellow, green
        var id: String { rawValue }
    }
}

struct NoiseContent: Codable, Equatable {
    /// Schwelle in geschätzten dB(A), ab der die Anzeige „zu laut“ meldet.
    ///
    /// 75 dB(A) ist der obere Rand dessen, was bei Gruppenarbeit in einer
    /// Grundschulklasse gemessen wird (siehe `NoiseSkala`). Die frühere
    /// Schwelle entsprach rechnerisch etwa 67 dB(A) und schlug damit schon
    /// beim gewöhnlichen Unterrichtsgespräch an.
    var schwelleDb: Double = NoiseSkala.schwelleVorgabe
    /// Alte Schwelle 0…1 aus der Web-App-Rechnung. Bleibt nur stehen, damit
    /// ältere Stände beim Einlesen umgerechnet werden können.
    var threshold: Double = 0.55
    /// Alte Empfindlichkeit. Der Abgleich in dB hat sie abgelöst.
    var gain: Double = 1.0
    var style: NoiseStyle = .gauge
    var alert: Bool = true
    var title: String = "Lautstärke"

    enum NoiseStyle: String, Codable, CaseIterable, Identifiable {
        case gauge, bars, lamp
        var id: String { rawValue }
        var title: String {
            switch self {
            case .gauge: return "Tacho"
            case .bars: return "Balken"
            case .lamp: return "Lampe"
            }
        }
    }
}

struct ChecklistItem: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var text: String = ""
    var done: Bool = false
    var emoji: String = ""
}

struct ChecklistContent: Codable, Equatable {
    var title: String = "Unser Tag"
    var items: [ChecklistItem] = []
    var showProgress: Bool = true
    /// Erledigte Punkte durchstreichen.
    var strikeDone: Bool = true
    /// Eingabefeld direkt auf der Karte (nur beim Bearbeiten sichtbar).
    var quickAdd: Bool = true
    /// Hakt sich beim ersten Öffnen an einem neuen Tag selbst wieder frei.
    var resetDaily: Bool = false
    /// Tag (yyyy-MM-dd) des letzten automatischen Zurücksetzens.
    var lastResetDay: String = ""
}

struct NamePickerContent: Codable, Equatable {
    /// Eigene Überschrift des Elements — leer heißt: Name der Liste.
    ///
    /// Wer mehrere Ziehungen auf einer Tafel hat („Wer liest vor?“,
    /// „Wer räumt auf?“), braucht sie auseinanderzuhalten. Anders als der
    /// Listenname hängt eine selbst gesetzte Überschrift NICHT an der
    /// Tafelregel „Beschriftungen“: Sie sagt, worum es geht.
    var title: String = ""
    /// ID der verwendeten Namensliste.
    var listID: String? = nil
    var mode: DrawMode = .withoutRepeat
    /// Bereits gezogene Namen (IDs der Listeneinträge, in Ziehreihenfolge).
    var drawnIDs: [String] = []
    /// Zuletzt gezogener Eintrag.
    var currentID: String? = nil
    var showHistory: Bool = true
    /// Wann die Liste der gezogenen Namen zu sehen ist.
    var showDrawn: ShowRule = .always
    var animate: Bool = true
    /// Klang, während die Namen durchlaufen.
    var spinSound: SpinSound = .karten
    /// Wie ein gezogener Name sichtbar wird.
    var reveal: RevealMode = .mosaik
    /// Bereits aufgedeckte Teile des aktuellen Namens.
    var revealParts: [Int] = []

    // MARK: Gruppen und Tagesgruppe

    /// Was dieses Element auslost.
    var modus: Ziehmodus = .einzel
    /// Eigene Überschrift der Gruppenziehung (leer = Vorgabe des Modus).
    ///
    /// Je Modus eine eigene: Wer bei „Gruppen“ „Partnerarbeit“ schreibt und
    /// bei „Tagesgruppe“ „Klassendienst“, bekommt beim Umschalten den
    /// jeweils passenden Namen zurück.
    var titelGruppen: String = ""
    var titelTagesgruppe: String = ""
    /// Wie viele Namen in eine Gruppe gehören (1 … 15).
    var gruppenGroesse: Int = 2
    /// Wie viele Namen die Tagesgruppe umfasst.
    var tagesgruppeAnzahl: Int = 1
    /// Merkmal, nach dem sortiert wird. Leer heißt: das erste der Liste.
    var mischMerkmalID: String = ""
    /// Wie die Merkmale in einer Gruppe stehen sollen.
    var merkmalsvorgabe: Merkmalsvorgabe = .unterschiedlich
    /// Altfeld: „als Checkliste zeigen". Was gilt, steht in `anzeige`.
    var alsCheckliste: Bool = false
    /// Wie das Ergebnis gezeigt wird.
    var anzeige: Ergebnisanzeige = .normal {
        didSet { alsCheckliste = (anzeige == .abhaken) }
    }
    /// Zählerstand je Name (Kennung → Anzahl). Nur in der Zählansicht.
    var zaehler: [String: Int] = [:]
    /// Farbe der Namenskärtchen. **Leer heißt: wie bisher** — eine ruhige
    /// Aufhellung des Untergrunds. `kartenfarbe2` gefüllt ergibt einen
    /// Verlauf (siehe `Fuellung`).
    var kartenfarbe: String = ""
    var kartenfarbe2: String = ""
    /// Ergebnis festgehalten: Es löst nichts mehr neu aus, abhaken geht.
    var festgehalten: Bool = false
    /// Das Ergebnis der letzten Auslosung, in Ziehreihenfolge.
    var ergebnis: [String] = []
    /// Abgehakte Zeilen — die Kennung des ersten Namens der Zeile.
    var erledigt: [String] = []
    /// Die letzten Auslosungen dieses Elements, neueste zuerst.
    ///
    /// Bewusst **am Element**, nicht an der Namensliste: „Sitzplätze" und
    /// „Kinder des Tages" ziehen aus derselben Klasse, sind aber zwei
    /// verschiedene Dinge. Lägen Archiv und Gedächtnis bei der Liste,
    /// schwappten die Ziehungen der einen Kachel in die andere.
    var ziehungen: [Ziehung] = []
    /// Wie oft zwei Namen in **diesem Element** schon zusammen waren
    /// (Schlüssel aus `Auslosung.paar`), bzw. wie oft jemand einzeln gezogen
    /// wurde (`Auslosung.einzel`). Danach richtet sich, wen die nächste
    /// Ziehung bevorzugt.
    var paare: [String: Int] = [:]

    /// So viele Auslosungen bleiben stehen. Danach fällt die älteste heraus:
    /// Ein Archiv, das ewig wächst, wandert bei jedem Abgleich mit — und es
    /// hängt jetzt an der Tafel, nicht an der Namensliste.
    static let archivGrenze = 40

    /// Kennung des Archiveintrags, zu dem das aktuelle Ergebnis gehört.
    ///
    /// Solange sie steht, gilt jede weitere Auslosung ab einer Stelle als
    /// **Korrektur desselben Vorgangs** — der Eintrag wird fortgeschrieben,
    /// nicht ein zweiter angelegt. „Neu auslosen" beginnt einen neuen.
    var ziehungID: String = ""

    /// Überschrift, die zum gewählten Modus gehört.
    var ueberschrift: String {
        get {
            switch modus {
            case .einzel:      return title
            case .gruppen:     return titelGruppen
            case .tagesgruppe: return titelTagesgruppe
            }
        }
        set {
            switch modus {
            case .einzel:      title = newValue
            case .gruppen:     titelGruppen = newValue
            case .tagesgruppe: titelTagesgruppe = newValue
            }
        }
    }

    /// Wie viele Namen nebeneinander stehen.
    var proZeile: Int {
        modus == .tagesgruppe ? 1 : max(1, min(gruppenGroesse, 15))
    }

    /// Das Ergebnis in Zeilen zerlegt — die letzte darf unvollständig sein.
    var zeilen: [[String]] {
        let breite = proZeile
        guard !ergebnis.isEmpty else { return [] }
        return stride(from: 0, to: ergebnis.count, by: breite).map { anfang in
            Array(ergebnis[anfang..<min(anfang + breite, ergebnis.count)])
        }
    }

    /// Nach welchem Merkmal wirklich sortiert wird — nil heißt: nach keinem.
    ///
    /// Hat die Liste genau ein Merkmal, braucht niemand es auszuwählen.
    func merkmal(in liste: NameList?) -> String? {
        guard merkmalsvorgabe != .egal, let liste, !liste.merkmale.isEmpty else { return nil }
        if let gewaehlt = mischMerkmalID.nonEmpty,
           liste.merkmale.contains(where: { $0.id == gewaehlt }) {
            return gewaehlt
        }
        return liste.merkmale.first?.id
    }

    /// Schlüssel, unter dem eine Zeile als erledigt vermerkt wird.
    static func zeilenSchluessel(_ zeile: [String]) -> String { zeile.first ?? "" }

    // MARK: Buchführung

    /// Schreibt das Ergebnis einer Auslosung fort — Archiv und Gedächtnis.
    ///
    /// **Ein Vorgang, ein Eintrag.** Wer ab einer Stelle neu auslost, hat
    /// berichtigt, nicht zweimal ausgelost: Der erste Entwurf ist nie
    /// zustande gekommen, und weder das Archiv noch das Gedächtnis sollen
    /// ihn kennen. Deshalb wird bei einer Berichtigung der bisherige Eintrag
    /// ersetzt und seine Paarzählung zurückgenommen.
    ///
    /// - Parameters:
    ///   - ids: das Ergebnis, das jetzt gilt. Leer heißt: Der Vorgang wird
    ///     verworfen.
    ///   - vorher: das Ergebnis, das dadurch abgelöst wird — es wird aus dem
    ///     Gedächtnis herausgerechnet.
    ///   - ersetzt: Kennung des Eintrags, der fortgeschrieben wird.
    ///     nil = neuer Vorgang.
    ///   - liste: für die Namen, die ins Archiv geschrieben werden.
    /// - Returns: Kennung des Eintrags, der jetzt gilt (leer, wenn keiner).
    @discardableResult
    mutating func merkeZiehung(_ ids: [String], vorher: [String] = [],
                               ersetzt: String? = nil, liste: NameList?) -> String {
        if !vorher.isEmpty { zaehle(vorher, richtung: -1) }
        if let ersetzt, !ersetzt.isEmpty { ziehungen.removeAll { $0.id == ersetzt } }

        guard !ids.isEmpty else { return "" }

        var eintrag = Ziehung()
        // Kennung behalten: Es ist derselbe Vorgang, nur berichtigt.
        if let ersetzt, !ersetzt.isEmpty { eintrag.id = ersetzt }
        eintrag.modus = modus.rawValue
        eintrag.proZeile = max(1, proZeile)
        eintrag.titel = ueberschrift.nonEmpty ?? modus.standardUeberschrift
        eintrag.texte = ids.map { id in
            liste?.entries.first { $0.id == id }?.text ?? "—"
        }
        ziehungen.insert(eintrag, at: 0)
        if ziehungen.count > NamePickerContent.archivGrenze {
            ziehungen = Array(ziehungen.prefix(NamePickerContent.archivGrenze))
        }
        zaehle(ids, richtung: 1)
        return eintrag.id
    }

    /// Archiv und Gedächtnis dieses Elements leeren.
    mutating func setzeZiehungenZurueck() {
        ziehungen = []
        paare = [:]
    }

    /// Zählt die Paarungen einer Ziehung hinauf (`richtung` 1) oder wieder
    /// herunter (−1). Bei null verschwindet der Eintrag: Eine Tabelle voller
    /// Nullen wandert sonst bei jedem Abgleich mit.
    private mutating func zaehle(_ ids: [String], richtung: Int) {
        func aendere(_ schluessel: String) {
            let neu = max(0, (paare[schluessel] ?? 0) + richtung)
            if neu == 0 { paare[schluessel] = nil } else { paare[schluessel] = neu }
        }

        if modus == .tagesgruppe {
            for id in ids { aendere(Auslosung.einzel(id)) }
            return
        }
        let breite = max(1, proZeile)
        var anfang = 0
        while anfang < ids.count {
            let gruppe = Array(ids[anfang..<min(anfang + breite, ids.count)])
            for (stelle, a) in gruppe.enumerated() {
                for b in gruppe.dropFirst(stelle + 1) { aendere(Auslosung.paar(a, b)) }
            }
            anfang += breite
        }
    }

    enum DrawMode: String, Codable, CaseIterable, Identifiable {
        /// Gezogene Namen kommen erst zurück, wenn die Liste durch ist.
        case withoutRepeat
        /// Bei jedem Zug stehen alle Namen wieder zur Verfügung.
        case withReplacement
        var id: String { rawValue }
        var title: String {
            switch self {
            case .withoutRepeat: return "Ohne Wiederholung"
            case .withReplacement: return "Immer alle Namen"
            }
        }
        var explanation: String {
            switch self {
            case .withoutRepeat:
                return "Ein gezogener Name kommt erst wieder in den Topf, wenn die ganze Liste durch ist."
            case .withReplacement:
                return "Bei jedem Zug stehen alle Namen der Liste zur Verfügung."
            }
        }
    }
}

/// Seitenverhältnis der Tafelfläche.
///
/// Die **Breite bleibt bei 1600 Punkten**, nur die Höhe ändert sich. Dadurch
/// behalten alle Elemente ihre Lage, wenn das Format gewechselt wird — nur
/// wer unten überstand, rückt herein.
enum Tafelformat: String, Codable, CaseIterable, Identifiable {
    /// 16:10 — die bisherige Fläche.
    case breit
    /// 16:9 — das Format der meisten Beamer und Bildschirme.
    case kino
    /// 4:3 — ältere Beamer und viele fest verbaute Tafeln.
    case klassisch

    var id: String { rawValue }

    var hoehe: Double {
        switch self {
        case .breit:     return 1000
        case .kino:      return 900
        case .klassisch: return 1200
        }
    }

    var title: String {
        switch self {
        case .breit:     return "16:10"
        case .kino:      return "16:9"
        case .klassisch: return "4:3"
        }
    }

    var erklaerung: String {
        switch self {
        case .breit:
            return "Etwas höher als ein Beamerbild — die bisherige Fläche."
        case .kino:
            return "Das Format der meisten Beamer und Bildschirme. Am Beamer bleiben damit keine Balken."
        case .klassisch:
            return "Hoch und kompakt — für ältere Beamer und viele fest verbaute Tafeln."
        }
    }
}

/// Wie das Ergebnis einer Ziehung gezeigt wird.
enum Ergebnisanzeige: String, Codable, CaseIterable, Identifiable {
    /// Nur die Namen.
    case normal
    /// Je Zeile ein Haken — welche Gruppe ist fertig?
    case abhaken
    /// Je Name ein Zähler — wie oft hat sich das Kind beteiligt?
    case zaehlen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal:  return "Nur Namen"
        case .abhaken: return "Abhaken"
        case .zaehlen: return "Zählen"
        }
    }

    var erklaerung: String {
        switch self {
        case .normal:
            return "Nur die Namen — nichts zum Antippen."
        case .abhaken:
            return "Jede Zeile bekommt einen Haken. So lässt sich festhalten, welche Gruppe eine Aufgabe schon erledigt hat."
        case .zaehlen:
            return "Jeder Name bekommt einen Zähler: Ein Tipp zählt eine Stufe hoch, langes Drücken wieder herunter. So lässt sich mitschreiben, wie oft sich jedes Kind beteiligt hat."
        }
    }
}

/// Wie die Merkmale innerhalb einer Gruppe stehen sollen.
enum Merkmalsvorgabe: String, Codable, CaseIterable, Identifiable {
    /// Merkmale spielen keine Rolle.
    case egal
    /// Jede Gruppe mischt — ein Junge und ein Mädchen zusammen.
    case unterschiedlich
    /// Jede Gruppe besteht möglichst aus gleichen Merkmalen — reine
    /// Jungen- und Mädchengruppen, gleiche Lesestufen.
    case gleich

    var id: String { rawValue }

    var title: String {
        switch self {
        case .egal:            return "Egal"
        case .unterschiedlich: return "Unterschiedlich"
        case .gleich:          return "Gleich"
        }
    }

    var erklaerung: String {
        switch self {
        case .egal:
            return "Merkmale spielen beim Auslosen keine Rolle."
        case .unterschiedlich:
            return "Jede Gruppe mischt die Merkmale — zum Beispiel ein Junge und ein Mädchen zusammen."
        case .gleich:
            return "Jede Gruppe besteht nach Möglichkeit aus gleichen Merkmalen — zum Beispiel reine Jungen- und Mädchengruppen oder gleiche Lesestufen."
        }
    }
}

/// Was ein Zufallsgenerator auslost.
enum Ziehmodus: String, Codable, CaseIterable, Identifiable {
    /// Ein Name, wie bisher — mit Aufdecken und Raten.
    case einzel
    /// Alle Namen auf Gruppen verteilt.
    case gruppen
    /// Eine Handvoll Namen für heute — Dienste, Helferinnen, Vorleser.
    case tagesgruppe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .einzel:      return "Einzelner Name"
        case .gruppen:     return "Gruppen"
        case .tagesgruppe: return "Tagesgruppe"
        }
    }

    var symbol: String {
        switch self {
        case .einzel:      return "person.fill"
        case .gruppen:     return "person.2.fill"
        case .tagesgruppe: return "person.3.fill"
        }
    }

    var erklaerung: String {
        switch self {
        case .einzel:
            return "Ein Name aus der Liste. Er lässt sich Stück für Stück aufdecken, damit die Klasse mitraten darf."
        case .gruppen:
            return "Alle Namen werden auf Gruppen verteilt und stehen als gleich große Kärtchen nebeneinander."
        case .tagesgruppe:
            return "Ein paar Namen für heute — untereinander, zum Beispiel für die Dienste."
        }
    }

    /// Was über dem Ergebnis steht, solange nichts Eigenes eingetragen ist.
    var standardUeberschrift: String {
        switch self {
        case .einzel:      return ""
        case .gruppen:     return "Gruppen"
        case .tagesgruppe: return "Heute dran"
        }
    }
}

/// Art, wie ein gezogener Name sichtbar wird — die Klasse darf raten.
enum RevealMode: String, Codable, CaseIterable, Identifiable {
    /// Der Name steht sofort da.
    case instant
    /// Feine Kacheln verschwinden nach und nach — zwölf Tipps.
    case mosaik
    /// Erst ein Farbnebel, mit jedem Tipp schärfer — zehn Tipps.
    case blur
    /// Ein Buchstabe nach dem anderen.
    case letters

    var id: String { rawValue }

    var title: String {
        switch self {
        case .instant: return "Sofort"
        case .mosaik:  return "Mosaik"
        case .blur:    return "Unschärfe"
        case .letters: return "Buchstaben"
        }
    }

    var explanation: String {
        switch self {
        case .instant: return "Der Name steht sofort da."
        case .mosaik:  return "Feine Kacheln verschwinden nach und nach — zwölf Tipps bis zum ganzen Namen."
        case .blur:    return "Erst nur ein Farbnebel, mit jedem Tipp schärfer — zehn Tipps."
        case .letters: return "Ein Buchstabe nach dem anderen erscheint."
        }
    }
}

/// Maße des Mosaiks — bewusst fein, damit ein Tipp wenig verrät.
/// (Die geltenden Werte stehen in `MosaikMasse`; `blurSteps` gilt weiter.)
enum RevealLayout {
    static let mosaicColumns = 14
    static let mosaicRows = 5
    static var mosaicTiles: Int { mosaicColumns * mosaicRows }
    static let mosaicSteps = 12
    static var mosaicPerTap: Int { Int(ceil(Double(mosaicTiles) / Double(mosaicSteps))) }
    static let blurSteps = 10
}

struct SoundButton: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var label: String = ""
    var emoji: String = "🔔"
    var colorHex: String = "#0f9b8e"
    /// Zweite Farbe des Feldes. Leer heißt: einfarbig.
    var colorHex2: String = ""
    /// Dateiname unter Documents/Media/ (nil = leeres Feld).
    var fileName: String? = nil
    /// Adresse einer Klangdatei im Netz — die reist beim Teilen mit.
    var url: String = ""
    var volume: Double = 1.0
    /// Beim erneuten Antippen stoppen statt neu starten.
    var toggle: Bool = false

    /// Ist überhaupt etwas zum Abspielen hinterlegt?
    var hasSource: Bool { fileName != nil || url.nonEmpty != nil }
}

struct SoundsContent: Codable, Equatable {
    var buttons: [SoundButton] = []
    var showLabels: Bool = true
}

// MARK: - Element (Widget)

/// Arbeitsformen, die als großes Symbol an der Tafel stehen.
enum WorkSymbol: String, Codable, CaseIterable, Identifiable {
    case einzel
    case partner
    case gruppe
    case still
    case fluestern
    case melden
    case zuhoeren
    case aufraeumen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .einzel:     return "Einzelarbeit"
        case .partner:    return "Partnerarbeit"
        case .gruppe:     return "Gruppenarbeit"
        case .still:      return "Stillarbeit"
        case .fluestern:  return "Flüsterstimme"
        case .melden:     return "Melden"
        case .zuhoeren:   return "Zuhören"
        case .aufraeumen: return "Aufräumen"
        }
    }

    var systemImage: String {
        switch self {
        case .einzel:     return "person.fill"
        case .partner:    return "person.2.fill"
        case .gruppe:     return "person.3.fill"
        case .still:      return "speaker.slash.fill"
        case .fluestern:  return "speaker.wave.1.fill"
        case .melden:     return "hand.raised.fill"
        case .zuhoeren:   return "ear.fill"
        case .aufraeumen: return "shippingbox.fill"
        }
    }

    /// Nächste Arbeitsform — Antippen schaltet der Reihe nach weiter.
    var next: WorkSymbol {
        let alle = WorkSymbol.allCases
        let index = alle.firstIndex(of: self) ?? 0
        return alle[(index + 1) % alle.count]
    }
}

/// Dokumentenkamera: Livebild der Gerätekamera, wahlweise eingefroren.
struct KameraContent: Codable, Equatable {
    /// Eingefrorenes Bild unter Documents/Media. nil = das Livebild läuft.
    ///
    /// Das Standbild ist eine gewöhnliche Bilddatei und reist deshalb wie
    /// jedes andere Bild über iCloud mit — wer die Tafel teilt, sieht das
    /// festgehaltene Heft, nicht die Kamera des anderen.
    var eingefroren: String? = nil
    var caption: String = ""
    /// Bild füllend zeigen (Vorgabe) oder ganz, mit Rändern.
    var fuellend: Bool = true

    var haeltStand: Bool { eingefroren != nil }
}

struct VideoContent: Codable, Equatable {
    /// Datei unter Documents/Media — bleibt bewusst auf diesem Gerät.
    var fileName: String? = nil
    /// Adresse eines Videos im Netz; die reist beim Teilen mit.
    var url: String = ""
    /// Anzeigename der gewählten Datei (nur zur Anzeige im Einstellungsblatt).
    var sourceLabel: String = ""
    var caption: String = ""
    var loop: Bool = false
    var showControls: Bool = true
    var muted: Bool = false

    /// Adresse, aus der abgespielt wird — Datei hat Vorrang vor dem Link.
    var playbackURL: URL? {
        if let fileName, MediaStore.exists(fileName) { return MediaStore.url(fileName) }
        if let trimmed = url.nonEmpty { return URL(string: trimmed) }
        return nil
    }

    /// Es ist eine Datei hinterlegt, die auf diesem Gerät fehlt.
    var fileMissing: Bool {
        guard let fileName else { return false }
        return !MediaStore.exists(fileName)
    }
}

struct SymbolContent: Codable, Equatable {
    var symbol: WorkSymbol = .einzel
    var showLabel: Bool = true
}

enum WidgetContent: Equatable {
    case namePicker(NamePickerContent)
    case timer(TimerContent)
    case clock(ClockContent)
    case trafficLight(TrafficLightContent)
    case noise(NoiseContent)
    case checklist(ChecklistContent)
    case text(TextContent)
    case image(ImageContent)
    case sounds(SoundsContent)
    case symbols(SymbolContent)
    case video(VideoContent)
    case kamera(KameraContent)
    case geburtstag(GeburtstagContent)
    case sitzplan(SitzplanContent)

    var kind: WidgetKind {
        switch self {
        case .namePicker:   return .namePicker
        case .timer:        return .timer
        case .clock:        return .clock
        case .trafficLight: return .trafficLight
        case .noise:        return .noise
        case .checklist:    return .checklist
        case .text:         return .text
        case .image:        return .image
        case .sounds:       return .sounds
        case .symbols:      return .symbols
        case .video:        return .video
        case .kamera:       return .kamera
        case .geburtstag:   return .geburtstag
        case .sitzplan:     return .sitzplan
        }
    }

    static func makeDefault(for kind: WidgetKind) -> WidgetContent {
        switch kind {
        case .namePicker:   return .namePicker(NamePickerContent())
        case .timer:        return .timer(TimerContent())
        case .clock:        return .clock(ClockContent())
        case .trafficLight: return .trafficLight(TrafficLightContent())
        case .noise:        return .noise(NoiseContent())
        case .checklist:    return .checklist(ChecklistContent(items: [
            ChecklistItem(text: "Ankommen und Morgenkreis", emoji: "☀️"),
            ChecklistItem(text: "Deutsch", emoji: "📖"),
            ChecklistItem(text: "Frühstück und Pause", emoji: "🍎"),
            ChecklistItem(text: "Mathe", emoji: "➗"),
            ChecklistItem(text: "Abschlussrunde", emoji: "👋")
        ]))
        case .text:         return .text(TextContent())
        case .image:        return .image(ImageContent())
        case .symbols:      return .symbols(SymbolContent())
        case .video:        return .video(VideoContent())
        // Ein Feld, wie in der Web-App (`sound.js`: `entries: [defaultEntry()]`).
        // Drei vorgefertigte Felder waren gut gemeint, aber wer nur einen
        // Klang braucht, muss erst zwei wegräumen.
        case .sounds:       return .sounds(SoundsContent(buttons: [
            SoundButton(label: "Klang", emoji: "🔔", colorHex: "#0f9b8e")
        ]))
        case .kamera:       return .kamera(KameraContent())
        case .geburtstag:   return .geburtstag(GeburtstagContent())
        // Dreißig Plätze als Anfang, paarweise in Reihen. Wer sie
        // einzeln aus einer Ecke ziehen müsste, gäbe vorher auf.
        case .sitzplan:     return .sitzplan(SitzplanContent(
            plaetze: Sitzordnung.vorschlag(anzahl: 30, raum: .quer)))
        }
    }
}

// Ausdrückliches Codable mit „type"-Kennung: So bleiben gespeicherte Tafeln
// auch dann lesbar, wenn später neue Elementtypen dazukommen.
extension WidgetContent: Codable {
    private enum Keys: String, CodingKey { case type, data }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let kind = try container.decode(WidgetKind.self, forKey: .type)
        switch kind {
        case .namePicker:   self = .namePicker(try container.decode(NamePickerContent.self, forKey: .data))
        case .timer:        self = .timer(try container.decode(TimerContent.self, forKey: .data))
        case .clock:        self = .clock(try container.decode(ClockContent.self, forKey: .data))
        case .trafficLight: self = .trafficLight(try container.decode(TrafficLightContent.self, forKey: .data))
        case .noise:        self = .noise(try container.decode(NoiseContent.self, forKey: .data))
        case .checklist:    self = .checklist(try container.decode(ChecklistContent.self, forKey: .data))
        case .text:         self = .text(try container.decode(TextContent.self, forKey: .data))
        case .image:        self = .image(try container.decode(ImageContent.self, forKey: .data))
        case .sounds:       self = .sounds(try container.decode(SoundsContent.self, forKey: .data))
        case .symbols:      self = .symbols(try container.decode(SymbolContent.self, forKey: .data))
        case .video:        self = .video(try container.decode(VideoContent.self, forKey: .data))
        case .kamera:       self = .kamera(try container.decode(KameraContent.self, forKey: .data))
        case .geburtstag:   self = .geburtstag(try container.decode(GeburtstagContent.self, forKey: .data))
        case .sitzplan:     self = .sitzplan(try container.decode(SitzplanContent.self, forKey: .data))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(kind, forKey: .type)
        switch self {
        case .namePicker(let value):   try container.encode(value, forKey: .data)
        case .timer(let value):        try container.encode(value, forKey: .data)
        case .clock(let value):        try container.encode(value, forKey: .data)
        case .trafficLight(let value): try container.encode(value, forKey: .data)
        case .noise(let value):        try container.encode(value, forKey: .data)
        case .checklist(let value):    try container.encode(value, forKey: .data)
        case .text(let value):         try container.encode(value, forKey: .data)
        case .image(let value):        try container.encode(value, forKey: .data)
        case .sounds(let value):       try container.encode(value, forKey: .data)
        case .symbols(let value):      try container.encode(value, forKey: .data)
        case .video(let value):        try container.encode(value, forKey: .data)
        case .kamera(let value):       try container.encode(value, forKey: .data)
        case .geburtstag(let value):   try container.encode(value, forKey: .data)
        case .sitzplan(let value):     try container.encode(value, forKey: .data)
        }
    }
}

/// Ob ein einzelnes Element seine Beschriftungen zeigt.
enum WidgetLabelRegel: String, Codable, CaseIterable, Identifiable {
    /// Der Tafelregel folgen (Vorgabe).
    case tafel
    case immer
    case nie

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tafel: return "Wie die Tafel"
        case .immer: return "Immer zeigen"
        case .nie:   return "Nie zeigen"
        }
    }

    func gilt(tafel: Bool) -> Bool {
        switch self {
        case .tafel: return tafel
        case .immer: return true
        case .nie:   return false
        }
    }
}

/// Wie ein Element auf der Tafel steht.
///
/// „Wie die Tafel“ folgt der Regel unter „Aussehen“ → „Rahmen“; die drei
/// anderen setzen sich darüber hinweg. Die Werte `tafel`, `immer` und `nie`
/// heißen absichtlich wie bei den Beschriftungen: Tafeln, die vor dieser
/// Fassung gespeichert wurden, lesen sich damit unverändert.
enum WidgetKarte: String, Codable, CaseIterable, Identifiable {
    case tafel
    /// Volle Karte — helle Fläche mit Rand.
    case immer
    /// Nur ein Rand; der Hintergrund der Tafel bleibt zu sehen.
    case rahmen
    /// Nichts — der Inhalt steht frei auf der Tafel.
    case nie

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tafel:  return "Wie die Tafel"
        case .immer:  return "Karte"
        case .rahmen: return "Nur Rahmen"
        case .nie:    return "Ohne"
        }
    }

    /// Was tatsächlich gilt, wenn die Tafelregel bekannt ist.
    func gilt(tafel: Bool) -> WidgetKarte {
        self == .tafel ? (tafel ? .immer : .nie) : self
    }

    var symbol: String {
        switch self {
        case .tafel, .immer: return "square.on.square"
        case .rahmen:        return "square"
        case .nie:           return "square.slash"
        }
    }

    /// Reihenfolge beim Durchtippen in der Werkzeugleiste.
    var naechste: WidgetKarte {
        switch self {
        case .tafel, .immer: return .rahmen
        case .rahmen:        return .nie
        case .nie:           return .immer
        }
    }
}

struct BoardWidget: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    /// Lage in Tafelpunkten (0…1600 / 0…1000).
    var x: Double = 100
    var y: Double = 100
    var width: Double = 400
    var height: Double = 300
    /// Stapelreihenfolge — größer liegt weiter vorn.
    var z: Int = 0
    /// Festgesteckt: lässt sich nicht mehr aus Versehen verschieben.
    var locked: Bool = false
    /// Ohne Karte — das Element steht frei auf der Tafel.
    ///
    /// Altfeld: Was wirklich gilt, steht in `karte`. Es wird weiter
    /// mitgeschrieben, damit ein Geraet mit aelterer Fassung die Tafel noch
    /// richtig zeichnet.
    var bare: Bool = false
    /// Traegt dieses Element eine Karte?
    ///
    /// Frueher entschied das allein die Tafelregel unter „Aussehen“ — stand
    /// sie auf „Nie“, blieb der Schalter am Element wirkungslos. Jetzt gilt
    /// dieselbe Ordnung wie bei den Beschriftungen: „Wie die Tafel“ ist die
    /// Vorgabe, „Immer“ und „Nie“ setzen sich darueber hinweg.
    var karte: WidgetKarte = .tafel {
        didSet { bare = (karte != .immer && karte != .tafel) }
    }
    /// iCloud-Kennung derjenigen, die dieses Element angelegt hat.
    ///
    /// Daran hängt das Löschrecht auf geteilten Tafeln (siehe
    /// `Loeschrecht`). **Leer heißt: vor dieser Fassung angelegt** — solche
    /// Elemente werden der Besitzerin zugerechnet. Das ist die vorsichtige
    /// Richtung: Es geht dabei nichts verloren, und die Besitzerin kann sie
    /// weiterhin löschen.
    var erstelltVon: String = ""
    /// Auf welcher Seite das Element liegt. **Leer heißt: erste Seite** —
    /// so gehören alle Elemente älterer Tafeln von selbst auf Seite 1.
    var pageID: String = ""
    /// Beschriftungen dieses Elements — unabhängig von der Tafelregel.
    ///
    /// Die Regel unter „Aussehen“ gilt für die ganze Tafel; hier entscheidet
    /// jedes Element für sich. „Wie die Tafel“ ist die Vorgabe und ändert
    /// nichts am bisherigen Verhalten.
    var labels: WidgetLabelRegel = .tafel
    /// Größe der Überschrift, 1 = wie vorgesehen.
    ///
    /// Überschriften sind für die letzte Reihe gedacht; wie groß sie sein
    /// müssen, hängt vom Raum ab. Deshalb je Element einstellbar.
    var labelSize: Double = 1
    /// Eigene Schriftfarbe dieses Elements (Hex). **Leer heißt: wie die
    /// Tafel** — dann gilt `Board.schriftfarbe`, und ist auch die leer, die
    /// automatische Farbe.
    var schriftfarbe: String = ""
    /// Nur für mich ausgeblendet.
    ///
    /// Gehört zur Anordnung, nicht zum Inhalt: Auf einer geteilten Tafel
    /// darf jede Person für sich entscheiden, was sie sehen will, ohne es
    /// den anderen wegzunehmen. Löschen entfernt es dagegen für alle.
    var versteckt: Bool = false
    var content: WidgetContent

    var kind: WidgetKind { content.kind }

    var rect: CGRect {
        get { CGRect(x: x, y: y, width: width, height: height) }
        set {
            x = newValue.origin.x
            y = newValue.origin.y
            width = newValue.width
            height = newValue.height
        }
    }

    /// Hält das Element vollständig auf der Tafel.
    mutating func clampToCanvas(hoehe: Double = Layout.canvasHeight) {
        width = min(max(width, Layout.minWidth), Layout.canvasWidth)
        height = min(max(height, Layout.minHeight), hoehe)
        x = min(max(x, 0), Layout.canvasWidth - width)
        y = min(max(y, 0), hoehe - height)
    }
}

// MARK: - Hintergrund

enum BoardBackground: Equatable {
    case solid(String)
    /// Zwei Farben (oben → unten).
    case gradient(String, String)
    /// Dateiname unter Documents/Media/ + Abdunklung 0…1.
    case image(String, Double)
    /// Bewegte Farbwolken — Kennung aus `AuroraPresets`.
    case aurora(String)
}

extension BoardBackground {
    /// Wirkt der Grund dunkel? Danach richtet sich die Handschrift.
    ///
    /// PencilKit zeichnet schwarze Tinte in dunkler Umgebung von selbst
    /// weiß — das ist genau richtig für eine Tafel. Dafür muss die
    /// Schreibebene aber wissen, worauf sie liegt: Auf hellem Grund bleibt
    /// Schwarz schwarz, auf dunklem wird es hell.
    var wirktDunkel: Bool {
        switch self {
        case .aurora:
            return true
        case .solid(let hex):
            return Self.dunkel(hex)
        case .gradient(let von, let bis):
            // Beide Enden zählen: Ein Verlauf von Dunkelblau nach Schwarz
            // ist dunkel, einer von Weiß nach Hellgrau nicht.
            return Self.dunkel(von) && Self.dunkel(bis)
        case .image(_, let abdunklung):
            // Ein Foto kann alles sein. Ab einer merklichen Abdunklung ist
            // es dunkel genug für helle Schrift; sonst lieber dunkle.
            return abdunklung >= 0.35
        }
    }

    private static func dunkel(_ hex: String) -> Bool {
        let sauber = hex.replacingOccurrences(of: "#", with: "")
        guard sauber.count == 6 else { return true }
        var wert: UInt64 = 0
        Scanner(string: sauber).scanHexInt64(&wert)
        let r = Double((wert >> 16) & 0xFF) / 255
        let g = Double((wert >> 8) & 0xFF) / 255
        let b = Double(wert & 0xFF) / 255
        return 0.299 * r + 0.587 * g + 0.114 * b < 0.55
    }
}

extension BoardBackground: Codable {
    private enum Keys: String, CodingKey { case type, a, b, dim }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "aurora":
            self = .aurora(try container.decodeIfPresent(String.self, forKey: .a) ?? "nordlicht")
        case "solid":
            self = .solid(try container.decode(String.self, forKey: .a))
        case "image":
            self = .image(try container.decode(String.self, forKey: .a),
                          try container.decodeIfPresent(Double.self, forKey: .dim) ?? 0.25)
        default:
            self = .gradient(try container.decode(String.self, forKey: .a),
                             try container.decode(String.self, forKey: .b))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        switch self {
        case .solid(let hex):
            try container.encode("solid", forKey: .type)
            try container.encode(hex, forKey: .a)
        case .gradient(let from, let to):
            try container.encode("gradient", forKey: .type)
            try container.encode(from, forKey: .a)
            try container.encode(to, forKey: .b)
        case .image(let file, let dim):
            try container.encode("image", forKey: .type)
            try container.encode(file, forKey: .a)
            try container.encode(dim, forKey: .dim)
        case .aurora(let id):
            try container.encode("aurora", forKey: .type)
            try container.encode(id, forKey: .a)
        }
    }

    /// Dateiname, falls ein Bild hinterlegt ist.
    var imageFileName: String? {
        if case .image(let name, _) = self { return name }
        return nil
    }
}

enum BackgroundPreset {
    /// Farbverläufe für die Auswahl im Tafel-Einstellungsblatt.
    static let gradients: [(String, String)] = [
        ("#134e4a", "#07242a"),
        ("#0f2027", "#203a43"),
        ("#1e1b4b", "#0b1020"),
        ("#232526", "#414345"),
        ("#3a1c71", "#1f1147"),
        ("#134e4a", "#0b2a27"),
        ("#7f1d1d", "#2b0d0d"),
        ("#0c4a6e", "#082f49"),
        ("#4a044e", "#1a032e"),
        ("#f8fafc", "#e2e8f0"),
        ("#fef3c7", "#fde68a")
    ]

    static let solids: [String] = [
        "#0f172a", "#1e293b", "#111827", "#052e16",
        "#0f9b8e", "#2dd4bf", "#f59e0b", "#ef4444",
        "#ffffff", "#e2e8f0"
    ]
}

// MARK: - Tafel

/// Eine Seite einer Tafel.
///
/// Eine Tafel kann mehrere Seiten haben — etwa eine je Unterrichtsstunde oder
/// je Fach. Jede Seite hat ihre eigenen Elemente und ihre eigene Handschrift;
/// Hintergrund, Farbschema und Namenslisten gelten für die ganze Tafel.
///
/// Ältere Tafeln haben gar keine Seiten eingetragen. Das ist Absicht und
/// bedeutet: genau eine Seite. Erst wer eine zweite anlegt, bekommt die Liste
/// wirklich gefüllt (siehe `seitenAnlegen`). So bleiben alte Stände lesbar,
/// auch auf Geräten mit einer älteren Fassung der App.
struct BoardPage: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    /// Leer = die App zeigt „Seite 1", „Seite 2" …
    var name: String = ""
    /// Handschrift dieser Seite (PencilKit, Base64).
    var drawing: String = ""
}

/// Wer auf einer geteilten Tafel Elemente löschen darf.
///
/// Entstanden aus einer Beobachtung im Betrieb: Eine Kollegin, mit der man
/// eine Tafel teilt, konnte darauf alles löschen — auch, was man selbst
/// mühsam eingerichtet hatte, und es verschwand dann bei allen. Für
/// gemeinsames Arbeiten ist das zu viel Zugriff.
///
/// Der Rest der Tafel bleibt gemeinsam: Wer darf, darf weiterhin anlegen,
/// verschieben und Inhalte ändern. Es geht allein ums Löschen — das ist der
/// einzige Schritt, der sich nicht zurücknehmen lässt.
///
/// Eingestellt wird das von der Person, der die Tafel gehört. **Der
/// Besitzerin gehört die Tafel, sie darf immer alles löschen.**
enum Loeschrecht: String, CaseIterable, Identifiable {
    /// Wie früher: Wer die Tafel sieht, darf sie auch aufräumen.
    case jeder
    /// Jede Person löscht nur, was sie selbst angelegt hat. **Vorgabe.**
    case eigene
    /// Nur die Besitzerin löscht. Die anderen dürfen anlegen und ändern.
    case nurBesitzer

    static let vorgabe: Loeschrecht = .eigene

    /// Aus dem gespeicherten Rohwert. Unbekanntes wird zur Vorgabe.
    static func aus(_ rohwert: String) -> Loeschrecht {
        Loeschrecht(rawValue: rohwert) ?? .vorgabe
    }

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .jeder:       return "Alle dürfen alles löschen"
        case .eigene:      return "Jede löscht nur Eigenes"
        case .nurBesitzer: return "Nur ich darf löschen"
        }
    }

    var hinweis: String {
        switch self {
        case .jeder:
            return "Wie eine Tafel im Lehrerzimmer: Wer sie sieht, darf sie "
                 + "auch abwischen."
        case .eigene:
            return "Was du angelegt hast, kann nur von dir gelöscht werden — "
                 + "und umgekehrt. Anlegen, verschieben und ändern dürfen "
                 + "weiterhin alle."
        case .nurBesitzer:
            return "Die anderen dürfen anlegen und ändern, aber nichts "
                 + "löschen — auch nicht das Eigene."
        }
    }

    var symbol: String {
        switch self {
        case .jeder:       return "person.2"
        case .eigene:      return "person.crop.circle.badge.checkmark"
        case .nurBesitzer: return "lock"
        }
    }
}

struct Board: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String = "Neue Tafel"
    var emoji: String = "🌟"
    var background: BoardBackground = .aurora("nordlicht")
    /// iCloud-Kennung dessen, der diesen Stand zuletzt gesichert hat.
    ///
    /// Daran erkennt der Abgleich, ob eine ankommende Fassung von einem
    /// eigenen Gerät stammt (dann zählt sie ganz) oder von jemand anderem
    /// (dann zählt nur der Inhalt, die eigene Anordnung bleibt).
    var zuletztVon: String = ""
    /// Kennung des Farbschemas aus `AccentSchemes`.
    var accent: String = "indigo"
    /// Eigenes Farbschema. Ist `accentVon` gefüllt, gilt es statt `accent`;
    /// `accentBis` leer heißt einfarbig (siehe Fuellung).
    var accentVon: String = ""
    var accentBis: String = ""
    /// Akzentfarbe als Verlauf (aus) oder als eine Farbe (an → aus).
    var gradient: Bool = true
    var cardStyle: CardStyle = .glass
    /// Seitenverhältnis der Tafelfläche.
    var format: Tafelformat = .breit
    /// Wann Rahmen um die Elemente zu sehen sind.
    var frames: ShowRule = .always
    /// Wann Überschriften und Hinweise in den Elementen zu sehen sind.
    var labels: ShowRule = .always
    /// Schriftfarbe für alle Elemente dieser Tafel (Hex). **Leer heißt:
    /// automatisch** — dann ergibt sich die Farbe wie bisher aus Kartenstil
    /// und Hintergrund (hell auf dunkel, dunkel auf hell).
    ///
    /// Nötig, seit Tafeln auch hell sein dürfen: Auf hellem Grund ging die
    /// weiße Schrift freistehender Elemente unter. Ein Element darf die
    /// Vorgabe mit `BoardWidget.schriftfarbe` überstimmen.
    var schriftfarbe: String = ""
    var widgets: [BoardWidget] = []
    /// Seiten der Tafel. Leer bedeutet: eine einzige Seite (siehe `BoardPage`).
    var pages: [BoardPage] = []
    /// Handschrift der ersten Seite (PencilKit, Base64). Ab der zweiten Seite
    /// steht sie in `pages`; dieses Feld bleibt für alte Stände erhalten.
    /// Reist mit der Tafel mit, damit Anmerkungen auf allen Geräten stehen.
    var drawing: String = ""
    /// Namen der Kolleginnen und Kollegen, die diese Tafel sehen
    /// (nur zur Anzeige — maßgeblich sind die iCloud-Kennungen unten).
    var members: [String] = []
    /// iCloud-Kennung der Person, der die Tafel gehört. Damit taucht eine
    /// Tafel auf allen Geräten derselben Apple-ID von selbst auf.
    var ownerUserID: String = ""
    /// iCloud-Kennungen aller Personen, die die Tafel sehen dürfen —
    /// wird beim Beitritt per Code ergänzt.
    var memberUserIDs: [String] = []
    // MARK: Geburtstage

    /// Beobachtet diese Tafel Geburtstage?
    ///
    /// Bewusst je Tafel und nicht je Namensliste: Eine Liste kann auf
    /// mehreren Tafeln liegen, und sonst tauchten die Seiten überall auf.
    var geburtstage: Bool = false
    /// Kennung der Namensliste, deren Geburtstage gelten. Leer = die erste
    /// Liste, die ein Zufallsnamen-Element dieser Tafel benutzt.
    var geburtstagsliste: String = ""
    /// Rohwert einer `Geburtstagserinnerung`.
    var geburtstagsErinnerung: String = Geburtstagserinnerung.vorgabe.rawValue
    /// Uhrzeit der Erinnerung, in Minuten seit Mitternacht. Vorgabe 8:00;
    /// beim Vortag greift stattdessen `geburtstagsZeitVortag`.
    var geburtstagsZeit: Int = 8 * 60
    /// Uhrzeit am Vortag. Vorgabe 15:00 — nach dem Unterricht.
    var geburtstagsZeitVortag: Int = 15 * 60

    /// Wer hier Elemente löschen darf — **Rohwert** eines `Loeschrecht`.
    ///
    /// Als Zeichenkette gespeichert, nicht als Aufzählung: Eine Tafel von
    /// einem neueren Gerät darf eine Regel nennen, die diese Fassung noch
    /// nicht kennt; sie bekommt dann die Vorgabe statt eines verworfenen
    /// Datensatzes.
    var loeschrecht: String = Loeschrecht.vorgabe.rawValue

    /// Sechsstelliger Einladungscode zum Teilen.
    ///
    /// Aus der Zeit der öffentlichen Datenbank. Seit die Tafeln privat liegen,
    /// wird nicht mehr über den Code geteilt, sondern über eine echte
    /// iCloud-Freigabe (`CKShare`). Das Feld bleibt, damit alte Stände weiter
    /// lesbar sind.
    var joinCode: String = Board.makeJoinCode()
    /// Ist für diese Tafel eine iCloud-Freigabe angelegt?
    ///
    /// Nur ein Merkzettel für die Anzeige und dafür, dass Bilder und Klänge
    /// sich an die Tafel hängen. Maßgeblich ist immer die Freigabe in der
    /// iCloud selbst.
    var geteilt: Bool = false
    var owner: String = ""
    var createdAtMs: Int64 = Date.nowMs
    var updatedAtMs: Int64 = Date.nowMs
    var deleted: Bool = false

    /// Kopien der Namenslisten, die diese Tafel benutzt.
    ///
    /// Sie reisen mit der Tafel mit, damit eine ankommende Tafel auf jedem
    /// Gerät sofort vollständig ist — auch wenn der eigene Datensatz der
    /// Liste (noch) nicht angekommen ist. Lokal bleibt das Feld leer; gefüllt
    /// wird es nur beim Hochladen, und beim Empfangen wandern die Listen in
    /// den gemeinsamen Bestand.
    var embeddedLists: [NameList] = []

    /// IDs aller Namenslisten, auf die Elemente dieser Tafel verweisen.
    var referencedListIDs: Set<String> {
        var ids = Set<String>()
        for widget in widgets {
            if case .namePicker(let content) = widget.content, let listID = content.listID {
                ids.insert(listID)
            }
            // Der Sitzplan hängt genauso an einer Liste — ohne diese Zeile
            // reiste sie beim Teilen nicht mit, und die Kollegin sähe einen
            // Plan ohne Namen.
            if case .sitzplan(let content) = widget.content, let listID = content.listID {
                ids.insert(listID)
            }
        }
        // Die Geburtstagsliste gehört dazu, auch ohne Zufallsnamen-Element:
        // An dieser Menge hängt, was beim Teilen mitreist. Ohne sie sähe
        // die Kollegin die Geburtstagsseiten nie.
        if geburtstage, let liste = geburtstagsliste.nonEmpty { ids.insert(liste) }
        return ids
    }

    /// Die Liste, deren Geburtstage für diese Tafel gelten.
    ///
    /// Ist keine ausgewählt, gilt die erste, die ein Zufallsnamen-Element
    /// benutzt — das ist fast immer die Klassenliste, und niemand muss
    /// etwas einstellen, damit es losgeht.
    func geburtstagslisteID(vorhanden: [NameList]) -> String? {
        if let gewaehlt = geburtstagsliste.nonEmpty,
           vorhanden.contains(where: { $0.id == gewaehlt }) {
            return gewaehlt
        }
        for widget in sortedWidgets {
            if case .namePicker(let inhalt) = widget.content,
               let listID = inhalt.listID,
               vorhanden.contains(where: { $0.id == listID }) {
                return listID
            }
        }
        return nil
    }

    static func makeJoinCode() -> String {
        // Ohne 0/O und 1/I — Codes werden auch mal vorgelesen.
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement() ?? "A" })
    }

    /// Alle Mediendateien, die diese Tafel auf diesem Gerät braucht.
    /// Danach richtet sich das Aufräumen — hier fehlt nichts.
    var referencedMedia: Set<String> {
        var names = syncedMedia
        for widget in widgets {
            if case .video(let content) = widget.content, let file = content.fileName {
                names.insert(file)
            }
        }
        return names
    }

    /// Mediendateien, die mit der Tafel in die Cloud gehen.
    ///
    /// Videos bleiben bewusst draußen: Sie sind schnell mehrere hundert
    /// Megabyte groß, das lohnt keine Übertragung an jedes Gerät. Wer ein
    /// Video teilen möchte, hinterlegt einen Link.
    var syncedMedia: Set<String> {
        var names = Set<String>()
        if let background = background.imageFileName { names.insert(background) }
        for widget in widgets {
            switch widget.content {
            case .image(let content):
                if let file = content.fileName { names.insert(file) }
            case .sounds(let content):
                for button in content.buttons {
                    if let file = button.fileName { names.insert(file) }
                }
            case .kamera(let content):
                if let file = content.eingefroren { names.insert(file) }
            case .timer(let content):
                // Der eigene Endklang reist mit: Sonst bliebe die Tafel auf
                // dem zweiten Gerät stumm, obwohl sie ihn eingestellt zeigt.
                if let file = content.endklangDatei { names.insert(file) }
            default:
                break
            }
        }
        return names
    }

    /// Eine fremde Fassung dieser Tafel einarbeiten — Inhalt übernehmen,
    /// eigene Anordnung behalten.
    ///
    /// Das ist die Regel für geteilte Tafeln: **Was auf der Tafel steht,
    /// gehört allen; wie es aussieht und wo es liegt, gehört jedem selbst.**
    /// Wer eine Tafel bekommt, sieht sie zunächst genau so, wie sie gedacht
    /// war (dann gibt es sie hier ja noch nicht, und alles wird übernommen).
    /// Ab da darf jede Person umräumen, ohne dass es den anderen die Tafel
    /// verstellt — und ohne dass ihr jemand beim Umräumen zusieht.
    ///
    /// Gemeinsam sind: Name und Symbol der Tafel, die Seiten, die
    /// Handschrift, die Mitglieder — und vor allem der **Inhalt der
    /// Elemente**. Gerade der Zufallsgenerator muss eins zu eins
    /// übertragen: Wer schon gezogen wurde, ist keine Ansichtssache.
    ///
    /// Persönlich bleiben: Lage, Größe, Stapelreihenfolge, Karte an oder
    /// aus, Festgestecktes, Seitenzugehörigkeit und Ausgeblendetes — dazu
    /// Hintergrund, Farbschema, Kartenstil, Rahmen- und Beschriftungsregel.
    ///
    /// Elemente, die die fremde Fassung nicht kennt, verschwinden: Löschen
    /// gilt für alle. Neue kommen so an, wie sie gedacht sind — nur nicht
    /// ausgeblendet, denn das war die Entscheidung des anderen.
    /// Was von einer gelöschten Tafel noch hochgeladen wird.
    ///
    /// Ein Löschvermerk und nichts weiter: Kennung, Löschzeichen und die
    /// beiden Zeitstempel, an denen die anderen Geräte erkennen, dass dieser
    /// Stand der neuere ist. Kein Name, keine Elemente, keine Namensliste,
    /// keine Handschrift, keine Mitglieder, keine iCloud-Kennung.
    ///
    /// Vorher ging die Tafel beim Löschen mit allem Inhalt erneut hinaus und
    /// blieb so mit den Vornamen der Kinder im Bereich der App stehen. Für
    /// das Durchreichen des Löschens war davon nie etwas nötig: Empfänger
    /// übernehmen `deleted` und blenden die Tafel aus (siehe
    /// `mitFremdemInhalt` und `BoardStore.visibleBoards`).
    func grabstein() -> Board {
        var leer = Board()
        leer.id = id
        leer.deleted = true
        leer.createdAtMs = createdAtMs
        leer.updatedAtMs = updatedAtMs
        leer.name = ""
        leer.emoji = ""
        leer.joinCode = ""
        leer.geteilt = false
        leer.widgets = []
        leer.pages = []
        leer.drawing = ""
        leer.members = []
        leer.memberUserIDs = []
        leer.ownerUserID = ""
        leer.owner = ""
        leer.zuletztVon = ""
        leer.embeddedLists = []
        return leer
    }

    /// Darf diese Person dieses Element löschen?
    ///
    /// Der Besitzerin gehört die Tafel — sie darf immer. Für alle anderen
    /// gilt, was unter `loeschrecht` eingestellt ist.
    ///
    /// **Ohne Kennungen wird nicht eingeschränkt.** Eine Tafel aus einem
    /// alten Stand hat keine `ownerUserID`, und ohne die ließe sich nicht
    /// einmal sagen, wem sie gehört. Dann gilt wie früher: Wer sie sieht,
    /// darf sie auch aufräumen.
    func darfLoeschen(_ widget: BoardWidget, wer kennung: String) -> Bool {
        guard !ownerUserID.isEmpty, !kennung.isEmpty else { return true }
        if kennung == ownerUserID { return true }
        switch Loeschrecht.aus(loeschrecht) {
        case .jeder:
            return true
        case .eigene:
            // Elemente ohne Vermerk stammen aus der Zeit vor dieser Fassung
            // und gehören damit der Besitzerin — nicht dieser Person hier.
            return !widget.erstelltVon.isEmpty && widget.erstelltVon == kennung
        case .nurBesitzer:
            return false
        }
    }

    func mitFremdemInhalt(_ fremd: Board) -> Board {
        var neu = self

        neu.name = fremd.name
        neu.emoji = fremd.emoji
        neu.pages = fremd.pages
        neu.drawing = fremd.drawing
        neu.members = fremd.members
        neu.memberUserIDs = fremd.memberUserIDs
        neu.ownerUserID = fremd.ownerUserID
        neu.owner = fremd.owner
        neu.joinCode = fremd.joinCode
        neu.createdAtMs = fremd.createdAtMs
        neu.updatedAtMs = fremd.updatedAtMs
        neu.deleted = fremd.deleted
        neu.zuletztVon = fremd.zuletztVon
        neu.embeddedLists = []

        neu.loeschrecht = fremd.loeschrecht

        neu.widgets = fremd.widgets.map { fremdes in
            guard var meines = widgets.first(where: { $0.id == fremdes.id }) else {
                var neues = fremdes
                neues.versteckt = false
                return neues
            }
            meines.content = fremdes.content
            // Wer es angelegt hat, steht ein für alle Mal fest. Es aus der
            // fremden Fassung zu übernehmen hieße, dass ein Gerät mit
            // älterem Stand den Vermerk beim Weiterreichen ausradiert.
            if meines.erstelltVon.isEmpty { meines.erstelltVon = fremdes.erstelltVon }
            return meines
        }

        // Was die fremde Fassung nicht mehr kennt, ist dort gelöscht worden.
        // Übernommen wird das nur, wenn die schreibende Person es auch
        // durfte — sonst bleibt das Element stehen.
        //
        // Das ist der eigentliche Riegel, nicht der ausgegraute Knopf drüben:
        // Ein Gerät mit älterem Stand kennt die Regel gar nicht und löscht
        // munter weiter. Hier kommt es trotzdem nicht durch.
        let bekannt = Set(fremd.widgets.map(\.id))
        let gerettet = widgets.filter {
            !bekannt.contains($0.id) && !neu.darfLoeschen($0, wer: fremd.zuletztVon)
        }
        neu.widgets.append(contentsOf: gerettet)

        return neu
    }

    var sortedWidgets: [BoardWidget] {
        widgets.sorted { $0.z < $1.z }
    }

    // MARK: - Seiten

    /// Die Seiten, wie die Oberfläche sie sieht: Sind keine eingetragen,
    /// ist es genau eine — mit der Handschrift aus `drawing`.
    var seiten: [BoardPage] {
        pages.isEmpty ? [BoardPage(id: "", name: "", drawing: drawing)] : pages
    }

    var hatMehrereSeiten: Bool { pages.count > 1 }

    /// Kennung der ersten Seite. Elemente ohne eigene Angabe gehören dorthin.
    /// Höhe der Tafelfläche in Tafelpunkten. Die Breite ist immer 1600.
    var hoehe: Double { format.hoehe }

    /// Nach einem Formatwechsel: alles wieder auf die Fläche holen.
    mutating func passeElementeAn() {
        for index in widgets.indices { widgets[index].clampToCanvas(hoehe: hoehe) }
    }

    var ersteSeitenID: String { pages.first?.id ?? "" }

    /// Gehört das Element auf diese Seite? Ein leeres `pageID` zählt zur
    /// ersten Seite — daran hängt die Verträglichkeit mit alten Tafeln.
    func liegtAuf(_ widget: BoardWidget, seite: String) -> Bool {
        if widget.pageID.isEmpty { return seite == ersteSeitenID }
        return widget.pageID == seite
    }

    /// Elemente einer Seite, von hinten nach vorn.
    /// - Parameter mitVersteckten: Beim Bearbeiten gehören die
    ///   ausgeblendeten Elemente dazu — sonst wären sie von der Tafel aus
    ///   nicht mehr zurückzuholen, und „ausblenden“ wäre dasselbe wie
    ///   löschen. Im Unterricht sind sie weg.
    func widgets(auf seite: String, mitVersteckten: Bool = false) -> [BoardWidget] {
        sortedWidgets.filter {
            (mitVersteckten || !$0.versteckt) && liegtAuf($0, seite: seite)
        }
    }

    /// Elemente, die diese Person für sich ausgeblendet hat.
    var versteckteWidgets: [BoardWidget] {
        sortedWidgets.filter(\.versteckt)
    }

    /// Handschrift einer Seite. Für die erste Seite alter Tafeln steht sie
    /// noch in `drawing`.
    func handschrift(auf seite: String) -> String {
        if let treffer = pages.first(where: { $0.id == seite }) { return treffer.drawing }
        return seite == ersteSeitenID ? drawing : ""
    }

    /// Anzeigename einer Seite — „Seite 3", wenn keiner vergeben wurde.
    func seitenName(_ seite: String) -> String {
        let liste = seiten
        guard let index = liste.firstIndex(where: { $0.id == seite }) else { return "Seite 1" }
        let eigener = liste[index].name.trimmingCharacters(in: .whitespaces)
        return eigener.isEmpty ? "Seite \(index + 1)" : eigener
    }
}

// MARK: - Namenslisten

/// Ein Merkmal einer Namensliste — etwas, wonach beim Auslosen gemischt
/// werden kann.
///
/// Das häufigste ist „Jungen und Mädchen“, aber es gibt mehr davon:
/// Tischgruppen, Lesestufen, wer schon zusammen gearbeitet hat. Deshalb
/// steht hier kein festes Feld „Geschlecht“, sondern ein Merkmal mit
/// eigenem Namen und eigenen Werten.
///
/// Die Werte sind bewusst kurze Zeichen („J“, „M“) — sie stehen später
/// klein an den Namenskärtchen.
struct Merkmal: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var name: String = ""
    /// Die möglichen Werte, in der Reihenfolge, in der sie angeboten werden.
    var werte: [String] = []

    /// Merkmale, die sich mit einem Tipp anlegen lassen.
    static let vorlagen: [Merkmal] = [
        Merkmal(name: "Jungen und Mädchen", werte: ["J", "M"]),
        Merkmal(name: "Tischgruppe", werte: ["1", "2", "3", "4", "5", "6"]),
        Merkmal(name: "Lesestufe", werte: ["A", "B", "C"])
    ]
}

struct NameEntry: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var text: String = ""
    /// Vorübergehend ausgeschlossen (z. B. krank) — wird nicht gezogen.
    var paused: Bool = false
    /// Wert je Merkmal (Kennung des Merkmals → Wert).
    ///
    /// Fehlt ein Eintrag, hat dieser Name das Merkmal nicht. Beim Auslosen
    /// zählt er dann als eigener Topf „ohne Angabe“ — nichts wird geraten.
    var merkmale: [String: String] = [:]
    /// Geburtstag als `JJJJ-MM-TT`. **Leer heißt: nicht eingetragen** —
    /// niemand muss ihn angeben, und ohne ihn passiert schlicht nichts.
    ///
    /// Bewusst als Zeichenkette und nicht als `Date`: Ein Geburtstag ist ein
    /// Kalendertag, kein Zeitpunkt. Als `Date` gespeichert verschöbe ihn
    /// jeder Zeitzonenwechsel um einen Tag — genau der Fehler, der einem
    /// Kind den Geburtstag am falschen Tag feiert.
    var geburtstag: String = ""
    /// Wo im Raum dieses Kind sitzen soll — Rohwert eines `Sitzwunsch`.
    /// Leer heißt „egal", und das ist der Regelfall.
    var sitzwunsch: String = ""
    /// Braucht einen freien Platz neben sich.
    var alleine: Bool = false

    func wert(_ merkmalID: String) -> String? {
        merkmale[merkmalID]?.nonEmpty
    }
}

/// Eine gespeicherte Auslosung — für „Was war letzte Woche?“.
///
/// Gemerkt werden die **Namen als Text**, nicht als Kennung: Der Bestand
/// ändert sich, Kinder kommen und gehen, und ein Archiv, in dem nachträglich
/// Striche stehen, hilft niemandem.
struct Ziehung: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var zeitMs: Int64 = Date.nowMs
    /// Rohwert eines `Ziehmodus`.
    var modus: String = Ziehmodus.gruppen.rawValue
    /// Wie viele Namen in eine Zeile gehörten.
    var proZeile: Int = 2
    /// Die Namen in Ziehreihenfolge, so wie sie damals hießen.
    var texte: [String] = []
    /// Überschrift des Elements — damit sich die Ziehung wiedererkennen lässt.
    var titel: String = ""

    var zeitpunkt: Date { Date(timeIntervalSince1970: Double(zeitMs) / 1000) }

    /// Die Namen in Zeilen zerlegt.
    var zeilen: [[String]] {
        let breite = max(1, proZeile)
        guard !texte.isEmpty else { return [] }
        return stride(from: 0, to: texte.count, by: breite).map { anfang in
            Array(texte[anfang..<min(anfang + breite, texte.count)])
        }
    }
}

struct NameList: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String = "Neue Liste"
    var entries: [NameEntry] = []
    var owner: String = ""
    var updatedAtMs: Int64 = Date.nowMs
    var deleted: Bool = false

    /// Merkmale, nach denen sich die Namen sortieren lassen.
    var merkmale: [Merkmal] = []

    /// Wer nicht nebeneinander soll und wer gern zusammen — für den
    /// Sitzplan. Steht an der Liste und nicht am Element, weil es eine
    /// Eigenschaft der Kinder ist und nicht eine des Raumes: Dieselbe
    /// Klasse behält ihre Regeln, auch wenn die Tische umgestellt werden.
    var sitzregeln: [Sitzregel] = []

    var activeEntries: [NameEntry] { entries.filter { !$0.paused } }

    /// Alle Regeln, die diesen Eintrag betreffen.
    func sitzregeln(zu eintragID: String) -> [Sitzregel] {
        sitzregeln.filter { $0.betrifft(eintragID) }
    }

    /// Regeln, deren Partner es nicht mehr gibt, fallen weg — sonst
    /// verhindert eine unsichtbare Regel eine Verteilung.
    func gueltigeSitzregeln() -> [Sitzregel] {
        let vorhanden = Set(entries.map(\.id))
        return sitzregeln.filter { vorhanden.contains($0.a) && vorhanden.contains($0.b) && $0.a != $0.b }
    }

    /// Was von einer gelöschten Liste noch hochgeladen wird — ein leerer
    /// Vermerk, ohne die Namen (siehe `Board.grabstein`).
    func grabstein() -> NameList {
        var leer = NameList()
        leer.id = id
        leer.deleted = true
        leer.updatedAtMs = updatedAtMs
        leer.name = ""
        leer.entries = []
        leer.merkmale = []
        leer.sitzregeln = []
        leer.owner = ""
        return leer
    }

    func merkmal(_ id: String?) -> Merkmal? {
        guard let id else { return nil }
        return merkmale.first { $0.id == id }
    }

    /// Wie oft jeder Wert eines Merkmals unter den aktiven Namen vorkommt.
    /// Namen ohne Angabe zählen unter dem leeren Schlüssel.
    func verteilung(_ merkmalID: String) -> [String: Int] {
        var zaehler: [String: Int] = [:]
        for eintrag in activeEntries {
            zaehler[eintrag.wert(merkmalID) ?? "", default: 0] += 1
        }
        return zaehler
    }

    /// Zerlegt eine eingefügte Liste (Zeilen oder Kommas) in Einträge.
    static func parse(_ raw: String) -> [NameEntry] {
        // split liefert Substrings — erst in String wandeln, dann trimmen.
        raw.split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == ";" })
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
            .map { NameEntry(text: $0) }
    }
}

// MARK: - Startinhalt

enum StarterContent {
    /// Beim allerersten Start: eine fertige Beispieltafel, damit sofort
    /// sichtbar ist, wie das Zusammenspiel gedacht ist.
    static func makeBoard(owner: String) -> Board {
        var board = Board(name: "Meine Klasse", emoji: "🍎", owner: owner)
        board.members = owner.nonEmpty.map { [$0] } ?? []

        // Die Größen liegen nahe an den vorgesehenen — dadurch zeichnen die
        // Elemente ungefähr im Maßstab 1, also so wie in der Web-App. Die
        // Kästen überschneiden sich nicht: links eine Spalte bis x = 700,
        // rechts daneben ab x = 740.
        var text = BoardWidget(x: 80, y: 30, width: 620, height: 180, z: 0,
                               content: .text(TextContent(text: "Guten Morgen!", fontSize: 84)))
        text.clampToCanvas()

        let picker = BoardWidget(x: 80, y: 230, width: 620, height: 420, z: 1,
                                 content: .namePicker(NamePickerContent()))
        // Mit Beispielpunkten — eine leere Liste sagt beim ersten Start nichts.
        let checklist = BoardWidget(x: 80, y: 670, width: 620, height: 310, z: 2,
                                    content: WidgetContent.makeDefault(for: .checklist))
        let timer = BoardWidget(x: 740, y: 30, width: 340, height: 340, z: 3,
                                content: .timer(TimerContent()))
        let clock = BoardWidget(x: 1120, y: 30, width: 380, height: 380, z: 4,
                                content: .clock(ClockContent()))
        let noise = BoardWidget(x: 740, y: 430, width: 460, height: 290, z: 5,
                                content: .noise(NoiseContent()))
        let light = BoardWidget(x: 1240, y: 440, width: 220, height: 330, z: 6,
                                content: .trafficLight(TrafficLightContent()))

        board.widgets = [text, clock, picker, timer, light, noise, checklist]
        return board
    }

    static func makeNameList(owner: String) -> NameList {
        NameList(
            name: "Beispielklasse",
            // Von A bis Z, damit beim ersten Ziehen sichtbar wird, dass die
            // Liste wirklich gemischt wird — und mit Namen, wie sie in einer
            // Klasse tatsaechlich nebeneinandersitzen.
            entries: NameList.parse("Adam, Betullah, Charlotte, Deniz, Erdem, Frida, "
                                    + "Giacomo, Hannah, Ilkay, Joel, Krystina, Liam, "
                                    + "Mia, Nesrin, Ophelia, Paul, Quentin, Ramazan, "
                                    + "Stine, Tallulah, Umut, Viktor, Weronika, Xenia, "
                                    + "Yesim, Zacharias"),
            owner: owner
        )
    }
}


// MARK: - Nachsichtige Decoder der synchronisierten Typen

extension Board {
    enum BoardKeys: String, CodingKey {
        case id, name, emoji, background, accent, accentVon, accentBis, gradient, cardStyle
        case format, frames, labels, schriftfarbe
        case zuletztVon
        case widgets, pages, drawing, members, ownerUserID, loeschrecht
        case geburtstage, geburtstagsliste, geburtstagsErinnerung
        case geburtstagsZeit, geburtstagsZeitVortag
        case memberUserIDs, joinCode, geteilt, owner, createdAtMs, updatedAtMs, deleted
        case embeddedLists
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: BoardKeys.self)
        self.init()
        id = c.wert(.id, UUID().uuidString)
        name = c.wert(.name, "Tafel")
        emoji = c.wert(.emoji, "🌟")
        background = c.wert(.background, BoardBackground.aurora("nordlicht"))
        accent = c.wert(.accent, "indigo")
        zuletztVon = c.wert(.zuletztVon, "")
        accentVon = c.wert(.accentVon, "")
        accentBis = c.wert(.accentBis, "")
        gradient = c.wert(.gradient, true)
        cardStyle = c.wert(.cardStyle, CardStyle.glass)
        format = c.wert(.format, Tafelformat.breit)
        frames = c.wert(.frames, ShowRule.always)
        labels = c.wert(.labels, ShowRule.always)
        schriftfarbe = c.wert(.schriftfarbe, "")
        widgets = c.wert(.widgets, [BoardWidget]())
        pages = c.wert(.pages, [BoardPage]())
        drawing = c.wert(.drawing, "")
        members = c.wert(.members, [String]())
        ownerUserID = c.wert(.ownerUserID, "")
        loeschrecht = c.wert(.loeschrecht, Loeschrecht.vorgabe.rawValue)
        geburtstage = c.wert(.geburtstage, false)
        geburtstagsliste = c.wert(.geburtstagsliste, "")
        geburtstagsErinnerung = c.wert(.geburtstagsErinnerung,
                                       Geburtstagserinnerung.vorgabe.rawValue)
        geburtstagsZeit = c.wert(.geburtstagsZeit, 8 * 60)
        geburtstagsZeitVortag = c.wert(.geburtstagsZeitVortag, 15 * 60)
        memberUserIDs = c.wert(.memberUserIDs, [String]())
        joinCode = c.wert(.joinCode, Board.makeJoinCode())
        geteilt = c.wert(.geteilt, false)
        owner = c.wert(.owner, "")
        createdAtMs = c.wert(.createdAtMs, Date.nowMs)
        updatedAtMs = c.wert(.updatedAtMs, Date.nowMs)
        deleted = c.wert(.deleted, false)
        embeddedLists = c.wert(.embeddedLists, [NameList]())
    }
}

extension NameList {
    enum ListKeys: String, CodingKey {
        case id, name, entries, owner, updatedAtMs, deleted, merkmale, sitzregeln
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ListKeys.self)
        self.init()
        id = c.wert(.id, UUID().uuidString)
        name = c.wert(.name, "Liste")
        entries = c.wert(.entries, [NameEntry]())
        merkmale = c.wert(.merkmale, [Merkmal]())
        sitzregeln = c.wert(.sitzregeln, [Sitzregel]())
        owner = c.wert(.owner, "")
        updatedAtMs = c.wert(.updatedAtMs, Date.nowMs)
        deleted = c.wert(.deleted, false)
    }
}

extension Ziehung {
    enum ZiehungKeys: String, CodingKey { case id, zeitMs, modus, proZeile, texte, titel }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ZiehungKeys.self)
        self.init()
        id = c.wert(.id, UUID().uuidString)
        zeitMs = c.wert(.zeitMs, Date.nowMs)
        modus = c.wert(.modus, Ziehmodus.gruppen.rawValue)
        proZeile = c.wert(.proZeile, 2)
        texte = c.wert(.texte, [String]())
        titel = c.wert(.titel, "")
    }
}

extension Merkmal {
    enum MerkmalKeys: String, CodingKey { case id, name, werte }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: MerkmalKeys.self)
        self.init()
        id = c.wert(.id, UUID().uuidString)
        name = c.wert(.name, "")
        werte = c.wert(.werte, [String]())
    }
}

extension NameEntry {
    enum EntryKeys: String, CodingKey {
        case id, text, paused, merkmale, geburtstag, sitzwunsch, alleine
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: EntryKeys.self)
        self.init()
        id = c.wert(.id, UUID().uuidString)
        text = c.wert(.text, "")
        paused = c.wert(.paused, false)
        merkmale = c.wert(.merkmale, [String: String]())
        geburtstag = c.wert(.geburtstag, "")
        sitzwunsch = c.wert(.sitzwunsch, "")
        alleine = c.wert(.alleine, false)
    }
}

extension BoardWidget {
    enum WidgetKeys: String, CodingKey {
        case id, x, y, width, height, z, locked, bare, karte, pageID, versteckt, content
        case labels, labelSize, schriftfarbe, erstelltVon
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: WidgetKeys.self)
        // Ohne Inhalt ist ein Element sinnlos — das darf scheitern.
        let inhalt = try c.decode(WidgetContent.self, forKey: .content)
        self.init(content: inhalt)
        id = c.wert(.id, UUID().uuidString)
        erstelltVon = c.wert(.erstelltVon, "")
        x = c.wert(.x, 100)
        y = c.wert(.y, 100)
        width = c.wert(.width, 400)
        height = c.wert(.height, 300)
        z = c.wert(.z, 0)
        locked = c.wert(.locked, false)
        pageID = c.wert(.pageID, "")
        // Altbestand: Wer nur `bare` kennt, meinte damit „nie eine Karte".
        let ohneKarte = c.wert(.bare, false)
        karte = c.wert(.karte, ohneKarte ? WidgetKarte.nie : .tafel)
        versteckt = c.wert(.versteckt, false)
        labels = c.wert(.labels, WidgetLabelRegel.tafel)
        labelSize = c.wert(.labelSize, 1)
        schriftfarbe = c.wert(.schriftfarbe, "")
    }
}

// MARK: - Nachsichtige Decoder der Element-Inhalte

extension TextContent {
    enum TextKeys: String, CodingKey {
        case text, fontSize, autoSize, colorHex, colorHex2, backgroundHex, backgroundHex2
        case backgroundOpacity, bold, alignment, rounded
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: TextKeys.self)
        self.init()
        text = c.wert(.text, "Text")
        fontSize = c.wert(.fontSize, 64)
        autoSize = c.wert(.autoSize, true)
        colorHex = c.wert(.colorHex, "#0f172a")
        colorHex2 = c.wert(.colorHex2, "")
        backgroundHex = c.wert(.backgroundHex, "#ffffff")
        backgroundHex2 = c.wert(.backgroundHex2, "")
        backgroundOpacity = c.wert(.backgroundOpacity, 0)
        bold = c.wert(.bold, true)
        alignment = c.wert(.alignment, TextContent.TextAlign.center)
        rounded = c.wert(.rounded, true)
    }
}

extension ImageContent {
    enum ImageKeys: String, CodingKey { case fileName, fill, cornerRadius, caption }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ImageKeys.self)
        self.init()
        fileName = c.optional(.fileName, String.self)
        fill = c.wert(.fill, true)
        cornerRadius = c.wert(.cornerRadius, 28)
        caption = c.wert(.caption, "")
    }
}

extension ClockContent {
    enum ClockKeys: String, CodingKey {
        case style, face, showSeconds, showDate, twentyFourHour, faceHex, faceHex2, accentHex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ClockKeys.self)
        self.init()
        style = c.wert(.style, ClockContent.ClockStyle.analog)
        face = c.wert(.face, ClockFace.modern)
        showSeconds = c.wert(.showSeconds, true)
        showDate = c.wert(.showDate, false)
        twentyFourHour = c.wert(.twentyFourHour, true)
        faceHex = c.wert(.faceHex, "#ffffff")
        faceHex2 = c.wert(.faceHex2, "")
        accentHex = c.wert(.accentHex, "#0f9b8e")
    }
}

extension TimerContent {
    enum TimerKeys: String, CodingKey {
        case mode, duration, endsAtMs, startedAtMs, pausedValue, soundOnEnd, accentHex
        case endklang, endklangDatei, endklangLautstaerke
        case showControls, knoepfe
        case darstellung, skalaMinuten, ziffernblatt, scheibeHex, scheibeHex2, blattHex
        case zeiger, zeitZeigen
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: TimerKeys.self)
        self.init()
        mode = c.wert(.mode, TimerContent.TimerMode.countdown)
        duration = c.wert(.duration, 300)
        endsAtMs = c.optional(.endsAtMs, Int64.self)
        startedAtMs = c.optional(.startedAtMs, Int64.self)
        pausedValue = c.optional(.pausedValue, Double.self)
        soundOnEnd = c.wert(.soundOnEnd, true)
        // Als Zeichenkette gelesen, nicht als Aufzählung: Eine Tafel von
        // einem neueren Gerät darf einen Klang nennen, den diese Fassung
        // noch nicht kennt — sie nimmt dann die Vorgabe, statt die ganze
        // Tafel zu verwerfen.
        endklang = c.wert(.endklang, Endklang.vorgabe.rawValue)
        endklangDatei = c.optional(.endklangDatei, String.self)
        endklangLautstaerke = min(max(c.wert(.endklangLautstaerke, 1.0), 0), 1)
        accentHex = c.wert(.accentHex, "#2dd4bf")
        // Stand dort noch der alte Vorgabewert „an", gilt die neue Vorgabe:
        // Diese Knöpfe hatte nie jemand ausgewählt, sie waren nur da.
        showControls = c.wert(.showControls, true)
        knoepfe = c.wert(.knoepfe, false)
        darstellung = c.wert(.darstellung, TimerDarstellung.ring)
        skalaMinuten = c.wert(.skalaMinuten, 0)
        ziffernblatt = c.wert(.ziffernblatt, Timerblatt.zahlen)
        scheibeHex = c.wert(.scheibeHex, "#e11d48")
        scheibeHex2 = c.wert(.scheibeHex2, "")
        blattHex = c.wert(.blattHex, "#f8fafc")
        zeiger = c.wert(.zeiger, true)
        zeitZeigen = c.wert(.zeitZeigen, true)
    }
}

extension TrafficLightContent {
    enum LightKeys: String, CodingKey { case state, horizontal, showLabels, redLabel, yellowLabel, greenLabel }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: LightKeys.self)
        self.init()
        state = c.wert(.state, TrafficLightContent.LightState.green)
        horizontal = c.wert(.horizontal, false)
        showLabels = c.wert(.showLabels, true)
        redLabel = c.wert(.redLabel, "Stopp")
        yellowLabel = c.wert(.yellowLabel, "Flüstern")
        greenLabel = c.wert(.greenLabel, "Gespräch")
    }
}

extension NoiseContent {
    enum NoiseKeys: String, CodingKey { case schwelleDb, threshold, gain, style, alert, title }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: NoiseKeys.self)
        self.init()
        threshold = c.wert(.threshold, 0.55)
        gain = c.wert(.gain, 1)
        schwelleDb = c.wert(.schwelleDb, Self.ausAlterSchwelle(threshold))
        style = c.wert(.style, NoiseContent.NoiseStyle.gauge)
        alert = c.wert(.alert, true)
        title = c.wert(.title, "Lautstärke")
    }

    /// Ältere Stände kannten nur eine Schwelle von 0 bis 1.
    ///
    /// Sie bezog sich auf den Ausschlag des Bandes, das von −52 bis −8 dBFS
    /// reichte; mit dem Abgleich von 95 dB entspricht das 43 bis 87 dB(A).
    /// Wer die Schwelle bewusst verstellt hatte, behält sie also.
    ///
    /// Stand dort noch der alte Vorgabewert 0,55, wird die neue Vorgabe
    /// genommen: Diese 0,55 waren nie eine Entscheidung, sondern eine aus
    /// der Web-App übernommene Zahl — und sie lag mit 67 dB(A) mitten im
    /// gewöhnlichen Unterrichtsgespräch.
    static func ausAlterSchwelle(_ alt: Double) -> Double {
        guard abs(alt - 0.55) > 0.001 else { return NoiseSkala.schwelleVorgabe }
        let db = 43 + alt * 44
        return min(max(db, NoiseSkala.schwelleMin), NoiseSkala.schwelleMax)
    }
}

extension ChecklistItem {
    enum ItemKeys: String, CodingKey { case id, text, done, emoji }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ItemKeys.self)
        self.init()
        id = c.wert(.id, UUID().uuidString)
        text = c.wert(.text, "")
        done = c.wert(.done, false)
        emoji = c.wert(.emoji, "")
    }
}

extension ChecklistContent {
    enum ChecklistKeys: String, CodingKey {
        case title, items, showProgress, strikeDone, quickAdd, resetDaily, lastResetDay
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ChecklistKeys.self)
        self.init()
        title = c.wert(.title, "Unser Tag")
        items = c.wert(.items, [ChecklistItem]())
        showProgress = c.wert(.showProgress, true)
        strikeDone = c.wert(.strikeDone, true)
        quickAdd = c.wert(.quickAdd, true)
        resetDaily = c.wert(.resetDaily, false)
        lastResetDay = c.wert(.lastResetDay, "")
    }
}

extension NamePickerContent {
    enum PickerKeys: String, CodingKey {
        case title, listID, mode, drawnIDs, currentID, showHistory, showDrawn, animate, spinSound,
             reveal, revealParts
        case modus, titelGruppen, titelTagesgruppe, gruppenGroesse, tagesgruppeAnzahl
        case mischMerkmalID, merkmalsvorgabe, alsCheckliste, festgehalten, ergebnis, erledigt
        case ziehungID, anzeige, zaehler, ziehungen, paare
        case kartenfarbe, kartenfarbe2
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: PickerKeys.self)
        self.init()
        title = c.wert(.title, "")
        listID = c.optional(.listID, String.self)
        mode = c.wert(.mode, NamePickerContent.DrawMode.withoutRepeat)
        drawnIDs = c.wert(.drawnIDs, [String]())
        currentID = c.optional(.currentID, String.self)
        showHistory = c.wert(.showHistory, true)
        // Ältere Stände kannten nur den Schalter „Gezogene anzeigen".
        showDrawn = c.wert(.showDrawn, showHistory ? ShowRule.always : ShowRule.never)
        animate = c.wert(.animate, true)
        spinSound = c.wert(.spinSound, SpinSound.karten)
        reveal = c.wert(.reveal, RevealMode.mosaik)
        revealParts = c.wert(.revealParts, [Int]())
        modus = c.wert(.modus, Ziehmodus.einzel)
        titelGruppen = c.wert(.titelGruppen, "")
        titelTagesgruppe = c.wert(.titelTagesgruppe, "")
        gruppenGroesse = c.wert(.gruppenGroesse, 2)
        tagesgruppeAnzahl = c.wert(.tagesgruppeAnzahl, 1)
        mischMerkmalID = c.wert(.mischMerkmalID, "")
        // Alte Stände kannten nur „nach diesem Merkmal mischen“. Wer damals
        // keines gewählt hatte, meinte „egal“.
        merkmalsvorgabe = c.wert(.merkmalsvorgabe,
                                 mischMerkmalID.isEmpty ? Merkmalsvorgabe.egal : .unterschiedlich)
        // Altstände kannten nur „Checkliste ja/nein".
        let alteCheckliste = c.wert(.alsCheckliste, false)
        anzeige = c.wert(.anzeige, alteCheckliste ? Ergebnisanzeige.abhaken : .normal)
        zaehler = c.wert(.zaehler, [String: Int]())
        kartenfarbe = c.wert(.kartenfarbe, "")
        kartenfarbe2 = c.wert(.kartenfarbe2, "")
        festgehalten = c.wert(.festgehalten, false)
        ergebnis = c.wert(.ergebnis, [String]())
        erledigt = c.wert(.erledigt, [String]())
        ziehungID = c.wert(.ziehungID, "")
        ziehungen = c.wert(.ziehungen, [Ziehung]())
        paare = c.wert(.paare, [String: Int]())
    }
}

extension SoundButton {
    enum ButtonKeys: String, CodingKey {
        case id, label, emoji, colorHex, colorHex2, fileName, url, volume, toggle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ButtonKeys.self)
        self.init()
        id = c.wert(.id, UUID().uuidString)
        label = c.wert(.label, "")
        emoji = c.wert(.emoji, "🔔")
        colorHex = c.wert(.colorHex, "#0f9b8e")
        colorHex2 = c.wert(.colorHex2, "")
        fileName = c.optional(.fileName, String.self)
        url = c.wert(.url, "")
        volume = c.wert(.volume, 1)
        toggle = c.wert(.toggle, false)
    }
}

extension VideoContent {
    enum VideoKeys: String, CodingKey {
        case fileName, url, sourceLabel, caption, loop, showControls, muted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: VideoKeys.self)
        self.init()
        fileName = c.optional(.fileName, String.self)
        url = c.wert(.url, "")
        sourceLabel = c.wert(.sourceLabel, "")
        caption = c.wert(.caption, "")
        loop = c.wert(.loop, false)
        showControls = c.wert(.showControls, true)
        muted = c.wert(.muted, false)
    }
}

extension KameraContent {
    enum KameraKeys: String, CodingKey { case eingefroren, caption, fuellend }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: KameraKeys.self)
        self.init()
        eingefroren = c.optional(.eingefroren, String.self)
        caption = c.wert(.caption, "")
        fuellend = c.wert(.fuellend, true)
    }
}

extension SymbolContent {
    enum SymbolKeys: String, CodingKey { case symbol, showLabel }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: SymbolKeys.self)
        self.init()
        symbol = c.wert(.symbol, WorkSymbol.einzel)
        showLabel = c.wert(.showLabel, true)
    }
}

extension SoundsContent {
    enum SoundsKeys: String, CodingKey { case buttons, showLabels }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: SoundsKeys.self)
        self.init()
        buttons = c.wert(.buttons, [SoundButton]())
        showLabels = c.wert(.showLabels, true)
    }
}
