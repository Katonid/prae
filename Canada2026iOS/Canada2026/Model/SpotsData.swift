import Foundation
import CoreLocation

// Fotospot- und "Interessantes"-Kataloge – vollständig portiert aus
// src/data/photoSpots.js und src/services/interestingService.js der PWA.

struct PhotoSpot: Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let lat: Double
    let lng: Double
    let category: String
    let description: String
    let bestTime: String
    let tips: String

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
    var mapsUrl: URL? {
        URL(string: "https://www.google.com/maps/search/?api=1&query=\(lat),\(lng)")
    }
}

struct InterestingPlace: Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let lat: Double
    let lng: Double
    let category: String
    let interests: [String]
    let description: String

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
    var mapsUrl: URL? {
        URL(string: "https://www.google.com/maps/search/?api=1&query=\(lat),\(lng)")
    }
}

struct InterestGroup: Identifiable, Hashable {
    let id: String
    let label: String
    let interests: [String]
}

enum SpotsData {
    static let interestGroups: [InterestGroup] = [
        InterestGroup(id: "sport", label: "Sport", interests: ["Basketball", "Fußball", "Baseball", "Eishockey"]),
        InterestGroup(id: "shopping", label: "Shopping", interests: ["Shopping", "Sneaker", "Streetwear", "Sportbekleidung", "Outlets"]),
        InterestGroup(id: "tech", label: "Technik", interests: ["Apple", "Gaming", "Elektronik"]),
        InterestGroup(id: "leisure", label: "Freizeit", interests: ["Freizeitparks", "Aussichtspunkte", "Fotospots", "Tiere", "Cafés", "Geschichte"])
    ]

    static var photoSpotRegions: [String] {
        var seen = Set<String>()
        return photoSpots.compactMap { seen.insert($0.region).inserted ? $0.region : nil }
    }

