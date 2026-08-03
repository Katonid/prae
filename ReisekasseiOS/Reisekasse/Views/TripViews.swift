import SwiftUI

// Reise anlegen/bearbeiten, Freunde einladen, Einstellungen.

private func parseGermanDouble(_ text: String) -> Double? {
    let cleaned = text
        .replacingOccurrences(of: ".", with: "")
        .replacingOccurrences(of: ",", with: ".")
        .trimmed
    guard !cleaned.isEmpty else { return nil }
    return Double(cleaned)
}

// MARK: - Reise-Editor

struct TripEditorSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let trip: Trip?
    let isNew: Bool

    @State private var name = ""
    @State private var homeCurrency = "EUR"
    @State private var totalBudgetText = ""
    @State private var dailyBudgetText = ""
    @State private var hasDates = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var rateTexts: [String: String] = [:]
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Reise") {
                    TextField("Name (z. B. Kanada)", text: $name)
                    Picker("Heimatwährung", selection: $homeCurrency) {
                        ForEach(Trip.currencyChoices, id: \.self) { Text($0) }
                    }
                }

                Section {
                    TextField("Gesamtbudget in \(homeCurrency)", text: $totalBudgetText)
                        .keyboardType(.decimalPad)
                    TextField("Tagesbudget in \(homeCurrency) (optional)", text: $dailyBudgetText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Budget")
                } footer: {
                    Text("Ohne Tagesbudget wird es aus Gesamtbudget und Reisedauer berechnet.")
                }

                Section("Zeitraum") {
                    Toggle("Reisezeitraum festlegen", isOn: $hasDates)
                    if hasDates {
                        DatePicker("Beginn", selection: $startDate, displayedComponents: .date)
                        DatePicker("Ende", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                Section {
                    ForEach(rateCurrencies, id: \.self) { code in
                        HStack {
                            Text("1 \(code) =")
                            TextField("Kurs", text: Binding(
                                get: { rateTexts[code] ?? "" },
                                set: { rateTexts[code] = $0 }
                            ))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            Text(homeCurrency)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Wechselkurse")
                } footer: {
                    Text("Kurse in die Heimatwährung — für die Umrechnung fremder Währungen (z. B. 1 CAD = 0,67 EUR).")
                }

                if !isNew {
                    Section {
                        Button("Reise löschen", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Neue Reise" : "Reise bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(name.trimmed.isEmpty)
                }
            }
            .confirmationDialog("Reise wirklich löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    if let trip { store.deleteTrip(trip) }
                    dismiss()
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: load)
    }

    private var rateCurrencies: [String] {
        Trip.currencyChoices.filter { $0 != homeCurrency }
    }

    private func load() {
        guard let trip else {
            rateTexts = ["CAD": "0,67"]
            return
        }
        name = trip.name
        homeCurrency = trip.homeCurrency
        totalBudgetText = trip.totalBudget.map { Formatters.plain($0) } ?? ""
        dailyBudgetText = trip.dailyBudget.map { Formatters.plain($0) } ?? ""
        hasDates = trip.startDate != nil && trip.endDate != nil
        startDate = trip.startDate ?? Date()
        endDate = trip.endDate ?? Date()
        for (code, value) in trip.rates {
            rateTexts[code] = Formatters.plain(value)
        }
    }

    private func save() {
        guard let tripName = name.nonEmpty else { return }
        var rates: [String: Double] = [:]
        for (code, text) in rateTexts {
            if let value = parseGermanDouble(text), value > 0 {
                rates[code] = value
            }
        }

        if var updated = trip {
            updated.name = tripName
            updated.homeCurrency = homeCurrency
            updated.totalBudget = parseGermanDouble(totalBudgetText)
            updated.dailyBudget = parseGermanDouble(dailyBudgetText)
            updated.startDate = hasDates ? startDate.startOfDay : nil
            updated.endDate = hasDates ? endDate.startOfDay : nil
            updated.rates = rates
            store.updateTrip(updated)
        } else {
            let newTrip = Trip(
                name: tripName,
                homeCurrency: homeCurrency,
                totalBudget: parseGermanDouble(totalBudgetText),
                dailyBudget: parseGermanDouble(dailyBudgetText),
                startDate: hasDates ? startDate.startOfDay : nil,
                endDate: hasDates ? endDate.startOfDay : nil,
                rates: rates
            )
            store.createTrip(newTrip)
        }
        dismiss()
    }
}

// MARK: - Freunde einladen / beitreten

struct FriendsSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var joinText = ""
    @State private var joinMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        if let trip = store.activeTrip {
                            inviteCard(trip)
                            participantsCard(trip)
                        }
                        joinCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Freunde hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func inviteCard(_ trip: Trip) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.badge.plus.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.blue)
            Text("Gemeinsame Reisekasse")
                .font(.headline)
            Text("Mitreisende installieren die App, tippen auf „Reise beitreten“ und geben diesen Code ein. Danach landen ihre Zahlungen — auch die automatisch per Apple Pay erfassten — in dieser Reise, auf allen Geräten.")
                .font(.subheadline)
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)

            Text(trip.joinCode)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .tracking(6)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardSoft))

            ShareLink(item: "Komm in unsere Reisekasse „\(trip.name)“! Lade die App und tritt mit dem Code \(trip.joinCode) bei.") {
                Label("Code teilen", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Theme.accent))
                    .foregroundStyle(.white)
            }
        }
        .padding(18)
        .cardStyle()
    }

    private func participantsCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mit dabei")
                .font(.headline)
            if trip.participants.isEmpty {
                Text("Noch niemand — teile den Code!")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textDim)
            } else {
                ForEach(trip.participants, id: \.self) { person in
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(Theme.blue)
                        Text(person)
                        if person == store.profileName {
                            Text("(du)")
                                .foregroundStyle(Theme.textDim)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reise beitreten")
                .font(.headline)
            Text("Code von Freunden erhalten? Hier eingeben — die Reise erscheint dann in deiner Reise-Auswahl.")
                .font(.subheadline)
                .foregroundStyle(Theme.textDim)
            HStack(spacing: 10) {
                TextField("Code, z. B. QX7K2M", text: $joinText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardSoft))
                Button("Beitreten") {
                    if let trip = store.joinTrip(code: joinText) {
                        joinMessage = "Willkommen bei „\(trip.name)“!"
                        joinText = ""
                    } else {
                        store.syncNow()
                        joinMessage = "Code nicht gefunden — kurz warten, bis die Reise synchronisiert ist, und erneut versuchen."
                    }
                }
                .font(.headline)
                .disabled(joinText.trimmed.isEmpty)
            }
            if let message = joinMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.textDim)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Einstellungen

struct SettingsSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Profil") {
                    TextField("Dein Name", text: $name)
                        .onSubmit { commitName() }
                }

                Section {
                    LabeledContent("Status", value: store.syncStatus.label)
                    LabeledContent("Ausstehend", value: "\(store.engine.pendingCount) Änderungen")
                    if let last = store.engine.lastSyncDate {
                        LabeledContent("Letzter Abgleich", value: "\(Formatters.shortDate(last)), \(Formatters.time(last)) Uhr")
                    }
                    Button("Jetzt synchronisieren") {
                        commitName()
                        store.syncNow()
                    }
                } header: {
                    Text("iCloud-Synchronisation")
                } footer: {
                    Text("Alle Geräte mit derselben App synchronisieren über iCloud — Mitreisende brauchen keine gemeinsame Apple-ID, nur irgendein iCloud-Konto.")
                }

                Section {
                    Button("Standort-Berechtigung anfragen") {
                        LocationService.shared.requestPermission()
                    }
                } header: {
                    Text("Standort")
                } footer: {
                    Text("Für den Ort am Eintrag. Für die automatische Erfassung per Apple Pay im Hintergrund die Stufe „Immer“ erlauben (Einstellungen → Reisekasse → Standort).")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Kurzbefehle-App → Automation → Neue Automation → „Transaktion“.")
                        Text("2. Karte(n) auswählen, „Sofort ausführen“ aktivieren.")
                        Text("3. Aktion „Ausgabe erfassen“ (Reisekasse) wählen.")
                        Text("4. Betrag, Währung und Händler aus der Transaktion als Parameter übergeben.")
                    }
                    .font(.subheadline)
                } header: {
                    Text("Automatischer Import über Apple Pay")
                } footer: {
                    Text("Danach wird jede Apple-Pay-Zahlung automatisch als Eintrag gespeichert — mit Händler, Betrag, Zeit, Ort und passender Kategorie. Details im README des Projekts.")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        commitName()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { name = store.profileName }
    }

    private func commitName() {
        guard let value = name.nonEmpty, value != store.profileName else { return }
        store.profileName = value
        if let trip = store.activeTrip {
            store.registerParticipant(in: trip.id)
        }
    }
}
