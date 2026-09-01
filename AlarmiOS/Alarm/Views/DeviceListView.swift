//  DeviceListView.swift
//  Which iPads would actually ring.
//
//  The closest this design comes to monitoring. Two things are shown, and the
//  difference between them is the point:
//
//  * When a device last said anything. Red after 48 hours — that is a device
//    nobody should count on, and it is the only silence measure available
//    without a server.
//  * What that device reported about its own permissions at that moment. A
//    device that checks in daily but has notifications switched off is worse
//    than a silent one, because it looks fine in a list of green dots.

import SwiftUI

struct DeviceListView: View {

    @EnvironmentObject private var model: AppModel
    @State private var pinged: Date?

    var body: some View {
        List {
            Section {
                Button {
                    Task {
                        await model.pingAll()
                        pinged = Date()
                        // The answers trickle in over the next seconds; a short
                        // wait before reloading is the difference between "all
                        // silent" and the truth.
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        await model.loadDeviceStatuses()
                    }
                } label: {
                    Label("Alle pingen", systemImage: "dot.radiowaves.left.and.right")
                }
                if let pinged {
                    Text("Gepingt um \(Clock.timeWithSeconds.string(from: pinged)). "
                         + "Geräte, die gerade aus sind, melden sich beim nächsten "
                         + "Start — nicht jetzt.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Geräte") {
                if model.deviceStatuses.isEmpty {
                    Text("Noch keine Meldung.").foregroundStyle(.secondary)
                }
                ForEach(model.deviceStatuses) { status in
                    row(status)
                }
            }
        }
        .navigationTitle("Geräte")
        .refreshable { await model.loadDeviceStatuses() }
        .task { await model.loadDeviceStatuses() }
    }

    private func row(_ status: DeviceStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(status.isSilent() ? Color.red
                          : (status.isFit ? Color.green : Color.orange))
                    .frame(width: 12, height: 12)
                Text(status.displayName).font(.headline)
                Spacer()
                Text(Clock.ago(status.lastSeen))
                    .font(.caption)
                    .foregroundStyle(status.isSilent() ? .red : .secondary)
            }
            Text("\(status.deviceModel) · App \(status.appVersion)")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                flag("Mitteilungen", status.notificationsAuthorized)
                flag("Zeitkritisch", status.timeSensitiveAllowed)
                flag("iCloud", status.iCloudAvailable)
                if model.criticalAlertsBuilt {
                    flag("Kritisch", status.criticalAllowed)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func flag(_ title: String, _ value: Bool) -> some View {
        Label(title, systemImage: value ? "checkmark" : "xmark")
            .font(.caption2)
            .foregroundStyle(value ? .green : .orange)
    }
}

struct DeviceListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DeviceListView().environmentObject(PreviewModels.joined())
        }
    }
}
