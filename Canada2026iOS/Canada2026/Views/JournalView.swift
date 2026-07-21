import SwiftUI

// Reisejournal – Einträge pro Tag mit Stimmung, für Betrachter nur lesbar.

struct JournalView: View {
    @EnvironmentObject private var store: AppStore
    @State private var editingEntry: JournalEntry?
    @State private var showsNewEntry = false

    private struct DayGroup: Identifiable {
        let day: String
        let entries: [JournalEntry]
        var id: String { day }
    }

    private var groupedEntries: [DayGroup] {
        let entries = store.journalEntries()
        let grouped = Dictionary(grouping: entries, by: { $0.day })
        return grouped.keys.sorted(by: >).map { day in
            DayGroup(day: day, entries: (grouped[day] ?? []).sorted { $0.createdAt > $1.createdAt })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if groupedEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Noch keine Einträge")
                            .font(.headline)
                        Text(store.isCrew
                             ? "Halte Momente der Reise fest – jeden Tag ein paar Zeilen."
                             : "Sobald die Crew schreibt, erscheinen die Einträge hier.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                ForEach(groupedEntries) { group in
                    Section(HomeView.dayLabel(group.day)) {
                        ForEach(group.entries) { entry in
                            JournalRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if store.isCrew && (entry.author == store.deviceUser.name || store.isAdmin) {
                                        editingEntry = entry
                                    }
                                }
                                .swipeActions {
                                    if store.isCrew && (entry.author == store.deviceUser.name || store.isAdmin) {
                                        Button(role: .destructive) {
                                            store.deleteJournalEntry(entry)
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        SyncStatusDot()
                        if store.isCrew {
                            Button {
                                showsNewEntry = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showsNewEntry) {
                JournalEditorSheet(entry: nil)
            }
            .sheet(item: $editingEntry) { entry in
                JournalEditorSheet(entry: entry)
            }
        }
    }
}

struct JournalRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                MemberChip(name: entry.author)
                if entry.mood > 0 {
                    Text(String(repeating: "★", count: entry.mood))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
                if let station = TravelData.station(withId: entry.stationId) {
                    Text(station.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if !entry.title.isEmpty {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
            }
            Text(entry.text)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}

struct JournalEditorSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let entry: JournalEntry?

    @State private var title = ""
    @State private var text = ""
    @State private var mood = 0
    @State private var day = TravelData.isoDay.string(from: Date())

    var body: some View {
        NavigationStack {
            Form {
                Section("Eintrag") {
                    TextField("Überschrift (optional)", text: $title)
                    TextField("Was ist heute passiert?", text: $text, axis: .vertical)
                        .lineLimit(5...12)
                }
                Section("Stimmung") {
                    Picker("Stimmung", selection: $mood) {
                        Text("Keine Angabe").tag(0)
                        ForEach(1...5, id: \.self) { value in
                            Text(String(repeating: "★", count: value)).tag(value)
                        }
                    }
                }
                Section("Tag") {
                    DatePicker(
                        "Datum",
                        selection: Binding(
                            get: { TravelData.isoDay.date(from: day) ?? Date() },
                            set: { day = TravelData.isoDay.string(from: $0) }
                        ),
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle(entry == nil ? "Neuer Eintrag" : "Eintrag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        var saved = entry ?? JournalEntry()
                        if entry == nil {
                            saved.author = store.deviceUser.name
                        }
                        saved.title = title
                        saved.text = text
                        saved.mood = mood
                        saved.day = day
                        saved.stationId = TravelData.currentStation()?.id ?? saved.stationId
                        store.saveJournalEntry(saved)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let entry {
                    title = entry.title
                    text = entry.text
                    mood = entry.mood
                    day = entry.day
                }
            }
        }
    }
}
