import SwiftUI
import UIKit

/// Übersicht aller Tafeln: wechseln, anlegen, duplizieren, beitreten.
struct BoardsSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss

    @State private var showJoin = false
    @State private var newName = ""
    @State private var showNew = false
    /// Welche Tafel gerade umbenannt wird — nil, wenn keine.
    @State private var umbenennen: String?
    @State private var neuerName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.visibleBoards) { board in
                        Button {
                            store.activeBoardID = board.id
                            store.selectedWidgetID = nil
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Text(board.emoji).font(.system(size: 28))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(board.name)
                                        .font(Theme.font(18, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text(subtitle(for: board))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if board.id == store.activeBoard?.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.deleteBoard(board)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                            Button {
                                store.duplicateBoard(board)
                            } label: {
                                Label("Kopie", systemImage: "plus.square.on.square")
                            }
                            .tint(Theme.accent)
                        }
                        // Umbenennen gehört dorthin, wo die Tafeln stehen.
                        // Es ging bisher nur unter „Aussehen“ — dort sucht
                        // niemand einen Namen.
                        .swipeActions(edge: .leading) {
                            Button {
                                neuerName = board.name
                                umbenennen = board.id
                            } label: {
                                Label("Umbenennen", systemImage: "pencil")
                            }
                            .tint(Theme.mint)
                        }
                        .contextMenu {
                            Button {
                                neuerName = board.name
                                umbenennen = board.id
                            } label: {
                                Label("Umbenennen", systemImage: "pencil")
                            }
                            Button {
                                store.duplicateBoard(board)
                            } label: {
                                Label("Kopie anlegen", systemImage: "plus.square.on.square")
                            }
                            Button(role: .destructive) {
                                store.deleteBoard(board)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Meine Tafeln")
                }

                Section {
                    Button {
                        showNew = true
                    } label: {
                        Label("Neue Tafel", systemImage: "plus")
                    }
                    if !Umbau.teilenRuht {
                        Button {
                            showJoin = true
                        } label: {
                            Label("Tafel beitreten (Code)", systemImage: "person.badge.plus")
                        }
                    }
                }
            }
            .navigationTitle("Tafeln")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .alert("Neue Tafel", isPresented: $showNew) {
                TextField("Name der Klasse", text: $newName)
                Button("Anlegen") {
                    let name = newName.nonEmpty ?? "Neue Tafel"
                    store.createBoard(name: name)
                    newName = ""
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) { newName = "" }
            }
            .alert("Tafel umbenennen", isPresented: Binding(
                get: { umbenennen != nil },
                set: { if !$0 { umbenennen = nil } }
            )) {
                TextField("Name der Tafel", text: $neuerName)
                Button("Sichern") {
                    if let id = umbenennen, var tafel = store.board(id) {
                        tafel.name = neuerName.nonEmpty ?? tafel.name
                        store.updateBoard(tafel)
                    }
                    umbenennen = nil
                }
                Button("Abbrechen", role: .cancel) { umbenennen = nil }
            } message: {
                Text("Das Symbol der Tafel ändert sich unter „Aussehen“.")
            }
            .sheet(isPresented: $showJoin) {
                JoinBoardSheet()
            }
        }
    }

    private func subtitle(for board: Board) -> String {
        var parts = ["\(board.widgets.count) Elemente"]
        if board.members.count > 1 {
            parts.append("geteilt mit \(board.members.count - 1)")
        }
        return parts.joined(separator: " · ")
    }
}

