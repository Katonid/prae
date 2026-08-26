import SwiftUI

/// Namenslisten verwalten — sie stehen allen Tafeln zur Verfügung.
struct NameListsSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss

    @State private var newListName = ""
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.visibleNameLists) { list in
                        NavigationLink {
                            NameListEditor(listID: list.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(list.name)
                                    .font(Theme.font(17, weight: .semibold))
                                Text("\(list.entries.count) Namen"
                                     + (list.entries.contains(where: \.paused) ? " · einige pausiert" : ""))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            store.deleteNameList(store.visibleNameLists[index])
                        }
                    }
                } footer: {
                    Text("Tipp: Eine Liste kann in mehreren Tafeln benutzt werden — zum Beispiel dieselbe Klasse in „Deutsch“ und „Mathe“.")
                }

                Section {
                    Button {
                        showNew = true
                    } label: {
                        Label("Neue Liste", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Namenslisten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .alert("Neue Liste", isPresented: $showNew) {
                TextField("z. B. Klasse 4a", text: $newListName)
                Button("Anlegen") {
                    store.createNameList(name: newListName.nonEmpty ?? "Neue Liste")
                    newListName = ""
                }
                Button("Abbrechen", role: .cancel) { newListName = "" }
            }
        }
    }
}

/// Einträge einer Namensliste bearbeiten.
struct NameListEditor: View {
    @EnvironmentObject private var store: BoardStore
    let listID: String

    @State private var newName = ""
    @State private var bulkText = ""
    @State private var showBulk = false

    private var list: NameList { store.nameList(listID) ?? NameList() }

