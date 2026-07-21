import SwiftUI
import CoreData
import PhotosUI
import UniformTypeIdentifiers
import UIKit

// Fahrzeuge verwalten, Tankerkönig-API-Schlüssel, Datensicherung
// (PWA-kompatibler Import/Export) und iCloud-Hinweis.

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [SortDescriptor(\Vehicle.createdAt)]) private var vehicles: FetchedResults<Vehicle>
    @FetchRequest(sortDescriptors: []) private var entries: FetchedResults<FuelEntry>

    @State private var vehicleToEdit: Vehicle?
    @State private var showNewVehicle = false
    @State private var vehicleToDelete: Vehicle?

    @State private var showImporter = false
    @State private var pendingBackup: ParsedBackup?
    @State private var backupMessage: String?
    @State private var exportDocument: BackupDocument?
    @State private var showExporter = false

    @StateObject private var syncMonitor = SyncMonitor()
    @State private var syncMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                vehiclesSection
                SharingSection()
                appearanceSection
                apiKeySection
                backupSection
                iCloudSection
            }
            .navigationTitle("Einstellungen")
            .sheet(item: $vehicleToEdit) { vehicle in
                VehicleEditView(vehicle: vehicle)
            }
            .sheet(isPresented: $showNewVehicle) {
                VehicleEditView(vehicle: nil)
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .text]) { result in
                handleImportSelection(result)
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: Backup.suggestedFileName
            ) { result in
                if case .success = result {
                    backupMessage = "Backup gespeichert."
                }
            }
            .alert("Backup importieren?", isPresented: Binding(
                get: { pendingBackup != nil },
                set: { if !$0 { pendingBackup = nil } }
            )) {
                Button("Importieren und ersetzen", role: .destructive) { applyPendingBackup() }
                Button("Abbrechen", role: .cancel) { pendingBackup = nil }
            } message: {
                if let preview = pendingBackup?.preview {
                    Text("Aktuelle Daten werden ersetzt.\n\n\(preview.vehicleCount) Fahrzeug(e), \(preview.entryCount) Eintrag(e)\(preview.exportedAt.map { "\nStand: \(Format.date($0))" } ?? "")")
                }
            }
            .alert("Fahrzeug löschen?", isPresented: Binding(
                get: { vehicleToDelete != nil },
                set: { if !$0 { vehicleToDelete = nil } }
            )) {
                Button("Löschen", role: .destructive) { deleteVehicle() }
                Button("Abbrechen", role: .cancel) { vehicleToDelete = nil }
            } message: {
                if let vehicle = vehicleToDelete {
                    let count = entries.filter { $0.vehicleId == vehicle.externalId }.count
                    Text(count > 0
                         ? "Fahrzeug und \(count) zugehörige Einträge löschen?"
                         : "Fahrzeug löschen?")
                }
            }
        }
    }

    // MARK: Fahrzeuge

    private var vehiclesSection: some View {
        Section("Fahrzeuge") {
            ForEach(vehicles) { vehicle in
                Button {
                    vehicleToEdit = vehicle
                } label: {
                    HStack(spacing: 12) {
                        if let data = vehicle.photoData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "car.fill")
                                .frame(width: 44, height: 44)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vehicle.displayName)
                                .foregroundStyle(.primary)
                            Text(FuelType.label(for: vehicle.fuelType))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if vehicle.externalId == appModel.selectedVehicleId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .swipeActions {
                    if vehicles.count > 1 {
                        Button("Löschen", systemImage: "trash", role: .destructive) {
                            vehicleToDelete = vehicle
                        }
                    }
                }
            }

            Button {
                showNewVehicle = true
            } label: {
                Label("Neues Fahrzeug", systemImage: "plus")
            }
        }
    }

    // MARK: Darstellung

    private var appearanceSection: some View {
        Section("Darstellung") {
            Picker("Erscheinungsbild", selection: $appModel.appearance) {
                ForEach(Appearance.allCases) { appearance in
                    Text(appearance.label).tag(appearance)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Tankerkönig

    private var apiKeySection: some View {
        Section {
            TextField("API-Schlüssel", text: $appModel.tankerkoenigApiKey)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        } header: {
            Text("Tankerkönig-Livepreise")
        } footer: {
            Text("Kostenloser API-Schlüssel von creativecommons.tankerkoenig.de – damit zeigt die Tankstellensuche Livepreise (MTS-K). Ohne Schlüssel werden Tankstellen über Apple Karten gefunden, ohne Preise.")
        }
    }

    // MARK: Datensicherung

    private var backupSection: some View {
        Section {
            Button {
                showImporter = true
            } label: {
                Label("Backup importieren (PWA-Datei)", systemImage: "square.and.arrow.down")
            }

            Button {
                prepareExport()
            } label: {
                Label("Backup exportieren (PWA-Datei, .json)", systemImage: "square.and.arrow.up")
            }
            .disabled(vehicles.isEmpty)

            if let backupMessage {
                Text(backupMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Datensicherung")
        } footer: {
            Text("Importiert die JSON-Datensicherung der Tankbuch-Web-App (tankbuch-backup-….json) und ersetzt dabei alle Daten in der App. Der Export erzeugt dieselbe Datei und kann auch wieder in die Web-App eingespielt werden.")
        }
    }

    private var iCloudSection: some View {
        Section {
            LabeledContent("Letzter Abgleich") {
                Text(syncMonitor.lastEventText)
                    .font(.footnote)
                    .foregroundStyle(syncMonitor.lastEventWasError ? .red : .secondary)
                    .multilineTextAlignment(.trailing)
            }

            Button {
                triggerSync()
            } label: {
                Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath.icloud")
            }

            if let syncMessage {
                Text(syncMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("iCloud")
        } footer: {
            Text("Fahrzeuge und Tankvorgänge synchronisieren automatisch über iCloud auf alle Geräte derselben Apple-ID. „Jetzt synchronisieren“ stößt den Abgleich zusätzlich manuell an.")
        }
    }

    // MARK: Aktionen

    private func handleImportSelection(_ result: Result<URL, Error>) {
        backupMessage = nil
        guard case .success(let url) = result else { return }

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            pendingBackup = try Backup.parse(data: data)
        } catch {
            backupMessage = (error as? BackupError)?.errorDescription ?? "Backup konnte nicht gelesen werden."
        }
    }

    private func applyPendingBackup() {
        guard let backup = pendingBackup else { return }
        pendingBackup = nil
        do {
            try Backup.apply(backup, context: viewContext, persistence: PersistenceController.shared)
            if let key = backup.tankerkoenigApiKey, !key.isEmpty {
                appModel.tankerkoenigApiKey = key
            }
            if let selected = backup.selectedVehicleId, backup.vehicles.contains(where: { $0.id == selected }) {
                appModel.selectedVehicleId = selected
            } else {
                appModel.selectedVehicleId = backup.vehicles.first?.id ?? ""
            }
            backupMessage = "Backup importiert: \(backup.vehicles.count) Fahrzeug(e), \(backup.entries.count) Eintrag(e)."
        } catch {
            backupMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func prepareExport() {
        do {
            let data = try Backup.export(
                vehicles: Array(vehicles),
                entries: Array(entries),
                selectedVehicleId: appModel.selectedVehicleId,
                tankerkoenigApiKey: appModel.tankerkoenigApiKey
            )
            exportDocument = BackupDocument(data: data)
            showExporter = true
        } catch {
            backupMessage = "Export fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    /// CloudKit bietet keinen offiziellen „Sync jetzt“-Aufruf; eine winzige
    /// Änderung am Ping-Datensatz erzeugt aber einen Export und weckt damit
    /// den Abgleich (auch auf den anderen Geräten).
    private func triggerSync() {
        do {
            let request = NSFetchRequest<SyncPing>(entityName: "SyncPing")
            let pings = try viewContext.fetch(request)
            if let ping = pings.first {
                ping.updatedAt = Date()
                // Durch parallele Geräte entstandene Duplikate aufräumen.
                pings.dropFirst().forEach { viewContext.delete($0) }
            } else {
                let ping = SyncPing(context: viewContext)
                PersistenceController.shared.assign(ping, near: nil, in: viewContext)
                ping.updatedAt = Date()
            }
            try viewContext.save()
            syncMessage = "Synchronisierung angestoßen – Ergebnis erscheint oben."
        } catch {
            syncMessage = "Synchronisierung konnte nicht angestoßen werden: \(error.localizedDescription)"
        }
    }

    private func deleteVehicle() {
        guard let vehicle = vehicleToDelete, vehicles.count > 1 else { return }
        vehicleToDelete = nil

        // ID vor dem Löschen sichern – nach dem Save ist das Objekt ungültig.
        let deletedId = vehicle.externalId
        for entry in entries where entry.vehicleId == deletedId {
            viewContext.delete(entry)
        }
        viewContext.delete(vehicle)
        try? viewContext.save()

        if appModel.selectedVehicleId == deletedId {
            appModel.selectedVehicleId = vehicles.first { $0.externalId != deletedId }?.externalId ?? ""
        }
    }
}

// MARK: - Export-Dokument

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Fahrzeug bearbeiten

struct VehicleEditView: View {
    let vehicle: Vehicle?

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var plate = ""
    @State private var fuelType = FuelType.diesel.rawValue
    @State private var defaultPriceText = ""
    @State private var startOdometerText = ""
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Fahrzeug") {
                    TextField("Name", text: $name)
                    TextField("Kennzeichen", text: $plate)
                        .textInputAutocapitalization(.characters)
                    Picker("Kraftstoff", selection: $fuelType) {
                        ForEach(FuelType.allCases) { fuel in
                            Text(fuel.label).tag(fuel.rawValue)
                        }
                    }
                }

                Section("Vorgaben") {
                    HStack {
                        Text("Preisvorgabe (€/l)")
                        Spacer()
                        TextField("z. B. 1,659", text: $defaultPriceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                    HStack {
                        Text("Anfangs-Kilometerstand")
                        Spacer()
                        TextField("z. B. 45000", text: $startOdometerText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                }

                Section("Foto") {
                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photoData == nil ? "Foto auswählen" : "Foto ändern", systemImage: "photo")
                    }
                    if photoData != nil {
                        Button("Foto entfernen", role: .destructive) {
                            photoData = nil
                            photoItem = nil
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            .navigationTitle(vehicle == nil ? "Neues Fahrzeug" : "Fahrzeug bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Speichern") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: loadOnce)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        // Verkleinern, damit Backups und iCloud-Sync schlank bleiben.
                        photoData = resized(image)
                    }
                }
            }
        }
    }

    private func loadOnce() {
        guard !loaded else { return }
        loaded = true
        guard let vehicle else { return }
        name = vehicle.name
        plate = vehicle.plate
        fuelType = vehicle.fuelType
        defaultPriceText = Format.inputNumber(vehicle.defaultPrice, digits: 3)
        startOdometerText = Format.inputNumber(vehicle.startOdometer, digits: 0)
        photoData = vehicle.photoData
    }

    private func resized(_ image: UIImage, maxDimension: CGFloat = 900) -> Data? {
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resizedImage.jpegData(compressionQuality: 0.75)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Fahrzeugname fehlt."
            return
        }

        let target: Vehicle
        if let vehicle {
            target = vehicle
        } else {
            target = Vehicle.create(in: viewContext, persistence: PersistenceController.shared)
        }

        target.name = trimmedName
        target.plate = plate.trimmingCharacters(in: .whitespaces)
        target.fuelType = fuelType
        target.defaultPrice = Format.parseNumber(defaultPriceText)
        target.startOdometer = Format.parseNumber(startOdometerText)
        target.photoData = photoData

        do {
            try viewContext.save()
        } catch {
            errorMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
            return
        }

        if vehicle == nil || appModel.selectedVehicleId.isEmpty {
            appModel.selectedVehicleId = target.externalId
        }
        dismiss()
    }
}
