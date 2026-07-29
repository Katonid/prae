import SwiftUI
import SwiftData

/// Hauptansicht der Watch-App: Tages-km, eigene Aufzeichnung
/// (Workout-Session) und Fernbedienung fürs iPhone.
struct WatchHomeView: View {
    @EnvironmentObject private var recorder: WatchRecorder
    @EnvironmentObject private var phone: PhoneLink
    @Environment(\.modelContext) private var context
    @Query private var days: [TrackDay]

    /// Tages-km über alle Geräte, die per CloudKit schon da sind —
    /// mindestens aber der zuletzt vom iPhone gemeldete Stand.
    private var todayKilometers: Double {
        let key = DayKey.key(for: Date())
        let synced = days.filter { $0.dayKey == key }.reduce(0) { $0 + $1.distanceMeters }
        return max(synced, phone.phoneDistanceMeters) / 1000
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.1f km", todayKilometers))
                            .font(.system(.title2, design: .rounded).bold())
                        Text("Heute")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    recordButton

                    if recorder.isRecording {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.2f km aufgezeichnet", recorder.distanceMeters / 1000))
                                .font(.footnote)
                            if let start = recorder.startedAt {
                                Text(start, style: .timer)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !recorder.statusText.isEmpty {
                        Text(recorder.statusText)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    Divider()

                    phoneSection
                }
            }
            .navigationTitle("Tagesspur")
        }
        .task {
            WatchWidgetBridge.update(container: context.container, isRecording: recorder.isRecording)
        }
    }

    private var recordButton: some View {
        Button {
            if recorder.isRecording {
                recorder.stop()
            } else {
                recorder.start()
            }
        } label: {
            Label(
                recorder.isRecording ? "Weg beenden" : "Weg starten",
                systemImage: recorder.isRecording ? "stop.circle.fill" : "record.circle"
            )
        }
        .tint(recorder.isRecording ? .red : .green)
    }

    private var phoneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("iPhone")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let tracking = phone.trackingEnabled {
                Toggle("Aufzeichnung", isOn: Binding(
                    get: { tracking },
                    set: { phone.setTracking($0) }
                ))
                Toggle("Hohe Genauigkeit", isOn: Binding(
                    get: { phone.highAccuracy ?? false },
                    set: { phone.setHighAccuracy($0) }
                ))
            } else {
                Text("Noch kein Status vom iPhone — dort einmal Tagesspur öffnen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
