import SwiftUI
import PhotosUI
import UIKit

// Eintrag anlegen/bearbeiten — Aufbau nach Vorbild der Referenz:
// Betrag + Währung oben, Name/Notiz, Datum + „Auf Tage verteilen",
// Zahlungsmittel, Land, Ort, Foto, erweiterte Einstellungen, Löschen.

struct EntryEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let existing: Expense?

    @State private var title = ""
    @State private var note = ""
    @State private var showNote = false
    @State private var amountText = ""
    @State private var currency = "EUR"
    @State private var category: ExpenseCategory = .sonstiges
    @State private var categoryChosenManually = false
    @State private var payment: PaymentMethod = .kreditkarte
    @State private var date = Date()
    @State private var spreadDays = 1
    @State private var countryName = ""
    @State private var countryCode = ""
    @State private var placeName = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var excludeFromDaily = false
    @State private var refunded = false
    @State private var photoFilename: String?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var confirmDelete = false
    @FocusState private var amountFocused: Bool

    private var amount: Double? {
        let cleaned = amountText.replacingOccurrences(of: ",", with: ".").trimmed
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    private var canSave: Bool { amount != nil && title.nonEmpty != nil }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    topBar
                    amountHeader
                    nameCard
                    dateCard
                    detailsCard
                    advancedCard
                    if existing != nil {
                        deleteButton
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: load)
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    photoFilename = store.savePhoto(data)
                }
            }
        }
        .confirmationDialog("Eintrag löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let existing { store.deleteExpense(existing) }
                dismiss()
            }
        }
    }

    // MARK: - Laden & Speichern

    private func load() {
        if let expense = existing {
            title = expense.title
            note = expense.note
            showNote = !expense.note.isEmpty
            amountText = Formatters.plain(expense.amount).replacingOccurrences(of: ".", with: "")
            currency = expense.currency
            category = expense.category
            categoryChosenManually = true
            payment = expense.payment
            date = expense.date
            spreadDays = expense.spreadDays
            countryName = expense.countryName
            countryCode = expense.countryCode
            placeName = expense.placeName
            latitude = expense.latitude
            longitude = expense.longitude
            excludeFromDaily = expense.excludeFromDaily
            refunded = expense.refunded
            photoFilename = expense.photoFilename
        } else {
            currency = store.activeTrip?.homeCurrency ?? "EUR"
            amountFocused = true
            // Ort für neue Einträge direkt vorschlagen.
            Task {
                if let fix = await LocationService.shared.currentPlace(timeout: 5) {
                    if latitude == nil {
                        latitude = fix.latitude
                        longitude = fix.longitude
                        placeName = fix.placeName
                        countryName = fix.countryName
                        countryCode = fix.countryCode
                    }
                }
            }
        }
    }

    private func save() {
        guard let trip = store.activeTrip, let value = amount, let name = title.nonEmpty else { return }
        if var expense = existing {
            expense.title = name
            expense.note = note.trimmed
            expense.amount = value
            expense.currency = currency
            expense.category = category
            expense.payment = payment
            expense.date = date
            expense.spreadDays = spreadDays
            expense.countryName = countryName
            expense.countryCode = countryCode
            expense.placeName = placeName
            expense.latitude = latitude
            expense.longitude = longitude
            expense.excludeFromDaily = excludeFromDaily
            expense.refunded = refunded
            expense.photoFilename = photoFilename
            store.updateExpense(expense)
        } else {
            let expense = Expense(
                tripId: trip.id,
                title: name,
                note: note.trimmed,
                amount: value,
                currency: currency,
                category: category,
                payment: payment,
                date: date,
                spreadDays: spreadDays,
                countryName: countryName,
                countryCode: countryCode,
                placeName: placeName,
                latitude: latitude,
                longitude: longitude,
                author: store.profileName,
                excludeFromDaily: excludeFromDaily,
                refunded: refunded,
                photoFilename: photoFilename
            )
            store.addExpense(expense)
        }
        dismiss()
    }

    // MARK: - Abschnitte

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().stroke(Theme.separator, lineWidth: 1))
            }
            Spacer()
            Button(action: save) {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.blue))
            }
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.4)
        }
    }

    private var amountHeader: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(ExpenseCategory.allCases) { choice in
                    Button {
                        category = choice
                        categoryChosenManually = true
                    } label: {
                        Label(choice.label, systemImage: choice.symbol)
                    }
                }
            } label: {
                CategoryBadge(category: category, size: 52)
            }

            Spacer()

            TextField("0", text: $amountText)
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Theme.blue)
                .frame(minWidth: 120)

            Menu {
                ForEach(Trip.currencyChoices, id: \.self) { code in
                    Button(code) { currency = code }
                }
            } label: {
                Text(currency)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.blue))
            }
        }
        .padding(.vertical, 8)
    }

    private var nameCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "pencil")
                    .foregroundStyle(Theme.blue)
                    .frame(width: 28)
                TextField("Name des Eintrags", text: $title)
                    .onChange(of: title) { _, newValue in
                        if !categoryChosenManually {
                            category = Classifier.categorize(newValue)
                        }
                    }
                if !showNote {
                    Button {
                        showNote = true
                    } label: {
                        Label("Notiz", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textDim)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Theme.cardSoft))
                    }
                }
            }
            .padding(14)

            if showNote {
                Divider().overlay(Theme.separator).padding(.leading, 54)
                HStack(spacing: 12) {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 28)
                    TextField("Notiz", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
                .padding(14)
            }
        }
        .cardStyle()
    }

    private var dateCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(Theme.blue)
                .frame(width: 28)
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
            Spacer()
            Menu {
                Button("Nicht verteilen") { spreadDays = 1 }
                ForEach([2, 3, 4, 5, 6, 7, 10, 14, 21, 30], id: \.self) { days in
                    Button("Auf \(days) Tage") { spreadDays = days }
                }
            } label: {
                Text(spreadDays > 1 ? "Auf \(spreadDays) Tage verteilt" : "Auf Tage verteilen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(spreadDays > 1 ? Theme.blue : Theme.textDim)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.cardSoft))
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            // Zahlungsmittel
            Menu {
                ForEach(PaymentMethod.allCases) { method in
                    Button {
                        payment = method
                    } label: {
                        Label(method.label, systemImage: method.symbol)
                    }
                }
            } label: {
                row(icon: payment.symbol, iconColor: Theme.blue) {
                    Text(payment.label).foregroundStyle(Theme.textPrimary)
                }
            }

            Divider().overlay(Theme.separator).padding(.leading, 54)

            // Land
            Menu {
                ForEach(knownCountries, id: \.code) { country in
                    Button("\(flagEmoji(countryCode: country.code)) \(country.name)") {
                        countryName = country.name
                        countryCode = country.code
                    }
                }
                Divider()
                Button("Land entfernen", role: .destructive) {
                    countryName = ""
                    countryCode = ""
                }
            } label: {
                HStack(spacing: 12) {
                    Text(countryCode.isEmpty ? "🌍" : flagEmoji(countryCode: countryCode))
                        .font(.system(size: 22))
                        .frame(width: 28)
                    Text(countryName.isEmpty ? "Land wählen" : countryName)
                        .foregroundStyle(countryName.isEmpty ? Theme.textDim : Theme.textPrimary)
                    Spacer()
                }
                .padding(14)
                .contentShape(Rectangle())
            }

            Divider().overlay(Theme.separator).padding(.leading, 54)

            // Ort
            if latitude != nil, longitude != nil {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Theme.blue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(placeName.isEmpty ? "Standort" : placeName)
                        Text(String(format: "%.5f, %.5f", latitude ?? 0, longitude ?? 0))
                            .font(.footnote)
                            .foregroundStyle(Theme.textDim)
                    }
                    Spacer()
                    Button {
                        latitude = nil
                        longitude = nil
                        placeName = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.textDim)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Theme.cardSoft))
                    }
                }
                .padding(14)
            } else {
                Button {
                    LocationService.shared.requestPermission()
                    Task {
                        if let fix = await LocationService.shared.currentPlace(timeout: 6) {
                            latitude = fix.latitude
                            longitude = fix.longitude
                            placeName = fix.placeName
                            if countryName.isEmpty {
                                countryName = fix.countryName
                                countryCode = fix.countryCode
                            }
                        }
                    }
                } label: {
                    row(icon: "mappin.circle", iconColor: Theme.blue) {
                        Text("Aktuellen Ort hinzufügen").foregroundStyle(Theme.textDim)
                    }
                }
            }

            Divider().overlay(Theme.separator).padding(.leading, 54)

            // Foto
            if let url = store.photoURL(photoFilename), let image = UIImage(contentsOfFile: url.path) {
                HStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("Foto angefügt")
                    Spacer()
                    Button {
                        photoFilename = nil
                        photoPickerItem = nil
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(14)
            } else {
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    row(icon: "camera.fill", iconColor: Theme.blue) {
                        Text("Foto anfügen").foregroundStyle(Theme.textDim)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var advancedCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "chevron.up")
                    .foregroundStyle(Theme.textDim)
                    .frame(width: 28)
                Text("Erweiterte Einstellungen")
                    .font(.headline)
                Spacer()
            }
            .padding(14)

            Divider().overlay(Theme.separator).padding(.leading, 54)

            Toggle(isOn: $excludeFromDaily) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Aus Tagesdurchschnitt ausschließen")
                    Text("Der Eintrag zählt nicht in die Tageskennzahlen — z. B. für Flüge und große Vorabbuchungen.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textDim)
                }
            }
            .tint(Theme.blue)
            .padding(14)

            Divider().overlay(Theme.separator).padding(.leading, 14)

            Toggle(isOn: $refunded) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Zahlung zurückerstattet")
                    Text("Subtrahiert den Betrag von den Gesamtausgaben.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textDim)
                }
            }
            .tint(Theme.blue)
            .padding(14)
        }
        .cardStyle()
    }

    private var deleteButton: some View {
        Button {
            confirmDelete = true
        } label: {
            Label("Löschen", systemImage: "trash")
                .font(.headline)
                .foregroundStyle(Theme.accent)
                .padding(.vertical, 12)
        }
    }

    private func row<Content: View>(icon: String, iconColor: Color, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 28)
            content()
            Spacer()
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}
