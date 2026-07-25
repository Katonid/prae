import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Export (GPX/JSON) für einen Tag, einen Zeitraum oder alles —
/// sowie Import von GPX-Dateien und Tagesspur-Backups.
struct ExportView: View {
    private enum ScopeChoice: String, CaseIterable, Identifiable {
        case day = "Ein Tag"
        case range = "Zeitraum"
        case all = "Alles"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \TrackDay.dayKey, order: .reverse) private var days: [TrackDay]

    @State private var scopeChoice: ScopeChoice = .day
    @State private var format: Exporter.Format = .gpx
    @State private var selectedDay = Date()
    @State private var rangeStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var rangeEnd = Date()
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Export") {
                    Picker("Umfang", selection: $scopeChoice) {
                        ForEach(ScopeChoice.allCases) { choice in
                            Text(choice.rawValue).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch scopeChoice {
                    case .day:
                        DatePicker("Tag", selection: $selectedDay, displayedComponents: .date)
                    case .range:
                        DatePicker("Von", selection: $rangeStart, displayedComponents: .date)
                        DatePicker("Bis", selection: $rangeEnd, displayedComponents: .date)
                    case .all:
                        LabeledContent("Aufgezeichnete Tage", value: "\(Set(days.map(\.dayKey)).count)")
                    }

                    Picker("Format", selection: $format) {
                        ForEach(Exporter.Format.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(format == .gpx
                         ? "GPX ist mit Karten- und Sport-Apps breit kompatibel (Tracks + Aufenthalte als Wegpunkte)."
                         : "JSON ist das verlustfreie Tagesspur-Backup — ideal für Umzug und Wiederherstellung.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        doExport()
                    } label: {
                        Label("Exportdatei erstellen", systemImage: "square.and.arrow.up")
                    }

                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("„\(exportURL.lastPathComponent)“ teilen", systemImage: "shareplay")
                        }
                    }
                }

                Section("Import") {
                    Button {
                        showImporter = true
                    } label: {
                        Label("GPX oder Tagesspur-Backup importieren", systemImage: "square.and.arrow.down")
                    }
                    Text("Vorhandene Punkte werden zusammengeführt, nichts wird doppelt angelegt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let message {
                    Section {
                        Text(message).font(.footnote)
                    }
                }
            }
            .navigationTitle("Export & Import")
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: importTypes,
                allowsMultipleSelection: false
            ) { result in
                doImport(result)
            }
        }
    }

    private var importTypes: [UTType] {
        var types: [UTType] = [.json, .xml]
        if let gpx = UTType(filenameExtension: "gpx") {
            types.append(gpx)
        }
        return types
    }

    private var scope: Exporter.Scope {
        switch scopeChoice {
        case .day:
            return .day(DayKey.key(for: selectedDay))
        case .range:
            let from = min(rangeStart, rangeEnd)
            let to = max(rangeStart, rangeEnd)
            return .range(DayKey.key(for: from), DayKey.key(for: to))
        case .all:
            return .all
        }
    }

    private func doExport() {
        do {
            exportURL = try Exporter.export(scope: scope, format: format, context: context)
            message = nil
        } catch {
            exportURL = nil
            message = "Export fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func doImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let imported = try Exporter.importFile(at: url, context: context)
            message = "Import: \(imported.importedPoints) Punkte, \(imported.importedDays) neue Tage, \(imported.importedVisits) Aufenthalte."
        } catch {
            message = "Import fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}
