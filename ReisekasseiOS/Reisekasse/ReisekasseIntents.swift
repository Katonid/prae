import Foundation
import AppIntents

// Kurzbefehle-Anbindung — der Kern des automatischen Apple-Pay-Imports.
//
// Apple gibt Dritt-Apps keinen direkten Zugriff auf Wallet-Transaktionen.
// Der offizielle Weg ist die Kurzbefehle-Automation „Transaktion":
// Sie feuert bei jeder Apple-Pay-Zahlung und übergibt Händler, Betrag,
// Währung und Karte an diesen Intent. Der Intent läuft im App-Prozess
// (iOS startet ihn bei Bedarf im Hintergrund), ergänzt Standort und
// Kategorie und speichert den Eintrag in der aktiven Reise.
// Einrichtung: siehe README („Automatischer Import über Apple Pay").

struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Ausgabe erfassen"
    // Hinweis: Siri-/Kurzbefehl-Metadaten (title, description, Parameter)
    // dürfen laut App-Store-Prüfung das Wort „Apple" nicht enthalten
    // (ITMS-90626) — deshalb hier bewusst nur „Wallet-Zahlung".
    static var description = IntentDescription(
        "Speichert eine Zahlung in der aktiven Reise von Kassenbuch. Gedacht für die Kurzbefehle-Automation „Transaktion“ bei Wallet-Zahlungen: Betrag, Währung und Händler aus der Transaktion einfach als Parameter übergeben."
    )
    static var openAppWhenRun = false

    // Betrag als TEXT: Kurzbefehle scheitert sonst daran, Fremdwährungs-
    // Beträge („$ 13.50" bei CAD-Zahlungen) in eine Zahl im deutschen
    // Format zu wandeln, und fragt mitten im Bezahlen nach dem Betrag.
    // Das Parsen übernimmt der Intent selbst — alle Schreibweisen.
    @Parameter(title: "Betrag")
    var betrag: String

    @Parameter(title: "Währung (z. B. EUR, CAD)")
    var waehrung: String?

    @Parameter(title: "Händler")
    var haendler: String?

    @Parameter(title: "Karte")
    var karte: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Erfasse \(\.$betrag) \(\.$waehrung) bei \(\.$haendler)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = AppStore.shared

        guard let amount = Self.parseAmount(betrag), amount > 0 else {
            store.logAuto("✗ Betrag „\(betrag)“ nicht lesbar — Zahlung verworfen (in der Automation den Transaktions-Betrag übergeben).")
            return .result(dialog: "Der Betrag „\(betrag)“ war nicht lesbar — in der Automation den Transaktions-Betrag übergeben.")
        }

        let merchant = haendler?.nonEmpty ?? "Zahlung"
        let category = Classifier.categorize(merchant)
        var note = ""
        if let card = karte?.nonEmpty {
            note = "Karte: \(card)"
        }

        // Ziel-Reise: die aktive, sonst die erste sichtbare. Gibt es keine
        // (z. B. Name auf diesem Gerät nicht gesetzt), wird die Zahlung
        // NICHT verworfen, sondern wartet in der App auf Zuordnung.
        let trip = store.activeTrip ?? store.visibleTrips.first

        // Währung: expliziter Parameter → aus dem Betrags-Text → Reise.
        // Ein nacktes „$" heißt CAD, wenn die Reise einen CAD-Kurs führt
        // (Kanada-Fall), sonst USD.
        var currency = normalizedCurrency(waehrung) ?? normalizedCurrency(betrag)
        if currency == nil, betrag.contains("$") {
            currency = (trip?.rates.keys.contains("CAD") ?? false) ? "CAD" : "USD"
        }
        let resolvedCurrency = currency ?? trip?.homeCurrency ?? "EUR"

        var expense = Expense(
            tripId: trip?.id ?? "",
            title: merchant,
            note: note,
            amount: amount,
            currency: resolvedCurrency,
            category: category,
            payment: .applePay,
            date: Date(),
            author: store.profileName
        )

        // Standort samt Ort/Land ergänzen (klappt im Hintergrund nur mit
        // der Berechtigung „Immer"; sonst bleibt der Eintrag ohne Ort).
        if let fix = await LocationService.shared.currentPlace(timeout: 5) {
            expense.latitude = fix.latitude
            expense.longitude = fix.longitude
            expense.placeName = fix.placeName
            expense.countryName = fix.countryName
            expense.countryCode = fix.countryCode
        }

        let amountText = Formatters.money(amount, resolvedCurrency)
        guard let trip else {
            store.addPendingAutoExpense(expense)
            store.logAuto("⚠︎ \(amountText) bei \(merchant) erfasst, aber keine Reise sichtbar — wartet in der App auf Zuordnung (Name in den Einstellungen prüfen).")
            return .result(dialog: "\(amountText) bei \(merchant) gesichert — bitte Kassenbuch öffnen und einer Reise zuordnen.")
        }

        store.addExpense(expense)
        // Sofort hochladen: Der Hintergrund-Prozess wird gleich eingefroren,
        // die verzögerte Outbox käme sonst erst beim nächsten App-Start dran.
        await store.pushExpenseNow(expense.id)
        store.logAuto("✓ \(amountText) bei \(merchant) → „\(trip.name)“ (Kategorie \(category.label)).")

        return .result(dialog: "\(amountText) bei \(merchant) erfasst — Kategorie \(category.label).")
    }

    /// Liest einen Geldbetrag aus beliebigen Schreibweisen:
    /// "13,50", "13.50", "$13.50", "CAD 13.50", "1.234,56", "1,234.56".
    /// Ein einzelnes Trennzeichen mit genau drei Nachziffern gilt als
    /// Tausendergruppe (Beträge haben keine drei Dezimalstellen).
    static func parseAmount(_ raw: String) -> Double? {
        var text = String(raw.filter { $0.isNumber || $0 == "," || $0 == "." })
        guard !text.isEmpty else { return nil }

        let lastComma = text.lastIndex(of: ",")
        let lastDot = text.lastIndex(of: ".")
        if let comma = lastComma, let dot = lastDot {
            // Beide vorhanden: das hintere ist das Dezimalzeichen.
            if comma > dot {
                text = text.replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            } else {
                text = text.replacingOccurrences(of: ",", with: "")
            }
        } else if let comma = lastComma {
            let decimals = text.distance(from: text.index(after: comma), to: text.endIndex)
            text = decimals == 3
                ? text.replacingOccurrences(of: ",", with: "")
                : text.replacingOccurrences(of: ",", with: ".")
        } else if let dot = lastDot {
            let decimals = text.distance(from: text.index(after: dot), to: text.endIndex)
            if decimals == 3 {
                text = text.replacingOccurrences(of: ".", with: "")
            }
        }
        return Double(text)
    }

    private func normalizedCurrency(_ raw: String?) -> String? {
        guard let raw = raw?.trimmed.uppercased(), !raw.isEmpty else { return nil }
        // Kurzbefehle liefern je nach Gerät "EUR", "€" oder "13,50 €" — Code herausfiltern.
        if raw.contains("€") || raw.contains("EUR") { return "EUR" }
        if raw.contains("CAD") { return "CAD" }
        if raw.contains("US") || raw.contains("USD") { return "USD" }
        if raw.contains("£") || raw.contains("GBP") { return "GBP" }
        if raw.contains("CHF") { return "CHF" }
        let letters = raw.filter { $0.isLetter }
        return letters.count == 3 ? String(letters) : nil
    }
}

struct ReisekasseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: ["Erfasse eine Ausgabe in \(.applicationName)"],
            shortTitle: "Ausgabe erfassen",
            systemImageName: "creditcard.fill"
        )
    }
}
