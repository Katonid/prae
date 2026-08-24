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
        }
    }

    /// Startgröße in Tafelpunkten.
    var defaultSize: CGSize {
        switch self {
        case .namePicker:   return CGSize(width: 560, height: 420)
        case .timer:        return CGSize(width: 460, height: 400)
        case .clock:        return CGSize(width: 380, height: 380)
        case .trafficLight: return CGSize(width: 240, height: 520)
        case .noise:        return CGSize(width: 420, height: 380)
        case .checklist:    return CGSize(width: 520, height: 560)
        case .text:         return CGSize(width: 640, height: 200)
        case .image:        return CGSize(width: 520, height: 380)
        case .sounds:       return CGSize(width: 640, height: 300)
        }
    }
}

// MARK: - Inhalte der einzelnen Elemente

struct TextContent: Codable, Equatable {
    var text: String = "Guten Morgen!"
    /// Schriftgröße in Tafelpunkten.
    var fontSize: Double = 64
    var colorHex: String = "#ffffff"
    var backgroundHex: String = "#000000"
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
    var showSeconds: Bool = true
    var showDate: Bool = false
    var twentyFourHour: Bool = true
    var faceHex: String = "#ffffff"
    var accentHex: String = "#7c5cff"

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
    var showControls: Bool = true

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
    /// Schwelle 0…1, ab der die Anzeige „zu laut" meldet.
    var threshold: Double = 0.6
    /// Empfindlichkeit (Verstärkung) 0,5 … 2,0.
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
    /// Hakt sich beim ersten Öffnen an einem neuen Tag selbst wieder frei.
    var resetDaily: Bool = false
    /// Tag (yyyy-MM-dd) des letzten automatischen Zurücksetzens.
    var lastResetDay: String = ""
}

struct NamePickerContent: Codable, Equatable {
    /// ID der verwendeten Namensliste.
    var listID: String? = nil
    var mode: DrawMode = .withoutRepeat
    /// Bereits gezogene Namen (IDs der Listeneinträge, in Ziehreihenfolge).
    var drawnIDs: [String] = []
    /// Zuletzt gezogener Eintrag.
    var currentID: String? = nil
    var showHistory: Bool = true
    var animate: Bool = true

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

struct SoundButton: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var label: String = ""
    var emoji: String = "🔔"
    var colorHex: String = "#7c5cff"
    /// Dateiname unter Documents/Media/ (nil = leeres Feld).
    var fileName: String? = nil
    var volume: Double = 1.0
    /// Beim erneuten Antippen stoppen statt neu starten.
    var toggle: Bool = false
}

struct SoundsContent: Codable, Equatable {
    var buttons: [SoundButton] = []
    var showLabels: Bool = true
}

// MARK: - Element (Widget)

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
        case .sounds:       return .sounds(SoundsContent(buttons: [
            SoundButton(label: "Gong", emoji: "🔔", colorHex: "#7c5cff"),
            SoundButton(label: "Applaus", emoji: "👏", colorHex: "#2dd4bf"),
            SoundButton(label: "Aufräumen", emoji: "🧹", colorHex: "#f59e0b")
        ]))
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
}

extension BoardBackground: Codable {
    private enum Keys: String, CodingKey { case type, a, b, dim }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        switch try container.decode(String.self, forKey: .type) {
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
        ("#1e1b4b", "#0b1020"),
        ("#0f2027", "#203a43"),
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
        "#7c5cff", "#2dd4bf", "#f59e0b", "#ef4444",
        "#ffffff", "#e2e8f0"
    ]
}

// MARK: - Tafel

struct Board: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String = "Neue Tafel"
    var emoji: String = "🌟"
    var background: BoardBackground = .gradient("#1e1b4b", "#0b1020")
    var widgets: [BoardWidget] = []
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

    static func makeJoinCode() -> String {
        // Ohne 0/O und 1/I — Codes werden auch mal vorgelesen.
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement() ?? "A" })
    }

    /// Alle Mediendateien, die diese Tafel braucht.
    var referencedMedia: Set<String> {
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
            default:
                break
            }
        }
        return names
    }

    var sortedWidgets: [BoardWidget] {
        widgets.sorted { $0.z < $1.z }
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

        var text = BoardWidget(x: 80, y: 60, width: 720, height: 180, z: 0,
                               content: .text(TextContent(text: "Guten Morgen!", fontSize: 84)))
        text.clampToCanvas()

        let clock = BoardWidget(x: 1180, y: 60, width: 360, height: 360, z: 1,
                                content: .clock(ClockContent()))
        let picker = BoardWidget(x: 80, y: 280, width: 600, height: 440, z: 2,
                                 content: .namePicker(NamePickerContent()))
        let timer = BoardWidget(x: 720, y: 280, width: 420, height: 380, z: 3,
                                content: .timer(TimerContent()))
        let light = BoardWidget(x: 1180, y: 450, width: 220, height: 470, z: 4,
                                content: .trafficLight(TrafficLightContent()))
        let noise = BoardWidget(x: 720, y: 690, width: 420, height: 250, z: 5,
                                content: .noise(NoiseContent()))
        let checklist = BoardWidget(x: 80, y: 750, width: 600, height: 200, z: 6,
                                    content: .checklist(ChecklistContent()))

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
