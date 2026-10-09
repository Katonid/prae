import SwiftUI
import Contacts

struct DatesPanel: View {
    @Binding var project: CalendarProject
    @ObservedObject private var school = SchoolHolidayService.shared
    @State private var editing: PersonalDate?
    @State private var showContacts = false

    private var s: Binding<DateSettings> { $project.dates }

    var body: some View {
        Form {
            holidaySection
            specialSection
            schoolSection
            personalSection
            Section("Darstellung") {
                Toggle("Sonntage hervorheben", isOn: s.highlightSundays)
                Toggle("Samstage hervorheben", isOn: s.highlightSaturdays)
                Toggle("Kalenderwochen zeigen", isOn: s.showWeekNumbers)
                Toggle("Namen der Feiertage zeigen", isOn: s.showHolidayNames)
            }
        }
        .sheet(item: $editing) { item in
            PersonalDateEditor(date: item, year: project.year) { result in
                if let i = project.personalDates.firstIndex(where: { $0.id == result.id }) {
                    project.personalDates[i] = result
                } else {
                    project.personalDates.append(result)
                }
                project.personalDates.sort { ($0.date.m, $0.date.d) < ($1.date.m, $1.date.d) }
            }
        }
        .sheet(isPresented: $showContacts) {
            ContactsImportView(year: project.year) { dates in
                let vorhanden = Set(project.personalDates.map { "\($0.title)|\($0.date.m)|\($0.date.d)" })
                for d in dates where !vorhanden.contains("\(d.title)|\(d.date.m)|\(d.date.d)") {
                    project.personalDates.append(d)
                }
                project.personalDates.sort { ($0.date.m, $0.date.d) < ($1.date.m, $1.date.d) }
            }
        }
    }

    // MARK: Feiertage

    private var stateBinding: Binding<String> {
        Binding(
            get: { project.dates.state?.rawValue ?? "" },
            set: { project.dates.state = Bundesland(rawValue: $0) }
        )
    }

