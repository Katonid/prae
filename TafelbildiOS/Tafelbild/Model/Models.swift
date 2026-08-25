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
    var bare: Bool = false
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
    mutating func clampToCanvas() {
        width = min(max(width, Layout.minWidth), Layout.canvasWidth)
        height = min(max(height, Layout.minHeight), Layout.canvasHeight)
        x = min(max(x, 0), Layout.canvasWidth - width)
        y = min(max(y, 0), Layout.canvasHeight - height)
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
    /// Wann Rahmen um die Elemente zu sehen sind.
    var frames: ShowRule = .always
    /// Wann Überschriften und Hinweise in den Elementen zu sehen sind.
    var labels: ShowRule = .always
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
    /// Sechsstelliger Einladungscode zum Teilen.
    var joinCode: String = Board.makeJoinCode()
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
        }
        return ids
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

        neu.widgets = fremd.widgets.map { fremdes in
            guard var meines = widgets.first(where: { $0.id == fremdes.id }) else {
                var neues = fremdes
                neues.versteckt = false
                return neues
            }
            meines.content = fremdes.content
            return meines
        }
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
    var ersteSeitenID: String { pages.first?.id ?? "" }

    /// Gehört das Element auf diese Seite? Ein leeres `pageID` zählt zur
    /// ersten Seite — daran hängt die Verträglichkeit mit alten Tafeln.
    func liegtAuf(_ widget: BoardWidget, seite: String) -> Bool {
        if widget.pageID.isEmpty { return seite == ersteSeitenID }
        return widget.pageID == seite
    }

    /// Elemente einer Seite, von hinten nach vorn.
    func widgets(auf seite: String) -> [BoardWidget] {
        sortedWidgets.filter { !$0.versteckt && liegtAuf($0, seite: seite) }
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

struct NameEntry: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var text: String = ""
    /// Vorübergehend ausgeschlossen (z. B. krank) — wird nicht gezogen.
    var paused: Bool = false
}

struct NameList: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String = "Neue Liste"
    var entries: [NameEntry] = []
    var owner: String = ""
    var updatedAtMs: Int64 = Date.nowMs
    var deleted: Bool = false

    var activeEntries: [NameEntry] { entries.filter { !$0.paused } }

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
            entries: NameList.parse("Ada, Ben, Charlotte, David, Emma, Finn, Greta, Hannes, Ida, Jonas"),
            owner: owner
        )
    }
}


// MARK: - Nachsichtige Decoder der synchronisierten Typen

extension Board {
    enum BoardKeys: String, CodingKey {
        case id, name, emoji, background, accent, accentVon, accentBis, gradient, cardStyle, frames, labels
        case zuletztVon
        case widgets, pages, drawing, members, ownerUserID
        case memberUserIDs, joinCode, owner, createdAtMs, updatedAtMs, deleted
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
        frames = c.wert(.frames, ShowRule.always)
        labels = c.wert(.labels, ShowRule.always)
        widgets = c.wert(.widgets, [BoardWidget]())
        pages = c.wert(.pages, [BoardPage]())
        drawing = c.wert(.drawing, "")
        members = c.wert(.members, [String]())
        ownerUserID = c.wert(.ownerUserID, "")
        memberUserIDs = c.wert(.memberUserIDs, [String]())
        joinCode = c.wert(.joinCode, Board.makeJoinCode())
        owner = c.wert(.owner, "")
        createdAtMs = c.wert(.createdAtMs, Date.nowMs)
        updatedAtMs = c.wert(.updatedAtMs, Date.nowMs)
        deleted = c.wert(.deleted, false)
        embeddedLists = c.wert(.embeddedLists, [NameList]())
    }
}

extension NameList {
    enum ListKeys: String, CodingKey {
        case id, name, entries, owner, updatedAtMs, deleted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ListKeys.self)
        self.init()
        id = c.wert(.id, UUID().uuidString)
        name = c.wert(.name, "Liste")
        entries = c.wert(.entries, [NameEntry]())
        owner = c.wert(.owner, "")
        updatedAtMs = c.wert(.updatedAtMs, Date.nowMs)
        deleted = c.wert(.deleted, false)
    }
}

extension NameEntry {
    enum EntryKeys: String, CodingKey { case id, text, paused }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: EntryKeys.self)
        self.init()
        id = c.wert(.id, UUID().uuidString)
        text = c.wert(.text, "")
        paused = c.wert(.paused, false)
    }
}

extension BoardWidget {
    enum WidgetKeys: String, CodingKey {
        case id, x, y, width, height, z, locked, bare, pageID, versteckt, content
        case labels, labelSize
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: WidgetKeys.self)
        // Ohne Inhalt ist ein Element sinnlos — das darf scheitern.
        let inhalt = try c.decode(WidgetContent.self, forKey: .content)
        self.init(content: inhalt)
        id = c.wert(.id, UUID().uuidString)
        x = c.wert(.x, 100)
        y = c.wert(.y, 100)
        width = c.wert(.width, 400)
        height = c.wert(.height, 300)
        z = c.wert(.z, 0)
        locked = c.wert(.locked, false)
        pageID = c.wert(.pageID, "")
        bare = c.wert(.bare, false)
        versteckt = c.wert(.versteckt, false)
        labels = c.wert(.labels, WidgetLabelRegel.tafel)
        labelSize = c.wert(.labelSize, 1)
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
        case showControls, knoepfe
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
        accentHex = c.wert(.accentHex, "#2dd4bf")
        // Stand dort noch der alte Vorgabewert „an", gilt die neue Vorgabe:
        // Diese Knöpfe hatte nie jemand ausgewählt, sie waren nur da.
        showControls = c.wert(.showControls, true)
        knoepfe = c.wert(.knoepfe, false)
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
