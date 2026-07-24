//
//  FlightLogView.swift
//  FlightMate
//
//  Flug-Logbuch (Roadmap-Punkt 4) im „Flüge"-Tab: oben umschaltbar
//  zwischen Logbuch und KI-Bildkritik (Review). Ein Eintrag pro
//  Flugtag — Datum, Spot, Score, Ein-Tipp-Bewertung, Notiz, bis zu
//  drei Fotos. Wer für HEUTE mit Bewertung loggt, füttert automatisch
//  die Score-Kalibrierung (ScoreValidation) mit.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import MapKit

/// Container für den Tab: Logbuch ⇄ Archiv ⇄ KI-Bildkritik.
/// (Archiv = Drone Media Explorer; als Bereich statt sechstem Tab,
/// weil iOS ab sechs Tabs den „Mehr"-Umweg erzwingt.)
struct FlightsTabView: View {
    private enum Section: String, CaseIterable {
        case logbook = "Logbuch"
        case archive = "Archiv"
        case review = "KI-Bildkritik"
    }
    @State private var section: Section = .logbook

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $section) {
                ForEach(Section.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            switch section {
            case .logbook: LogbookView()
            case .archive: ArchivView()
            case .review: FlightReviewView()
            }
        }
    }
}

// MARK: Logbuch-Liste

