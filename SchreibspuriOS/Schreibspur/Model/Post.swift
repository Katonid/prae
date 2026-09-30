import Foundation

/// Was zwischen Kinder- und Lehrergerät hin- und hergeht (seit 1.0.13).
///
/// Ein Kind schickt **Pakete**: jede bearbeitete Seite, seine Sterne,
/// seinen Namen. Jedes Paket hat eine eigene Id — so kommt es bei der
/// Lehrkraft genau einmal an, egal ob über den Briefkasten in iCloud, über
/// Funk im Klassenzimmer oder über beides.
struct Paket: Codable, Identifiable {
    enum Inhalt: Codable {
        case profil(name: String, tier: String)
        case sterne([String: Int])
        case bearbeitung(Bearbeitung, spuren: Data?)
    }

    var id = UUID()
    var kind: UUID
    var inhalt: Inhalt
}

/// Eine neue Anmeldung (verschlüsselt, siehe `Umschlag`).
struct Anmeldung: Codable {
    var kind: UUID
    var name: String
    var tier: String
}

/// Einstellungen der Klasse, die auf allen iPads gelten.
struct Klasseneinstellungen: Codable, Equatable {
    var lehrgangAn = false
    var freiBis = 0
    var vorfuehren = true
    var heftHoehe = 16.0
    var nurStift = false
}

/// Was die Lehrkraft einem Kind zurückmeldet.
struct Vorgaben: Codable, Equatable {
    var genauigkeit: Genauigkeit?
    /// Aus der Klasse genommen.
    var entfernt = false
}

/// Ein Kind, wie es das Lehrergerät über Funk kurz beschreibt — damit ein
/// Gast auf dem geteilten iPad sich aus der Liste wählen kann und seine
/// Sterne zurückbekommt.
struct KindKurz: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var tier: String
    var genauigkeit: Genauigkeit
    var sterne: [String: Int]
}

/// Die Klasse, wie ein Kindergerät sie kennen muss.
struct Klasseninfo: Codable, Equatable {
    var code: String
    var name: String
    /// Öffentlicher Schlüssel der Lehrkraft.
    var schluessel: Data
    var offen = true
    var einstellungen = Klasseneinstellungen()
    /// Nur über Funk (nie in der öffentlichen Datenbank): die Kinder der
    /// Klasse mit Namen.
    var kinder: [KindKurz] = []
}

/// Nachrichten über Funk (MultipeerConnectivity) im Klassenzimmer.
enum Nachricht: Codable {
    /// Kind → Lehrkraft: „Ich gehöre zu dieser Klasse.“
    case hallo(code: String)
    /// Lehrkraft → Kind.
    case klasse(Klasseninfo)
    /// Kind → Lehrkraft (verschlüsselt: `Anmeldung`).
    case anmeldung(code: String, umschlag: Data)
    /// Kind → Lehrkraft (verschlüsselt: `Paket`).
    case paket(code: String, id: UUID, umschlag: Data)
    /// Lehrkraft → Kind: diese Pakete sind angekommen, dazu die Vorgaben.
    case quittung(kind: UUID, pakete: [UUID], vorgaben: Vorgaben)
    /// Zweites Lehrergerät → erstes: bitte den Schlüssel (mit der Zahl,
    /// die das erste gerade zeigt).
    case schluesselAnfrage(pin: String)
    /// Erstes Lehrergerät → zweites.
    case schluessel(Data, [Klassenzimmer], [KindKurz], [UUID: String])
}
