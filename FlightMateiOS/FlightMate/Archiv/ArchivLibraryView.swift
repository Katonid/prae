//
//  ArchivLibraryView.swift
//  FlightMate
//
//  Drone Media Explorer, M2: die Bibliothek. Gitter aller
//  Katalog-Medien (neueste zuerst) mit Vorschau, Filter
//  Fotos/Videos, Mehrfach-Fundort-Kennzeichnung — und eine
//  Detail-Seite, die ALLES zeigt: strukturierte Metadaten, Fundorte,
//  Ort samt Quelle+Vertrauensgrad und die kompletten Roh-Metadaten.
//  Favorit, Bewertung, Notizen und Schlagworte leben im Katalog,
//  nie in der Datei.
//

import SwiftUI
import SwiftData
import CoreLocation

struct ArchivLibraryView: View {
    // Bewusst KEIN @Query: Die Bibliothek holt ihre Daten direkt aus
    // demselben Katalog-Store wie die Zählung der Übersicht — damit
    // kann keine fehlende Umgebungs-Weitergabe je wieder zu „Katalog
    // zählt 1, Bibliothek ist leer" führen (Nutzermeldung).
    @State private var assets: [MediaAsset] = []
    @State private var filter: String = "alle"
    @ObservedObject private var importer = ImportCoordinator.shared
    // Löschen (nur Katalogeintrag — Originale bleiben unberührt):
    // einzeln per Kontextmenü, im Block per Auswählen-Modus.
    @State private var selecting = false
    @State private var selection = Set<UUID>()
    @State private var pendingDelete: [MediaAsset] = []
    @State private var confirmDelete = false

    private var filtered: [MediaAsset] {
        switch filter {
        case MediaKind.photo.rawValue: return assets.filter { $0.kind == .photo }
        case MediaKind.video.rawValue: return assets.filter { $0.kind == .video }
        default: return assets
        }
    }

    private func reload() {
        guard let container = ArchivStore.shared.container else { return }
        let descriptor = FetchDescriptor<MediaAsset>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
        assets = (try? container.mainContext.fetch(descriptor)) ?? []
    }

