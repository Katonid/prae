import Foundation

// Automatische Kategorisierung und Schnelleingabe-Parser.
//
// Die Kategorisierung arbeitet mit Stichwortlisten (deutsch + englisch,
// inklusive typischer Händlernamen) — deterministisch und erklärbar.
// Sie liefert nur einen Vorschlag; jede Zuordnung bleibt im Editor änderbar.

enum Classifier {

    private static let keywords: [(ExpenseCategory, [String])] = [
        (.fluege, [
            "lufthansa", "condor", "eurowings", "ryanair", "easyjet", "air canada",
            "westjet", "airline", "flug", "flight", "airways", "air france", "klm",
            "united", "delta", "boarding", "lounge", "airport gate", "swiss",
        ]),
        (.transport, [
            "uber", "lyft", "taxi", "bolt", "bahn", "db ", "deutsche bahn", "zug",
            "train", "via rail", "bus", "flixbus", "metro", "subway station", "ttc",
            "presto", "tank", "shell", "esso", "aral", "petro", "chevron", "gas",
            "parken", "parking", "parkhaus", "mietwagen", "rental", "hertz", "avis",
            "sixt", "enterprise", "budget car", "toll", "maut", "ferry", "faehre", "fähre",
        ]),
        (.unterkunft, [
            "hotel", "motel", "hostel", "airbnb", "booking", "expedia", "marriott",
            "hilton", "best western", "holiday inn", "unterkunft", "lodge", "resort",
            "campground", "camping", "zimmer",
        ]),
        (.essen, [
            "restaurant", "cafe", "café", "coffee", "starbucks", "tim hortons",
            "mcdonald", "burger", "pizza", "pizzeria", "subway", "kfc", "wendy",
            "poutine", "diner", "bar ", "pub", "brauhaus", "bäckerei", "baeckerei",
            "bakery", "eis", "ice cream", "bistro", "imbiss", "food", "essen",
            "trinken", "brunch", "steakhouse", "sushi", "ramen", "taco", "chipotle",
        ]),
        (.lebensmittel, [
            "rewe", "edeka", "aldi", "lidl", "netto", "penny", "kaufland", "dm ",
            "rossmann", "supermarkt", "supermarket", "grocery", "loblaws", "sobeys",
            "metro inc", "no frills", "walmart", "costco", "safeway", "shoppers",
            "7-eleven", "spar ", "getränkemarkt", "lebensmittel",
        ]),
        (.shopping, [
            "amazon", "zalando", "ikea", "mediamarkt", "saturn", "apple store",
            "best buy", "canadian tire", "mall", "outlet", "store", "shop",
            "boutique", "nike", "adidas", "foot locker", "sneaker", "h&m", "zara",
            "uniqlo", "souvenir", "geschenk", "gift",
        ]),
        (.aktivitaeten, [
            "museum", "zoo", "aquarium", "kino", "cinema", "theater", "theatre",
            "konzert", "concert", "ticket", "eintritt", "admission", "tour",
            "niagara", "cn tower", "ripley", "nationalpark", "national park",
            "parks canada", "kajak", "kayak", "rafting", "ski", "eventim", "stadion",
            "stadium", "spiel", "game", "freizeitpark", "canada's wonderland",
        ]),
        (.gebuehren, [
            "gebühr", "gebuehr", "fee", "atm", "geldautomat", "withdrawal", "abhebung",
            "wechselkurs", "exchange", "visa fee", "eta", "zoll", "customs",
            "versicherung", "insurance", "roaming", "sim", "esim", "airalo",
        ]),
        (.gesundheit, [
            "apotheke", "pharmacy", "pharmaprix", "rexall", "arzt", "doctor",
            "clinic", "klinik", "hospital", "krankenhaus", "medikament", "drug mart",
        ]),
    ]

    /// Kategorie-Vorschlag für einen Händler-/Eintragsnamen.
    static func categorize(_ text: String) -> ExpenseCategory {
        let lowered = " " + text.lowercased() + " "
        for (category, words) in keywords {
            for word in words where lowered.contains(word) {
                return category
            }
        }
        return .sonstiges
    }
}

// MARK: - Schnelleingabe („pizza 13,5 bar")

struct QuickAddResult {
    var title: String
    var amount: Double
    var currency: String?
    var payment: PaymentMethod?
    var category: ExpenseCategory
}

enum QuickAddParser {

    private static let paymentWords: [String: PaymentMethod] = [
        "bar": .bargeld, "cash": .bargeld, "bargeld": .bargeld,
        "karte": .kreditkarte, "kreditkarte": .kreditkarte, "kredit": .kreditkarte,
        "debit": .debitkarte, "debitkarte": .debitkarte, "ec": .debitkarte,
        "apple": .applePay, "applepay": .applePay, "pay": .applePay,
        "überweisung": .ueberweisung, "ueberweisung": .ueberweisung,
    ]

    private static let currencyWords: [String: String] = [
        "eur": "EUR", "euro": "EUR", "€": "EUR",
        "cad": "CAD", "dollar": "CAD", "$": "CAD",
        "usd": "USD", "gbp": "GBP", "chf": "CHF", "franken": "CHF",
    ]

    /// Zerlegt eine freie Eingabe wie „pizza 13,5 bar" oder „parken 12 cad karte".
    static func parse(_ input: String) -> QuickAddResult? {
        var amount: Double?
        var payment: PaymentMethod?
        var currency: String?
        var titleWords: [String] = []

        for rawToken in input.split(separator: " ") {
            let token = String(rawToken)
            let lowered = token.lowercased().trimmed

            if amount == nil, let value = parseNumber(lowered) {
                amount = value
                continue
            }
            if payment == nil, let method = paymentWords[lowered] {
                payment = method
                continue
            }
            if currency == nil, let code = currencyWords[lowered] {
                currency = code
                continue
            }
            titleWords.append(token)
        }

        guard let value = amount, value > 0 else { return nil }
        let title = titleWords.joined(separator: " ").trimmed
        guard !title.isEmpty else { return nil }
        return QuickAddResult(
            title: title,
            amount: value,
            currency: currency,
            payment: payment,
            category: Classifier.categorize(title)
        )
    }

    private static func parseNumber(_ token: String) -> Double? {
        var cleaned = token
        for symbol in ["€", "$", "£"] { cleaned = cleaned.replacingOccurrences(of: symbol, with: "") }
        cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, cleaned.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil else { return nil }
        return Double(cleaned)
    }
}