    static let photoSpots: [PhotoSpot] = [
        PhotoSpot(id: "toronto-cn-tower", name: "CN Tower", region: "Toronto", lat: 43.6426, lng: -79.3871, category: "Skyline / Wahrzeichen", description: "Klassisches Toronto-Motiv mit sehr hohem Wiedererkennungswert.", bestTime: "später Nachmittag / Sonnenuntergang", tips: "Auch gut kombinierbar mit Harbourfront oder Toronto Islands."),
        PhotoSpot(id: "toronto-rogers-centre-view", name: "Rogers Centre View", region: "Toronto", lat: 43.6414, lng: -79.3894, category: "Architektur / Stadt", description: "Guter Blick auf Stadion, CN Tower und Downtown-Struktur.", bestTime: "Nachmittag", tips: "Vom Bereich Bremner Boulevard aus ergeben sich einfache Stadtmotive."),
        PhotoSpot(id: "toronto-harbourfront-centre", name: "Harbourfront Centre", region: "Toronto", lat: 43.6389, lng: -79.3829, category: "Wasser / Stadt", description: "Promenade, Boote und Skyline direkt am Ontariosee.", bestTime: "Sonnenuntergang", tips: "Ideal für entspannte Canada-Crew-Fotos mit Wasser im Hintergrund."),
        PhotoSpot(id: "toronto-islands-skyline", name: "Toronto Islands Skyline View", region: "Toronto", lat: 43.6208, lng: -79.3783, category: "Skyline / Aussicht", description: "Einer der besten klassischen Skyline-Blicke auf Toronto.", bestTime: "Abend / blaue Stunde", tips: "Fähre einplanen und genug Zeit für den Rückweg lassen."),
        PhotoSpot(id: "toronto-distillery-district", name: "Distillery District", region: "Toronto", lat: 43.6503, lng: -79.3596, category: "Altstadt / Architektur", description: "Backstein, Gassen und historische Industriearchitektur.", bestTime: "Vormittag", tips: "Früh hingehen, wenn weniger Menschen in den Gassen sind."),
        PhotoSpot(id: "toronto-kensington-market", name: "Kensington Market", region: "Toronto", lat: 43.6547, lng: -79.4004, category: "Street / Kultur", description: "Bunte Strassen, kleine Laeden und lebendige Details.", bestTime: "Mittag / Nachmittag", tips: "Gut für Street-Fotos, Essen und kleine Challenge-Aufgaben."),
        PhotoSpot(id: "toronto-graffiti-alley", name: "Graffiti Alley", region: "Toronto", lat: 43.6478, lng: -79.3982, category: "Street Art", description: "Lange Gasse mit vielen farbigen Wandbildern.", bestTime: "heller Nachmittag", tips: "Weitwinkel und Porträts funktionieren hier besonders gut."),
        PhotoSpot(id: "toronto-casa-loma", name: "Casa Loma", region: "Toronto", lat: 43.678, lng: -79.4094, category: "Architektur / Wahrzeichen", description: "Schlossartige Architektur mitten in Toronto.", bestTime: "Vormittag", tips: "Aussenansichten und Treppenbereiche für Canada-Crew-Bilder nutzen."),
        PhotoSpot(id: "toronto-nathan-phillips-square", name: "Nathan Phillips Square", region: "Toronto", lat: 43.6525, lng: -79.3832, category: "Stadt / Wahrzeichen", description: "Bekannter Platz mit Toronto-Schriftzug und City Hall.", bestTime: "Abend", tips: "Bei Beleuchtung wirkt der Platz besonders gut."),
        PhotoSpot(id: "toronto-royal-ontario-museum", name: "Royal Ontario Museum", region: "Toronto", lat: 43.6677, lng: -79.3948, category: "Architektur / Museum", description: "Kontrast aus historischer Fassade und moderner Glasform.", bestTime: "Vormittag / Nachmittag", tips: "Auch als Schlechtwetter-Spot gut geeignet."),
        PhotoSpot(id: "toronto-st-lawrence-market", name: "St. Lawrence Market", region: "Toronto", lat: 43.6487, lng: -79.3715, category: "Essen / Markt", description: "Historischer Markt mit Food-Motiven und Toronto-Atmosphaere.", bestTime: "Vormittag", tips: "Gut für Challenge: kanadisches Essen finden."),
        PhotoSpot(id: "toronto-high-park", name: "High Park", region: "Toronto", lat: 43.6465, lng: -79.4637, category: "Natur / Park", description: "Großer Stadtpark mit Wegen, Wiesen und Seeufernähe.", bestTime: "Morgen / später Nachmittag", tips: "Ruhiger Kontrast zu Downtown und gut für Pausenfotos."),
        PhotoSpot(id: "niagara-horseshoe-falls", name: "Horseshoe Falls", region: "Niagara Falls", lat: 43.0779, lng: -79.0759, category: "Wasserfall / Wahrzeichen", description: "Das eindrucksvollste Wasserfallmotiv der Niagara Falls.", bestTime: "früher Morgen / Abend", tips: "Spritzwasser einplanen und Linse regelmaessig trocknen."),
        PhotoSpot(id: "niagara-table-rock", name: "Table Rock Centre", region: "Niagara Falls", lat: 43.0792, lng: -79.0784, category: "Aussicht / Wasserfall", description: "Sehr naher Blick auf die Kante der Horseshoe Falls.", bestTime: "Vormittag", tips: "Gut für dramatische Detailaufnahmen mit viel Wasser."),
        PhotoSpot(id: "niagara-skylon-tower", name: "Skylon Tower", region: "Niagara Falls", lat: 43.085, lng: -79.0792, category: "Aussicht / Skyline", description: "Hoher Aussichtspunkt Über Wasserfaelle und Stadt.", bestTime: "Sonnenuntergang", tips: "Bei klarer Sicht lohnt sich der Blick Richtung Fluss und Falls."),
        PhotoSpot(id: "niagara-journey-behind-the-falls", name: "Journey Behind the Falls", region: "Niagara Falls", lat: 43.0798, lng: -79.078, category: "Erlebnis / Wasserfall", description: "Nahe Perspektiven am Fuss der Horseshoe Falls.", bestTime: "tagsüber", tips: "Wasserschutz für Handy oder Kamera mitnehmen."),
        PhotoSpot(id: "niagara-clifton-hill", name: "Clifton Hill", region: "Niagara Falls", lat: 43.0912, lng: -79.0751, category: "Street / Canada Crew", description: "Bunte Vergnuegungsmeile mit Lichtern und Schildern.", bestTime: "Abend", tips: "Gut für lustige Straßenschilder und Canada-Crew-Schnappschüsse."),
        PhotoSpot(id: "niagara-rainbow-bridge", name: "Rainbow Bridge View", region: "Niagara Falls", lat: 43.0908, lng: -79.0678, category: "Brücke / Aussicht", description: "Blick auf Brücke, Fluss und internationale Grenze.", bestTime: "Nachmittag", tips: "Auch interessant für einen möglichen USA-Abstecher-Kontext."),
        PhotoSpot(id: "niagara-floral-clock", name: "Niagara Parks Floral Clock", region: "Niagara Falls", lat: 43.151, lng: -79.0495, category: "Park / Detail", description: "Bekannte Blumenuhr entlang des Niagara Parkway.", bestTime: "Vormittag", tips: "Als kurzer Fotostopp auf einer Fahrt entlang des Parkway geeignet."),
        PhotoSpot(id: "niagara-whirlpool-aero-car", name: "Whirlpool Aero Car", region: "Niagara Falls", lat: 43.1196, lng: -79.0706, category: "Fluss / Aussicht", description: "Blick auf den Niagara Whirlpool und die Schlucht.", bestTime: "Nachmittag", tips: "Auch ohne Fahrt sind Motive in der Umgebung möglich."),
        PhotoSpot(id: "picton-main-street", name: "Picton Main Street", region: "Picton / Prince Edward County", lat: 44.0075, lng: -77.142, category: "Kleinstadt / Street", description: "Kleine Laeden, Fassaden und entspannte County-Atmosphaere.", bestTime: "Vormittag", tips: "Gut für Spaziergang, Snacks und kleine Detailfotos."),
        PhotoSpot(id: "picton-harbour", name: "Picton Harbour", region: "Picton / Prince Edward County", lat: 44.0126, lng: -77.1376, category: "Wasser / Hafen", description: "Ruhiges Hafenmotiv mit Booten und Wasserblick.", bestTime: "Morgen / Abend", tips: "Schöner Ort für ein kurzes Canada-Crew-Foto am Wasser."),
        PhotoSpot(id: "pec-sandbanks-dunes", name: "Sandbanks Provincial Park Dunes", region: "Picton / Prince Edward County", lat: 43.9138, lng: -77.276, category: "Natur / Strand", description: "Sanddünen, Strand und weiter Blick Über den Ontariosee.", bestTime: "später Nachmittag", tips: "Wind, Sonne und helle Flächen beim Fotografieren beachten."),
        PhotoSpot(id: "pec-lake-on-the-mountain", name: "Lake on the Mountain", region: "Picton / Prince Edward County", lat: 44.0346, lng: -77.0573, category: "Aussicht / Natur", description: "Ungewoehnlicher See auf einer Anhoehe mit Blick in die Region.", bestTime: "Nachmittag", tips: "Gut mit der Glenora Ferry kombinierbar."),
        PhotoSpot(id: "pec-glenora-ferry", name: "Glenora Ferry", region: "Picton / Prince Edward County", lat: 44.0432, lng: -77.0496, category: "Fahrt / Wasser", description: "Kurze Faehrfahrt mit Wasser- und Ufermotiven.", bestTime: "tagsüber", tips: "Vom Deck aus einfache Reisemotive aufnehmen."),
        PhotoSpot(id: "pec-wellington-beach", name: "Wellington Beach", region: "Picton / Prince Edward County", lat: 43.952, lng: -77.3538, category: "Strand / Seeufer", description: "Steiniger Strand und ruhiges Seeufer in Wellington.", bestTime: "Sonnenuntergang", tips: "Gut für das schönste Seeufer-Foto."),
        PhotoSpot(id: "pec-drake-devonshire-view", name: "Wellington Waterfront", region: "Picton / Prince Edward County", lat: 43.9514, lng: -77.3494, category: "Wasser / Ort", description: "Promenade und Uferblick mit entspannter County-Stimmung.", bestTime: "Abend", tips: "Nach dem Essen oder Spaziergang gut mitzunehmen."),
        PhotoSpot(id: "kingston-city-hall", name: "Kingston City Hall", region: "Kingston", lat: 44.2298, lng: -76.4808, category: "Architektur / Wahrzeichen", description: "Historisches Rathaus direkt am Market Square.", bestTime: "Vormittag / Abend", tips: "Frontansicht und Details am Platz fotografieren."),
        PhotoSpot(id: "kingston-waterfront", name: "Kingston Waterfront", region: "Kingston", lat: 44.228, lng: -76.4801, category: "Wasser / Stadt", description: "Uferpromenade mit Blick auf Hafen und Ontariosee.", bestTime: "Sonnenuntergang", tips: "Ideal für Spaziergang und ruhige Canada-Crew-Fotos."),
        PhotoSpot(id: "kingston-fort-henry", name: "Fort Henry", region: "Kingston", lat: 44.2318, lng: -76.4599, category: "Geschichte / Aussicht", description: "Historische Festung mit Blick auf Kingston und Wasser.", bestTime: "Nachmittag", tips: "Weitwinkel für Mauern und Aussicht mitnehmen."),
        PhotoSpot(id: "kingston-queens-university", name: "Queen's University", region: "Kingston", lat: 44.2253, lng: -76.4951, category: "Campus / Architektur", description: "Historische Campusgebäude und grüne Wege.", bestTime: "Vormittag", tips: "Ruhige Alternative zur Innenstadt."),
        PhotoSpot(id: "kingston-kingston-penitentiary", name: "Kingston Penitentiary", region: "Kingston", lat: 44.2207, lng: -76.5137, category: "Geschichte / Architektur", description: "Markantes historisches Gebaeude am Wasser.", bestTime: "Nachmittag", tips: "Aussenansicht respektvoll und aus Öffentlichen Bereichen fotografieren."),
        PhotoSpot(id: "kingston-pump-house", name: "PumpHouse Museum", region: "Kingston", lat: 44.2254, lng: -76.4868, category: "Museum / Wasser", description: "Kleines Technikmuseum nahe der Waterfront.", bestTime: "tagsüber", tips: "Gut mit einem Hafen- oder Innenstadtspaziergang kombinierbar."),
        PhotoSpot(id: "kingston-confederation-park", name: "Confederation Park", region: "Kingston", lat: 44.2294, lng: -76.4801, category: "Park / Hafen", description: "Zentraler Park am Wasser mit Blick auf Boote und City Hall.", bestTime: "Abend", tips: "Einfacher Spot für Gruppenfoto und Hafenstimmung."),
        PhotoSpot(id: "thousand-islands-gananoque-harbour", name: "Gananoque Waterfront", region: "Thousand Islands", lat: 44.3296, lng: -76.1612, category: "Hafen / Inseln", description: "Startpunkt vieler Bootstouren mit Wasser- und Inselmotiven.", bestTime: "Morgen", tips: "Vor einer Bootstour etwas Zeit am Hafen einplanen."),
        PhotoSpot(id: "thousand-islands-ivy-lea", name: "Ivy Lea Bridge Viewpoint", region: "Thousand Islands", lat: 44.3635, lng: -76.0013, category: "Fluss / Inseln", description: "Kleiner Ort mit Nähe zu Brücken und Inselblicken.", bestTime: "Nachmittag", tips: "Guter Zwischenstopp entlang des Thousand Islands Parkway."),
        PhotoSpot(id: "thousand-islands-1000-islands-tower", name: "1000 Islands Tower", region: "Thousand Islands", lat: 44.347, lng: -75.9839, category: "Aussicht / Inseln", description: "Hoher Aussichtspunkt Über den Sankt-Lorenz-Strom.", bestTime: "klarer Nachmittag", tips: "Bei guter Sicht besonders lohnend für Übersichtsfotos."),
        PhotoSpot(id: "thousand-islands-parkway-lookouts", name: "Thousand Islands Parkway Lookouts", region: "Thousand Islands", lat: 44.3652, lng: -76.0685, category: "Aussicht / Roadtrip", description: "Mehrere kleine Aussichtspunkte entlang des Thousand Islands Parkway.", bestTime: "Nachmittag / Abend", tips: "Als flexible Fotostopps zwischen Gananoque, Ivy Lea und dem Tower einplanen."),
        PhotoSpot(id: "thousand-islands-boldt-castle-view", name: "Boldt Castle View / Boat Tour Spot", region: "Thousand Islands", lat: 44.3441, lng: -75.9229, category: "Schloss / Inseln", description: "Bekanntes Schlossmotiv auf Heart Island.", bestTime: "Vormittag / Nachmittag", tips: "Oft am besten von Bootstouren aus zu fotografieren."),
        PhotoSpot(id: "thousand-islands-brockville-railway-tunnel", name: "Brockville Railway Tunnel", region: "Thousand Islands", lat: 44.5905, lng: -75.681, category: "Architektur / Licht", description: "Historischer Tunnel mit farbiger Beleuchtung.", bestTime: "tagsüber", tips: "Innen auf ruhige Hand oder Nachtmodus achten."),
        PhotoSpot(id: "thousand-islands-brockville-waterfront", name: "Brockville Waterfront", region: "Thousand Islands", lat: 44.5895, lng: -75.6844, category: "Wasser / Stadt", description: "Uferblick am Sankt-Lorenz-Strom mit Promenade.", bestTime: "Abend", tips: "Gut mit dem Railway Tunnel kombinierbar."),
        PhotoSpot(id: "ottawa-parliament-hill", name: "Parliament Hill", region: "Ottawa", lat: 45.4236, lng: -75.7009, category: "Wahrzeichen / Architektur", description: "Klassisches Ottawa-Motiv mit Parlamentsgebäuden.", bestTime: "Vormittag / Abend", tips: "Mehrere Perspektiven vom Lawn und von gegenÜber einplanen."),
        PhotoSpot(id: "ottawa-rideau-canal", name: "Rideau Canal", region: "Ottawa", lat: 45.4217, lng: -75.69, category: "Wasser / Stadt", description: "Historischer Kanal mit Brücken und Stadtblicken.", bestTime: "später Nachmittag", tips: "Gut für Linien, Spiegelungen und Spaziergangsfotos."),
        PhotoSpot(id: "ottawa-byward-market", name: "ByWard Market", region: "Ottawa", lat: 45.4275, lng: -75.6923, category: "Markt / Street", description: "Lebendiges Viertel mit Essen, Laeden und Strassenszenen.", bestTime: "Mittag / Abend", tips: "Gut für Food-Fotos und Roadtrip Challenges."),
        PhotoSpot(id: "ottawa-major-hill-park", name: "Major's Hill Park", region: "Ottawa", lat: 45.4266, lng: -75.6961, category: "Park / Aussicht", description: "Grüner Park mit Blick auf Parliament Hill und Umgebung.", bestTime: "Abend", tips: "Sehr gut als entspannter Spot nach ByWard Market."),
        PhotoSpot(id: "ottawa-national-gallery", name: "National Gallery of Canada", region: "Ottawa", lat: 45.4295, lng: -75.6986, category: "Museum / Architektur", description: "Markante Glasarchitektur und bekannte Spinnenskulptur.", bestTime: "Vormittag", tips: "Aussenmotiv ist auch ohne Museumsbesuch schnell machbar."),
        PhotoSpot(id: "ottawa-fairmont-chateau-laurier", name: "Fairmont Chateau Laurier", region: "Ottawa", lat: 45.4254, lng: -75.695, category: "Architektur / Wahrzeichen", description: "Schlossartiges Hotel direkt am Kanal und nahe Parliament Hill.", bestTime: "Abend", tips: "Mit Rideau Canal oder Major's Hill Park kombinieren."),
        PhotoSpot(id: "ottawa-canadian-museum-of-nature", name: "Canadian Museum of Nature", region: "Ottawa", lat: 45.4128, lng: -75.6884, category: "Museum / Architektur", description: "Historisches Museumsgebäude mit markanter Fassade.", bestTime: "Vormittag / Nachmittag", tips: "Gute Schlechtwetteroption mit starkem Aussenmotiv."),
        PhotoSpot(id: "gatineau-canadian-museum-of-history", name: "Canadian Museum of History", region: "Gatineau", lat: 45.4299, lng: -75.7081, category: "Museum / Architektur", description: "Geschwungene Architektur mit Blick Richtung Ottawa.", bestTime: "Nachmittag / Abend", tips: "Von hier aus gibt es schöne Perspektiven auf Parliament Hill."),
        PhotoSpot(id: "gatineau-jacques-cartier-park", name: "Jacques-Cartier Park", region: "Gatineau", lat: 45.4346, lng: -75.7093, category: "Park / Fluss", description: "Park am Ottawa River mit Blick auf Ottawa.", bestTime: "Abend", tips: "Gut für ruhige Canada-Crew-Fotos und Skyline-Blick."),
        PhotoSpot(id: "gatineau-park-champlain-lookout", name: "Champlain Lookout", region: "Gatineau", lat: 45.5087, lng: -75.8551, category: "Aussicht / Natur", description: "Bekannter Aussichtspunkt im Gatineau Park.", bestTime: "Sonnenuntergang", tips: "Wetter und Parkzugang vorher prüfen."),
        PhotoSpot(id: "gatineau-pink-lake", name: "Pink Lake", region: "Gatineau", lat: 45.4752, lng: -75.8123, category: "Natur / See", description: "Kleiner See im Gatineau Park mit Wald- und Wasserblicken.", bestTime: "Morgen / später Nachmittag", tips: "Auf markierten Wegen bleiben und Zeit für den Rundweg einplanen."),
        PhotoSpot(id: "gatineau-mackenzie-king-estate", name: "Mackenzie King Estate", region: "Gatineau", lat: 45.5102, lng: -75.7884, category: "Garten / Geschichte", description: "Historisches Anwesen mit Gartenruinen und Waldumgebung.", bestTime: "Vormittag", tips: "Gut für ruhige Detailfotos und Canada-Crew-Porträts."),
        PhotoSpot(id: "gatineau-belvedere-etienne-brule", name: "Belvedere Etienne-Brule", region: "Gatineau", lat: 45.4868, lng: -75.8289, category: "Aussicht / Natur", description: "Aussichtspunkt im Gatineau Park mit weitem Blick.", bestTime: "Nachmittag / Abend", tips: "Als Alternative oder Ergaenzung zu Champlain Lookout merken."),    ]

