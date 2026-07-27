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
            let baseName = list.first?.deviceName ?? "Gerät"
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

    var body: some View {
        NavigationStack {
            Form {
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

                Section("Aufzeichnung") {
                    Toggle("Standort aufzeichnen", isOn: $tracker.trackingEnabled)
                    Toggle("Hohe Genauigkeit", isOn: $tracker.highAccuracy)
                    LabeledContent("Standort-Berechtigung", value: locationStatusText)
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

                Section("iCloud-Sync (eigene Geräte)") {
                    LabeledContent("Datenbank",
                                   value: SyncDiagnose.cloudKitAktiv ? "iCloud-Sync aktiv" : "NUR LOKAL — kein Sync")
                    LabeledContent("iCloud-Konto", value: accountStatusText)
                    ForEach(deviceSummaries) { summary in
                        LabeledContent(summary.name) {
                            VStack(alignment: .trailing) {
                                Text("\(summary.dayCount) Tage")
                                Text("Stand \(summary.latest.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text("Hier müssen alle deine Geräte mit Tagen auftauchen. Voraussetzungen: gleiche Apple-ID, iCloud für Tagesspur erlaubt (iOS-Einstellungen → Apple-ID → iCloud → „Alle anzeigen“). Wichtig: Direkt über Xcode installierte Builds syncen in der CloudKit-ENTWICKLUNGSUMGEBUNG, TestFlight-/App-Store-Builds in der PRODUKTIONSUMGEBUNG — die beiden Welten sehen einander nicht. Alle Geräte (auch die der Familie) müssen dieselbe Installationsart nutzen. Der erste Abgleich kann einige Minuten dauern und braucht die App einmal geöffnet auf jedem Gerät.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Dieses Gerät") {
                    TextField("Gerätename", text: $deviceName)
                        .onChange(of: deviceName) { _, newValue in
                            DeviceInfo.deviceName = newValue
                        }
                    Text("Jedes Gerät speichert seine eigenen Aufzeichnungen; über iCloud siehst du alle Geräte gemeinsam. Der Name hilft beim Auseinanderhalten.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Daten") {
                    Button("Aufzeichnungen dieses Geräts löschen", role: .destructive) {
                        confirmDelete = true
                    }
                }
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