    var body: some View {
        List {
            Section("Name der Liste") {
                TextField("Name", text: Binding(
                    get: { list.name },
                    set: { value in
                        var updated = list
                        updated.name = value
                        store.updateNameList(updated)
                    }
                ))
            }

            Section {
                ForEach(list.entries) { entry in
                    HStack(spacing: 8) {
                        TextField("Name", text: Binding(
                            get: { entry.text },
                            set: { value in
                                var updated = list
                                if let index = updated.entries.firstIndex(where: { $0.id == entry.id }) {
                                    updated.entries[index].text = value
                                    store.updateNameList(updated)
                                }
                            }
                        ))
                        .foregroundStyle(entry.paused ? .secondary : .primary)
                        if entry.paused {
                            Image(systemName: "pause.circle")
                                .foregroundStyle(.secondary)
                        }
                        // Je Merkmal ein kleiner Knopf mit dem Wert. „–“ heißt:
                        // für diesen Namen nichts angegeben.
                        ForEach(list.merkmale) { merkmal in
                            Menu {
                                ForEach(merkmal.werte, id: \.self) { wert in
                                    Button(wert) { setze(merkmal, wert, fuer: entry) }
                                }
                                Divider()
                                Button("Ohne Angabe") { setze(merkmal, "", fuer: entry) }
                            } label: {
                                Text(entry.wert(merkmal.id) ?? "–")
                                    .font(Theme.font(14, weight: .bold))
                                    .monospaced()
                                    .foregroundStyle(entry.wert(merkmal.id) == nil
                                                     ? Color.secondary : Color.white)
                                    .frame(minWidth: 30, minHeight: 30)
                                    .background {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(entry.wert(merkmal.id) == nil
                                                  ? Color.secondary.opacity(0.15)
                                                  : Theme.accent)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            var updated = list
                            if let index = updated.entries.firstIndex(where: { $0.id == entry.id }) {
                                updated.entries[index].paused.toggle()
                                store.updateNameList(updated)
                            }
                        } label: {
                            Label(entry.paused ? "Wieder dabei" : "Pausieren",
                                  systemImage: entry.paused ? "play" : "pause")
                        }
                        .tint(Theme.amber)
                    }
                }
                .onDelete { offsets in
                    var updated = list
                    updated.entries.remove(atOffsets: offsets)
                    store.updateNameList(updated)
                }
                .onMove { source, destination in
                    var updated = list
                    updated.entries.move(fromOffsets: source, toOffset: destination)
                    store.updateNameList(updated)
                }

                HStack {
                    TextField("Namen hinzufügen", text: $newName)
                        .onSubmit(addName)
                    Button("Hinzufügen", action: addName)
                        .disabled(newName.trimmed.isEmpty)
                }
            } header: {
                Text("Namen (\(list.entries.count))")
            } footer: {
                Text("Pausierte Namen werden nicht gezogen — praktisch, wenn jemand krank ist.")
            }

            Section {
                Button {
                    bulkText = ""
                    showBulk = true
                } label: {
                    Label("Mehrere Namen einfügen", systemImage: "text.badge.plus")
                }
            }

            merkmalsAbschnitt
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $showBulk) {
            NavigationStack {
                VStack(alignment: .leading) {
                    Text("Ein Name pro Zeile (Kommas gehen auch).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    TextEditor(text: $bulkText)
                        .font(.system(.body, design: .rounded))
                        .padding(8)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding()
                }
                .navigationTitle("Namen einfügen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { showBulk = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Übernehmen") {
                            var updated = list
                            updated.entries.append(contentsOf: NameList.parse(bulkText))
                            store.updateNameList(updated)
                            showBulk = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Merkmale

    @ViewBuilder
    private var merkmalsAbschnitt: some View {
        Section {
            ForEach(list.merkmale) { merkmal in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name des Merkmals", text: Binding(
                        get: { merkmal.name },
                        set: { wert in aendere(merkmal) { $0.name = wert } }
                    ))
                    .font(Theme.font(16, weight: .semibold))

                    TextField("Werte, mit Komma getrennt", text: Binding(
                        get: { merkmal.werte.joined(separator: ", ") },
                        set: { text in
                            let werte = text.split(separator: ",")
                                .map { String($0).trimmed }
                                .filter { !$0.isEmpty }
                            aendere(merkmal) { $0.werte = werte }
                        }
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    // Wie viele Namen welchen Wert tragen — so ist auf einen
                    // Blick zu sehen, ob noch etwas fehlt.
                    let verteilung = list.verteilung(merkmal.id)
                    HStack(spacing: 6) {
                        ForEach(merkmal.werte, id: \.self) { wert in
                            zaehlerPille(wert, verteilung[wert] ?? 0, fehlend: false)
                        }
                        if let ohne = verteilung[""], ohne > 0 {
                            zaehlerPille("ohne", ohne, fehlend: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in
                var updated = list
                let entfernt = offsets.map { updated.merkmale[$0].id }
                updated.merkmale.remove(atOffsets: offsets)
                // Die Werte an den Namen gleich mit wegräumen — sonst bliebe
                // unsichtbarer Ballast in der Liste stehen.
                for index in updated.entries.indices {
                    for id in entfernt { updated.entries[index].merkmale[id] = nil }
                }
                store.updateNameList(updated)
            }

            Menu {
                ForEach(Merkmal.vorlagen) { vorlage in
                    Button(vorlage.name + " (" + vorlage.werte.joined(separator: "/") + ")") {
                        var neu = vorlage
                        neu.id = UUID().uuidString
                        var updated = list
                        updated.merkmale.append(neu)
                        store.updateNameList(updated)
                    }
                }
                Divider()
                Button("Eigenes Merkmal") {
                    var updated = list
                    updated.merkmale.append(Merkmal())
                    store.updateNameList(updated)
                }
            } label: {
                Label("Merkmal hinzufügen", systemImage: "plus")
            }
        } header: {
            Text("Merkmale")
        } footer: {
            Text("Ein Merkmal ist etwas, wonach sich die Namen sortieren lassen — "
                 + "am häufigsten Jungen und Mädchen. Der Wert steht als kurzes "
                 + "Zeichen hinter jedem Namen und lässt sich dort antippen. "
                 + "Gebraucht wird er beim Auslosen von Gruppen: Dann kann die "
                 + "Ziehung darauf achten, dass die Gruppen gemischt sind.")
        }
    }

    private func zaehlerPille(_ text: String, _ anzahl: Int, fehlend: Bool) -> some View {
        Text("\(text) \(anzahl)")
            .font(Theme.font(13, weight: .semibold))
            .foregroundStyle(fehlend ? Color.orange : Color.secondary)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background {
                Capsule().fill((fehlend ? Color.orange : Color.secondary).opacity(0.15))
            }
    }

    private func aendere(_ merkmal: Merkmal, _ change: (inout Merkmal) -> Void) {
        var updated = list
        guard let index = updated.merkmale.firstIndex(where: { $0.id == merkmal.id }) else { return }
        change(&updated.merkmale[index])
        store.updateNameList(updated)
    }

    private func setze(_ merkmal: Merkmal, _ wert: String, fuer entry: NameEntry) {
        var updated = list
        guard let index = updated.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        if wert.isEmpty {
            updated.entries[index].merkmale[merkmal.id] = nil
        } else {
            updated.entries[index].merkmale[merkmal.id] = wert
        }
        store.updateNameList(updated)
        Haptics.tap()
    }

    private func addName() {
        guard let text = newName.nonEmpty else { return }
        var updated = list
        updated.entries.append(NameEntry(text: text))
        store.updateNameList(updated)
        newName = ""
    }
}
