import SwiftUI

/// Startseite: alle Druckaufträge.
struct HomeView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var path: [UUID] = []
    @State private var renaming: PosterProject?
    @State private var newName = ""
    @State private var deleting: PosterProject?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.projects.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Posterdruck")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let p = store.create()
                        path.append(p.id)
                    } label: {
                        Label("Neuer Auftrag", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let binding = store.binding(for: id) {
                    EditorView(project: binding)
                } else {
                    Text("Dieser Auftrag ist nicht mehr da.")
                }
            }
            .alert("Umbenennen", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $newName)
                Button("Abbrechen", role: .cancel) { renaming = nil }
                Button("Sichern") {
                    if let r = renaming, let b = store.binding(for: r.id) {
                        b.wrappedValue.name = newName.trimmingCharacters(in: .whitespaces)
                    }
                    renaming = nil
                }
            }
            .confirmationDialog("Auftrag löschen?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                                titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    if let d = deleting { store.delete(d) }
                    deleting = nil
                }
            } message: {
                Text("Der Auftrag und seine Bilder in dieser App werden gelöscht. Die Fotos in deiner Mediathek bleiben.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "photo.artframe")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Poster für die Druckerei")
                .font(.title2.bold())
            Text("Bilder laden, Format mit Beschnitt wählen (z. B. DIN A2 mit 3 mm: 426 × 600 mm) und eine druckfertige PDF erstellen.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            Button {
                let p = store.create()
                path.append(p.id)
            } label: {
                Label("Neuer Auftrag", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var list: some View {
        List {
            ForEach(store.projects) { project in
                NavigationLink(value: project.id) {
                    row(project)
                }
                .contextMenu { menu(project) }
                .swipeActions {
                    Button(role: .destructive) { deleting = project } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func menu(_ project: PosterProject) -> some View {
        Button {
            newName = project.name
            renaming = project
        } label: { Label("Umbenennen", systemImage: "pencil") }
        Button {
            store.duplicate(project)
        } label: { Label("Duplizieren", systemImage: "plus.square.on.square") }
        Button(role: .destructive) {
            deleting = project
        } label: { Label("Löschen", systemImage: "trash") }
    }

    private func row(_ project: PosterProject) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.15))
                if let first = project.items.first {
                    let size = PosterPageView.size(format: project.format, item: first, scale: 1)
                    let s = min(54 / size.width, 54 / size.height)
                    PosterPageView(format: project.format, item: first, scale: s, guides: false)
                        .shadow(radius: 1.5)
                } else {
                    Image(systemName: "photo.on.rectangle").foregroundStyle(.secondary)
                }
            }
            .frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name).font(.headline)
                Text("\(project.format.presetName) · \(project.format.dataSummary) mit Beschnitt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(project.items.count == 1 ? "1 Bild" : "\(project.items.count) Bilder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
