import Foundation
import CoreLocation

// Statische Reisedaten – portiert aus travelData.js der Canada-2026-PWA.

struct MapLink: Identifiable, Hashable {
    let title: String
    let url: String
    var id: String { url }
}

struct InfoSection: Identifiable, Hashable {
    let title: String
    let items: [String]
    var id: String { title }
}

struct Station: Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let tags: [String]
    let date: String            // ISO yyyy-MM-dd (Ankunftstag)
    let lat: Double
    let lng: Double
    let timezone: String
    let address: String
    let notes: String
    let todos: [String]
    let mapsUrl: String
    let relatedMaps: [(title: String, url: String)]

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
    var arrivalDate: Date? { TravelData.isoDay.date(from: date) }
    var relatedLinks: [MapLink] { relatedMaps.map { MapLink(title: $0.title, url: $0.url) } }

    static func == (lhs: Station, rhs: Station) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ChallengeDefinition: Identifiable, Hashable {
    let id: String
    let station: String
    let stationId: String
    let title: String
    let points: Int
}

struct BingoDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let points: Int
}

struct AchievementDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let description: String
    let condition: String
    let points: Int
}

struct FlightDefinition: Identifiable, Hashable {
    let id: String
    let direction: String
    let flightNumber: String
    let date: String
    let airline: String
    let operatedBy: String
    let codeshareNote: String
    let fromCode: String
    let fromName: String
    let fromCity: String
    let fromTimezone: String
    let toCode: String
    let toName: String
    let toCity: String
    let toTimezone: String
    let seatMapUrl: String
    let links: [(title: String, url: String)]

    var linkItems: [MapLink] { links.map { MapLink(title: $0.title, url: $0.url) } }