struct LogbookView: View {
    @EnvironmentObject private var state: AppState
    @State private var entries: [FlightLogEntry] = []
    @State private var editingEntry: FlightLogEntry?
    @State private var showLogImporter = false
    @State private var importMessage: String?
    // Auswahl-Modus: einzeln oder im Block löschen/sichern.
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<UUID>()
    @State private var exportURL: URL?
    @State private var exportMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Flüge geloggt",
                        systemImage: "book.closed",
                        description: Text("Halte deine Flugtage fest: Ort, Score, wie es wirklich war — und die besten Bilder. Nach der Reise hast du deine ganze Foto-Flug-Historie beisammen.")
                    )
                } else if editMode.isEditing {
                    // Auswahl-Anbindung NUR im Auswählen-Modus: Eine
                    // List mit selection macht auf dem iPad jede Zeile
                    // dauerhaft per Einzeltipp auswählbar — der Tipp
                    // landete in der Auswahl statt im Öffnen-Knopf
                    // (Nutzermeldung: Eintrag auf dem iPad nicht
                    // antippbar).
                    List(selection: $selection) {
                        entryRows
                    }
                    .listStyle(.plain)
                    .environment(\.editMode, $editMode)
                } else {
                    List {
                        entryRows
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Logbuch")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showLogImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("DJI-Fluglogs importieren")
                }
                ToolbarItem(placement: .topBarLeading) {
                    // GPX-Sicherung: Auswahl, sonst alle Einträge.
                    Button {
                        exportGPX()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(entries.isEmpty)
                    .accessibilityLabel("Logbuch als GPX sichern")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !entries.isEmpty {
                        Button(editMode.isEditing ? "Fertig" : "Auswählen") {
                            withAnimation {
                                editMode = editMode.isEditing ? .inactive : .active
                                if !editMode.isEditing { selection.removeAll() }
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        var new = FlightLogEntry()
                        new.spotName = state.locationName ?? state.spots.first?.name ?? ""
                        new.score = state.today?.score
                        // Ort automatisch vom aktuellen Standort —
                        // nachträglich im Eintrag änderbar.
                        if let here = state.currentLocation {
                            new.latitude = here.latitude
                            new.longitude = here.longitude
                        }
                        editingEntry = new
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Flug eintragen")
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    if editMode.isEditing {
                        Button(role: .destructive) {
                            for entry in entries where selection.contains(entry.id) {
                                FlightLog.delete(entry)
                            }
                            selection.removeAll()
                            entries = FlightLog.all()
                            withAnimation { editMode = .inactive }
                        } label: {
                            Label("Löschen (\(selection.count))", systemImage: "trash")
                        }
                        .disabled(selection.isEmpty)
                        Spacer()
                        Button {
                            exportGPX()
                        } label: {
                            Label("Sichern (\(selection.count))", systemImage: "square.and.arrow.up")
                        }
                        .disabled(selection.isEmpty)
                    }
                }
            }
            .fileImporter(isPresented: $showLogImporter,
                          allowedContentTypes: [.plainText, .commaSeparatedText, .text, .data],
                          allowsMultipleSelection: true) { result in
                guard case .success(let urls) = result else { return }
                Task {
                    importMessage = await DJILogImport.importFiles(urls)
                    entries = FlightLog.all()
                }
            }
            .alert("DJI-Import", isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button("OK") { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
            .sheet(item: $editingEntry, onDismiss: { entries = FlightLog.all() }) { entry in
                LogEntryEditor(entry: entry)
            }
            .sheet(isPresented: Binding(
                get: { exportURL != nil },
                set: { if !$0 { exportURL = nil } }
            )) {
                if let exportURL {
                    exportSheet(exportURL)
                        .presentationDetents([.medium])
                }
            }
            .alert("GPX-Sicherung", isPresented: Binding(
                get: { exportMessage != nil },
                set: { if !$0 { exportMessage = nil } }
            )) {
                Button("OK") { exportMessage = nil }
            } message: {
                Text(exportMessage ?? "")
            }
            .onAppear { entries = FlightLog.all() }
            // Vom anderen Gerät übernommene Einträge sofort zeigen.
            .onChange(of: state.flightLogChangeID) {
                entries = FlightLog.all()
            }
        }
    }

    /// Auswahl (oder alle) als GPX bereitstellen.
    private func exportGPX() {
        let target = selection.isEmpty
            ? entries
            : entries.filter { selection.contains($0.id) }
        if let url = FlightLogGPX.export(target) {
            exportURL = url
        } else {
            exportMessage = "Keiner der gewählten Einträge hat einen Flugort — GPX braucht Koordinaten. Öffne die Einträge und setze den Ort, dann klappt die Sicherung."
        }
    }

    private func exportSheet(_ url: URL) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("Logbuch als GPX")
                .font(.headline)
            Text("GPX ist der offene Standard für Geo-Wegpunkte: Die Datei öffnet in Karten-, Foto- und Outdoor-Apps und bleibt langfristig lesbar. Jeder Flug ist ein Wegpunkt mit Name, Zeit, Score und Notiz. Fotos bleiben auf dem Gerät; Einträge ohne Ort werden ausgelassen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            ShareLink(item: url) {
                Label("Sichern / Teilen", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    @ViewBuilder
    private var entryRows: some View {
        ForEach(entries) { entry in
            Button {
                if !editMode.isEditing { editingEntry = entry }
            } label: {
                row(entry)
            }
            .buttonStyle(.plain)
            .tag(entry.id)
        }
        .onDelete { indexSet in
            for index in indexSet {
                FlightLog.delete(entries[index])
            }
            entries = FlightLog.all()
        }
    }

    private func row(_ entry: FlightLogEntry) -> some View {
        HStack(spacing: 12) {
            // Erstes Foto als Miniatur (speicherschonend per
            // Downsampling); Foto-Zähler bei mehreren Bildern.
            if let filename = entry.photoFilenames.first,
               let image = FlightLog.loadThumbnail(filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .bottomTrailing) {
                        if entry.photoFilenames.count > 1 {
                            Text("\(entry.photoFilenames.count)")
                                .font(.caption2.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.55), in: Capsule())
                                .foregroundStyle(.white)
                                .padding(3)
                        }
                    }
            } else {
                Image(systemName: "airplane.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, height: 60)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.spotName.isEmpty ? "Flug" : entry.spotName)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(Theme.shortDayFormatter.string(from: entry.date)) · \(Theme.time(entry.date)) Uhr")
                    if let rating = entry.rating {
                        Label(rating.title, systemImage: rating.symbol)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                // Gesyncter Eintrag, dessen Fotos auf dem anderen
                // Gerät liegen — ehrlich sagen statt leer wirken.
                if entry.photoFilenames.isEmpty,
                   let count = entry.cloudPhotoCount, count > 0 {
                    Label("\(count) Foto\(count == 1 ? "" : "s") — nur auf dem Aufnahmegerät",
                          systemImage: "icloud")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if let score = entry.score {
                Text("\(score)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.scoreColor(score))
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: Eintrag anlegen/bearbeiten

struct LogEntryEditor: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State var entry: FlightLogEntry
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var hasScore: Bool
    @State private var showLocationPicker = false
    @State private var viewerTarget: PhotoViewerTarget?

    init(entry: FlightLogEntry) {
        _entry = State(initialValue: entry)
        _hasScore = State(initialValue: entry.score != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Flug") {
                    DatePicker("Datum & Uhrzeit", selection: $entry.date,
                               displayedComponents: [.date, .hourAndMinute])
                    TextField("Ort / Spot", text: $entry.spotName)
                    if !state.spots.isEmpty {
                        Menu("Gespeicherten Spot übernehmen") {
                            ForEach(state.spots) { spot in
                                Button(spot.name) {
                                    entry.spotName = spot.name
                                    entry.latitude = spot.coordinate.latitude
                                    entry.longitude = spot.coordinate.longitude
                                }
                            }
                        }
                        .font(.caption)
                    }
                }

                Section("Flugort") {
                    if let coordinate = entry.coordinate {
                        // Mini-Karte; Antippen öffnet die große,
                        // zoombare Karte zum Ansehen und Verschieben.
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        )), interactionModes: []) {
                            Marker(entry.spotName.isEmpty ? "Flugort" : entry.spotName,
                                   systemImage: "airplane", coordinate: coordinate)
                                .tint(.purple)
                        }
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                        .onTapGesture { showLocationPicker = true }
                        // initialPosition folgt Änderungen nicht —
                        // neue Koordinate erzwingt eine frische Karte.
                        .id(String(format: "logmap-%.5f-%.5f",
                                   coordinate.latitude, coordinate.longitude))
                        .listRowInsets(EdgeInsets())
                        Button {
                            showLocationPicker = true
                        } label: {
                            Label("Ort ändern", systemImage: "mappin.and.ellipse")
                        }
                        Toggle("Auf der Zonenkarte zeigen", isOn: Binding(
                            get: { entry.showsOnMap ?? true },
                            set: { entry.showsOnMap = $0 }
                        ))
                    } else {
                        if let here = state.currentLocation {
                            Button {
                                entry.latitude = here.latitude
                                entry.longitude = here.longitude
                            } label: {
                                Label("Aktuellen Standort übernehmen", systemImage: "location")
                            }
                        }
                        Button {
                            showLocationPicker = true
                        } label: {
                            Label("Ort auf der Karte wählen", systemImage: "mappin.and.ellipse")
                        }
                    }
                }

                Section("Score & Bewertung") {
                    Toggle("Flight Score festhalten", isOn: $hasScore)
                    if hasScore {
                        Stepper(value: Binding(
                            get: { entry.score ?? state.today?.score ?? 5 },
                            set: { entry.score = $0 }
                        ), in: 0...10) {
                            HStack {
                                Text("Score")
                                Spacer()
                                Text("\(entry.score ?? state.today?.score ?? 5)")
                                    .foregroundStyle(Theme.scoreColor(entry.score ?? state.today?.score ?? 5))
                                    .bold()
                            }
                        }
                    }
                    Picker("Wie traf der Score?", selection: $entry.rating) {
                        Text("Keine Angabe").tag(ScoreFeedback.Rating?.none)
                        ForEach(ScoreFeedback.Rating.allCases, id: \.self) { rating in
                            Text(rating.title).tag(ScoreFeedback.Rating?.some(rating))
                        }
                    }
                }

                Section("Notiz") {
                    TextField("Was war besonders? (Licht, Motive, Lehren …)",
                              text: $entry.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Fotos (max. 3)") {
                    if !entry.photoFilenames.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(entry.photoFilenames.enumerated()), id: \.element) { index, filename in
                                    if let image = FlightLog.loadThumbnail(filename, maxPixel: 200) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 84, height: 84)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            // Tipp aufs Bild → Vollbild-
                                            // Betrachter (Nutzerwunsch).
                                            .onTapGesture {
                                                viewerTarget = PhotoViewerTarget(id: index)
                                            }
                                            .overlay(alignment: .topTrailing) {
                                                Button {
                                                    entry.photoFilenames.removeAll { $0 == filename }
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundStyle(.white, .black.opacity(0.6))
                                                }
                                                .padding(2)
                                            }
                                    }
                                }
                            }
                        }
                        Text("Tipp aufs Bild zeigt es groß")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if entry.photoFilenames.count < 3 {
                        PhotosPicker(selection: $pickerItems,
                                     maxSelectionCount: 3 - entry.photoFilenames.count,
                                     matching: .images) {
                            Label("Fotos hinzufügen", systemImage: "photo.on.rectangle")
                        }
                    }
                }
            }
            .navigationTitle("Flug eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { saveAndClose() }
                        .bold()
                }
            }
            .onChange(of: pickerItems) {
                Task { await importPhotos() }
            }
            .sheet(isPresented: $showLocationPicker) {
                LogLocationPicker(
                    coordinate: entry.coordinate ?? state.effectiveLocation
                ) { picked in
                    entry.latitude = picked.latitude
                    entry.longitude = picked.longitude
                }
            }
            .fullScreenCover(item: $viewerTarget) { target in
                LogPhotoViewer(filenames: entry.photoFilenames, startIndex: target.id)
            }
        }
    }

    private func importPhotos() async {
        for item in pickerItems {
            guard entry.photoFilenames.count < 3,
                  let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let filename = FlightLog.storePhoto(image) else { continue }
            entry.photoFilenames.append(filename)
        }
        pickerItems = []
    }

    private func saveAndClose() {
        if !hasScore { entry.score = nil }
        if hasScore && entry.score == nil { entry.score = state.today?.score }
        FlightLog.save(entry)
        // Heute geloggt + bewertet → füttert die Score-Kalibrierung mit.
        if let rating = entry.rating, let score = entry.score,
           Calendar.current.isDateInToday(entry.date) {
            ScoreValidation.rate(score: score, rating: rating)
        }
        dismiss()
    }
}

