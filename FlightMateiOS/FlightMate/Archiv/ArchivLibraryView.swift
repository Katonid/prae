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

struct ArchivLibraryView: View {
    @Query(sort: \MediaAsset.capturedAt, order: .reverse)
    private var assets: [MediaAsset]
    @State private var filter: String = "alle"

    private var filtered: [MediaAsset] {
        switch filter {
        case MediaKind.photo.rawValue: return assets.filter { $0.kind == .photo }
        case MediaKind.video.rawValue: return assets.filter { $0.kind == .video }
        default: return assets
        }
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
                            NavigationLink {
                                ArchivAssetDetailView(asset: asset)
                            } label: {
                                cell(asset)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 3)
                }
            }
        }
        .navigationTitle("Bibliothek")
        .navigationBarTitleDisplayMode(.inline)
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
    @Environment(\.modelContext) private var modelContext
    @State private var newTag = ""

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
                }
            } else {
                Section("Ort") {
                    Text("Kein Ort hinterlegt — die Zuordnung (Flight Log, Nachbar-Fotos, manuell) kommt mit Ausbauschritt M3.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .onDisappear { try? modelContext.save() }
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
