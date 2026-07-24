//
//  ArchivView.swift
//  FlightMate
//
//  Drone Media Explorer, M1: Das Archiv-Fundament sichtbar gemacht —
//  Katalogstand, Sync-Status (ehrlich: CloudKit aktiv oder lokal)
//  und die verbundenen Ordner-Quellen (DJI Fly, SD-Karte, Ordner).
//  Der eigentliche Import folgt in M2; Quellen lassen sich aber
//  schon jetzt verbinden, damit M2 sofort losscannen kann.
//

import SwiftUI
import UniformTypeIdentifiers

struct ArchivView: View {
    @ObservedObject private var store = ArchivStore.shared
    @State private var sources: [ConnectedSource] = []
    @State private var showFolderPicker = false
    @State private var pickerError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    sourcesCard
                    roadmapCard
                }
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("Archiv")
            .onAppear { sources = BookmarkStore.all() }
            .fileImporter(isPresented: $showFolderPicker,
                          allowedContentTypes: [.folder]) { result in
                switch result {
                case .success(let url):
                    do {
                        try BookmarkStore.add(url: url, label: url.lastPathComponent)
                        sources = BookmarkStore.all()
                    } catch {
                        pickerError = "Der Ordner konnte nicht gemerkt werden: \(error.localizedDescription)"
                    }
                case .failure:
                    break
                }
            }
            .alert("Quelle verbinden", isPresented: Binding(
                get: { pickerError != nil },
                set: { if !$0 { pickerError = nil } }
            )) {
                Button("OK") { pickerError = nil }
            } message: {
                Text(pickerError ?? "")
            }
        }
    }

    private var statusCard: some View {
        let counts = store.counts()
        return VStack(alignment: .leading, spacing: 10) {
            Label("Medien-Katalog", systemImage: "archivebox")
                .font(.subheadline.bold())
            HStack(spacing: 20) {
                statTile("\(counts.photos)", "Fotos")
                statTile("\(counts.videos)", "Videos")
                statTile("\(counts.versions)", "Versionen")
            }
            Label(store.statusText,
                  systemImage: store.cloudSyncActive ? "icloud" : "icloud.slash")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Grundprinzip: Originale werden nie verändert — alles lebt im Katalog.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .flightCard(cornerRadius: 16)
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Verbundene Quellen", systemImage: "externaldrive.connected.to.line.below")
                .font(.subheadline.bold())
            if sources.isEmpty {
                Text("Noch keine Ordner-Quelle verbunden. Verbinde z. B. die DJI-Fly-Ablage (Dateien-App → „Auf meinem iPhone“ → DJI Fly), eine SD-Karte oder einen beliebigen Ordner — der Import startet mit dem nächsten Ausbauschritt (M2) automatisch bei jedem App-Start.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sources) { source in
                    let available = BookmarkStore.resolve(source) != nil
                    HStack {
                        Image(systemName: available ? "folder" : "folder.badge.questionmark")
                            .foregroundStyle(available ? Color.accentColor : .orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(source.label)
                                .font(.subheadline)
                            Text(available
                                 ? (source.lastScanAt.map { "zuletzt gescannt \(Theme.time($0)) Uhr" }
                                    ?? "bereit — Scan kommt mit M2")
                                 : "zurzeit nicht verfügbar (Karte ausgeworfen / Ordner weg?)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            BookmarkStore.remove(source)
                            sources = BookmarkStore.all()
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            Button {
                showFolderPicker = true
            } label: {
                Label("Ordner-Quelle verbinden", systemImage: "plus")
            }
            .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .flightCard(cornerRadius: 16)
    }

    private var roadmapCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("So geht es weiter", systemImage: "map")
                .font(.subheadline.bold())
            Text("M1 (dieses Fundament): Katalog mit iCloud-Sync, Dedupe und Quellen-Verwaltung. M2: Import aus Apple Fotos, DJI-Fly-Ordner und SD-Karte mit vollständigen Metadaten. M3: Orte, Flugrouten und Karte. M4: Reisen, Spots und bearbeitete Versionen. M5: lokale KI-Suche.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .flightCard(cornerRadius: 16)
    }
}