    static let interestingPlaces: [InterestingPlace] = [
        InterestingPlace(id: "toronto-eaton-centre", name: "CF Toronto Eaton Centre", region: "Toronto", lat: 43.6544, lng: -79.3807, category: "Shopping", interests: ["Shopping",  "Streetwear",  "Sneaker"], description: "Großes Einkaufszentrum in Downtown Toronto."),
        InterestingPlace(id: "toronto-nike-yorkdale", name: "Nike Yorkdale", region: "Toronto", lat: 43.7256, lng: -79.4528, category: "Sneaker", interests: ["Sneaker",  "Sportbekleidung",  "Shopping"], description: "Nike Store im Yorkdale Shopping Centre."),
        InterestingPlace(id: "toronto-foot-locker-eaton", name: "Foot Locker Eaton Centre", region: "Toronto", lat: 43.6547, lng: -79.3802, category: "Sneaker", interests: ["Sneaker",  "Streetwear"], description: "Sneaker- und Streetwear-Stopp in Downtown Toronto."),
        InterestingPlace(id: "toronto-jd-sports-eaton", name: "JD Sports Eaton Centre", region: "Toronto", lat: 43.6545, lng: -79.3805, category: "Sneaker", interests: ["Sneaker",  "Streetwear",  "Sportbekleidung"], description: "Relevant für Sneaker, Streetwear und Sportbekleidung."),
        InterestingPlace(id: "toronto-apple-eaton", name: "Apple Eaton Centre", region: "Toronto", lat: 43.6541, lng: -79.3807, category: "Technik", interests: ["Apple",  "Elektronik"], description: "Apple Store im Zentrum."),
        InterestingPlace(id: "toronto-sport-chek-eaton", name: "Sport Chek Eaton Centre", region: "Toronto", lat: 43.6546, lng: -79.3806, category: "Sportbekleidung", interests: ["Sportbekleidung",  "Basketball",  "Fußball",  "Eishockey"], description: "Sport- und Outdoor-Ausrüstung."),
        InterestingPlace(id: "toronto-lids-eaton", name: "Lids Eaton Centre", region: "Toronto", lat: 43.6543, lng: -79.3808, category: "Streetwear", interests: ["Streetwear",  "Baseball",  "Eishockey"], description: "Caps und Team-Merch."),
        InterestingPlace(id: "toronto-apple-yorkdale", name: "Apple Yorkdale", region: "Toronto", lat: 43.7253, lng: -79.4522, category: "Technik", interests: ["Apple",  "Elektronik"], description: "Apple Store im Yorkdale Shopping Centre."),
        InterestingPlace(id: "toronto-nathan-phillips", name: "Basketballplatz / Nathan Phillips Area", region: "Toronto", lat: 43.6525, lng: -79.3835, category: "Sport", interests: ["Basketball",  "Aussichtspunkte"], description: "Urbaner Stopp nahe City Hall."),
        InterestingPlace(id: "niagara-outlet-collection", name: "Outlet Collection at Niagara", region: "Niagara Falls", lat: 43.1579, lng: -79.1725, category: "Outlet", interests: ["Outlets",  "Sneaker",  "Sportbekleidung",  "Shopping"], description: "Outlet-Zentrum zwischen Niagara Falls und Niagara-on-the-Lake."),
        InterestingPlace(id: "niagara-clifton-hill", name: "Clifton Hill", region: "Niagara Falls", lat: 43.0916, lng: -79.0755, category: "Freizeit", interests: ["Freizeitparks",  "Gaming",  "Fotospots"], description: "Arcades, Attraktionen und Fotomotive nahe den Fällen."),
        InterestingPlace(id: "niagara-skylon", name: "Skylon Tower", region: "Niagara Falls", lat: 43.0856, lng: -79.0793, category: "Aussichtspunkt", interests: ["Aussichtspunkte",  "Fotospots"], description: "Klassischer Aussichtspunkt über die Fälle."),
        InterestingPlace(id: "kingston-cataraqui", name: "Cataraqui Centre", region: "Kingston", lat: 44.2572, lng: -76.5686, category: "Shopping", interests: ["Shopping",  "Sneaker",  "Streetwear",  "Sportbekleidung"], description: "Großes Einkaufszentrum in Kingston."),
        InterestingPlace(id: "kingston-sport-chek", name: "Sport Chek Kingston", region: "Kingston", lat: 44.2572, lng: -76.5688, category: "Sportbekleidung", interests: ["Sportbekleidung",  "Basketball",  "Fußball"], description: "Sportbekleidung und Ausrüstung im Cataraqui-Umfeld."),
        InterestingPlace(id: "kingston-waterfront", name: "Kingston Waterfront", region: "Kingston", lat: 44.2297, lng: -76.4808, category: "Fotospot", interests: ["Fotospots",  "Aussichtspunkte",  "Geschichte"], description: "Hafen, Wasser und historische Kulisse."),
        InterestingPlace(id: "thousand-islands-tower", name: "1000 Islands Tower", region: "Thousand Islands", lat: 44.3437, lng: -75.9839, category: "Aussichtspunkt", interests: ["Aussichtspunkte",  "Fotospots"], description: "Hoher Aussichtspunkt über die Inselwelt."),
        InterestingPlace(id: "gananoque-waterfront", name: "Gananoque Waterfront", region: "Thousand Islands", lat: 44.3268, lng: -76.1611, category: "Fotospot", interests: ["Fotospots",  "Tiere",  "Aussichtspunkte"], description: "Wasser, Boote und Inselgefühl."),
        InterestingPlace(id: "ottawa-rideau-centre", name: "CF Rideau Centre", region: "Ottawa", lat: 45.4252, lng: -75.6900, category: "Shopping", interests: ["Shopping",  "Sneaker",  "Streetwear",  "Apple",  "Sportbekleidung"], description: "Zentrales Einkaufszentrum in Ottawa."),
        InterestingPlace(id: "ottawa-apple-rideau", name: "Apple Rideau", region: "Ottawa", lat: 45.4252, lng: -75.6900, category: "Technik", interests: ["Apple",  "Elektronik"], description: "Apple Store im Rideau Centre."),
        InterestingPlace(id: "ottawa-foot-locker-rideau", name: "Foot Locker Rideau Centre", region: "Ottawa", lat: 45.4252, lng: -75.6900, category: "Sneaker", interests: ["Sneaker",  "Streetwear"], description: "Sneaker-Stopp im Rideau Centre."),
        InterestingPlace(id: "ottawa-parliament", name: "Parliament Hill View", region: "Ottawa", lat: 45.4248, lng: -75.6992, category: "Aussichtspunkt", interests: ["Fotospots",  "Geschichte",  "Aussichtspunkte"], description: "Klassisches Ottawa-Motiv."),
        InterestingPlace(id: "gatineau-park-lookout", name: "Gatineau Park Lookouts", region: "Gatineau", lat: 45.5088, lng: -75.8506, category: "Aussichtspunkt", interests: ["Aussichtspunkte",  "Fotospots",  "Tiere"], description: "Natur, Aussicht und Fotostopps im Gatineau Park."),    ]
}
