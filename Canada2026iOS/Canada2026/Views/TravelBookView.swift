import SwiftUI

// STAN Roadbook – Reisebuch-Export als PDF und JSON, wie in der PWA.

struct TravelBookView: View {
    @EnvironmentObject private var store: AppStore

    @State private var includeJournal = true
    @State private var includePhotos = true
    @State private var includeStats = true
    @State private var includeAwards = true
    @State private var generatedPDF: URL?
    @State private var generating = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("STAN Roadbook")
                        .font(.headline)
                    Text("Das Reisebuch fasst Route, Journal, Fotos, Awards und die Statistik der Reise in einem PDF zusammen – zum Teilen, Drucken oder Archivieren.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Inhalt") {
                Toggle("Reisejournal", isOn: $includeJournal)
                Toggle("Fotoalbum", isOn: $includePhotos)
                Toggle("Canada Awards", isOn: $includeAwards)
                Toggle("Statistik & Bucket List", isOn: $includeStats)
            }

            Section("PDF") {
                Button {
                    generate()
                } label: {
                    if generating {
                        HStack {
                            ProgressView()
                            Text("PDF wird erstellt ...")
                        }
                    } else {
                        Label("Roadbook-PDF erstellen", systemImage: "doc.richtext")
                    }
                }
                .disabled(generating)

                if let generatedPDF {
                    ShareLink(item: generatedPDF) {
                        Label("Roadbook teilen / sichern", systemImage: "square.and.arrow.up")
                    }
                }
            }

            Section("Daten") {
                if let exportURL = store.exportFileURL() {
                    ShareLink(item: exportURL) {
                        Label("Rohdaten als JSON exportieren", systemImage: "curlybraces.square")
                    }
                }
                Text("Das JSON enthält alle synchronisierten Inhalte und eignet sich als vollständiges Backup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("STAN Roadbook")
    }

    private func generate() {
        generating = true
        generatedPDF = nil
        // Kurze Pause, damit der Fortschrittszustand sichtbar gerendert wird;
        // die PDF-Erzeugung selbst läuft auf dem Main-Actor (Store-Zugriff).
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            let builder = RoadbookPDF(store: store)
            var options = RoadbookPDF.Options()
            options.includeJournal = includeJournal
            options.includePhotos = includePhotos
            options.includeStats = includeStats
            options.includeAwards = includeAwards
            generatedPDF = builder.generate(options: options)
            generating = false
        }
    }
}