    static func == (lhs: FlightDefinition, rhs: FlightDefinition) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum TravelData {
    static let title = "Canada 2026"
    static let eyebrow = "STAN on Tour"
    static let startDate = "2026-08-04"
    static let endDate = "2026-08-22"
    static let startDateTime = "2026-08-04T16:00:00+02:00"
    static let exchangeRateCadToEur = 0.67
    static let crewNames = ["Andreas", "Nadine", "Simon", "Tobias"]
    static let adminName = "Andreas"
    static let expenseCategories = ["Essen", "Benzin", "Unterkunft", "Eintritt", "Parken", "Sonstiges"]

    static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "America/Toronto")
        return formatter
    }()

    static var tripStart: Date { isoDay.date(from: startDate) ?? .distantFuture }
    static var tripEnd: Date { isoDay.date(from: endDate) ?? .distantFuture }

    static let memberInterests: [String: [String]] = [
        "Andreas": ["Fotospots", "Geschichte", "Aussichtspunkte"],
        "Nadine": ["Shopping", "Cafés", "Fotospots"],
        "Simon": ["Sneaker", "Streetwear", "Basketball", "Gaming"],
        "Tobias": ["Sneaker", "Fußball", "Apple", "Elektronik"]
    ]

    static let memberColors: [String: String] = [
        "Andreas": "C82538",
        "Nadine": "2E7D5B",
        "Simon": "2C5FA8",
        "Tobias": "B26A00"
    ]

    static let documents = [
        "Reisepässe",
        "eTA",
        "ESTA für möglichen USA-Abstecher",
        "Flugbuchung",
        "Mietwagen",
        "Auslandskrankenversicherung",
        "Kreditkarten",
        "Führerschein",
        "Offline-Karten"
    ]

    static let dailyQuestionTemplates = [
        "Was war heute dein Highlight?",
        "Was hat dich heute überrascht?",
        "Was war heute typisch Kanada?",
        "Was war heute lustig?",
        "Was würdest du morgen gerne machen?",
        "Welchen Moment willst du nicht vergessen?",
        "Was war heute besser als erwartet?"
    ]

    static let awardTemplates = [
        "Bestes Foto des Tages",
        "Lustigster Moment",
        "Schönster Fotospot",
        "Kanadischster Moment",
        "Beste Essensentdeckung",
        "Tagesheld"
    ]

    static let defaultBucketListItems = [
        "Poutine essen",
        "Beaver Tail probieren",
        "Fähre fahren",
        "Sonnenuntergang am See sehen",
        "Sportgeschäft besuchen",
        "Outlet besuchen",
        "Bootsfahrt machen"
    ]

    static let stations: [Station] = [
        Station(
            id: "toronto", name: "Toronto", region: "Toronto",
            tags: ["Stadt", "Skyline", "Ankommen"], date: "2026-08-04",
            lat: 43.6532, lng: -79.3832, timezone: "America/Toronto",
            address: "Toronto, Ontario, Kanada",
            notes: "Ankommen, erster Überblick, Waterfront und CN Tower vormerken.",
            todos: ["Unterkunft bestätigen", "Erste Metro-/Presto-Option prüfen", "Restaurant in Laufnähe suchen"],
            mapsUrl: "https://www.google.com/maps/search/?api=1&query=Toronto%2C%20Ontario%2C%20Canada",
            relatedMaps: [
                ("Guildwood", "https://maps.app.goo.gl/Y2YVnjbU5xv1wmLC8?g_st=ic"),
                ("CN Tower", "https://maps.app.goo.gl/HyPdefpNszzSsBcUA?g_st=ic"),
                ("The Distillery District", "https://maps.app.goo.gl/z2kQkihzV7gSX6pz5?g_st=ic"),
                ("St. Lawrence Market", "https://maps.app.goo.gl/kStQ5KpAQrvDjiYz9?g_st=ic"),
                ("Casa Loma", "https://maps.app.goo.gl/amoUNeBTUDtaak2Y7?g_st=ic"),
                ("Toronto Islands", "https://maps.app.goo.gl/knYFh2ah6d8kC33z5?g_st=ic"),
                ("Kensington Market", "https://maps.app.goo.gl/Z7UFH6zYBFQeG8Z98?g_st=ic"),
                ("Black Creek Village", "https://maps.app.goo.gl/C2Tzx4cNcsYxtTgq8?g_st=ic")
            ]
        ),
        Station(
            id: "niagara-falls", name: "Niagara Falls", region: "Niagara Falls",
            tags: ["Wasserfall", "Natur", "Aussicht"], date: "2026-08-06",
            lat: 43.0896, lng: -79.0849, timezone: "America/Toronto",
            address: "Niagara Falls, Ontario, Kanada",
            notes: "Wasserfälle, Aussichtspunkte und mögliche Bootstour prüfen.",
            todos: ["Parkoptionen prüfen", "Regenjacken griffbereit", "Aussicht bei Tag und Abend"],
            mapsUrl: "https://www.google.com/maps/search/?api=1&query=Niagara%20Falls%2C%20Ontario%2C%20Canada",
            relatedMaps: [
                ("Niagara Falls Bahnhof", "https://maps.app.goo.gl/MDbgEv4Jz7pgmVKA7?g_st=ic"),
                ("Queenston Heights Park", "https://maps.app.goo.gl/eYP4wCLdpTgmAWi19?g_st=ic"),
                ("Nah an den Fällen", "https://maps.app.goo.gl/AqjvBBLEJTn7gsNS6?g_st=ic"),
                ("Niagarafälle", "https://maps.app.goo.gl/e7imxRHvFzL6Pbmd8?g_st=ic"),
                ("Skylon Tower", "https://maps.app.goo.gl/1k1BqtkFqiQUrv8g9?g_st=ic"),
                ("White Water Walk", "https://maps.app.goo.gl/oBVkNLbBF2fhsy9p8?g_st=ic"),
                ("Journey Behind the Falls", "https://maps.app.goo.gl/J17NoYZcfXiPaysN7?g_st=ic"),
                ("Cave of the Winds", "https://maps.app.goo.gl/ZDrnYNMUwFQi5tWv6?g_st=ic"),
                ("Observation Tower", "https://maps.app.goo.gl/mdTGvN2tjiQCJksKA?g_st=ic"),
                ("Niagara-on-the-Lake", "https://maps.app.goo.gl/uDXWrG1ziCYBaX6c7?g_st=ic"),
                ("Lock 3", "https://maps.app.goo.gl/x43wm9niQmN1ciJEA?g_st=ic")
            ]
        ),
        Station(
            id: "picton", name: "Picton", region: "Picton / Prince Edward County",
            tags: ["Natur", "Seeufer", "Roadtrip"], date: "2026-08-08",
            lat: 44.0074, lng: -77.1428, timezone: "America/Toronto",
            address: "Picton, Prince Edward County, Ontario, Kanada",
            notes: "Prince Edward County, Seeufer und entspannter Zwischenstopp.",
            todos: ["Sandbanks Provincial Park prüfen", "Fähre / Glenora Ferry prüfen", "Sonnenuntergang am Seeufer einplanen"],
            mapsUrl: "https://www.google.com/maps/search/?api=1&query=Picton%2C%20Ontario%2C%20Canada",
            relatedMaps: [
                ("Sandbanks", "https://maps.app.goo.gl/mcBSx6HewRNDmEXL6?g_st=ic"),
                ("Lake on the Mountain", "https://maps.app.goo.gl/SpTDHChjaymGtpo87?g_st=ic"),
                ("Slickers Eisdiele Bloomfield", "https://maps.app.goo.gl/6dsukeoVaBoqB2TKA?g_st=ic"),
                ("Prince Edward County", "https://maps.app.goo.gl/2UH5HEuuMisQvcsEA?g_st=ic")
            ]
        ),
        Station(
            id: "kingston", name: "Kingston", region: "Kingston",
            tags: ["Stadt", "Wasser", "Geschichte"], date: "2026-08-10",
            lat: 44.2312, lng: -76.4860, timezone: "America/Toronto",
            address: "Kingston, Ontario, Kanada",
            notes: "Historische Innenstadt, Hafen und Thousand-Islands-Option.",
            todos: ["Bootstour recherchieren", "Parkplatz Altstadt", "Fort Henry vormerken"],
            mapsUrl: "https://www.google.com/maps/search/?api=1&query=Kingston%2C%20Ontario%2C%20Canada",
            relatedMaps: [
                ("Kingston Waterfront", "https://maps.app.goo.gl/bKNTVszAB16kxZ1t7?g_st=ic"),
                ("Fort Henry", "https://maps.app.goo.gl/5pPqJB2TfF5BWYgq8?g_st=ic"),
                ("Gefängnismuseum", "https://maps.app.goo.gl/WTXJmNwuj8j5d2dA9?g_st=ic"),
                ("Gananoque", "https://maps.app.goo.gl/8dvjFjthCDV29m2w9?g_st=ic"),
                ("City Cruises", "https://maps.app.goo.gl/gLJFBUBdA5vhX5yX9?g_st=ic"),
                ("Hill Tower", "https://maps.app.goo.gl/vQctw9YbnKBUXVxW8?g_st=ic")
            ]
        ),
        Station(
            id: "thousand-islands", name: "Thousand Islands", region: "Thousand Islands",
            tags: ["Natur", "Wasser", "Aussicht", "Bootstour", "Roadtrip"], date: "2026-08-11",
            lat: 44.3296, lng: -76.1612, timezone: "America/Toronto",
            address: "Gananoque / 1000 Islands Parkway, Ontario, Kanada",
            notes: "Bootstour, Gananoque, 1000 Islands Parkway, Aussichtspunkte prüfen.",
            todos: ["Bootstour prüfen", "Wetter/Wind prüfen", "Parkmöglichkeit Gananoque prüfen", "Tickets/Abfahrtszeiten prüfen", "Kamera/Powerbank mitnehmen"],
            mapsUrl: "https://www.google.com/maps/search/?api=1&query=Gananoque%20Thousand%20Islands%20Ontario%20Canada",
            relatedMaps: [
                ("Gananoque", "https://maps.app.goo.gl/8dvjFjthCDV29m2w9?g_st=ic"),
                ("City Cruises", "https://maps.app.goo.gl/gLJFBUBdA5vhX5yX9?g_st=ic"),
                ("1000 Islands Tower", "https://maps.app.goo.gl/vQctw9YbnKBUXVxW8?g_st=ic")
            ]
        ),
        Station(
            id: "ottawa", name: "Ottawa", region: "Ottawa",
            tags: ["Stadt", "Kultur", "Parlament"], date: "2026-08-12",
            lat: 45.4215, lng: -75.6972, timezone: "America/Toronto",
            address: "Ottawa, Ontario, Kanada",
            notes: "Parliament Hill, Museen, ByWard Market und Rideau Canal.",
            todos: ["Parlament-Führung prüfen", "Museumsauswahl festlegen", "Abendspaziergang planen"],
            mapsUrl: "https://www.google.com/maps/search/?api=1&query=Ottawa%2C%20Ontario%2C%20Canada",
            relatedMaps: [
                ("ByWard Market", "https://maps.app.goo.gl/2GrGhTp1qrUPPbW16?g_st=ic"),
                ("Parlament", "https://maps.app.goo.gl/BKhqoxYhTVjcYu7c7?g_st=ic"),
                ("Notre Dame Cathedral Basilica", "https://maps.app.goo.gl/g9UVaP7SutjXuFTA7?g_st=ic")
            ]
        ),
        Station(
            id: "gatineau", name: "Gatineau", region: "Gatineau",
            tags: ["Natur", "Aussicht", "Roadtrip"], date: "2026-08-14",
            lat: 45.4765, lng: -75.7013, timezone: "America/Toronto",
            address: "Gatineau, Québec, Kanada",
            notes: "Gatineau Park, Blick zurück auf Ottawa und Naturzeit einplanen.",
            todos: ["Gatineau Park Route wählen", "Snacks und Wasser", "Wetter für Outdoor-Plan prüfen"],
            mapsUrl: "https://www.google.com/maps/search/?api=1&query=Gatineau%2C%20Quebec%2C%20Canada",
            relatedMaps: [
                ("Parc Omega", "https://maps.app.goo.gl/3JFtni8avgrXkPrj8?g_st=ic")
            ]
        )
    ]

    static func station(withId id: String) -> Station? {
        stations.first { $0.id == id }
    }

    /// Aktuelle Station anhand des Datums (letzte Station, deren Ankunftstag erreicht ist).
    static func currentStation(on date: Date = Date()) -> Station? {
        let reached = stations.filter { ($0.arrivalDate ?? .distantFuture) <= date }
        return reached.last ?? (date >= tripStart ? stations.first : nil)
    }

    static func nextStation(on date: Date = Date()) -> Station? {
        stations.first { ($0.arrivalDate ?? .distantPast) > date }
    }

    static let challenges: [ChallengeDefinition] = [
        ChallengeDefinition(id: "picton-1", station: "Picton", stationId: "picton", title: "Schönstes Strandfoto", points: 10),
        ChallengeDefinition(id: "picton-2", station: "Picton", stationId: "picton", title: "Leuchtturm entdecken", points: 10),
        ChallengeDefinition(id: "picton-3", station: "Picton", stationId: "picton", title: "Sonnenuntergang am Wasser", points: 20),
        ChallengeDefinition(id: "picton-4", station: "Picton", stationId: "picton", title: "Fähre fotografieren", points: 10),
        ChallengeDefinition(id: "picton-5", station: "Picton", stationId: "picton", title: "Lustigstes Schild", points: 10),
        ChallengeDefinition(id: "picton-6", station: "Picton", stationId: "picton", title: "Schönster Baum", points: 10),
        ChallengeDefinition(id: "kingston-1", station: "Kingston", stationId: "kingston", title: "Kanone fotografieren", points: 10),
        ChallengeDefinition(id: "kingston-2", station: "Kingston", stationId: "kingston", title: "Historisches Gebäude fotografieren", points: 10),
        ChallengeDefinition(id: "kingston-3", station: "Kingston", stationId: "kingston", title: "Schönstes Hafenfoto", points: 10),
        ChallengeDefinition(id: "kingston-4", station: "Kingston", stationId: "kingston", title: "Die meisten Boote auf einem Foto", points: 20),
        ChallengeDefinition(id: "kingston-5", station: "Kingston", stationId: "kingston", title: "Gruppenfoto mit historischer Kulisse", points: 20),
        ChallengeDefinition(id: "thousand-1", station: "Thousand Islands", stationId: "thousand-islands", title: "Kleinste Insel entdecken", points: 20),
        ChallengeDefinition(id: "thousand-2", station: "Thousand Islands", stationId: "thousand-islands", title: "Die meisten Inseln auf einem Bild", points: 20),
        ChallengeDefinition(id: "thousand-3", station: "Thousand Islands", stationId: "thousand-islands", title: "Lustigste Bootsbezeichnung", points: 10),
        ChallengeDefinition(id: "thousand-4", station: "Thousand Islands", stationId: "thousand-islands", title: "Schönster Brückenblick", points: 10),
        ChallengeDefinition(id: "thousand-5", station: "Thousand Islands", stationId: "thousand-islands", title: "Bestes Wasserpanorama", points: 20),
        ChallengeDefinition(id: "thousand-6", station: "Thousand Islands", stationId: "thousand-islands", title: "Erstes Wildtier fotografieren", points: 20),
        ChallengeDefinition(id: "toronto-1", station: "Toronto", stationId: "toronto", title: "CN Tower fotografieren", points: 10),
        ChallengeDefinition(id: "toronto-2", station: "Toronto", stationId: "toronto", title: "Toronto Skyline fotografieren", points: 10),
        ChallengeDefinition(id: "toronto-3", station: "Toronto", stationId: "toronto", title: "Straßenbahn fotografieren", points: 10),
        ChallengeDefinition(id: "toronto-4", station: "Toronto", stationId: "toronto", title: "Straßenmusiker entdecken", points: 10),
        ChallengeDefinition(id: "toronto-5", station: "Toronto", stationId: "toronto", title: "Typisch kanadisches Produkt finden", points: 10),
        ChallengeDefinition(id: "toronto-6", station: "Toronto", stationId: "toronto", title: "Verrücktestes Fast Food", points: 10),
        ChallengeDefinition(id: "niagara-1", station: "Niagara Falls", stationId: "niagara-falls", title: "Wasserfall fotografieren", points: 10),
        ChallengeDefinition(id: "niagara-2", station: "Niagara Falls", stationId: "niagara-falls", title: "Regenbogen fotografieren", points: 20),
        ChallengeDefinition(id: "niagara-3", station: "Niagara Falls", stationId: "niagara-falls", title: "Nassestes Foto", points: 10),
        ChallengeDefinition(id: "niagara-4", station: "Niagara Falls", stationId: "niagara-falls", title: "Foto mit maximaler Gischt", points: 20),
        ChallengeDefinition(id: "niagara-5", station: "Niagara Falls", stationId: "niagara-falls", title: "Gruppenfoto an den Fällen", points: 20),
        ChallengeDefinition(id: "niagara-6", station: "Niagara Falls", stationId: "niagara-falls", title: "Kreativstes Wasserfallfoto", points: 20),
        ChallengeDefinition(id: "gatineau-1", station: "Gatineau", stationId: "gatineau", title: "Französisches Schild entdecken", points: 10),
        ChallengeDefinition(id: "gatineau-2", station: "Gatineau", stationId: "gatineau", title: "Schönstes Waldfoto", points: 10),
        ChallengeDefinition(id: "gatineau-3", station: "Gatineau", stationId: "gatineau", title: "Panorama fotografieren", points: 10),
        ChallengeDefinition(id: "gatineau-4", station: "Gatineau", stationId: "gatineau", title: "Aussichtspunkt finden", points: 10),
        ChallengeDefinition(id: "gatineau-5", station: "Gatineau", stationId: "gatineau", title: "Naturfoto des Tages", points: 20),
        ChallengeDefinition(id: "ottawa-1", station: "Ottawa", stationId: "ottawa", title: "Parlament fotografieren", points: 10),
        ChallengeDefinition(id: "ottawa-2", station: "Ottawa", stationId: "ottawa", title: "Die meisten Flaggen auf einem Bild", points: 20),
        ChallengeDefinition(id: "ottawa-3", station: "Ottawa", stationId: "ottawa", title: "Statue entdecken", points: 10),
        ChallengeDefinition(id: "ottawa-4", station: "Ottawa", stationId: "ottawa", title: "Rideau Canal fotografieren", points: 10),
        ChallengeDefinition(id: "ottawa-5", station: "Ottawa", stationId: "ottawa", title: "Regierungsgebäude fotografieren", points: 10)
    ]

    static let bingoTasks: [BingoDefinition] = {
        var tasks: [BingoDefinition] = []
        func add(_ titles: [String], _ category: String, _ prefix: String, points: (Int) -> Int) {
            for (index, title) in titles.enumerated() {
                tasks.append(BingoDefinition(id: "bingo-\(prefix)-\(index + 1)", title: title, category: category, points: points(index)))
            }
        }
        add(["Kanadagans", "Chipmunk", "Eichhörnchen", "Waschbär", "Reiher", "Wildtier am Wasser"], "Tiere", "animal") { $0 == 5 ? 20 : 10 }
        add(["Kanadische Flagge", "Ahornblatt", "Kanadisches Produkt", "Polizeifahrzeug", "Briefkasten"], "Kanada", "canada") { _ in 10 }
        add(["Straßenbahn", "Fähre", "Zug", "Wassertaxi", "Boot"], "Verkehr", "traffic") { _ in 10 }
        add(["Sonnenaufgang am Wasser", "Sonnenuntergang am Wasser", "Wasserfall", "Regenbogen", "Spiegelung im Wasser"], "Wasser", "water") { $0 == 3 ? 20 : 10 }
        add(["Toronto Skyline", "CN Tower", "Niagara Falls", "Parlament", "Fort Henry", "Thousand Islands Aussichtspunkt"], "Städte", "city") { _ in 10 }
        add(["Straßenmusiker", "Künstler", "Canada-Crew-Gruppenfoto", "Selfie mit Wahrzeichen"], "Menschen", "people") { _ in 10 }
        add(["Schönster Baum", "Schönster Strand", "Leuchtturm", "Insel", "Panorama"], "Natur", "nature") { _ in 10 }
        add(["Lustigstes Schild", "Kuriosestes Fahrzeug", "Verrückteste Hausnummer", "Ungewöhnlicher Laden"], "Spaß", "fun") { $0 > 0 ? 20 : 10 }
        add(["Poutine essen", "Ahornsirup-Produkt", "Food Truck", "Kanadisches Eis", "Lokales Restaurant"], "Essen", "food") { _ in 10 }
        add(["Schönstes Foto der Reise", "Schönster Sonnenuntergang", "Schönster Sonnenaufgang", "Überraschendste Entdeckung", "Geheimtipp der Reise"], "Bonus", "bonus") { _ in 30 }
        return tasks
    }()

    static var bingoCategories: [String] {
        var seen = Set<String>()
        return bingoTasks.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }

    static let achievements: [AchievementDefinition] = [
        AchievementDefinition(id: "animal-spotter", title: "Tierbeobachter", icon: "🦆", description: "Tiere und Wildtiere dokumentiert.", condition: "5 Bingo-Felder aus Tiere/Natur", points: 30),
        AchievementDefinition(id: "photographer", title: "Fotograf", icon: "📷", description: "Viele Challenge-Fotos gesammelt.", condition: "10 Fotos", points: 30),
        AchievementDefinition(id: "explorer", title: "Entdecker", icon: "🧭", description: "Viele verschiedene Stationen aktiv erlebt.", condition: "Challenges an 5 Stationen", points: 30),
        AchievementDefinition(id: "nature-friend", title: "Naturfreund", icon: "🌲", description: "Naturmotive im Blick.", condition: "8 Natur/Wasser/Bingo-Felder", points: 30),
        AchievementDefinition(id: "city-expert", title: "Städteexperte", icon: "🏙", description: "Stadtmotive erledigt.", condition: "6 Städte/Verkehr-Felder", points: 30),
        AchievementDefinition(id: "waterfall-hunter", title: "Wasserfalljäger", icon: "🌊", description: "Niagara-Motive erledigt.", condition: "4 Niagara-Challenges", points: 30),
        AchievementDefinition(id: "island-king", title: "Inselkönig", icon: "🏝", description: "Thousand Islands gemeistert.", condition: "4 Thousand-Islands-Challenges", points: 30),
        AchievementDefinition(id: "canada-pro", title: "Kanada-Profi", icon: "🍁", description: "Kanada-Bingo stark gefüllt.", condition: "30 Bingo-Felder", points: 50),
        AchievementDefinition(id: "sunset-hunter", title: "Sonnenuntergangsjäger", icon: "🌅", description: "Sonnenauf- oder Untergänge gesammelt.", condition: "3 Sonnen-Felder/Challenges", points: 30),
        AchievementDefinition(id: "roadtrip-champion", title: "Roadtrip Champion", icon: "🏆", description: "Gesamtwertung dominiert.", condition: "50 erledigte Aufgaben", points: 50)
    ]

    static let flights: [FlightDefinition] = [
        FlightDefinition(
            id: "lh240-2026-08-04", direction: "Hinflug", flightNumber: "LH240",
            date: "2026-08-04", airline: "Lufthansa", operatedBy: "Lufthansa", codeshareNote: "",
            fromCode: "FRA", fromName: "Frankfurt am Main", fromCity: "Frankfurt", fromTimezone: "Europe/Berlin",
            toCode: "YYZ", toName: "Toronto Pearson", toCity: "Toronto", toTimezone: "America/Toronto",
            seatMapUrl: "https://www.lufthansa.com/de/de/sitzplaene",
            links: [
                ("Lufthansa Flugstatus", "https://www.lufthansa.com/de/de/flugstatus"),
                ("Abflug Frankfurt", "https://www.frankfurt-airport.com/de/fluege-und-transfer/flugsuche.html"),
                ("Ankunft Toronto Pearson", "https://www.torontopearson.com/en/departures"),
                ("Flightradar24", "https://www.flightradar24.com/data/flights/lh240"),
                ("Online Check-in", "https://www.lufthansa.com/de/de/online-check-in")
            ]
        ),
        FlightDefinition(
            id: "lh6779-2026-08-22", direction: "Rückflug", flightNumber: "LH6779",
            date: "2026-08-22", airline: "Lufthansa", operatedBy: "Air Canada",
            codeshareNote: "Lufthansa-Codeshare, vermutlich durchgeführt von Air Canada",
            fromCode: "YYZ", fromName: "Toronto Pearson", fromCity: "Toronto", fromTimezone: "America/Toronto",
            toCode: "FRA", toName: "Frankfurt am Main", toCity: "Frankfurt", toTimezone: "Europe/Berlin",
            seatMapUrl: "https://www.aircanada.com/ca/en/aco/home/fly/onboard/fleet.html",
            links: [
                ("Air Canada Flugstatus", "https://www.aircanada.com/ca/en/aco/home/fly/flight-information/flight-status-results.html"),
                ("Lufthansa Flugstatus", "https://www.lufthansa.com/de/de/flugstatus"),
                ("Abflug Toronto Pearson", "https://www.torontopearson.com/en/departures"),
                ("Ankunft Frankfurt", "https://www.frankfurt-airport.com/de/fluege-und-transfer/flugsuche.html"),
                ("Flightradar24", "https://www.flightradar24.com/data/flights/lh6779"),
                ("Check-in Air Canada", "https://www.aircanada.com/ca/en/aco/home/fly/at-the-airport/check-in-information.html")
            ]
        )
    ]

    static var infoSections: [InfoSection] {
        travelInfos.map { InfoSection(title: $0.title, items: $0.items) }
    }

    static let travelInfos: [(title: String, items: [String])] = [
        ("Einreise & Dokumente", [
            "Reisepässe für alle vier Reisenden gültig",
            "eTA (Electronic Travel Authorization) für Kanada beantragen",
            "ESTA nur nötig bei USA-Abstecher (z. B. Cave of the Winds)",
            "Führerschein + internationale Kreditkarten mitnehmen"
        ]),
        ("Geld & Kosten", [
            "Währung: Kanadischer Dollar (CAD), Kurs ca. 1 CAD = 0,67 EUR",
            "Kreditkarte ist Standard, auch für Kleinbeträge",
            "Trinkgeld 15–20 % in Restaurants üblich",
            "Steuern (HST 13 % in Ontario) kommen an der Kasse dazu"
        ]),
        ("Unterwegs", [
            "Mietwagen: Vertrag, Versicherung und Fahrer prüfen",
            "Tempolimits in km/h – Highways meist 100 km/h",
            "Offline-Karten für Ontario/Québec vorbereiten",
            "Roaming/eSIM für Kanada vor Abflug klären"
        ]),
        ("Gesundheit & Sicherheit", [
            "Auslandskrankenversicherung für alle Reisenden",
            "Notruf: 911",
            "Sonnenschutz und Mückenschutz einpacken",
            "Wildtiere: Abstand halten, nicht füttern"
        ])
    ]
}
