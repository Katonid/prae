import SwiftUI
import SwiftData
import Photos
import CoreLocation

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
                    if !tracker.hasAlwaysPermission {
                        Button("Berechtigung anfragen („Immer“ empfohlen)") {
                            tracker.requestPermission()
                        }
                    }
                    Text("Ausgewogen (Standard): präzises GPS bei Bewegung; nach 5 Minuten Stillstand grober Ruhemodus, der Bewegungsbeginn sofort selbst erkennt. „Hohe Genauigkeit“ zeichnet dauerhaft präzise auf — bestes Trackbild, spürbar mehr Akkuverbrauch.")
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
