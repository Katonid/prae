import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: ProjectStore
    @ObservedObject private var fonts = FontStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var report = ProfileRights.read()
    @State private var photoCounts: (local: Int, cloud: Int, missing: Int)?
    @State private var copied = false
    @State private var copiedFonts = false

    private var cloudBinding: Binding<Bool> {
        Binding(get: { CloudStore.shared.enabled }, set: { store.setCloudEnabled($0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Mit iCloud abgleichen", isOn: cloudBinding)
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: store.cloudActive ? "checkmark.icloud.fill" : "icloud.slash")
                            .foregroundStyle(store.cloudActive ? Color.green : Color.orange)
                        Text(store.cloudMessage)
                            .font(.subheadline)
                    }
                    if let last = store.lastSync {
                        LabeledContent("Zuletzt abgeglichen",
                                       value: last.formatted(date: .omitted, time: .shortened))
                    }
                    if store.cloudActive {
                        Button {
                            Task { await store.syncNow(); countPhotos() }
                        } label: {
                            HStack {
                                Label("Jetzt abgleichen", systemImage: "arrow.triangle.2.circlepath.icloud")
                                if store.syncing { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(store.syncing)
                        if let c = photoCounts {
                            LabeledContent("Fotos auf diesem Gerät", value: "\(c.local)")
                            LabeledContent("Fotos noch in iCloud", value: "\(c.cloud)")
                            if c.missing > 0 {
                                LabeledContent("Fotos fehlen ganz") {
                                    Text("\(c.missing)").foregroundStyle(.red)
                                }
                            }
                        }
                    }
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("Kalender, Fotos und geladene Schriftdateien liegen dann in iCloud Drive im Ordner „Kalenderstudio“ und erscheinen auf deinen anderen Geräten mit derselben Apple-ID. Die Kopie auf diesem Gerät bleibt immer erhalten — Ausschalten löscht nichts. Haben zwei Geräte denselben Kalender gleichzeitig geändert, bleibt die ältere Fassung als eigener Kalender liegen.")
                }

                Section {
                    if let name = report.profileName {
                        LabeledContent("Profil", value: name)
                        ForEach(report.entries) { e in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.title).font(.subheadline.weight(.semibold))
                                Text(e.value.map { "BEWILLIGT als \($0)" } ?? "nicht bewilligt")
                                    .font(.footnote.monospaced())
                                    .foregroundStyle(e.value == nil ? Color.orange : Color.green)
                            }
                        }
                        Button {
                            UIPasteboard.general.string = reportText
                            copied = true
                        } label: {
                            Label(copied ? "Kopiert" : "Befund kopieren", systemImage: "doc.on.doc")
                        }
                    } else {
                        Text("In dieser Fassung liegt kein Signaturprofil (so ist es bei TestFlight, App Store und Simulator). Was bewilligt ist, lässt sich hier deshalb nicht messen.")
                            .font(.footnote)
                    }
                } header: {
                    Text("Einrichtung prüfen")
                } footer: {
                    Text("Liest aus dem Signaturprofil, welche Rechte diese App-Id trägt. Erst wenn hier iCloud und das Schriftenrecht als bewilligt stehen, darf die App sie verlangen — ein Recht, das die App-Id nicht trägt, macht die App unsignierbar (Lehre aus dem Reisebuch).")
                }

                Section {
                    LabeledContent("Schriftenrecht in diesem Bau", value: fontRightText)
                    LabeledContent("Vom System gemeldet",
                                   value: "\(FontStore.systemFund().families.count) Familien")
                    LabeledContent("Eigene Schriften", value: "\(fonts.families.count)")
                    ForEach(fonts.families, id: \.self) { family in
                        HStack {
                            Text(family)
                            Spacer()
                            FontStatusBadge(family: family)
                        }
                    }
                    Button {
                        FontStore.shared.activate()
                    } label: {
                        Label("Neu anmelden", systemImage: "arrow.clockwise")
                    }
                    Button {
                        UIPasteboard.general.string = fontReportText
                        copiedFonts = true
                    } label: {
                        Label(copiedFonts ? "Kopiert" : "Schriftbefund kopieren", systemImage: "doc.on.doc")
                    }
                    ForEach(Array(fonts.protocolLines.suffix(6).reversed().enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Schriften")
                } footer: {
                    Text("Selbst installierte Schriften holt die App beim Start vom System. Fehlen sie im Wähler von iOS, darf dieser Bau sie nicht sehen — dann steht oben beim Schriftenrecht „nicht bewilligt“ oder die installierte Fassung ist älter als 1.0.6. Geladene Schriftdateien kommen über iCloud von selbst mit.")
                }

                Section {
                    LabeledContent("Fassung", value: AppVersion.text)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onAppear { countPhotos() }
        }
    }

    private var fontRightText: String {
        guard report.profileName != nil else { return "nicht messbar" }
        return report.entries.first { $0.key == "com.apple.developer.user-fonts" }?.value ?? "nicht bewilligt"
    }

    private var fontReportText: String {
        let fund = FontStore.systemFund()
        var lines = ["Kalenderstudio \(AppVersion.text) — Schriften",
                     "Schriftenrecht: \(fontRightText)",
                     "System meldet \(fund.raw) Einträge, lesbar \(fund.descriptors.count), "
                        + "Familien: \(fund.families.joined(separator: ", "))",
                     "Eigene Schriften: \(fonts.families.joined(separator: ", "))",
                     "Gewählte Schnitte: \(fonts.faces.joined(separator: ", "))"]
        for f in fonts.families {
            lines.append("  \(f): " + (fonts.isAvailable(f) ? "auffindbar" : "NICHT auffindbar"))
        }
        lines.append("Protokoll:")
        lines += fonts.protocolLines.suffix(15)
        return lines.joined(separator: "\n")
    }

    private var reportText: String {
        var lines = ["Kalenderstudio \(AppVersion.text) — Einrichtung prüfen",
                     "Profil: \(report.profileName ?? "keines")"]
        for e in report.entries {
            lines.append("\(e.title) (\(e.key)): \(e.value.map { "BEWILLIGT als \($0)" } ?? "nicht bewilligt")")
        }
        lines.append("iCloud: \(store.cloudMessage)")
        return lines.joined(separator: "\n")
    }

    private func countPhotos() {
        let ids = Set(store.projects.flatMap { $0.photos.map(\.id) })
        Task.detached(priority: .utility) {
            var local = 0, cloud = 0, missing = 0
            for id in ids {
                switch ImageStore.shared.state(id) {
                case .local: local += 1
                case .downloading: cloud += 1
                case .missing: missing += 1
                }
            }
            let result = (local: local, cloud: cloud, missing: missing)
            await MainActor.run { photoCounts = result }
        }
    }
}

/// Kurzer Befund zu einer Schrift: fehlt sie, darf sie nicht eingebettet werden?
struct FontStatusBadge: View {
    let family: String

    var body: some View {
        switch FontLicense.check(family: family) {
        case .allowed:
            EmptyView()
        case .unknown:
            Label("Einbettung unbekannt", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .restricted:
            Label("darf nicht ins PDF", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .unavailable:
            Label("auf diesem Gerät nicht verfügbar", systemImage: "xmark.circle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}

/// Die Fassung sichtbar in der App — sonst lässt sich ein Befund keinem
/// Stand zuordnen (Lehre aus dem Reisebuch 1.0.101).
enum AppVersion {
    static var text: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
