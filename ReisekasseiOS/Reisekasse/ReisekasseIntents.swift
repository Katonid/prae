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

        guard betrag > 0 else {
            store.logAuto("✗ Zahlung ohne Betrag verworfen (Automation: Transaktions-Betrag als Parameter übergeben).")
            return .result(dialog: "Der Betrag fehlt — in der Automation den Transaktions-Betrag übergeben.")
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
        let currency = normalizedCurrency(waehrung) ?? trip?.homeCurrency ?? "EUR"

        var expense = Expense(
            tripId: trip?.id ?? "",
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
        if let fix = await LocationService.shared.currentPlace(timeout: 5) {
            expense.latitude = fix.latitude
            expense.longitude = fix.longitude
            expense.placeName = fix.placeName
            expense.countryName = fix.countryName
            expense.countryCode = fix.countryCode
        }

        let amountText = Formatters.money(betrag, currency)
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
