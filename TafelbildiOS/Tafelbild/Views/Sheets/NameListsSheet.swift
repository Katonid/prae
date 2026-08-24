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
                    Text("Tipp: Eine Liste kann in mehreren Tafeln benutzt werden — zum Beispiel dieselbe Klasse in „Deutsch\" und „Mathe\".")
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
                    HStack {
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

    private func addName() {
        guard let text = newName.nonEmpty else { return }
        var updated = list
        updated.entries.append(NameEntry(text: text))
        store.updateNameList(updated)
        newName = ""
    }
}
