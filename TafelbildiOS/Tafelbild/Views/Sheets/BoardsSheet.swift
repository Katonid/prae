import SwiftUI
import UIKit
import CloudKit

/// Übersicht aller Tafeln: wechseln, anlegen, duplizieren, umbenennen.
struct BoardsSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss

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
        }
    }

    private func subtitle(for board: Board) -> String {
        var parts = ["\(board.widgets.count) Elemente"]
        if store.istGast(board) {
            parts.append("von \(board.owner.nonEmpty ?? "jemand anderem")")
        } else if board.geteilt {
            parts.append(board.members.count > 1
                         ? "freigegeben für \(board.members.count - 1)"
                         : "freigegeben")
        }
        return parts.joined(separator: " · ")
    }
}

/// Tafel mit Kolleginnen und Kollegen teilen — über eine echte
/// iCloud-Freigabe (`CKShare`).
///
/// Der Einladungscode von früher ist weg. Er konnte nur funktionieren,
/// solange alle Tafeln im selben öffentlichen Bereich lagen und jeder darin
/// suchen durfte. Seit die Tafeln in der privaten iCloud liegen, gibt es
/// stattdessen einen Link: Wer ihn öffnet, ist eingeladen — und niemand
/// sonst kommt heran.
struct ShareSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss
    let boardID: String

    private var board: Board? { store.board(boardID) }

    @State private var laeuft = false
    /// Das Teilen-Blatt. Ein Objekt, kein Ansichtswert: Es wird von UIKit
    /// gezeigt, nicht von SwiftUI (siehe `Freigabewahl`).
    @State private var freigabewahl = Freigabewahl()
    @State private var fehler: String?
    @State private var fragtWiderruf = false
    @State private var fragtVerlassen = false
    @State private var fragtUebernahme = false

    var body: some View {
        NavigationStack {
            Form {
                if let board {
                    if store.istGast(board) {
                        gastAbschnitt(board)
                    } else {
                        besitzAbschnitt(board)
                    }
                    teilnehmerAbschnitt(board)
                }
                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(Theme.danger)
                    }
                }
            }
            .alert("Freigabe zurücknehmen?", isPresented: $fragtWiderruf) {
                Button("Zurücknehmen", role: .destructive) {
                    guard let board else { return }
                    Task {
                        laeuft = true
                        let geklappt = await store.freigabeWiderrufen(fuer: board)
                        laeuft = false
                        if !geklappt {
                            fehler = "Die Freigabe ließ sich nicht zurücknehmen."
                        }
                    }
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Die Tafel verschwindet danach bei allen anderen. Wer sie "
                     + "vorher als eigene übernommen hat, behält seine Kopie.")
            }
            .alert("Als eigene Tafel übernehmen?", isPresented: $fragtUebernahme) {
                Button("Übernehmen") {
                    guard let board else { return }
                    store.alsEigeneUebernehmen(board)
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Es entsteht eine Kopie, die nur dir gehört. Die geteilte "
                     + "Tafel bleibt daneben bestehen — beende die Teilnahme, "
                     + "wenn du sie nicht mehr brauchst.")
            }
            .alert("Teilnahme beenden?", isPresented: $fragtVerlassen) {
                Button("Beenden", role: .destructive) {
                    guard let board else { return }
                    Task {
                        laeuft = true
                        let geklappt = await store.freigabeVerlassen(fuer: board)
                        laeuft = false
                        if geklappt { dismiss() } else { fehler = "Das hat nicht geklappt." }
                    }
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Die Tafel verschwindet von diesem Konto. Bei deiner "
                     + "Kollegin bleibt sie stehen.")
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

    // MARK: Meine eigene Tafel

    @ViewBuilder
    private func besitzAbschnitt(_ board: Board) -> some View {
        Section {
            Button {
                // Das Blatt legt die Freigabe selbst an — hier wird nur
                // geöffnet. Warum, steht bei `Freigabewahl`.
                fehler = nil
                freigabewahl.oeffne(boardID: board.id, titel: board.name)
            } label: {
                HStack {
                    Label(board.geteilt ? "Weitere Person einladen" : "Tafel freigeben",
                          systemImage: "person.crop.circle.badge.plus")
                    if laeuft {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(laeuft)
            if board.geteilt {
                Button(role: .destructive) {
                    fragtWiderruf = true
                } label: {
                    Label("Freigabe zurücknehmen", systemImage: "person.crop.circle.badge.xmark")
                }
                .disabled(laeuft)
            }
        } header: {
            Text("Freigabe")
        } footer: {
            Text("Du verschickst einen Link — über Nachrichten, Mail oder was "
                 + "sonst zur Hand ist. Wer ihn öffnet, sieht die Tafel sofort "
                 + "und darf gleich "
                 + "mitschreiben; eine Rückfrage nach Rechten gibt es bewusst "
                 + "nicht. Nur-Zuschauen hätte hier wenig Sinn: Von einer "
                 + "Auslosung, die man nicht auslösen kann, hat niemand etwas.\n\n"

                 + "Was auf der Tafel steht, gehört euch dann gemeinsam — "
                 + "Namenslisten samt gezogener Namen, Texte, Tagesablauf, "
                 + "Bilder und Klänge. Wie es aussieht und wo es liegt, "
                 + "entscheidet jede für sich: Anordnung, Größen, Farben und "
                 + "Ausgeblendetes bleiben auf dem eigenen Gerät. Zwischen "
                 + "deinen eigenen Geräten gleicht sich dagegen alles ab.\n\n"
                 + "„Zurücknehmen“ beendet die Freigabe für alle auf einmal. "
                 + "Deine Tafel bleibt dabei unangetastet stehen.")
        }
    }

    // MARK: Tafel von jemand anderem

    @ViewBuilder
    private func gastAbschnitt(_ board: Board) -> some View {
        Section {
            Label("Diese Tafel gehört \(board.owner.nonEmpty ?? "jemand anderem")",
                  systemImage: "person.crop.circle")
            Button {
                fragtUebernahme = true
            } label: {
                Label("Als eigene Tafel übernehmen", systemImage: "square.on.square.dashed")
            }
            Button(role: .destructive) {
                fragtVerlassen = true
            } label: {
                Label("Teilnahme beenden", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } header: {
            Text("Geteilte Tafel")
        } footer: {
            Text("Du arbeitest hier an der Tafel deiner Kollegin mit: Was du "
                 + "änderst, sieht sie auch.\n\n"
                 + "„Als eigene übernehmen“ macht daraus eine Kopie, die nur "
                 + "dir gehört — mit eigenen Namenslisten, damit deine Klasse "
                 + "nicht in ihrer landet. Danach geht ihr getrennte Wege: "
                 + "Änderungen wandern nicht mehr hin und her. So gibt man "
                 + "eine vorbereitete Tafel an andere Klassen weiter.\n\n"
                 + "„Teilnahme beenden“ nimmt die Tafel von diesem Konto "
                 + "herunter. Bei deiner Kollegin bleibt sie stehen.")
        }
    }

    // MARK: Wer mitmacht

    @ViewBuilder
    private func teilnehmerAbschnitt(_ board: Board) -> some View {
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
        } header: {
            Text("Macht mit")
        } footer: {
            Text("Wer eine Einladung annimmt, trägt sich selbst ein — mit dem "
                 + "Namen aus seinen Einstellungen.")
        }
    }

}

/// Zeigt Apples Teilen-Blatt — **an SwiftUI vorbei**.
///
/// Es zeigt zugleich, wer teilnimmt, und lässt einzelne Personen wieder
/// entfernen; deshalb baut die App das nicht nach.
///
/// **Präsentieren, nicht einbetten.** In 1.0.60 steckte dieses Blatt in einem
/// SwiftUI-`.sheet` und erschien als schwarzes Rechteck mitten auf der Tafel.
/// `UICloudSharingController` ist das Fenster eines fremden Dienstes — wie
/// der Dateiwähler. Beide wollen von UIKit gezeigt werden. Dieselbe Regel,
/// zweimal gelernt (siehe `Oberflaeche`).
///
/// **Die Freigabe legt das Blatt selbst an**, über den Vorbereitungs-Rückruf.
/// Die Adresse (`CKShare.url`) entsteht erst beim Sichern; wer ein fertiges
/// Objekt hereinreicht, hat sie noch nicht, und „Link kopieren" kopiert
/// nichts (1.0.58 und 1.0.59). Fehler werden roh durchgereicht: Das Blatt
/// zeigt Apples Wortlaut, und der ist die bessere Spur.
final class Freigabewahl: NSObject, UICloudSharingControllerDelegate {
    private var titel = ""
    private var offen = false

    func oeffne(boardID: String, titel: String) {
        guard !offen, let halter = Oberflaeche.obersterHalter() else { return }
        offen = true
        self.titel = titel

        let blatt = UICloudSharingController { _, fertig in
            Task { @MainActor in
                guard let board = BoardStore.shared.board(boardID) else {
                    fertig(nil, nil, CloudSyncEngine.Freigabefehler.tafelFehlt)
                    return
                }
                switch await BoardStore.shared.bereiteFreigabeVor(fuer: board) {
                case .success(let share):
                    fertig(share, CKContainer(identifier: CloudSyncEngine.containerID), nil)
                case .failure(let fehler):
                    fertig(nil, nil, fehler)
                }
            }
        }
        // Nur-Lesen gibt es hier bewusst nicht (siehe Hinweistext im Blatt).
        blatt.availablePermissions = [.allowPublic, .allowReadWrite]
        blatt.delegate = self
        Oberflaeche.ausMitte(blatt, in: halter)
        halter.present(blatt, animated: true)
    }

    func itemTitle(for controller: UICloudSharingController) -> String? { titel }

    func cloudSharingController(_ controller: UICloudSharingController,
                                failedToSaveShareWithError error: Error) {
        offen = false
        Task { @MainActor in
            BoardStore.shared.showStatus("Die Einladung ließ sich nicht anlegen: "
                                         + error.localizedDescription)
        }
    }

    func cloudSharingControllerDidSaveShare(_ controller: UICloudSharingController) {
        offen = false
        Task { @MainActor in BoardStore.shared.syncNow() }
    }

    func cloudSharingControllerDidStopSharing(_ controller: UICloudSharingController) {
        offen = false
        Task { @MainActor in BoardStore.shared.syncNow() }
    }
}
