//
//  ArchivView.swift
//  FlightMate
//
//  Drone Media Explorer — Archiv-Übersicht (M2): Katalogstand mit
//  Zugang zur Bibliothek, Import aus Apple Fotos (System-Picker)
//  und Ordner-Quellen (DJI-Fly-Ablage, SD-Karte, beliebige Ordner)
//  mit automatischem Differenz-Scan bei jedem Öffnen. Ehrliche
//  Statusanzeige: Sync-Zustand, Scan-Fortschritt, Ergebnis.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Absturz-Sicherung ums Archiv: Vor dem Öffnen des Katalogs wird
/// eine Wächter-Flagge gesetzt und nach sauberem Verlassen gelöscht.
/// Steht sie beim nächsten Öffnen noch (= die App ist mit offenem
/// Archiv gestorben), erscheint zuerst ein Wiederherstellungs-
/// Bildschirm mit der Option, den Katalog zurückzusetzen — ein
/// beschädigter Katalog kann die App so nie dauerhaft lahmlegen.
struct ArchivView: View {
    @AppStorage("archivOpenGuard") private var openGuard = false
    @State private var started = false

    var body: some View {
        NavigationStack {
            if started {
                ArchivHomeView()
            } else if openGuard {
                recoveryView
            } else {
                Color.clear.onAppear { start() }
            }
        }
    }

    private func start() {
        openGuard = true
        _ = ArchivStore.shared
        started = true
    }

    private var recoveryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bandage")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Das Archiv wurde beim letzten Mal nicht sauber beendet")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Vermutlich ein Absturz (z. B. beim Import). Du kannst es normal erneut versuchen — oder den Katalog zurücksetzen, falls es wiederholt hakt. Beim Zurücksetzen gehen nur Katalog-Daten (Bewertungen, Schlagworte) verloren; deine Originale bleiben unberührt und werden beim nächsten Scan neu importiert.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                start()
            } label: {
                Label("Archiv normal öffnen", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button(role: .destructive) {
                ArchivStore.destroyStoreFiles()
                start()
            } label: {
                Label("Katalog zurücksetzen und öffnen", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(maxWidth: 480)
    }
}

private struct ArchivHomeView: View {
    @ObservedObject private var store = ArchivStore.shared
    @ObservedObject private var importer = ImportCoordinator.shared
    @State private var sources: [ConnectedSource] = []
    @State private var showFolderPicker = false
    @State private var pickerError: String?
    @State private var photoItems: [PhotosPickerItem] = []
    @AppStorage("archivOpenGuard") private var openGuard = false

    var body: some View {
        Group {
            if let container = store.container {
                content
                    .modelContainer(container)
            } else {
                ContentUnavailableView("Katalog nicht verfügbar",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text(store.statusText))
            }
        }
        // Katalog hat sich sauber geöffnet → Wächter lösen. Während
        // eines Imports setzt der ImportCoordinator ihn erneut —
        // die beiden echten Absturz-Fenster sind damit abgedeckt.
        .onAppear { openGuard = false }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                statusCard
                importCard
                sourcesCard
                roadmapCard
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle("Archiv")
        .onAppear {
            sources = BookmarkStore.all()
            // Automatik (Kap. 6): Differenz-Scan bei jedem Öffnen —
            // unveränderte Dateien kosten dabei praktisch nichts.
            Task { await importer.scanFolderSources() }
        }
        .fileImporter(isPresented: $showFolderPicker,
                      allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                do {
                    try BookmarkStore.add(url: url, label: url.lastPathComponent)
                    sources = BookmarkStore.all()
                    Task { await importer.scanFolderSources() }
                } catch {
                    pickerError = "Der Ordner konnte nicht gemerkt werden: \(error.localizedDescription)"
                }
            case .failure:
                break
            }
        }
        .onChange(of: photoItems) {
            guard !photoItems.isEmpty else { return }
            let items = photoItems
            photoItems = []
            Task { await importer.importPhotoItems(items) }
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
            NavigationLink {
                ArchivLibraryView()
            } label: {
                HStack {
                    Label("Bibliothek öffnen", systemImage: "photo.stack")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
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

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Importieren", systemImage: "square.and.arrow.down")
                .font(.subheadline.bold())
            if importer.isRunning {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(importer.progressText.isEmpty ? "Import läuft …" : importer.progressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                PhotosPicker(selection: $photoItems,
                             matching: .any(of: [.images, .videos]),
                             photoLibrary: .shared()) {
                    Label("Aus Apple Fotos wählen", systemImage: "photo.on.rectangle.angled")
                }
                .font(.subheadline)
                Button {
                    Task { await importer.scanFolderSources() }
                } label: {
                    Label("Ordner-Quellen jetzt scannen", systemImage: "arrow.clockwise")
                }
                .font(.subheadline)
                .disabled(sources.isEmpty)
            }
            if let summary = importer.lastSummary {
                Label(summary, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Doppelte Inhalte werden erkannt (Inhalts-Hash) und nur als weiterer Fundort vermerkt — nie doppelt importiert.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .flightCard(cornerRadius: 16)
    }

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Verbundene Quellen", systemImage: "externaldrive.connected.to.line.below")
                .font(.subheadline.bold())
            if sources.isEmpty {
                Text("Noch keine Ordner-Quelle verbunden. Verbinde z. B. die DJI-Fly-Ablage (Dateien-App → „Auf meinem iPhone“ → DJI Fly), eine SD-Karte oder einen beliebigen Ordner — verbundene Quellen scannt das Archiv bei jedem Öffnen automatisch auf neue Aufnahmen.")
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
                                    ?? "bereit")
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
            Text("M2 (jetzt): Import aus Apple Fotos und Ordner-Quellen mit vollständigen Metadaten, Bibliothek mit Detail-Ansicht. M3: Orte für Videos (Flight-Log-Kaskade), Flugrouten und die Medien-Karte. M4: Reisen, Spots und bearbeitete Versionen. M5: lokale KI-Suche.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .flightCard(cornerRadius: 16)
    }
}