    var body: some View {
        Group {
            if assets.isEmpty {
                ContentUnavailableView(
                    "Bibliothek ist leer",
                    systemImage: "photo.stack",
                    description: Text("Verbinde im Archiv eine Ordner-Quelle oder importiere aus Apple Fotos — dann erscheinen deine Aufnahmen hier.")
                )
            } else {
                ScrollView {
                    Picker("Filter", selection: $filter) {
                        Text("Alle (\(assets.count))").tag("alle")
                        Text("Fotos").tag(MediaKind.photo.rawValue)
                        Text("Videos").tag(MediaKind.video.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 3)],
                              spacing: 3) {
                        ForEach(filtered) { asset in
                            if selecting {
                                Button {
                                    if selection.contains(asset.id) {
                                        selection.remove(asset.id)
                                    } else {
                                        selection.insert(asset.id)
                                    }
                                } label: {
                                    cell(asset)
                                        .overlay(alignment: .topLeading) {
                                            Image(systemName: selection.contains(asset.id)
                                                  ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(.white, .blue)
                                                .shadow(radius: 2)
                                                .padding(5)
                                        }
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    ArchivAssetDetailView(asset: asset)
                                } label: {
                                    cell(asset)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        pendingDelete = [asset]
                                        confirmDelete = true
                                    } label: {
                                        Label("Aus dem Katalog entfernen", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 3)
                }
            }
        }
        .navigationTitle("Bibliothek")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !assets.isEmpty {
                    Button(selecting ? "Fertig" : "Auswählen") {
                        selecting.toggle()
                        if !selecting { selection.removeAll() }
                    }
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                if selecting {
                    Button(role: .destructive) {
                        pendingDelete = assets.filter { selection.contains($0.id) }
                        confirmDelete = true
                    } label: {
                        Label("Entfernen (\(selection.count))", systemImage: "trash")
                    }
                    .disabled(selection.isEmpty)
                    Spacer()
                    Text("Originale bleiben unberührt")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog(
            pendingDelete.count == 1
                ? "Diesen Eintrag aus dem Katalog entfernen?"
                : "\(pendingDelete.count) Einträge aus dem Katalog entfernen?",
            isPresented: $confirmDelete, titleVisibility: .visible
        ) {
            Button("Aus dem Katalog entfernen", role: .destructive) {
                ArchivStore.shared.delete(pendingDelete)
                pendingDelete = []
                selection.removeAll()
                selecting = false
                reload()
            }
            Button("Abbrechen", role: .cancel) { pendingDelete = [] }
        } message: {
            Text("Entfernt werden nur Katalog-Daten (Metadaten, Bewertung, Vorschau) — die Originaldateien bleiben unberührt. Über den Fotos-Import jederzeit wieder aufnehmbar; Ordner-Funde erst nach einem Katalog-Reset erneut automatisch.")
        }
        .onAppear { reload() }
        // Nach einem Import (isRunning kippt auf false) auffrischen.
        .onChange(of: importer.isRunning) { _, running in
            if !running { reload() }
        }
    }

    private func cell(_ asset: MediaAsset) -> some View {
        ZStack {
            if let thumb = ThumbnailStore.thumbnail(for: asset.contentHash) {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                Image(systemName: asset.kind == .video ? "video" : "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 4) {
                if asset.kind == .video {
                    Label(durationText(asset), systemImage: "video.fill")
                        .labelStyle(.titleAndIcon)
                }
                if asset.favorite {
                    Image(systemName: "heart.fill")
                }
            }
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .shadow(radius: 2)
            .padding(4)
        }
        .overlay(alignment: .topTrailing) {
            if (asset.files?.count ?? 0) > 1 {
                Text("\(asset.files?.count ?? 0) Fundorte")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.55), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(3)
            }
        }
    }

    private func durationText(_ asset: MediaAsset) -> String {
        guard let seconds = asset.videoMeta?.durationS, seconds > 0 else { return "" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: Detail — alles nachschlagbar

struct ArchivAssetDetailView: View {
    @Bindable var asset: MediaAsset
    @Environment(\.dismiss) private var dismiss
    @State private var newTag = ""
    @State private var confirmDelete = false
    @State private var showLocationPicker = false
    @State private var showAddVersion = false

    private var sortedVersions: [EditedVersion] {
        (asset.versions ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            Section {
                if let thumb = ThumbnailStore.thumbnail(for: asset.contentHash) {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section("Bewertung") {
                Toggle(isOn: $asset.favorite) {
                    Label("Favorit", systemImage: "heart")
                }
                HStack {
                    Text("Sterne")
                    Spacer()
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= (asset.rating ?? 0) ? "star.fill" : "star")
                            .foregroundStyle(.yellow)
                            .onTapGesture {
                                asset.rating = (asset.rating == star) ? nil : star
                            }
                    }
                }
                TextField("Notizen", text: $asset.notes, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("Schlagworte") {
                if !asset.userTags.isEmpty {
                    Text(asset.userTags.joined(separator: " · "))
                        .font(.callout)
                }
                HStack {
                    TextField("Schlagwort hinzufügen", text: $newTag)
                        .onSubmit(addTag)
                    Button("OK", action: addTag)
                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Aufnahme") {
                row("Datum", Theme.dayFormatter.string(from: asset.capturedAt))
                row("Uhrzeit", "\(Theme.time(asset.capturedAt)) Uhr")
                row("Datei", asset.fileName)
                row("Größe", sizeText(asset.fileSize))
                row("Inhalt", asset.kind == .video ? "Video" : "Foto")
            }

            if let coordinate = asset.coordinate {
                Section("Ort") {
                    row("Koordinate", String(format: "%.5f, %.5f",
                                             coordinate.latitude, coordinate.longitude))
                    if let altitude = asset.altitudeM {
                        row("Höhe", String(format: "%.0f m", altitude))
                    }
                    if let source = asset.locationSource,
                       let confidence = asset.locationConfidence {
                        row("Herkunft", "\(source.titleDE) — \(confidence.titleDE)")
                    }
                    Button {
                        showLocationPicker = true
                    } label: {
                        Label("Ort korrigieren", systemImage: "mappin.and.ellipse")
                    }
                }
            } else {
                Section("Ort") {
                    Text("Kein Ort ermittelbar — keine GPS-Daten, kein passender Flug, kein zeitnahes Foto. Du kannst ihn manuell setzen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        showLocationPicker = true
                    } label: {
                        Label("Ort auf der Karte setzen", systemImage: "mappin.and.ellipse")
                    }
                }
            }

            if let flight = asset.flight {
                Section("Flug") {
                    row("Start", "\(Theme.shortDayFormatter.string(from: flight.start)) · \(Theme.time(flight.start)) Uhr")
                    row("Dauer", String(format: "%.0f min", flight.durationS / 60))
                    if let maxAlt = flight.maxAltitudeM {
                        row("Max. Höhe", String(format: "%.0f m", maxAlt))
                    }
                    row("Quelle", flight.sourceFileName)
                }
            }

            if let photo = asset.photoMeta {
                Section("Foto-Metadaten") {
                    if let model = photo.droneModel ?? photo.cameraModel {
                        row("Kamera/Drohne", model)
                    }
                    if let iso = photo.iso { row("ISO", "\(iso)") }
                    if let exposure = photo.exposureSeconds {
                        row("Belichtung", exposureText(exposure))
                    }
                    if let aperture = photo.aperture {
                        row("Blende", String(format: "f/%.1f", aperture))
                    }
                    if let focal = photo.focalLengthMM {
                        row("Brennweite", String(format: "%.1f mm%@", focal,
                            photo.focalLength35MM.map { String(format: " (%.0f mm KB)", $0) } ?? ""))
                    }
                    if let heading = photo.headingDeg {
                        row("Blickrichtung", "\(Theme.compassDirection(heading)) (\(Int(heading))°)")
                    }
                    if let width = photo.pixelWidth, let height = photo.pixelHeight {
                        row("Abmessungen", "\(width) × \(height)")
                    }
                }
            }

            if let video = asset.videoMeta {
                Section("Video-Metadaten") {
                    if let model = video.droneModel ?? video.cameraModel {
                        row("Kamera/Drohne", model)
                    }
                    if let duration = video.durationS {
                        row("Länge", durationLong(duration))
                    }
                    if let width = video.pixelWidth, let height = video.pixelHeight {
                        row("Auflösung", "\(width) × \(height)")
                    }
                    if let fps = video.frameRate {
                        row("Bildrate", String(format: "%.2f fps", fps))
                    }
                    if let codec = video.codec { row("Codec", codec) }
                    row("HDR", video.hdrFormat ?? "SDR")
                    if video.suspectedDLog {
                        row("Farbprofil", "vermutlich D-Log (Heuristik)")
                    }
                }
            }

            Section("Fundorte") {
                ForEach(asset.files ?? []) { file in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.sourceLabel.isEmpty ? "Quelle" : file.sourceLabel)
                            .font(.subheadline)
                        Text("\(file.deviceName.isEmpty ? "Gerät" : file.deviceName) · \(file.relativePath)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Bearbeitete Versionen") {
                ForEach(sortedVersions) { version in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(version.purpose.isEmpty ? "Version" : version.purpose)
                            .font(.subheadline.bold())
                        if let link = version.linkURL, let url = URL(string: link) {
                            Link(link, destination: url)
                                .font(.caption)
                                .lineLimit(1)
                        } else if let fileName = version.fileName {
                            Text(fileName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(Theme.shortDayFormatter.string(from: version.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .onDelete { indexSet in
                    let versions = sortedVersions
                    for index in indexSet {
                        ArchivStore.shared.container?.mainContext.delete(versions[index])
                    }
                    ArchivStore.shared.saveQuietly()
                }
                Button {
                    showAddVersion = true
                } label: {
                    Label("Version verknüpfen", systemImage: "plus")
                }
            }

            if let raw = rawMetadata {
                Section {
                    DisclosureGroup("Roh-Metadaten (\(raw.count) Felder)") {
                        ForEach(raw, id: \.0) { key, value in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(key)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(value)
                                    .font(.caption.monospaced())
                            }
                        }
                    }
                } footer: {
                    Text("Verlustfrei gespeichert — auch Felder, die die App (noch) nicht deutet.")
                }
            }
        }
        .navigationTitle(asset.fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Aus dem Katalog entfernen")
            }
        }
        .confirmationDialog("Diesen Eintrag aus dem Katalog entfernen?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Aus dem Katalog entfernen", role: .destructive) {
                ArchivStore.shared.delete([asset])
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Entfernt werden nur Katalog-Daten — die Originaldatei bleibt unberührt.")
        }
        // Manuell gesetzte Orte gelten als hohe Sicherheit und werden
        // von der automatischen Kaskade nie überschrieben.
        .sheet(isPresented: $showLocationPicker) {
            LogLocationPicker(
                coordinate: asset.coordinate
                    ?? CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
            ) { picked in
                asset.latitude = picked.latitude
                asset.longitude = picked.longitude
                asset.locationSourceRaw = LocationSource.manual.rawValue
                asset.locationConfidenceRaw = LocationConfidence.high.rawValue
                ArchivStore.shared.saveQuietly()
            }
        }
        .sheet(isPresented: $showAddVersion) {
            AddVersionSheet(asset: asset)
        }
        .onDisappear { ArchivStore.shared.saveQuietly() }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var tags = asset.userTags
        if !tags.contains(trimmed) { tags.append(trimmed) }
        asset.userTagsRaw = tags.joined(separator: "\n")
        newTag = ""
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func sizeText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func exposureText(_ seconds: Double) -> String {
        seconds >= 1 ? String(format: "%.1f s", seconds)
                     : "1/\(Int((1 / seconds).rounded())) s"
    }

    private func durationLong(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d min", total / 60, total % 60)
    }

    /// Roh-Metadaten (Foto-EXIF bzw. Video) flach als Schlüssel/Wert.
    private var rawMetadata: [(String, String)]? {
        let data = asset.photoMeta?.rawExifJSON ?? asset.videoMeta?.rawMetadataJSON
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        var flat: [(String, String)] = []
        func walk(_ dictionary: [String: Any], prefix: String) {
            for key in dictionary.keys.sorted() {
                let value = dictionary[key]!
                let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"
                if let nested = value as? [String: Any] {
                    walk(nested, prefix: fullKey)
                } else {
                    flat.append((fullKey, String(describing: value)))
                }
            }
        }
        walk(object, prefix: "")
        return flat.isEmpty ? nil : flat
    }
}

// MARK: Bearbeitete Version verknüpfen (Link oder Datei)

struct AddVersionSheet: View {
    let asset: MediaAsset
    @Environment(\.dismiss) private var dismiss
    @State private var purpose = ""
    @State private var linkURL = ""
    @State private var pickedFileName: String?
    @State private var pickedBookmark: Data?
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Zweck") {
                    TextField("z. B. YouTube, Instagram, Familienfilm", text: $purpose)
                }
                Section("Verknüpfung") {
                    TextField("Link (z. B. YouTube-URL)", text: $linkURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        showFilePicker = true
                    } label: {
                        Label(pickedFileName ?? "… oder Datei wählen",
                              systemImage: "doc")
                    }
                } footer: {
                    Text("Link ODER Datei — die Version bleibt dauerhaft mit dem Original verknüpft. Die Datei selbst wird nicht kopiert, nur gemerkt.")
                }
            }
            .navigationTitle("Version verknüpfen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .bold()
                        .disabled(purpose.trimmingCharacters(in: .whitespaces).isEmpty
                                  || (linkURL.isEmpty && pickedBookmark == nil))
                }
            }
            .fileImporter(isPresented: $showFilePicker,
                          allowedContentTypes: [.movie, .image, .data]) { result in
                guard case .success(let url) = result else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                pickedBookmark = try? url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil, relativeTo: nil)
                if scoped { url.stopAccessingSecurityScopedResource() }
                pickedFileName = url.lastPathComponent
            }
        }
    }

    private func save() {
        guard let container = ArchivStore.shared.container else { return }
        let version = EditedVersion()
        version.purpose = purpose.trimmingCharacters(in: .whitespaces)
        let trimmedLink = linkURL.trimmingCharacters(in: .whitespaces)
        version.linkURL = trimmedLink.isEmpty ? nil : trimmedLink
        version.bookmark = pickedBookmark
        version.fileName = pickedFileName
        version.original = asset
        container.mainContext.insert(version)
        ArchivStore.shared.saveQuietly()
        dismiss()
    }
}
