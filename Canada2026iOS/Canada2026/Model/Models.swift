import Foundation

// Synchronisierbare Datentypen. Jede Entität ist Codable und wird sowohl lokal
// (JSON im Documents-Verzeichnis) als auch als CloudKit-Record gespeichert.

/// Zugriffsrollen wie in der PWA: Crew (Andreas = Admin) plus die beiden
/// Betrachter-Rollen "Familie" und "Begleiter".
enum AccessRole: String, Codable, CaseIterable, Identifiable {
    case admin
    case crew
    case family      // Betrachter-Rolle "Familie"
    case companion   // Betrachter-Rolle "Begleiter"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .admin: return "Admin"
        case .crew: return "STAN on Tour"
        case .family: return "Familie"
        case .companion: return "Begleiter"
        }
    }

    var isCrew: Bool { self == .admin || self == .crew }
    var isViewer: Bool { !isCrew }
}

/// Auf diesem Gerät angemeldetes Profil.
struct DeviceUser: Codable, Equatable {
    var name: String = ""
    var role: AccessRole = .crew
    var viewerId: String = ""    // stabile ID für Betrachter-Profile
    var selected: Bool = false

    var isCrew: Bool { role.isCrew }
    var isViewer: Bool { role.isViewer }
    var isAdmin: Bool { role == .admin }
}

struct ChatMessage: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var channel: String = "all"          // "crew" oder "all"
    var author: String = ""
    var authorRole: String = "crew"
    var text: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false
}

struct JournalEntry: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var day: String = ""                 // yyyy-MM-dd
    var author: String = ""
    var title: String = ""
    var text: String = ""
    var mood: Int = 0                    // 0 = keine Angabe, 1–5
    var stationId: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false
}

struct PhotoItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var author: String = ""
    var caption: String = ""
    var day: String = ""                 // yyyy-MM-dd
    var stationId: String = ""
    var bingoTaskId: String = ""         // optional: belegt ein Bingo-Feld
    var challengeId: String = ""         // optional: belegt eine Challenge
    var isHighlight: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false
    /// Dateiname des lokalen Bilds im Photos-Ordner (JPEG). Wird über CKAsset synchronisiert.
    var fileName: String { "\(id).jpg" }
}

struct Expense: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String = ""
    var category: String = "Sonstiges"
    var amountCad: Double = 0
    var paidBy: String = ""
    var day: String = ""
    var stationId: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    var amountEur: Double { amountCad * TravelData.exchangeRateCadToEur }
}

/// Zustand eines Häkchens (Dokumenten-Checkliste oder Stations-Todo).
struct CheckState: Codable, Identifiable, Equatable {
    var id: String = ""                  // z. B. "doc-0" oder "todo-toronto-1"
    var done: Bool = false
    var doneBy: String = ""
    var updatedAt: Date = Date()
}

/// Bingo-Feld-Status pro Crew-Mitglied.
struct BingoState: Codable, Identifiable, Equatable {
    var id: String = ""                  // "\(member)|\(taskId)"
    var member: String = ""
    var taskId: String = ""
    var done: Bool = false
    var photoId: String = ""
    var updatedAt: Date = Date()
}

/// Challenge-Status pro Crew-Mitglied.
struct ChallengeState: Codable, Identifiable, Equatable {
    var id: String = ""                  // "\(member)|\(challengeId)"
    var member: String = ""
    var challengeId: String = ""
    var done: Bool = false
    var photoId: String = ""
    var updatedAt: Date = Date()
}

struct TrailPoint: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var member: String = ""
    var lat: Double = 0
    var lng: Double = 0
    var note: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false
}

struct BucketItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var text: String = ""
    var addedBy: String = ""
    var done: Bool = false
    var doneBy: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false
}

struct DailyQuestion: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var day: String = ""
    var question: String = ""
    var author: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false
}

struct DailyAnswer: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var questionId: String = ""
    var author: String = ""
    var text: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false
}

struct SoundtrackItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String = ""
    var artist: String = ""
    var url: String = ""
    var addedBy: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false
}

/// Registriertes Betrachter-Profil (Familie/Begleiter), damit die Crew sieht, wer mitliest.
struct ViewerProfile: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var displayName: String = ""
    var role: String = AccessRole.family.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false
}

/// Geteilte App-Konfiguration (Zugangscodes), vom Admin änderbar, synchronisiert.
struct SharedConfig: Codable, Equatable {
    var crewCode: String = "AHORN26"
    var familyCode: String = "FAMILIE26"
    var companionCode: String = "BEGLEITER26"
    var updatedAt: Date = Date()
}

/// Lokale Hinweis-/Aktivitätsmeldung (abgeleitet aus Sync-Ereignissen).
struct AppNotice: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var kind: String = "info"
    var text: String = ""
    var view: String = ""
    var createdAt: Date = Date()
    var read: Bool = false
}

/// Gesamter synchronisierter Datenbestand.
struct TripData: Codable, Equatable {
    var messages: [ChatMessage] = []
    var journal: [JournalEntry] = []
    var photos: [PhotoItem] = []
    var expenses: [Expense] = []
    var checks: [CheckState] = []
    var bingo: [BingoState] = []
    var challenges: [ChallengeState] = []
    var trail: [TrailPoint] = []
    var bucketList: [BucketItem] = []
    var dailyQuestions: [DailyQuestion] = []
    var dailyAnswers: [DailyAnswer] = []
    var soundtrack: [SoundtrackItem] = []
    var viewerProfiles: [ViewerProfile] = []
    var config: SharedConfig = SharedConfig()
}

/// Kennungen der Sync-Entitätstypen (entspricht "kind" im CloudKit-Record).
enum EntityKind: String, CaseIterable, Codable {
    case message
    case journal
    case photo
    case expense
    case check
    case bingo
    case challenge
    case trail
    case bucket
    case dailyQuestion
    case dailyAnswer
    case soundtrack
    case viewerProfile
    case config
}
