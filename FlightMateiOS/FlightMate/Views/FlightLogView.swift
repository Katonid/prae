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

/// Container für den Tab: Logbuch ⇄ KI-Bildkritik.
struct FlightsTabView: View {
    private enum Section: String, CaseIterable {
        case logbook = "Logbuch"
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

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Flüge geloggt",
                        systemImage: "book.closed",
                        description: Text("Halte deine Flugtage fest: Ort, Score, wie es wirklich war — und die besten Bilder. Nach der Reise hast du deine ganze Foto-Flug-Historie beisammen.")
                    )
                } else {
                    List {
                        ForEach(entries) { entry in
                            Button {
                                editingEntry = entry
                            } label: {
                                row(entry)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                FlightLog.delete(entries[index])
                            }
                            entries = FlightLog.all()
                        }
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        var new = FlightLogEntry()
                        new.spotName = state.locationName ?? state.spots.first?.name ?? ""
                        new.score = state.today?.score
                        editingEntry = new
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Flug eintragen")
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
            .onAppear { entries = FlightLog.all() }
        }
    }

    private func row(_ entry: FlightLogEntry) -> some View {
        HStack(spacing: 12) {
            if let filename = entry.photoFilenames.first,
               let image = FlightLog.loadPhoto(filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "airplane.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 52, height: 52)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.spotName.isEmpty ? "Flug" : entry.spotName)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(Theme.shortDayFormatter.string(from: entry.date))
                    if let rating = entry.rating {
                        Label(rating.title, systemImage: rating.symbol)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
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

    init(entry: FlightLogEntry) {
        _entry = State(initialValue: entry)
        _hasScore = State(initialValue: entry.score != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Flug") {
                    DatePicker("Datum", selection: $entry.date, displayedComponents: .date)
                    TextField("Ort / Spot", text: $entry.spotName)
                    if !state.spots.isEmpty {
                        Menu("Gespeicherten Spot übernehmen") {
                            ForEach(state.spots) { spot in
                                Button(spot.name) { entry.spotName = spot.name }
                            }
                        }
                        .font(.caption)
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
                                ForEach(entry.photoFilenames, id: \.self) { filename in
                                    if let image = FlightLog.loadPhoto(filename) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 84, height: 84)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
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
