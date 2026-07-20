import SwiftUI
import SwiftData
import CoreLocation

// Tankvorgang erfassen/bearbeiten – portiert aus dem PWA-Formular inklusive
// gegenseitiger Umrechnung von Literpreis/Liter/Gesamtpreis, Preisvorschlag,
// Fahrtvorschau und den Markierungen Volltankung/AdBlue/Anhänger/Reifen.

/// Tab-Variante: immer ein neuer Eintrag.
struct EntryFormScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty {
                    NoVehiclePlaceholder()
                } else {
                    EntryFormView(entryToEdit: nil)
                        .id(appModel.entryFormResetToken)
                }
            }
            .navigationTitle("Tankvorgang")
        }
    }
}

struct EntryFormView: View {
    let entryToEdit: FuelEntry?
    var onDone: (() -> Void)?

    /// Im Bearbeitungsmodus werden alle Zustände schon im Init gesetzt, damit
    /// die initialen onChange-Durchläufe keine Werte überschreiben.
    init(entryToEdit: FuelEntry?, onDone: (() -> Void)? = nil) {
        self.entryToEdit = entryToEdit
        self.onDone = onDone

        guard let entry = entryToEdit else { return }
        _vehicleId = State(initialValue: entry.vehicleId)
        _date = State(initialValue: entry.date)
        _stationId = State(initialValue: entry.stationId)
        _stationName = State(initialValue: entry.stationName)
        _stationPlace = State(initialValue: entry.stationPlace)
        _appliedStationName = State(initialValue: entry.stationName)
        _appliedStationPlace = State(initialValue: entry.stationPlace)
        if let lat = entry.stationLat, let lng = entry.stationLng {
            _stationCoordinate = State(initialValue: CLLocationCoordinate2D(latitude: lat, longitude: lng))
            _stationSource = State(initialValue: entry.stationLocationSource)
        }
        _fuelType = State(initialValue: entry.fuelType)
        _odometerText = State(initialValue: Format.inputNumber(entry.odometer, digits: 0))
        _priceText = State(initialValue: Format.inputNumber(entry.pricePerLiter, digits: 3))
        _litersText = State(initialValue: Format.inputNumber(entry.liters, digits: 2))
        _totalText = State(initialValue: Format.inputNumber(entry.totalPrice, digits: 2))
        _notes = State(initialValue: entry.notes)
        _fullTank = State(initialValue: entry.fullTank)
        _adBlue = State(initialValue: entry.adBlue)
        _trailer = State(initialValue: entry.trailer)
        _tireSeason = State(initialValue: TireSeason.from(entry.tireSeason))
        _adBlueLitersText = State(initialValue: Format.inputNumber(entry.adBlueLiters, digits: 2))
        _adBluePriceText = State(initialValue: Format.inputNumber(entry.adBluePricePerLiter, digits: 3))
        _adBlueTotalText = State(initialValue: Format.inputNumber(entry.adBlueTotalPrice, digits: 2))
        _priceWasAutoFilled = State(initialValue: false)
        _priceSourceStatus = State(initialValue: "Gespeicherter Eintrag")
        _initialized = State(initialValue: true)
    }

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query private var allEntries: [FuelEntry]

    // Formularzustand
    @State private var vehicleId = ""
    @State private var date = Date()
    @State private var stationId: String?
    @State private var stationName = ""
    @State private var stationPlace = ""
    @State private var stationCoordinate: CLLocationCoordinate2D?
    @State private var stationSource: String?
    @State private var fuelType = FuelType.diesel.rawValue
    @State private var odometerText = ""
    @State private var priceText = ""
    @State private var litersText = ""
    @State private var totalText = ""
    @State private var notes = ""

    @State private var fullTank = true
    @State private var adBlue = false
    @State private var trailer = false
    @State private var tireSeason = TireSeason.summer
    @State private var adBlueLitersText = ""
    @State private var adBluePriceText = ""
    @State private var adBlueTotalText = ""

