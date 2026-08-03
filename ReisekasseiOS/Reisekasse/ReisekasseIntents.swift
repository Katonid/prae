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

    @Parameter(title: "Betrag")
    var betrag: Double

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
        guard let trip = store.activeTrip else {
            return .result(dialog: "Keine aktive Reise — bitte Kassenbuch einmal öffnen.")
        }
        guard betrag > 0 else {
            return .result(dialog: "Der Betrag fehlt — in der Automation den Transaktions-Betrag übergeben.")
        }

        let merchant = haendler?.nonEmpty ?? "Zahlung"
        let currency = normalizedCurrency(waehrung) ?? trip.homeCurrency
        let category = Classifier.categorize(merchant)

        var note = ""
        if let card = karte?.nonEmpty {
            note = "Karte: \(card)"
        }

        var expense = Expense(
            tripId: trip.id,
            title: merchant,
            note: note,
            amount: betrag,
            currency: currency,
            category: category,
            payment: .applePay,
            date: Date(),
            author: store.profileName
        )

        // Standort samt Ort/Land ergänzen (klappt im Hintergrund nur mit
        // der Berechtigung „Immer"; sonst bleibt der Eintrag ohne Ort).
        if let fix = await LocationService.shared.currentPlace(timeout: 6) {
            expense.latitude = fix.latitude
            expense.longitude = fix.longitude
            expense.placeName = fix.placeName
            expense.countryName = fix.countryName
            expense.countryCode = fix.countryCode
        }

        store.addExpense(expense)

        let amountText = Formatters.money(betrag, currency)
        return .result(dialog: "\(amountText) bei \(merchant) erfasst — Kategorie \(category.label).")
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