// MARK: Fotos in groß — Blättern, Kneif-Zoom, Doppeltipp

struct PhotoViewerTarget: Identifiable {
    let id: Int
}

struct LogPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let filenames: [String]
    @State private var current: Int

    init(filenames: [String], startIndex: Int) {
        self.filenames = filenames
        _current = State(initialValue: min(startIndex, max(filenames.count - 1, 0)))
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $current) {
                ForEach(Array(filenames.enumerated()), id: \.element) { index, filename in
                    ZoomableImage(image: FlightLog.loadPhoto(filename))
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            .background(Color.black)
            .navigationTitle(filenames.count > 1 ? "\(current + 1) von \(filenames.count)" : "Foto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

/// Vollbild mit Kneif-Zoom (bis 4-fach), Ziehen im gezoomten Zustand
/// und Doppeltipp (rein/raus).
private struct ZoomableImage: View {
    let image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(max(lastScale * value, 1), 4)
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale <= 1.01 { resetZoom() }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                guard scale > 1 else { return }
                                offset = CGSize(width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height)
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            if scale > 1 {
                                resetZoom()
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
        .background(Color.black)
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}

// MARK: Flugort wählen — große, zoombare Karte

struct LogLocationPicker: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (CLLocationCoordinate2D) -> Void
    @State private var picked: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D,
         onPick: @escaping (CLLocationCoordinate2D) -> Void) {
        self.onPick = onPick
        _picked = State(initialValue: coordinate)
    }

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: picked,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))) {
                    Marker("Flugort", systemImage: "airplane", coordinate: picked)
                        .tint(.purple)
                    UserAnnotation()
                }
                .mapStyle(.hybrid)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .onTapGesture { screenPoint in
                    if let coordinate = proxy.convert(screenPoint, from: .local) {
                        picked = coordinate
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("Tippe auf die Karte, um den Flugort zu setzen")
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial)
            }
            .navigationTitle("Flugort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        onPick(picked)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
