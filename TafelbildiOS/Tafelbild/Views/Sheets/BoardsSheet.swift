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
    /// Die echten Teilnehmer aus der Freigabe. Leer, solange noch geladen
    /// wird oder die Tafel nicht geteilt ist.
    @State private var teilnehmer: [CloudSyncEngine.Teilnehmer] = []
    @State private var ladeTeilnehmer = false
    /// Wen die Rückfrage gerade betrifft.
    @State private var fragtEntfernen: CloudSyncEngine.Teilnehmer?
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
                if let grund = store.freigabefehler {
                    Section {
                        Text(grund)
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                            .textSelection(.enabled)
                        Button("Meldung ausblenden") { store.freigabefehler = nil }
                    } header: {
                        Text("Das sagt iCloud")
                    } footer: {
                        Text("Der Wortlaut kommt von iCloud, nicht von dieser App. "
                             + "Er lässt sich markieren und kopieren.")
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
            .alert("Zugriff entziehen?", isPresented: Binding(
                get: { fragtEntfernen != nil },
                set: { if !$0 { fragtEntfernen = nil } }
            ), presenting: fragtEntfernen) { person in
                Button("Entfernen", role: .destructive) {
                    guard let board else { return }
                    Task {
                        laeuft = true
                        let geklappt = await store.teilnehmerEntfernen(person.id, von: board)
                        laeuft = false
                        if geklappt {
                            ladeTeilnehmerNeu(board)
                        } else {
                            fehler = "Das hat nicht geklappt. Entfernen darf nur, "
                                   + "wem die Tafel gehört."
                        }
                    }
                }
                Button("Abbrechen", role: .cancel) { }
            } message: { person in
                Text("\(person.name) sieht die Tafel danach nicht mehr. Alle "
                     + "anderen behalten sie. Wer sie vorher als eigene "
                     + "übernommen hat, behält seine Kopie.")
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
                // Erst die Tafel hochladen, dann das Blatt öffnen. Der
                // Vorbereitungs-Rückruf des Blattes darf nicht lange
                // brauchen — siehe `BoardStore.tafelHochladen`.
                fehler = nil
                store.freigabefehler = nil
                Task {
                    laeuft = true
                    await store.tafelHochladen(board)
                    laeuft = false
                    freigabewahl.oeffne(boardID: board.id, titel: board.name)
                }
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

        loeschrechtAbschnitt(board)
    }

    /// Wer auf dieser Tafel löschen darf — nur die Besitzerin stellt das ein.
    ///
    /// Steht bewusst hier und nicht unter „Aussehen": Es ist eine Frage des
    /// Zusammenarbeitens, keine der Gestaltung, und gesucht wird sie genau
    /// dann, wenn man gerade jemanden einlädt.
    @ViewBuilder
    private func loeschrechtAbschnitt(_ board: Board) -> some View {
        let gewaehlt = Loeschrecht.aus(board.loeschrecht)
        Section {
            Picker("Löschen dürfen", selection: Binding(
                get: { gewaehlt },
                set: { neu in
                    var geaendert = board
                    geaendert.loeschrecht = neu.rawValue
                    store.updateBoard(geaendert)
                }
            )) {
                ForEach(Loeschrecht.allCases) { moeglichkeit in
                    Label(moeglichkeit.titel, systemImage: moeglichkeit.symbol)
                        .tag(moeglichkeit)
                }
            }
            .pickerStyle(.inline)

            Text(gewaehlt.hinweis)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Löschen")
        } footer: {
            Text("Anlegen, verschieben und Inhalte ändern dürfen immer alle — "
                 + "hier geht es nur ums Löschen, weil das der einzige Schritt "
                 + "ist, der sich nicht zurücknehmen lässt.\n\n"

                 + "Dir gehört die Tafel: Du darfst in jedem Fall alles löschen. "
                 + "Elemente, die vor dieser Fassung angelegt wurden, tragen "
                 + "keinen Vermerk, wer sie angelegt hat — sie zählen als "
                 + "deine.\n\n"

                 + "Wer ein fremdes Element nicht mehr sehen mag, blendet es "
                 + "über die Leiste am Element nur für sich aus. Bei den "
                 + "anderen bleibt es stehen.")
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
            if ladeTeilnehmer && teilnehmer.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Wird aus iCloud geholt …").foregroundStyle(.secondary)
                }
            } else if teilnehmer.isEmpty {
                Text(board.geteilt ? "Noch niemand — der Link ist unterwegs."
                                   : "Diese Tafel ist nicht geteilt.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(teilnehmer) { person in
                    HStack(spacing: 10) {
                        Image(systemName: person.istBesitzer ? "crown"
                              : (person.hatAngenommen ? "person.circle.fill"
                                                      : "person.crop.circle.badge.clock"))
                            .foregroundStyle(person.hatAngenommen ? Theme.mint : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.binIchSelbst ? "\(person.name) (du)" : person.name)
                            Text(person.kennzeichen)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        // Die Besitzerin lässt sich nicht entfernen — ihr
                        // gehört die Tafel. Und wer selbst Gast ist, beendet
                        // die eigene Teilnahme über den Knopf oben.
                        if !person.istBesitzer, !store.istGast(board) {
                            Button(role: .destructive) {
                                fragtEntfernen = person
                            } label: {
                                Label("Entfernen", systemImage: "person.badge.minus")
                            }
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Macht mit")
                Spacer()
                Button {
                    ladeTeilnehmerNeu(board)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(ladeTeilnehmer)
            }
        } footer: {
            Text(store.istGast(board)
                 ? "Wer hier steht, kommt aus der Freigabe von iCloud. Ändern "
                   + "kann das nur, wem die Tafel gehört."
                 : "Nach links wischen entfernt eine Person einzeln — die "
                   + "anderen behalten die Tafel. Wer eine Einladung noch "
                   + "nicht angenommen hat, ist iCloud oft nur als Adresse "
                   + "bekannt; dann steht die statt eines Namens.")
        }
        .task(id: board.id) { ladeTeilnehmerNeu(board) }
    }

    private func ladeTeilnehmerNeu(_ board: Board) {
        guard !ladeTeilnehmer else { return }
        ladeTeilnehmer = true
        Task {
            teilnehmer = await store.teilnehmer(fuer: board)
            ladeTeilnehmer = false
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
/// **Die Freigabe steht, bevor das Blatt aufgeht.** Bis 1.1.0 legte das Blatt
/// sie selbst an, über seinen Vorbereitungs-Rückruf — den zugehörigen
/// Erzeuger hat Apple mit iOS 17 für veraltet erklärt. Genommen wird jetzt
/// `init(share:container:)`: Die Freigabe wird vorher angelegt und fertig
/// hereingereicht.
///
/// Dass genau das früher schiefging (1.0.58, 1.0.59: „Link kopieren" kopierte
/// nichts), lag nicht am Vorab-Anlegen. Es fehlte der Record-Typ
/// `cloudkit.share` im Schema, und weitergereicht wurde das hingeschickte
/// statt des zurückgemeldeten Objekts. Beides ist behoben, und
/// `legeFreigabeAn` gibt seit 1.1.1 nichts mehr heraus, was keine Adresse
/// hat — ein Blatt ohne Link kann so gar nicht mehr entstehen.
///
/// Fehler werden roh durchgereicht: Das Blatt zeigt Apples Wortlaut, und der
/// ist die bessere Spur.
final class Freigabewahl: NSObject, UICloudSharingControllerDelegate {
    private var titel = ""

    /// Läuft gerade die Vorbereitung? Sie dauert einen Augenblick, und in
    /// dieser Lücke soll ein zweiter Tipp nichts auslösen.
    private var bereitetVor = false

    /// Das gezeigte Blatt. **Schwach und über den Präsentierenden geprüft,
    /// nicht als Merker.** Ein einfaches „offen"-Flag blieb hängen, wenn der
    /// Nutzer das Blatt schlicht wieder zumachte: Es meldet das Schließen
    /// nicht, nur das Sichern und das Beenden der Freigabe. Danach tat
    /// „Tafel freigeben" gar nichts mehr.
    private weak var blatt: UICloudSharingController?

    private var laeuft: Bool {
        bereitetVor || blatt?.presentingViewController != nil
    }

    func oeffne(boardID: String, titel: String) {
        guard !laeuft else { return }
        bereitetVor = true
        self.titel = titel

        Task { @MainActor in
            defer { self.bereitetVor = false }
            guard let board = BoardStore.shared.board(boardID) else {
                BoardStore.shared.freigabefehler =
                    CloudSyncEngine.Freigabefehler.tafelFehlt.localizedDescription
                return
            }
            switch await BoardStore.shared.bereiteFreigabeVor(fuer: board) {
            case .success(let share):
                self.zeige(share)
            case .failure(let fehler):
                // Festhalten, nicht nur weiterreichen: Sonst bliebe von der
                // Auskunft aus iCloud nichts übrig.
                BoardStore.shared.freigabefehler = Self.klartext(fehler)
            }
        }
    }

    /// Das Blatt — erst hier, mit einer Freigabe, die eine Adresse hat.
    private func zeige(_ share: CKShare) {
        guard let halter = Oberflaeche.obersterHalter() else { return }
        let neues = UICloudSharingController(
            share: share,
            container: CKContainer(identifier: CloudSyncEngine.containerID))
        // Nur-Lesen gibt es hier bewusst nicht (siehe Hinweistext im Blatt).
        neues.availablePermissions = [.allowPublic, .allowReadWrite]
        neues.delegate = self
        blatt = neues
        Oberflaeche.ausMitte(neues, in: halter)
        halter.present(neues, animated: true)
    }

    func itemTitle(for controller: UICloudSharingController) -> String? { titel }

    func cloudSharingController(_ controller: UICloudSharingController,
                                failedToSaveShareWithError error: Error) {
        Task { @MainActor in
            BoardStore.shared.freigabefehler = Self.klartext(error)
        }
    }

    /// Der Fehler von iCloud, so genau wie er zu bekommen ist — samt Nummer.
    /// Apples Blatt zeigt nur einen allgemeinen Satz; ohne die Nummer ist
    /// nicht zu unterscheiden, woran es liegt.
    static func klartext(_ fehler: Error) -> String {
        guard let ck = fehler as? CKError else { return fehler.localizedDescription }
        var text = "iCloud-Fehler \(ck.errorCode): \(ck.localizedDescription)"
        if let grund = ck.userInfo[NSUnderlyingErrorKey] as? Error {
            text += "\n\n" + grund.localizedDescription
        }
        return text
    }

    func cloudSharingControllerDidSaveShare(_ controller: UICloudSharingController) {
        Task { @MainActor in BoardStore.shared.syncNow() }
    }

    func cloudSharingControllerDidStopSharing(_ controller: UICloudSharingController) {
        Task { @MainActor in BoardStore.shared.syncNow() }
    }
}
