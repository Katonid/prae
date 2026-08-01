import SwiftUI
import SwiftData
import Photos
import CoreLocation
import CloudKit

struct SettingsView: View {
    @EnvironmentObject private var tracker: LocationTracker
    @Environment(\.modelContext) private var context

    @Query private var days: [TrackDay]
    @Query private var tags: [MediaTag]
    @Query private var familyDays: [FamilyDay]
    @ObservedObject private var trackColors = TrackColorStore.shared

    @State private var deviceName = DeviceInfo.deviceName
    @State private var photoStatus = PhotoMatcher.authorizationStatus
    @State private var confirmDelete = false
    @State private var analysisEnabled = PhotoAnalyzer.isEnabled
    @State private var analysisRunning = false
    @State private var analysisProgress = ""
    @AppStorage(AppearanceMode.appKey) private var appAppearance = AppearanceMode.system.rawValue
    @AppStorage(AppearanceMode.mapKey) private var mapAppearance = AppearanceMode.system.rawValue
    @State private var thunderforestKey = UserDefaults.standard.string(forKey: OutdoorMapView.OutdoorTileOverlay.thunderforestKeyDefault) ?? ""
    @State private var accountStatusText = "…"
    @State private var deviceToDelete: DeviceSummary?
    @State private var syncNudgeRunning = false
    @State private var syncNudgeDone = false
    @State private var cloudKitLogRunning = false
    @State private var cloudKitLogText: String?
    @State private var serverStateRunning = false
    @State private var serverStateText: String?
    @State private var rebuildConfirmShown = false
    @State private var rebuildRequested = false

    private struct DeviceSummary: Identifiable {
        let id: String
        let name: String
        let dayCount: Int
        let latest: Date
    }

    /// Alle Geräte, deren Tage in der (lokal gesyncten) Datenbank liegen —
    /// fehlt hier ein eigenes Gerät, kommt dessen Sync nicht an.
    private var deviceSummaries: [DeviceSummary] {
        Dictionary(grouping: days, by: \.deviceId).map { id, list in
            // Aktuellster Name gewinnt — alte Aufzeichnungen können noch
            // den Namen vom Aufnahmezeitpunkt tragen.
            let baseName: String
            if id == DeviceInfo.deviceId {
                baseName = DeviceInfo.deviceName
            } else {
                baseName = list.max { $0.updatedAt < $1.updatedAt }?.deviceName ?? "Gerät"
            }
            let name = id == DeviceInfo.deviceId ? "\(baseName) (dieses Gerät)" : baseName
            return DeviceSummary(
                id: id,
                name: name,
                dayCount: list.count,
                latest: list.map(\.updatedAt).max() ?? .distantPast
            )
        }
        .sorted { $0.name < $1.name }
    }

