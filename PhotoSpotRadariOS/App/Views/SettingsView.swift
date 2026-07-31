import SwiftUI
import PhotoSpotCore

struct SettingsView: View {
    @Bindable var settings: SettingsManager
    @Bindable var viewModel: RadarViewModel
    let locationManager: LocationManager
    let notificationManager: NotificationManager
    let imageService: ImageService
    @State private var permissionMessage: String?
    @State private var flickrAPIKey = FlickrAPIKeyStore.load() ?? ""
    @State private var flickrMessage: String?
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Darstellung") {
                    Picker("Erscheinungsbild", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Kartenhelligkeit", selection: $settings.mapColorScheme) {
                        Text("Wie App").tag(AppAppearance.system)
                        Text("Hell").tag(AppAppearance.light)
                        Text("Dunkel").tag(AppAppearance.dark)
                    }
                    Text("Das Erscheinungsbild gilt für die ganze App; die Kartenhelligkeit übersteuert es nur für die Karte (auch direkt im Ebenen-Menü der Karte umschaltbar).")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Ergebnis-Relevanz") {
                    Picker("Auswahl der Orte", selection: $settings.relevanceLevel) {
                        ForEach(SpotRelevanceLevel.allCases, id: \.self) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    Text(settings.relevanceLevel.footnote)
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Kanada-Reisemodus") {
                    Toggle("Reisemodus aktiv", isOn: $settings.travelModeEnabled)
                    TextField("Start, z. B. Toronto, Ontario", text: $settings.tripStart)
                    TextField("Ziel, z. B. Ottawa, Ontario", text: $settings.tripDestination)
                    Button {
                        Task { await viewModel.prepareTrip() }
                    } label: {
                        if viewModel.isPreparingTrip {
                            Label("Route wird vorbereitet …", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                        } else {
                            Label("Route über WLAN vorbereiten", systemImage: "arrow.down.map")
                        }
                    }
                    .disabled(viewModel.isPreparingTrip)
                    Toggle("Live-Daten unterwegs nachladen", isOn: $settings.liveTravelRefreshEnabled)
                    Text("Ausgeschaltet arbeitet die App unterwegs nur mit dem vorbereiteten Offline-Bestand und verbraucht für Spots keine mobilen Daten.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let progress = viewModel.tripPreparationProgress {
                        Text(progress).font(.footnote)
                    }
                    if let preparedAt = settings.tripPreparedAt {
                        LabeledContent("Zuletzt vorbereitet", value: preparedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                Section("Radar") {
                    Picker("Benachrichtigungsradius", selection: $settings.radius) {
                        ForEach(SettingsManager.supportedRadii, id: \.self) { radius in
                            Text(Measurement(value: Double(radius), unit: UnitLength.meters)
                                .formatted(.measurement(width: .abbreviated, usage: .road))).tag(radius)
                        }
                    }
                    Toggle("Benachrichtigungen", isOn: $settings.notificationsEnabled)
                    Toggle("Nur bekannte Sehenswürdigkeiten melden", isOn: $settings.famousOnlyNotifications)
                        .disabled(!settings.notificationsEnabled)
                    Text("Eingeschaltet melden sich nur Orte mit belegter Bekanntheit (Wikipedia-/Wikidata-/Denkmal-Eintrag mit Foto) – nicht jeder Aussichtspunkt am Weg.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Toggle("Nur nicht besuchte Spots", isOn: $settings.unvisitedOnly)
                    Toggle("Nur Spots mit Bildern", isOn: $settings.imagesOnly)
                    Picker("Motive", selection: $settings.themeFilter) {
                        ForEach(SpotThemeFilter.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Besuche automatisch erkennen", isOn: $settings.autoMarkVisited)
                    LabeledContent("Mindest-SpotScore", value: "\(settings.minimumScore)")
                    Slider(value: Binding(get: { Double(settings.minimumScore) }, set: { settings.minimumScore = Int($0) }), in: 0...100, step: 5)
                    LabeledContent("Mindestbewertung", value: settings.minimumRating == 0 ? "Aus" : String(format: "%.1f / 5", settings.minimumRating))
                    Slider(value: $settings.minimumRating, in: 0...5, step: 0.5)
                }
                Section("Offline & Bilder") {
                    Toggle("Bilder nur über WLAN", isOn: $settings.wifiOnlyImages)
                    Picker("Bildqualität", selection: $settings.imageQuality) {
                        ForEach(ImageQuality.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("Cache: \(settings.cacheSizeMB) MB", value: $settings.cacheSizeMB, in: 64...2_048, step: 64)
                    Button("Cache auf Limit reduzieren") { Task { await imageService.trim(toMegabytes: settings.cacheSizeMB) } }
                }
                Section("Flickr-Entdeckung") {
                    Toggle("Flickr als zusätzliche Quelle", isOn: $settings.flickrDiscoveryEnabled)
                        .disabled(flickrAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Toggle("Nur Flickr-Ergebnisse anzeigen", isOn: $settings.flickrOnlyResults)
                        .disabled(!settings.flickrDiscoveryEnabled)
                    SecureField("Flickr API Key", text: $flickrAPIKey)
                        .textContentType(.password)
                    Button("API-Schlüssel sicher speichern") {
                        do {
                            try FlickrAPIKeyStore.save(flickrAPIKey)
                            if flickrAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                settings.flickrDiscoveryEnabled = false
                            }
                            flickrMessage = "Der API-Schlüssel wurde im iOS-Schlüsselbund gespeichert."
                        } catch { flickrMessage = error.localizedDescription }
                    }
                    Button("Flickr-Verbindung prüfen") {
                        flickrMessage = "Verbindung wird geprüft …"
                        Task { flickrMessage = await FlickrService().connectionStatus() }
                    }
                    .disabled(flickrAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Flickr-Suche am aktuellen Punkt prüfen") {
                        flickrMessage = "Flickr-Suche wird geprüft …"
                        Task {
                            flickrMessage = await FlickrService().searchDiagnosis(
                                near: viewModel.referencePoint, radius: settings.radius
                            )
                        }
                    }
                    .disabled(!settings.flickrDiscoveryEnabled)
                    LabeledContent("Geladene Flickr-Treffer",
                                   value: "\(viewModel.spots.filter { $0.sourceName.hasPrefix("Flickr") }.count)")
                    Link("Eigenen Flickr-API-Schlüssel beantragen",
                         destination: URL(string: "https://www.flickr.com/services/apps/create/")!)
                    Text("Es werden nur öffentliche, georeferenzierte Fotos mit Natur- oder Architekturbezug berücksichtigt. Flickr bleibt optional.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let flickrMessage { Text(flickrMessage).font(.footnote) }
                    Text("Dieses Produkt verwendet die Flickr-API, wird aber nicht von SmugMug, Inc. unterstützt oder zertifiziert.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Gespeicherte Ergebnisse") {
                    Button("Suchergebnisse leeren", systemImage: "trash", role: .destructive) {
                        showClearConfirmation = true
                    }
                    Text("Entfernt alle geladenen Spots. Favoriten und besuchte Orte bleiben erhalten. Eine neue Suche ersetzt Treffer im Suchgebiet außerdem automatisch.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Datenquellen") {
                    Text("Kartendaten: © OpenStreetMap-Mitwirkende (ODbL)")
                        .font(.footnote).foregroundStyle(.secondary)
                    Link("OpenStreetMap-Lizenz ansehen",
                         destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                    Text("Texte und Bilder aus Wikipedia, Wikidata und Wikimedia Commons behalten ihre jeweilige Lizenz; die Originalquelle ist in jeder Detailansicht verlinkt. Motive von Flickr-Fotos können vom eigentlichen Spot abweichen.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Berechtigungen") {
                    Button("Standortzugriff einrichten") { locationManager.requestAuthorization() }
                    Button("Mitteilungen erlauben") {
                        Task {
                            do { permissionMessage = try await notificationManager.requestAuthorization() ? "Mitteilungen sind erlaubt." : "Mitteilungen wurden nicht erlaubt." }
                            catch { permissionMessage = error.localizedDescription }
                        }
                    }
                    if let permissionMessage { Text(permissionMessage).font(.footnote).foregroundStyle(.secondary) }
                }
                Section("Energie") {
                    Text("PhotoSpot Radar verwendet keine dauerhafte GPS-Ortung. Das System weckt die App bei signifikanten Ortsänderungen, Visits oder überwachten Regionen.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Über diese App") {
                    LabeledContent("Version", value: Self.appVersion)
                    LabeledContent("Build", value: Self.buildNumber)
                }
            }.navigationTitle("Einstellungen")
        }
        .onChange(of: settings.cacheSizeMB) { _, size in
            Task { await imageService.setLimit(megabytes: size) }
        }
        .onChange(of: settings.wifiOnlyImages) { _, wifiOnly in
            Task { await imageService.setWiFiOnly(wifiOnly) }
        }
        .onChange(of: settings.flickrDiscoveryEnabled) { _, enabled in
            if !enabled { settings.flickrOnlyResults = false }
        }
        .confirmationDialog("Alle geladenen Suchergebnisse löschen?", isPresented: $showClearConfirmation,
                            titleVisibility: .visible) {
            Button("Suchergebnisse leeren", role: .destructive) { viewModel.clearSearchResults() }
        } message: {
            Text("Favoriten und besuchte Orte bleiben erhalten.")
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }
    private static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
    }
}
