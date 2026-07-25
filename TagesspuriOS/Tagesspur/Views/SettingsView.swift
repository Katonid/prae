import SwiftUI
import SwiftData
import Photos
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject private var tracker: LocationTracker
    @Environment(\.modelContext) private var context

    @State private var deviceName = DeviceInfo.deviceName
    @State private var photoStatus = PhotoMatcher.authorizationStatus
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Aufzeichnung") {
                    Toggle("Standort aufzeichnen", isOn: $tracker.trackingEnabled)
                    LabeledContent("Standort-Berechtigung", value: locationStatusText)
                    if !tracker.hasAlwaysPermission {
                        Button("Berechtigung anfragen („Immer“ empfohlen)") {
                            tracker.requestPermission()
                        }
                    }
                    Text("Sparsam per Design: präzises GPS nur bei Bewegung, nach 5 Minuten Stillstand Ruhemodus; Besuchs­erkennung läuft dauerhaft mit minimalem Verbrauch.")
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

    private func deleteOwnData() {
        let deviceId = DeviceInfo.deviceId
        let dayPredicate = #Predicate<TrackDay> { $0.deviceId == deviceId }
        let visitPredicate = #Predicate<PlaceVisit> { $0.deviceId == deviceId }
        try? context.delete(model: TrackDay.self, where: dayPredicate)
        try? context.delete(model: PlaceVisit.self, where: visitPredicate)
        try? context.save()
    }
}
