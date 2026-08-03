import Foundation

// CSV-Import für TravelSpend-Exporte („travelspend_export_….csv").
//
// Das Format: kommagetrennt, Felder in Anführungszeichen, deutsche
// Zahlen („2.351,79", Koordinaten „51,5"), Datum „04.06.2026".
// Die Spalten werden über die Kopfzeile gefunden — zusätzliche oder
// unbekannte Spalten (z. B. die Pro-Person-Spalte des Exports)
// werden einfach ignoriert. Der Eintragsname steht je nach Zeile in
// „description" oder in „notes" — genommen wird description, sonst notes.

enum CSVImport {

    // MARK: - Generischer CSV-Parser (Anführungszeichen, "" als Escape, CRLF)

    static func parseCSV(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = text.startIndex

        func endField() {
            row.append(field)
            field = ""
        }
        func endRow() {
            endField()
            if !(row.count == 1 && row[0].trimmed.isEmpty) {
                rows.append(row)
            }
            row = []
        }

        while index < text.endIndex {
            let character = text[index]
            if inQuotes {
                if character == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    inQuotes = true
                case delimiter:
                    endField()
                case "\r":
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\n" { index = next }
                    endRow()
                case "\n":
                    endRow()
                default:
                    field.append(character)
                }
            }
            index = text.index(after: index)
        }
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }

    // MARK: - Wertehelfer

    /// „2.351,79" → 2351.79; „51,5" → 51.5; leere Strings → nil.
    static func germanNumber(_ raw: String) -> Double? {
        let cleaned = raw
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmed
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    static func germanDate(_ raw: String) -> Date? {
        guard let parsed = dateFormatter.date(from: raw.trimmed) else { return nil }
        // Auf 12:00 Uhr legen, damit Zeitzonen den Kalendertag nicht verschieben.
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: parsed)
    }

    // MARK: - Zuordnungen

    static func category(name: String, icon: String, title: String) -> ExpenseCategory {
        let lowered = name.lowercased()
        let nameMap: [(String, ExpenseCategory)] = [
            ("flüge", .fluege), ("flug", .fluege), ("flights", .fluege),
            ("transport", .transport),
            ("unterkunft", .unterkunft), ("accommodation", .unterkunft),
            ("essen", .essen), ("food", .essen), ("restaurant", .essen), ("drinks", .essen),
            ("lebensmittel", .lebensmittel), ("groceries", .lebensmittel),
            ("shopping", .shopping),
            ("aktivitäten", .aktivitaeten), ("activities", .aktivitaeten),
            ("touren", .aktivitaeten), ("tours", .aktivitaeten), ("entertainment", .aktivitaeten),
            ("gebühren", .gebuehren), ("fees", .gebuehren),
            ("gesundheit", .gesundheit), ("health", .gesundheit),
        ]
        for (needle, category) in nameMap where lowered.contains(needle) {
            return category
        }

        let iconMap: [(String, ExpenseCategory)] = [
            ("flight", .fluege),
            ("train", .transport), ("bus", .transport), ("taxi", .transport),
            ("car", .transport), ("gas_station", .transport),
            ("hotel", .unterkunft), ("bed", .unterkunft),
            ("restaurant", .essen), ("fastfood", .essen), ("local_cafe", .essen), ("local_bar", .essen),
            ("grocery", .lebensmittel), ("shopping_cart", .lebensmittel),
            ("shopping_bag", .shopping), ("local_mall", .shopping),
            ("attractions", .aktivitaeten), ("theater", .aktivitaeten), ("museum", .aktivitaeten),
            ("account_balance", .gebuehren), ("atm", .gebuehren),
            ("hospital", .gesundheit), ("healing", .gesundheit),
        ]
        let iconLowered = icon.lowercased()
        for (needle, category) in iconMap where iconLowered.contains(needle) {
            return category
        }

        // „Unkategorisiert" & Unbekanntes: der Klassifikator versucht es über den Namen.
        return Classifier.categorize(title)
    }

    static func payment(_ raw: String) -> PaymentMethod {
        let lowered = raw.lowercased()
        if lowered.contains("apple") || lowered.contains("wallet") { return .applePay }
        if lowered.contains("kredit") || lowered.contains("credit") { return .kreditkarte }
        if lowered.contains("debit") || lowered.contains("ec-") { return .debitkarte }
        if lowered.contains("bar") || lowered.contains("cash") { return .bargeld }
        if lowered.contains("überweisung") || lowered.contains("ueberweisung") || lowered.contains("transfer") { return .ueberweisung }
        return lowered.isEmpty ? .sonstiges : .sonstiges
    }

    // MARK: - TravelSpend-Zeilen → Einträge

    struct Result {
        var expenses: [Expense] = []
        var skippedRows = 0
    }

    /// Baut Einträge für die Reise aus dem CSV-Text. Zeilen ohne Betrag
    /// oder Datum werden gezählt und übersprungen.
    static func travelSpendExpenses(from text: String, tripId: String, fallbackAuthor: String) -> Result? {
        // Trennzeichen erkennen: TravelSpend nutzt Komma, eigene Exporte Semikolon.
        guard let headerLine = text.split(separator: "\n", maxSplits: 1).first else { return nil }
        let delimiter: Character = headerLine.contains(";") && !headerLine.contains(",") ? ";" : ","

        let rows = parseCSV(text, delimiter: delimiter)
        guard rows.count >= 2 else { return nil }

        let header = rows[0].map { $0.lowercased().trimmed }
        func column(_ name: String) -> Int? { header.firstIndex(of: name) }
        guard let amountCol = column("amount"), let dateCol = column("datepaid") else {
            // Keine TravelSpend-Kopfzeile.
            return nil
        }

        func value(_ row: [String], _ name: String) -> String {
            guard let index = column(name), index < row.count else { return "" }
            return row[index].trimmed
        }

        var result = Result()
        for row in rows.dropFirst() {
            guard amountCol < row.count, dateCol < row.count,
                  let amount = germanNumber(row[amountCol]), amount > 0,
                  let date = germanDate(row[dateCol]) else {
                result.skippedRows += 1
                continue
            }

            let description = value(row, "description")
            let notes = value(row, "notes")
            let title = description.nonEmpty ?? notes.nonEmpty ?? "Eintrag"
            let note = (description.nonEmpty != nil) ? notes : ""
            let categoryName = value(row, "category")
            let icon = value(row, "categoryicon")
            let currency = value(row, "localcurrency").nonEmpty ?? "EUR"
            let isIncome = value(row, "type").lowercased() == "income"
            let days = Int(value(row, "numberofdays")) ?? 1

            let expense = Expense(
                tripId: tripId,
                title: title,
                note: note,
                amount: amount,
                currency: currency.uppercased(),
                category: category(name: categoryName, icon: icon, title: title),
                payment: payment(value(row, "paymentmethod")),
                date: date,
                spreadDays: max(1, days),
                countryName: value(row, "country"),
                countryCode: value(row, "countrycode").uppercased(),
                placeName: value(row, "place"),
                latitude: germanNumber(value(row, "latitude")),
                longitude: germanNumber(value(row, "longitude")),
                author: value(row, "paidby").nonEmpty ?? fallbackAuthor,
                excludeFromDaily: value(row, "excludefromavg").lowercased() == "true",
                refunded: isIncome
            )
            result.expenses.append(expense)
        }
        return result
    }
}