/// Beitritt zu einer geteilten Tafel per Einladungscode.
struct JoinBoardSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var working = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("z. B. K7M2QX", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.title2, design: .monospaced))
                } header: {
                    Text("Einladungscode")
                } footer: {
                    Text("Den Code findest du auf dem Gerät deiner Kollegin unter „Tafel teilen“. Der Abgleich läuft über iCloud — dafür muss auf beiden Geräten ein iCloud-Konto angemeldet sein.")
                }

                if failed {
                    Text("Zu diesem Code wurde keine Tafel gefunden. Wurde die Tafel schon einmal synchronisiert?")
                        .foregroundStyle(Theme.danger)
                }

                Section {
                    Button {
                        working = true
                        failed = false
                        store.joinBoard(code: code) { success in
                            working = false
                            if success { dismiss() } else { failed = true }
                        }
                    } label: {
                        HStack {
                            Text("Beitreten")
                            if working {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(code.trimmed.count < 4 || working)
                }
            }
            .navigationTitle("Tafel beitreten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}

/// Tafel mit Kolleginnen und Kollegen teilen.
///
/// Solange der Umbau läuft (`Umbau.teilenRuht`), steht hier statt des
/// Einladungscodes die Erklärung, warum es gerade nicht geht — ein Code, den
/// niemand einlösen kann, wäre schlimmer als kein Code.
struct ShareSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss
    let boardID: String

    private var board: Board { store.board(boardID) ?? Board() }

    @State private var newMember = ""

    var body: some View {
        NavigationStack {
            Form {
                if Umbau.teilenRuht {
                    Section {
                        Label("Teilen wird gerade umgebaut", systemImage: "hammer")
                            .font(.headline)
                    } footer: {
                        Text("Diese Fassung legt die Tafeln in deiner privaten iCloud ab. "
                             + "Dort kann sie niemand sonst finden — auch nicht mit einem "
                             + "Einladungscode. Genau darum geht es bei dem Umbau.\n\n"
                             + "An die Stelle des Codes tritt eine echte iCloud-Freigabe: "
                             + "Du verschickst einen Link, siehst, wer teilnimmt, kannst "
                             + "jemanden auch wieder herausnehmen und Nur-Lesen vergeben. "
                             + "Bis dahin bleibt jede Tafel auf deinen eigenen Geräten — "
                             + "dort gleicht sie sich wie gewohnt ab.")
                    }
                } else {
                    Section {
                        HStack {
                            Text(board.joinCode)
                                .font(.system(size: 34, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 6)
                        ShareLink(item: store.shareText(for: board)) {
                            Label("Einladung senden", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            UIPasteboard.general.string = board.joinCode
                            store.showStatus("Code kopiert.")
                        } label: {
                            Label("Code kopieren", systemImage: "doc.on.doc")
                        }
                    } header: {
                        Text("Einladungscode")
                    } footer: {
                    Text("Deine Kollegin öffnet Klassenraum → Tafeln → „Tafel beitreten“ und gibt "
                         + "den Code ein. Sie sieht die Tafel dann zunächst genau so, wie du sie "
                         + "eingerichtet hast.\n\n"
                         + "Danach gilt: Was auf der Tafel steht, gehört euch gemeinsam — "
                         + "Namenslisten samt gezogener Namen, Texte, Tagesablauf, Klänge. "
                         + "Wie es aussieht und wo es liegt, entscheidet jede für sich: "
                         + "Anordnung, Größen, Farben und Ausgeblendetes bleiben auf dem "
                         + "eigenen Gerät. Zwischen deinen eigenen Geräten gleicht sich "
                         + "dagegen alles ab, auch das Umräumen.")
                    }
                }

                Section {
                    ForEach(board.members, id: \.self) { member in
                        HStack {
                            Image(systemName: "person.circle")
                            Text(member)
                            if member.lowercased() == board.owner.lowercased() {
                                Text("· Besitzerin")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        var updated = board
                        updated.members.remove(atOffsets: offsets)
                        store.updateBoard(updated)
                    }
                    HStack {
                        TextField("Name eintragen", text: $newMember)
                        Button("Hinzufügen") {
                            guard let name = newMember.nonEmpty else { return }
                            var updated = board
                            if !updated.members.contains(where: { $0.lowercased() == name.lowercased() }) {
                                updated.members.append(name)
                                store.updateBoard(updated)
                            }
                            newMember = ""
                        }
                        .disabled(newMember.trimmed.isEmpty)
                    }
                } header: {
                    Text("Sieht diese Tafel")
                } footer: {
                    Text("Wer beitritt, trägt sich automatisch selbst ein. Namen hier eintragen ist nur nötig, wenn du jemanden vorab freischalten möchtest.")
                }
            }
            .navigationTitle("Tafel teilen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