    // Der Formular-Rumpf ist in benannte Teil-Sektionen zerlegt — als ein
    // einziger Ausdruck bringt er Swifts Typprüfung an die Grenze
    // („unable to type-check this expression in reasonable time“).
    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                colorSection
                outdoorSection
                recordingSection
                photosSection
                analysisSection
                familySection
                syncSection
                deviceSection
                dataSection
                aboutSection
            }
            .navigationTitle("Einstellungen")
            .confirmationDialog(
                "Alle Aufzeichnungen dieses Geräts löschen? Über iCloud wird die Löschung auf alle Geräte übertragen.",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Endgültig löschen", role: .destructive) {
                    deleteOwnData()
                }
            }
            .confirmationDialog(
                "Alle Aufzeichnungen von „\(deviceToDelete?.name ?? "")“ löschen? Über iCloud wird die Löschung auf alle Geräte übertragen.",
                isPresented: Binding(
                    get: { deviceToDelete != nil },
                    set: { if !$0 { deviceToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Endgültig löschen", role: .destructive) {
                    if let device = deviceToDelete {
                        deleteDevice(device.id)
                    }
                    deviceToDelete = nil
                }
            }
            .onAppear {
                photoStatus = PhotoMatcher.authorizationStatus
            }
            .task {
                let status = (try? await CKContainer.default().accountStatus()) ?? .couldNotDetermine
                accountStatusText = switch status {
                case .available: "Angemeldet"
                case .noAccount: "Kein iCloud-Konto"
                case .restricted: "Eingeschränkt"
                case .temporarilyUnavailable: "Vorübergehend nicht verfügbar"
                case .couldNotDetermine: "Unbekannt"
                @unknown default: "Unbekannt"
                }
            }
        }
    }

    // MARK: - Spurfarben

    private struct ColorTarget: Identifiable {
        let id: String
        let name: String
        let index: Int
    }

    /// Alle bekannten Spuren: eigene Geräte + Familien-Geräte.
    private var colorTargets: [ColorTarget] {
        var targets = deviceSummaries.enumerated().map { index, summary in
            ColorTarget(id: summary.id, name: summary.name, index: index)
        }
        let familyGroups = Dictionary(grouping: familyDays) {
            $0.deviceId.isEmpty ? $0.recordName : $0.deviceId
        }
        let start = targets.count
        let sortedGroups = familyGroups.sorted {
            ($0.value.first?.displayName ?? "") < ($1.value.first?.displayName ?? "")
        }
        for (offset, group) in sortedGroups.enumerated() {
            targets.append(ColorTarget(
                id: group.key,
                name: group.value.first?.displayName ?? "Familie",
                index: start + offset
            ))
        }
        return targets
    }

    private var colorSection: some View {
        Section("Spurfarben") {
            ForEach(colorTargets) { target in
                ColorPicker(target.name, selection: Binding(
                    get: { trackColors.color(forId: target.id, fallbackIndex: target.index) },
                    set: { trackColors.setColor($0, forId: target.id) }
                ), supportsOpacity: false)
            }
            if !trackColors.map.isEmpty {
                Button("Standardfarben wiederherstellen") {
                    trackColors.resetAll()
                }
            }
            Text("Die Farbwahl gilt überall — Karte, Legende, Tagesdetail — und synchronisiert über iCloud auf alle deine Geräte.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Teil-Sektionen

    private var appearanceSection: some View {
        Section("Darstellung") {
                    Picker("App", selection: $appAppearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    Picker("Karte", selection: $mapAppearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    Text("App und Karte getrennt einstellbar — z. B. dunkle App mit heller Karte. „Automatisch“ folgt der Systemeinstellung.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
        }
    }

    private var outdoorSection: some View {
        Section("Outdoor-Karte") {
                    TextField("Thunderforest-API-Key (optional)", text: $thunderforestKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: thunderforestKey) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: OutdoorMapView.OutdoorTileOverlay.thunderforestKeyDefault)
                        }
                    Text("Ohne Key nutzt der Outdoor-Stil den freien OpenTopoMap-Server — der ist oft träge. Mit einem kostenlosen Key von thunderforest.com (Tarif „Hobby Project“) lädt der Outdoor-Stil deutlich schneller über deren CDN. Bereits geladene Gegenden bleiben lokal zwischengespeichert.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
        }
    }

    private var recordingSection: some View {
        Section("Aufzeichnung") {
                    Toggle("Standort aufzeichnen", isOn: $tracker.trackingEnabled)
                    Toggle("Hohe Genauigkeit", isOn: $tracker.highAccuracy)
                    Toggle("Dauer-Sitzung (blauer Pfeil)", isOn: $tracker.persistentSession)
                    Text(tracker.persistentSession
                        ? "Zuverlässigste Aufzeichnung: Die Hintergrund-Sitzung bleibt dauerhaft bestehen — dafür zeigt iOS den blauen Ortungspfeil auch im Ruhemodus. iOS erkennt Sitzungen nur an, die entstehen, während die App benutzt wird; deshalb ist „dauerhaft“ der einzige Weg, Fahrten mit gesperrtem Gerät garantiert präzise zu erfassen."
                        : "Pfeil nur bei Bewegung: Im Ruhemodus erlischt der blaue Pfeil. ACHTUNG: Beginnt eine Fahrt mit gesperrtem Gerät, erkennt iOS die neue Sitzung oft nicht an — die Aufzeichnung kann dann grob bleiben (nur Funkzellen-Ortung) oder Lücken haben. Apple koppelt Präzision im Hintergrund bewusst an die Sichtbarkeit.")
                        .font(.footnote)
                        .foregroundStyle(tracker.persistentSession ? Color.secondary : Color.orange)
                    LabeledContent("Standort-Berechtigung", value: locationStatusText)
                    LabeledContent("Genauer Standort") {
                        Text(tracker.accuracyAuthorization == .fullAccuracy ? "Ein" : "AUS — nur ±1–2 km!")
                            .foregroundStyle(tracker.accuracyAuthorization == .fullAccuracy ? Color.secondary : Color.red)
                    }
                    if tracker.accuracyAuthorization == .reducedAccuracy {
                        Text("Ohne „Genauer Standort“ liefert iOS nur die ungefähre Position — Stadtteile stimmen, Straßenverläufe sind unmöglich. Einschalten: iOS-Einstellungen → Datenschutz & Sicherheit → Ortungsdienste → Tagesspur → „Genauer Standort“.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    LabeledContent("Bewegungssensor", value: LocationTracker.motionStatusText)
                    if !tracker.hasAlwaysPermission {
                        Button("Berechtigung anfragen („Immer“ empfohlen)") {
                            tracker.requestPermission()
                        }
                    }
                    LabeledContent("Hintergrund-Neustarts heute", value: "\(LocationTracker.backgroundRelaunchesToday)")
                    Text("Ausgewogen (Standard): beste GPS-Stufe bei Bewegung; nach 5 Minuten Stillstand grober Ruhemodus. Den Beginn einer Fahrt oder eines Wegs meldet der Bewegungssensor in Sekunden (bitte Bewegungs-Berechtigung erlauben) — die App schaltet sofort zurück auf präzise. „Hohe Genauigkeit“ zeichnet dauerhaft mit Navigations-GPS und Punkten alle 10 m auf (wie Sport-Apps à la Komoot). Hintergrund-Neustarts: So oft hat iOS die App heute beendet und wieder geweckt — jede dieser Stellen kann eine kleine Track-Lücke sein; ein Geofence (150 m) hält sie so kurz wie möglich.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
        }
    }

    private var photosSection: some View {
        Section("Fotos & Videos") {
                    LabeledContent("Mediathek-Zugriff", value: photoStatusText)
                    if photoStatus != .authorized && photoStatus != .limited {
                        Button("Zugriff erlauben") {
                            Task {
                                photoStatus = await PhotoMatcher.requestAccess()
                            }
                        }
                    }
                    Text("Medien werden nur gelesen und anhand von Zeit und GPS eingeblendet — Tagesspur speichert keine Kopien.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
        }
    }

    private var analysisSection: some View {
        Section("Fotoanalyse (auf dem Gerät)") {
                    Toggle("Foto-Stichwörter für die Suche", isOn: $analysisEnabled)
                        .onChange(of: analysisEnabled) { _, newValue in
                            PhotoAnalyzer.isEnabled = newValue
                        }
                    if analysisEnabled {
                        Button {
                            runAnalysis()
                        } label: {
                            if analysisRunning {
                                Label(analysisProgress.isEmpty ? "Analysiere…" : analysisProgress,
                                      systemImage: "sparkles")
                            } else {
                                Label("Alle Tage jetzt analysieren", systemImage: "sparkles")
                            }
                        }
                        .disabled(analysisRunning)
                        LabeledContent("Analysierte Aufnahmen", value: "\(tags.count)")
                    }
                    Text("Erkennt Motive (z. B. Picknick, See, Hund) komplett auf dem Gerät mit Apples Vision-Framework. Gespeichert werden nur Stichwörter, nie Bilder — nichts verlässt das Gerät. Treffer erscheinen in der Suche als „Fotoanalyse“ markiert; wie jede Mustererkennung kann sie sich irren.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
        }
    }

    private var familySection: some View {
        Section("Familie") {
                    NavigationLink {
                        FamilyView()
                    } label: {
                        Label("Familienfreigabe", systemImage: "person.3.fill")
                    }
                    Text("Teile deine Tage mit Familienmitgliedern — auch mit anderen Apple-IDs — und sieh deren Tage in Karte, Tagesliste und Suche.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
        }
    }

    private var syncSection: some View {
        Section("iCloud-Sync (eigene Geräte)") {
                    LabeledContent("Datenbank",
                                   value: SyncDiagnose.cloudKitAktiv ? "iCloud-Sync aktiv" : "NUR LOKAL — kein Sync")
                    LabeledContent("iCloud-Konto", value: accountStatusText)
                    LabeledContent("Letztes Hochladen",
                                   value: SyncMonitor.lastExport?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                    LabeledContent("Letztes Empfangen",
                                   value: SyncMonitor.lastImport?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                    Button {
                        nudgeSync()
                    } label: {
                        if syncNudgeRunning {
                            Label("Wird angestoßen…", systemImage: "arrow.triangle.2.circlepath")
                        } else if syncNudgeDone {
                            Label("Angestoßen — Zeilen oben zeigen den Erfolg", systemImage: "checkmark.circle")
                        } else {
                            Label("Sync jetzt anstoßen", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(syncNudgeRunning)
                    if let error = SyncMonitor.lastError {
                        Text("Sync-Fehler (\(error.date.formatted(date: .abbreviated, time: .shortened))): \(error.text)")
                            .font(.footnote)
                            .foregroundStyle(.red)
                        // Roh-Fehler zum Aufklappen: Wenn CloudKit die
                        // Einzelgründe versteckt (wie am 30.7., 12:29),
                        // steht hier trotzdem der komplette Originaltext.
                        if let detail = SyncMonitor.lastErrorDetail {
                            DisclosureGroup("Technische Details") {
                                Text(detail)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                // Wenn der Fehler „nackt“ ankommt (Code=2
                                // ohne Details), stehen die echten Gründe
                                // nur im Systemprotokoll — hier auslesbar.
                                Button {
                                    cloudKitLogRunning = true
                                    Task.detached(priority: .userInitiated) {
                                        let text = SyncMonitor.cloudKitLogExcerpt()
                                        await MainActor.run {
                                            cloudKitLogText = text
                                            cloudKitLogRunning = false
                                        }
                                    }
                                } label: {
                                    Label(
                                        cloudKitLogRunning ? "Lese Systemprotokoll…" : "CloudKit-Protokoll auslesen",
                                        systemImage: "doc.text.magnifyingglass"
                                    )
                                }
                                .disabled(cloudKitLogRunning)
                                if let cloudKitLogText {
                                    Text(cloudKitLogText)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                                // Eigene Abrufe werden nicht geschwärzt —
                                // zeigt unverfälscht, ob Zone/Freigabe
                                // auf dem Server wirklich existieren.
                                Button {
                                    serverStateRunning = true
                                    Task {
                                        let text = await FamilySync.shared.serverStateReport()
                                        serverStateText = text
                                        serverStateRunning = false
                                    }
                                } label: {
                                    Label(
                                        serverStateRunning ? "Prüfe Server…" : "Server-Zustand prüfen",
                                        systemImage: "externaldrive.badge.icloud"
                                    )
                                }
                                .disabled(serverStateRunning)
                                if let serverStateText {
                                    Text(serverStateText)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                                // Letzter Ausweg bei festgefahrenem
                                // CloudKit-Gedächtnis: Store frisch
                                // aufbauen — Daten bleiben (Sicherung
                                // + Wiedereinsetzen), Duplikate werden
                                // danach automatisch zusammengeführt.
                                Button(role: .destructive) {
                                    rebuildConfirmShown = true
                                } label: {
                                    Label("Sync-Zustand neu aufbauen…", systemImage: "arrow.counterclockwise.icloud")
                                }
                                .confirmationDialog(
                                    "Lokalen Sync-Zustand neu aufbauen?",
                                    isPresented: $rebuildConfirmShown,
                                    titleVisibility: .visible
                                ) {
                                    Button("Beim nächsten Start neu aufbauen", role: .destructive) {
                                        StoreRebuild.request()
                                        rebuildRequested = true
                                    }
                                    Button("Abbrechen", role: .cancel) {}
                                } message: {
                                    Text("Alle Tage, Aufenthalte und Foto-Stichwörter bleiben erhalten: Sie werden als JSON-Datei gesichert und nach dem Neuaufbau automatisch wieder eingesetzt. Nur das festgefahrene CloudKit-Gedächtnis wird verworfen. Danach die App beenden (App-Umschalter, nach oben wischen) und neu öffnen.")
                                }
                                if rebuildRequested || StoreRebuild.isPending {
                                    Label("Vorgemerkt — jetzt App beenden und neu öffnen", systemImage: "checkmark.circle")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.footnote)
                        }
                    }
                    ForEach(deviceSummaries) { summary in
                        LabeledContent(summary.name) {
                            VStack(alignment: .trailing) {
                                Text("\(summary.dayCount) Tage")
                                Text("Stand \(summary.latest.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            if summary.id != DeviceInfo.deviceId {
                                Button("Löschen", role: .destructive) {
                                    deviceToDelete = summary
                                }
                            }
                        }
                    }
                    Text("Hier müssen alle deine Geräte mit Tagen auftauchen. Voraussetzungen: gleiche Apple-ID, iCloud für Tagesspur erlaubt (iOS-Einstellungen → Apple-ID → iCloud → „Alle anzeigen“). Wichtig: Direkt über Xcode installierte Builds syncen in der CloudKit-ENTWICKLUNGSUMGEBUNG, TestFlight-/App-Store-Builds in der PRODUKTIONSUMGEBUNG — die beiden Welten sehen einander nicht. Alle Geräte (auch die der Familie) müssen dieselbe Installationsart nutzen. Der erste Abgleich kann einige Minuten dauern und braucht die App einmal geöffnet auf jedem Gerät. Neue Aufzeichnungen lädt ein Gerät vor allem hoch, während die App dort geöffnet ist. Ein fremdes Gerät nach links wischen löscht dessen Aufzeichnungen — über iCloud auf allen Geräten.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
        }
    }

    private var deviceSection: some View {
        Section("Dieses Gerät") {
                    TextField("Gerätename", text: $deviceName)
                        .onChange(of: deviceName) { _, newValue in
                            DeviceInfo.deviceName = newValue
                        }
                        .onSubmit {
                            DeviceInfo.normalizeStoredNames(container: context.container)
                        }
                    Text("Jedes Gerät speichert seine eigenen Aufzeichnungen; über iCloud siehst du alle Geräte gemeinsam. Der Name hilft beim Auseinanderhalten.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
        }
    }

    private var dataSection: some View {
        Section("Daten") {
            Button("Aufzeichnungen dieses Geräts löschen", role: .destructive) {
                confirmDelete = true
            }
        }
    }

    /// „Welcher Stand läuft hier eigentlich?“ — nie wieder raten:
    /// Version + Build-Nummer (= Commit-Zähler) sind direkt ablesbar.
    private var aboutSection: some View {
        Section("Über") {
            LabeledContent("Version", value: Self.versionText)
        }
    }

    static var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (Build \(build))"
    }

    private var locationStatusText: String {
        switch tracker.authorization {
        case .authorizedAlways: return "Immer"
        case .authorizedWhenInUse: return "Beim Verwenden"
        case .denied: return "Verweigert"
        case .restricted: return "Eingeschränkt"
        default: return "Nicht festgelegt"
        }
    }

    private var photoStatusText: String {
        switch photoStatus {
        case .authorized: return "Erlaubt"
        case .limited: return "Ausgewählte Medien"
        case .denied: return "Verweigert"
        case .restricted: return "Eingeschränkt"
        default: return "Nicht festgelegt"
        }
    }

    private func runAnalysis() {
        analysisRunning = true
        analysisProgress = ""
        let dayKeys = Array(Set(days.map(\.dayKey)))
        let container = context.container
        Task {
            let count = await PhotoAnalyzer.analyzeDays(dayKeys, container: container) { done, total in
                analysisProgress = "\(done) von \(total)…"
            }
            await MainActor.run {
                analysisRunning = false
                analysisProgress = count == 0 ? "" : "\(count) neu analysiert"
            }
        }
    }

    /// Manueller Sync-Anstoß. Apples CloudKit-Sync kennt keinen
    /// offiziellen „Jetzt syncen“-Befehl — aber eine markierte Änderung
    /// am jüngsten eigenen Tag zwingt den Export sofort an, und der
    /// Familien-Abgleich läuft ungedrosselt mit. Erfolg ist an
    /// „Letztes Hochladen/Empfangen“ ablesbar (SyncMonitor).
    private func nudgeSync() {
        syncNudgeRunning = true
        syncNudgeDone = false
        let deviceId = DeviceInfo.deviceId
        var descriptor = FetchDescriptor<TrackDay>(
            predicate: #Predicate { $0.deviceId == deviceId },
            sortBy: [SortDescriptor(\TrackDay.dayKey, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let latest = try? context.fetch(descriptor).first {
            latest.updatedAt = Date()
            try? context.save()
        }
        Task {
            await FamilySync.shared.autoSync(force: true)
            await MainActor.run {
                syncNudgeRunning = false
                syncNudgeDone = true
            }
        }
    }

    /// Aufzeichnungen eines (anderen) Geräts überall löschen — die
    /// Löschung synct per iCloud auf alle Geräte.
    private func deleteDevice(_ id: String) {
        let dayPredicate = #Predicate<TrackDay> { $0.deviceId == id }
        let visitPredicate = #Predicate<PlaceVisit> { $0.deviceId == id }
        let tagPredicate = #Predicate<MediaTag> { $0.deviceId == id }
        try? context.delete(model: TrackDay.self, where: dayPredicate)
        try? context.delete(model: PlaceVisit.self, where: visitPredicate)
        try? context.delete(model: MediaTag.self, where: tagPredicate)
        try? context.save()
    }

    private func deleteOwnData() {
        let deviceId = DeviceInfo.deviceId
        let dayPredicate = #Predicate<TrackDay> { $0.deviceId == deviceId }
        let visitPredicate = #Predicate<PlaceVisit> { $0.deviceId == deviceId }
        let tagPredicate = #Predicate<MediaTag> { $0.deviceId == deviceId }
        try? context.delete(model: TrackDay.self, where: dayPredicate)
        try? context.delete(model: PlaceVisit.self, where: visitPredicate)
        try? context.delete(model: MediaTag.self, where: tagPredicate)
        try? context.save()
    }
}