    @State private var priceWasAutoFilled = true
    // Werte der zuletzt programmatisch übernommenen Station: solange die
    // Textfelder damit übereinstimmen, bleiben deren Koordinaten erhalten.
    @State private var appliedStationName: String?
    @State private var appliedStationPlace: String?
    @State private var priceSourceStatus = "Kein Livepreis geladen"
    @State private var statusMessage: String?
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var initialized = false

    @FocusState private var focusedField: FuelField?

    enum FuelField {
        case price, liters, total
        case adBluePrice, adBlueLiters, adBlueTotal
    }

    private var isEditing: Bool { entryToEdit != nil }

    private var selectedVehicle: Vehicle? {
        vehicles.first { $0.externalId == vehicleId } ?? vehicles.selected(id: appModel.selectedVehicleId)
    }

    var body: some View {
        Form {
            vehicleSection
            stationSection
            tankSection
            adBlueSection
            previewSection
            notesSection
            actionSection
        }
        .onAppear(perform: initializeOnce)
        .onChange(of: appModel.prefillStation) { _, station in
            if let station { applyStation(station) }
        }
        .onChange(of: vehicleId) { _, newValue in
            guard initialized, !newValue.isEmpty else { return }
            appModel.selectedVehicleId = newValue
            if let vehicle = selectedVehicle, !isEditing {
                fuelType = vehicle.fuelType
            }
            priceWasAutoFilled = true
            prefillPrice()
        }
        .onChange(of: fuelType) { _, _ in
            guard initialized else { return }
            priceWasAutoFilled = true
            prefillPrice()
        }
        .alert("Eintrag löschen?", isPresented: $showDeleteConfirmation) {
            Button("Endgültig löschen", role: .destructive) { deleteEntry() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Dieser Vorgang kann nicht rückgängig gemacht werden.")
        }
    }

    // MARK: Abschnitte

    private var vehicleSection: some View {
        Section("Fahrzeug & Datum") {
            Picker("Fahrzeug", selection: $vehicleId) {
                ForEach(vehicles) { vehicle in
                    Text(vehicle.displayName).tag(vehicle.externalId)
                }
            }
            DatePicker("Datum", selection: $date)
            Picker("Kraftstoff", selection: $fuelType) {
                ForEach(FuelType.allCases) { fuel in
                    Text(fuel.label).tag(fuel.rawValue)
                }
            }
        }
    }

    private var stationSection: some View {
        Section("Tankstelle") {
            if !appModel.stations.isEmpty {
                Picker("In der Nähe", selection: Binding(
                    get: {
                        guard let stationId, appModel.stations.contains(where: { $0.id == stationId }) else { return "" }
                        return stationId
                    },
                    set: { newValue in
                        if let station = appModel.stations.first(where: { $0.id == newValue }) {
                            applyStation(station)
                        } else {
                            stationId = nil
                        }
                    }
                )) {
                    Text("Manuell eingeben").tag("")
                    ForEach(appModel.stations) { station in
                        Text(stationOptionLabel(station)).tag(station.id)
                    }
                }
            }

            // onChange feuert auch bei programmatischen Änderungen (applyStation);
            // die Koordinaten werden nur gelöscht, wenn der Text tatsächlich
            // von der übernommenen Station abweicht.
            TextField("Name der Tankstelle", text: $stationName)
                .onChange(of: stationName) { _, newValue in
                    guard initialized, newValue != appliedStationName else { return }
                    stationCoordinate = nil
                    stationSource = nil
                }
            TextField("Ort / Adresse", text: $stationPlace)
                .onChange(of: stationPlace) { _, newValue in
                    guard initialized, newValue != appliedStationPlace else { return }
                    stationCoordinate = nil
                    stationSource = nil
                }

            Button {
                Task {
                    await appModel.refreshStationsAroundCurrentLocation()
                    if let first = appModel.stations.first {
                        applyStation(first)
                    }
                }
            } label: {
                Label(appModel.isLoadingStations ? "Tankstellen werden geladen..." : "Tankstellen in der Nähe suchen",
                      systemImage: "location.fill")
            }
            .disabled(appModel.isLoadingStations)
        }
    }

    private var tankSection: some View {
        Section {
            HStack {
                Text("Kilometerstand")
                Spacer()
                TextField("z. B. 123456", text: $odometerText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
            }

            Toggle("Volltankung", isOn: $fullTank)
            Toggle("Anhänger", isOn: $trailer)
            Picker("Reifen", selection: $tireSeason) {
                ForEach(TireSeason.allCases) { season in
                    Text(season.label).tag(season)
                }
            }

            numberRow("Literpreis (€)", text: $priceText, field: .price, digits: 3)
            numberRow("Liter", text: $litersText, field: .liters, digits: 2)
            numberRow("Gesamtpreis (€)", text: $totalText, field: .total, digits: 2)

            Text(priceSourceStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Tankdaten")
        } footer: {
            Text("Zwei Werte genügen – der dritte wird automatisch berechnet.")
        }
    }

    private var adBlueSection: some View {
        Section {
            Toggle("AdBlue getankt", isOn: $adBlue)
            if adBlue {
                numberRow("AdBlue Liter", text: $adBlueLitersText, field: .adBlueLiters, digits: 2)
                numberRow("AdBlue Literpreis (€)", text: $adBluePriceText, field: .adBluePrice, digits: 3)
                numberRow("AdBlue Gesamtpreis (€)", text: $adBlueTotalText, field: .adBlueTotal, digits: 2)
            }
        }
    }

    private var previewSection: some View {
        let trip = currentTrip()
        return Section("Fahrt seit letztem Tanken") {
            LabeledContent("Strecke", value: trip.distance.map { "\(Format.number($0, digits: 0)) km" } ?? "-")
            LabeledContent("Verbrauch", value: trip.consumption.map { "\(Format.number($0, digits: 1)) l/100 km" } ?? (fullTank ? "-" : "Nur bei Volltankung"))
            LabeledContent("Kosten", value: trip.costPer100.map { "\(Format.currency($0)) / 100 km" } ?? "-")
        }
    }

    private var notesSection: some View {
        Section("Notizen") {
            TextField("Notizen", text: $notes, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    private var actionSection: some View {
        Section {
            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Button {
                Task { await save() }
            } label: {
                if isSaving {
                    HStack {
                        ProgressView()
                        Text("Wird gespeichert...")
                    }
                } else {
                    Text(isEditing ? "Änderungen speichern" : "Tankvorgang speichern")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
            }
            .disabled(isSaving)

            if isEditing {
                Button("Eintrag löschen", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
    }

    private func numberRow(_ title: String, text: Binding<String>, field: FuelField, digits: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
                .focused($focusedField, equals: field)
                .onChange(of: text.wrappedValue) { _, _ in
                    guard initialized, focusedField == field else { return }
                    if field == .price {
                        priceWasAutoFilled = false
                        priceSourceStatus = text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty
                            ? "Kein Livepreis geladen"
                            : "Manuell eingetragen"
                    }
                    recalculate(changed: field)
                }
        }
    }

    // MARK: Initialisierung

    private func initializeOnce() {
        guard !initialized else { return }
        defer { initialized = true }

        let vehicle = vehicles.selected(id: appModel.selectedVehicleId)
        vehicleId = vehicle?.externalId ?? ""
        fuelType = vehicle?.fuelType ?? FuelType.diesel.rawValue
        tireSeason = TireSeason.defaultFor(date: Date())

        if let station = appModel.prefillStation {
            applyStation(station)
        } else {
            prefillPrice()
        }
    }

    private func applyStation(_ station: NearbyStation) {
        stationId = station.id
        appliedStationName = station.name
        appliedStationPlace = station.place
        stationName = station.name
        stationPlace = station.place
        stationCoordinate = station.coordinate
        stationSource = station.source
        appModel.prefillStation = nil

        if let livePrice = station.price(for: fuelType) {
            priceText = Format.inputNumber(livePrice, digits: 3)
            priceSourceStatus = "Livepreis: \(station.sourceLabel)"
            priceWasAutoFilled = true
            recalculate(changed: .price)
        } else {
            priceWasAutoFilled = true
            prefillPrice()
        }
    }

    private func stationOptionLabel(_ station: NearbyStation) -> String {
        let price = station.price(for: fuelType).map { "\(Format.number($0, digits: 3)) €" } ?? "ohne Preis"
        return "\(station.name) · \(price) · \(Format.number(station.distanceKm, digits: 1)) km"
    }

    // MARK: Preislogik (wie die PWA)

    private func prefillPrice() {
        let currentPrice = priceText.trimmingCharacters(in: .whitespaces)
        guard priceWasAutoFilled || currentPrice.isEmpty else { return }
        guard let vehicle = selectedVehicle else { return }

        if let station = appModel.stations.first(where: { $0.id == stationId }),
           let livePrice = station.price(for: fuelType) {
            priceText = Format.inputNumber(livePrice, digits: 3)
            priceSourceStatus = "Livepreis: \(station.sourceLabel)"
            priceWasAutoFilled = true
            recalculate(changed: .price)
            return
        }

        let stationPrice = TripMath.lastStationPrice(entries: allEntries, stationId: stationId, stationName: stationName, fuelType: fuelType)
        let vehiclePrice = TripMath.lastVehiclePrice(entries: allEntries, vehicleId: vehicle.externalId, fuelType: fuelType)
        let defaultPrice = vehicle.defaultPrice
        let fallback = stationPrice ?? vehiclePrice ?? defaultPrice

        priceText = Format.inputNumber(fallback, digits: 3)
        if fallback == nil {
            priceSourceStatus = "Kein Livepreis geladen"
        } else if stationPrice != nil {
            priceSourceStatus = "Vorschlag: letzter eigener Preis an dieser Tankstelle"
        } else if vehiclePrice != nil {
            priceSourceStatus = "Vorschlag: letzter eigener Preis dieses Fahrzeugs"
        } else {
            priceSourceStatus = "Vorschlag: Preisvorgabe des Fahrzeugs"
        }
        priceWasAutoFilled = true
        recalculate(changed: .price)
    }

    /// Gegenseitige Umrechnung von Preis/Liter/Gesamt (bzw. AdBlue).
    private func recalculate(changed: FuelField) {
        switch changed {
        case .price, .liters, .total:
            let price = Format.parseNumber(priceText)
            let liters = Format.parseNumber(litersText)
            let total = Format.parseNumber(totalText)

            switch changed {
            case .total:
                if let total, let price, price > 0 {
                    litersText = Format.inputNumber(total / price, digits: 2)
                } else if let total, let liters, liters > 0 {
                    priceText = Format.inputNumber(total / liters, digits: 3)
                }
            case .liters:
                if let liters, let price {
                    totalText = Format.inputNumber(liters * price, digits: 2)
                } else if let liters, liters > 0, let total {
                    priceText = Format.inputNumber(total / liters, digits: 3)
                }
            default:
                if let price, let liters {
                    totalText = Format.inputNumber(liters * price, digits: 2)
                } else if let price, price > 0, let total {
                    litersText = Format.inputNumber(total / price, digits: 2)
                }
            }

        case .adBluePrice, .adBlueLiters, .adBlueTotal:
            let price = Format.parseNumber(adBluePriceText)
            let liters = Format.parseNumber(adBlueLitersText)
            let total = Format.parseNumber(adBlueTotalText)

            switch changed {
            case .adBlueTotal:
                if let total, let price, price > 0 {
                    adBlueLitersText = Format.inputNumber(total / price, digits: 2)
                } else if let total, let liters, liters > 0 {
                    adBluePriceText = Format.inputNumber(total / liters, digits: 3)
                }
            case .adBlueLiters:
                if let liters, let price {
                    adBlueTotalText = Format.inputNumber(liters * price, digits: 2)
                } else if let liters, liters > 0, let total {
                    adBluePriceText = Format.inputNumber(total / liters, digits: 3)
                }
            default:
                if let price, let liters {
                    adBlueTotalText = Format.inputNumber(liters * price, digits: 2)
                } else if let price, price > 0, let total {
                    adBlueLitersText = Format.inputNumber(total / price, digits: 2)
                }
            }
        }
    }

    private func currentTrip() -> TripResult {
        guard let vehicle = selectedVehicle else { return TripResult() }
        return TripMath.calculateTrip(
            odometer: Format.parseNumber(odometerText),
            liters: Format.parseNumber(litersText),
            totalPrice: Format.parseNumber(totalText),
            vehicle: vehicle,
            entries: allEntries,
            date: date,
            fullTank: fullTank,
            ignoredEntryId: entryToEdit?.externalId
        )
    }

    // MARK: Speichern & Löschen

    private func save() async {
        recalculate(changed: .price)
        if adBlue { recalculate(changed: .adBluePrice) }

        guard let vehicle = selectedVehicle else {
            statusMessage = "Fahrzeug fehlt."
            return
        }
        let trimmedStationName = stationName.trimmingCharacters(in: .whitespaces)
        guard !trimmedStationName.isEmpty else {
            statusMessage = "Name der Tankstelle fehlt."
            return
        }
        guard let odometer = Format.parseNumber(odometerText) else {
            statusMessage = "Kilometerstand fehlt."
            return
        }
        guard let price = Format.parseNumber(priceText),
              let liters = Format.parseNumber(litersText),
              let total = Format.parseNumber(totalText) else {
            statusMessage = "Zwei Tankwerte genügen, der dritte muss berechenbar sein."
            return
        }

        let trip = currentTrip()
        if let distance = trip.distance, distance < 0 {
            statusMessage = "Kilometerstand liegt unter dem letzten Wert."
            return
        }

        isSaving = true
        statusMessage = nil
        defer { isSaving = false }

        // Kartenposition bestimmen: gewählte Station, sonst Geocoding,
        // sonst vorhandene Position des bearbeiteten Eintrags.
        var coordinate = stationCoordinate
        var source = stationSource
        if coordinate == nil {
            let query = [trimmedStationName, stationPlace.trimmingCharacters(in: .whitespaces)]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            if let geocoded = await StationService.geocode(place: query) {
                coordinate = geocoded.coordinate
                source = "geocode"
            } else if let entry = entryToEdit, let lat = entry.stationLat, let lng = entry.stationLng {
                coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                source = entry.stationLocationSource
            }
        }

        let entry: FuelEntry
        if let existing = entryToEdit {
            entry = existing
            entry.updatedAt = Date()
        } else {
            entry = FuelEntry(vehicleId: vehicle.externalId, vehicleName: vehicle.name, date: date)
            modelContext.insert(entry)
        }

        entry.vehicleId = vehicle.externalId
        entry.vehicleName = vehicle.name
        entry.date = date
        entry.stationId = stationId
        entry.stationName = trimmedStationName
        entry.stationPlace = stationPlace.trimmingCharacters(in: .whitespaces)
        entry.stationLat = coordinate?.latitude
        entry.stationLng = coordinate?.longitude
        entry.stationLocationSource = source
        entry.fuelType = fuelType
        entry.fullTank = fullTank
        entry.adBlue = adBlue
        entry.trailer = trailer
        entry.tireSeason = tireSeason.rawValue
        entry.adBlueLiters = adBlue ? Format.parseNumber(adBlueLitersText) : nil
        entry.adBluePricePerLiter = adBlue ? Format.parseNumber(adBluePriceText) : nil
        entry.adBlueTotalPrice = adBlue ? Format.parseNumber(adBlueTotalText) : nil
        entry.pricePerLiter = price
        entry.liters = liters
        entry.totalPrice = total
        entry.odometer = odometer
        entry.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        vehicle.defaultPrice = price
        appModel.selectedVehicleId = vehicle.externalId

        try? modelContext.save()

        if isEditing {
            onDone?()
        } else {
            // Formular für den nächsten Eintrag leeren.
            appModel.entryFormResetToken = UUID()
            appModel.selectedTab = .history
        }
    }

    private func deleteEntry() {
        guard let entry = entryToEdit else { return }
        modelContext.delete(entry)
        try? modelContext.save()
        onDone?()
    }
}