    private var holidaySection: some View {
        Section {
            Toggle("Gesetzliche Feiertage", isOn: s.showHolidays)
            if project.dates.showHolidays {
                Picker("Bundesland", selection: stateBinding) {
                    Text("Nur bundesweite").tag("")
                    ForEach(Bundesland.allCases) { b in
                        Text(b.name).tag(b.rawValue)
                    }
                }
                DisclosureGroup("Einzelne Feiertage") {
                    ForEach(HolidayCatalog.publicHolidays.filter { $0.applies(to: project.dates.state) }) { def in
                        Toggle(isOn: holidayToggle(def.id)) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(def.name)
                                Text(holidayDetail(def))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Feiertage")
        } footer: {
            Text("Gesetzliche Feiertage erscheinen in der Feiertagsfarbe. Regionale Feiertage (etwa Mariä Himmelfahrt in Teilen Bayerns) lassen sich einzeln abwählen.")
        }
    }

    private func holidayDetail(_ def: HolidayDefinition) -> String {
        let day = def.rule(project.year)
        var text = "\(CalendarMath.weekdayShort[day.isoWeekday - 1]), \(CalendarMath.shortDate(day)) \(project.year)"
        if def.states != nil { text += " · \(def.regionText)" }
        if let note = def.note { text += " · \(note)" }
        return text
    }

    private func holidayToggle(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !project.dates.disabledHolidays.contains(id) },
            set: { on in
                if on { project.dates.disabledHolidays.remove(id) } else { project.dates.disabledHolidays.insert(id) }
            }
        )
    }

    private var specialSection: some View {
        Section {
            DisclosureGroup("Besondere Tage (\(project.dates.specialDays.count))") {
                ForEach(HolidayCatalog.specialDays) { def in
                    Toggle(isOn: specialToggle(def.id)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(def.name)
                            let day = def.rule(project.year)
                            Text("\(CalendarMath.weekdayShort[day.isoWeekday - 1]), \(CalendarMath.shortDate(day))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } footer: {
            Text("Muttertag, Advent, Zeitumstellung und mehr — als Hinweis, ohne Feiertagsfarbe.")
        }
    }

    private func specialToggle(_ id: String) -> Binding<Bool> {
        Binding(
            get: { project.dates.specialDays.contains(id) },
            set: { on in
                if on { project.dates.specialDays.insert(id) } else { project.dates.specialDays.remove(id) }
            }
        )
    }

    // MARK: Schulferien

    private var schoolSection: some View {
        Section {
            Toggle("Schulferien zeigen", isOn: s.showSchoolHolidays)
            if project.dates.showSchoolHolidays {
                ForEach($project.dates.schoolStates) { $sel in
                    HStack {
                        ColorPicker(sel.state.name, selection: $sel.color.color, supportsOpacity: false)
                    }
                }
                .onDelete { project.dates.schoolStates.remove(atOffsets: $0) }
                if project.dates.schoolStates.count < 5 {
                    Menu {
                        ForEach(Bundesland.allCases.filter { b in !project.dates.schoolStates.contains { $0.state == b } }) { b in
                            Button(b.name) {
                                let color = SchoolSelection.palette[project.dates.schoolStates.count % SchoolSelection.palette.count]
                                project.dates.schoolStates.append(SchoolSelection(state: b, color: color))
                            }
                        }
                    } label: {
                        Label("Bundesland hinzufügen", systemImage: "plus.circle")
                    }
                }
                Button {
                    Task { await school.refresh(years: Array(project.yearRange)) }
                } label: {
                    HStack {
                        Label("Ferientermine online aktualisieren", systemImage: "arrow.down.circle")
                        if school.loading {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(school.loading)
                if !school.status.isEmpty {
                    Text(school.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if !school.covers(year: project.year) {
                    Label("Für \(String(project.year)) sind noch keine Ferientermine gespeichert.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Schulferien")
        } footer: {
            Text("Eingebaut sind die Ferien aller 16 Länder für 2026 bis 2028 (Quelle: OpenHolidays). Bis zu fünf Länder lassen sich gleichzeitig zeigen — jedes mit eigener Farbe.")
        }
    }

    // MARK: Persönliche Termine

    private var personalSection: some View {
        Section {
            ForEach(project.personalDates) { item in
                Button {
                    editing = item
                } label: {
                    HStack(spacing: 10) {
                        Text(item.symbol.isEmpty ? "•" : item.symbol)
                            .font(.title3)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .foregroundStyle(item.color.color)
                            Text(personalDetail(item))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete { project.personalDates.remove(atOffsets: $0) }
            Button {
                editing = PersonalDate(title: "", date: DayKey(project.year, 1, 1))
            } label: {
                Label("Termin hinzufügen", systemImage: "plus.circle")
            }
            Button {
                showContacts = true
            } label: {
                Label("Geburtstage aus Kontakten", systemImage: "person.crop.circle.badge.plus")
            }
        } header: {
            Text("Persönliche Termine")
        } footer: {
            Text("Geburtstage, Jahrestage, Urlaube — mit Symbol und eigener Farbe. Mit Jahrgang zeigt der Kalender das Alter an.")
        }
    }

    private func personalDetail(_ item: PersonalDate) -> String {
        var text = CalendarMath.shortDate(item.date)
        if let end = item.endDate, end > item.date { text += " – \(CalendarMath.shortDate(end))" }
        text += item.repeatsYearly ? " · jährlich" : " · \(item.date.y)"
        if item.showAge && item.repeatsYearly { text += " · Jahrgang \(item.date.y)" }
        return text
    }
}

// MARK: - Termin bearbeiten

struct PersonalDateEditor: View {
    @State var date: PersonalDate
    let year: Int
    let onSave: (PersonalDate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var hasEnd = false

    init(date: PersonalDate, year: Int, onSave: @escaping (PersonalDate) -> Void) {
        _date = State(initialValue: date)
        _hasEnd = State(initialValue: date.endDate != nil)
        self.year = year
        self.onSave = onSave
    }

    private let symbols = ["🎂", "🎉", "💍", "❤️", "🎓", "✈️", "🏖️", "⛷️", "🏥", "⚽️", "🎵", "🐶", "🌻", "🎄", "⭐️", "📌"]

    private var startBinding: Binding<Date> {
        Binding(get: { date.date.date }, set: { date.date = DayKey($0) })
    }

    private var endBinding: Binding<Date> {
        Binding(get: { (date.endDate ?? date.date).date }, set: { date.endDate = DayKey($0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Bezeichnung (z. B. Oma Hilde)", text: $date.title)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(symbols, id: \.self) { sym in
                                Button {
                                    date.symbol = sym
                                } label: {
                                    Text(sym)
                                        .font(.title2)
                                        .frame(width: 42, height: 42)
                                        .background(Circle().fill(date.symbol == sym ? Color.accentColor.opacity(0.25) : Color.clear))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    TextField("Eigenes Symbol", text: $date.symbol)
                    ColorPicker("Farbe", selection: $date.color.color, supportsOpacity: false)
                }
                Section {
                    DatePicker("Datum", selection: startBinding, displayedComponents: .date)
                        .environment(\.timeZone, TimeZone(identifier: "UTC") ?? .current)
                    Toggle("Jedes Jahr", isOn: $date.repeatsYearly)
                    if date.repeatsYearly {
                        Toggle("Alter bzw. Jahre anzeigen", isOn: $date.showAge)
                    }
                    Toggle("Mehrere Tage (Zeitraum)", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("Bis", selection: endBinding, in: date.date.date..., displayedComponents: .date)
                            .environment(\.timeZone, TimeZone(identifier: "UTC") ?? .current)
                    }
                } footer: {
                    if date.showAge && date.repeatsYearly {
                        Text("Das Jahr des Datums gilt als Jahrgang: Ein Geburtstag 1950 erscheint \(String(year)) als „\(date.title.isEmpty ? "Name" : date.title) (\(year - date.date.y))“.")
                    }
                }
            }
            .navigationTitle(date.title.isEmpty ? "Neuer Termin" : date.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        var result = date
                        if !hasEnd { result.endDate = nil }
                        if result.title.trimmingCharacters(in: .whitespaces).isEmpty { result.title = "Termin" }
                        onSave(result)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Geburtstage aus Kontakten

struct ContactsImportView: View {
    let year: Int
    let onImport: ([PersonalDate]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var entries: [Entry] = []
    @State private var selected: Set<String> = []
    @State private var status = "Lade Kontakte …"

    struct Entry: Identifiable {
        let id: String
        let name: String
        let month: Int
        let day: Int
        let birthYear: Int?

        var dateText: String {
            var text = "\(day). \(CalendarMath.monthName(month))"
            if let birthYear { text += " \(birthYear)" }
            return text
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    Text(status).foregroundStyle(.secondary)
                } else {
                    Section {
                        ForEach(entries) { e in
                            Button {
                                if selected.contains(e.id) { selected.remove(e.id) } else { selected.insert(e.id) }
                            } label: {
                                HStack {
                                    Image(systemName: selected.contains(e.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(e.id) ? Color.accentColor : Color.secondary)
                                    Text(e.name)
                                    Spacer()
                                    Text(e.dateText)
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } footer: {
                        Text("\(entries.count) Kontakte mit Geburtstag. Ist der Jahrgang bekannt, zeigt der Kalender das Alter.")
                    }
                }
            }
            .navigationTitle("Geburtstage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen (\(selected.count))") {
                        let list = entries.filter { selected.contains($0.id) }.map { e in
                            PersonalDate(title: e.name, symbol: "🎂",
                                         date: DayKey(e.birthYear ?? year, e.month, e.day),
                                         repeatsYearly: true, showAge: e.birthYear != nil)
                        }
                        onImport(list)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(selected.count == entries.count ? "Keine" : "Alle auswählen") {
                        if selected.count == entries.count { selected = [] } else { selected = Set(entries.map(\.id)) }
                    }
                    .disabled(entries.isEmpty)
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            guard granted else {
                status = "Kein Zugriff auf die Kontakte. Du kannst ihn in den Einstellungen erlauben."
                return
            }
            let result: [Entry] = try await Task.detached(priority: .userInitiated) {
                let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactNicknameKey,
                            CNContactBirthdayKey] as [CNKeyDescriptor]
                let request = CNContactFetchRequest(keysToFetch: keys)
                var list: [Entry] = []
                try CNContactStore().enumerateContacts(with: request) { contact, _ in
                    guard let b = contact.birthday, let m = b.month, let d = b.day else { return }
                    let name = contact.nickname.isEmpty
                        ? [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                        : contact.nickname
                    guard !name.isEmpty else { return }
                    list.append(Entry(id: contact.identifier, name: name, month: m, day: d, birthYear: b.year))
                }
                return list.sorted { ($0.month, $0.day) < ($1.month, $1.day) }
            }.value
            entries = result
            if result.isEmpty { status = "Keine Kontakte mit Geburtstag gefunden." }
        } catch {
            status = "Die Kontakte ließen sich nicht lesen."
        }
    }
}
