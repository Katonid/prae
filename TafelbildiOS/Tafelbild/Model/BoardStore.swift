import Foundation
import SwiftUI
import CloudKit

// Zentraler Zustand der App: Tafeln, Namenslisten, Mediendateien,
// Persistenz (JSON im Documents-Ordner) und die CloudKit-Anbindung.
//
// Sichtbar ist eine Tafel, wenn der eigene Anzeigename in ihrer
// Mitgliederliste steht oder sie auf diesem Gerät angelegt wurde. Dadurch
// funktioniert die App auch ohne eingetragenen Namen, und geteilte Tafeln
// tauchen auf, sobald ein Einladungslink angenommen wurde.

@MainActor
final class BoardStore: ObservableObject {
    static let shared = BoardStore()

    @Published private(set) var boards: [Board] = []
    @Published private(set) var nameLists: [NameList] = []

    @Published var activeBoardID: String = "" {
        didSet { defaults.set(activeBoardID, forKey: "activeBoardID") }
    }
    @Published var profileName: String = "" {
        didSet {
            defaults.set(profileName, forKey: "profileName")
            adoptOwnBoards()
        }
    }
    @Published var syncEnabled: Bool {
        didSet {
            defaults.set(syncEnabled, forKey: "syncEnabled")
            engine.enabled = syncEnabled
            if syncEnabled {
                engine.ensureSubscription()
                engine.syncNow()
            }
        }
    }
    @Published var syncStatus: SyncStatus = .idle

    /// Kurze Rückmeldung am oberen Rand (verschwindet von selbst).
    @Published var statusMessage: String?
    /// Was beim Teilen zuletzt schiefging — im Teilen-Blatt nachzulesen.
    ///
    /// Bewusst nicht als flüchtiger Hinweis: Apples Blatt zeigt bei einem
    /// Fehler nur „Es konnte kein Link zum Teilen erstellt werden" und
    /// verschluckt damit die Auskunft von iCloud, auf die es ankommt.
    @Published var freigabefehler: String?

    /// Kennung des angemeldeten iCloud-Kontos. Sie ist auf allen Geräten
    /// derselben Apple-ID gleich und entscheidet, welche Tafeln mir gehören.
    @Published private(set) var myUserID: String?

    // Reine Bedienzustände (werden nicht gespeichert)
    @Published var editing: Bool = false
    @Published var selectedWidgetID: String?
    @Published var presenting: Bool = false

    /// Welche Seite der aktiven Tafel gerade zu sehen ist.
    ///
    /// Bewusst NICHT abgeglichen: Wer am iPad blättert, soll nicht der
    /// Kollegin an der Wandtafel die Seite wegziehen. Leer = erste Seite.
    @Published var aktiveSeitenID: String = ""
    /// Schreiben und Markieren auf der Tafel ist eingeschaltet.
    @Published var drawing: Bool = false
    /// Nur der Apple Pencil schreibt — der Finger bleibt zum Bedienen frei.
    @Published var pencilOnly: Bool {
        didSet { UserDefaults.standard.set(pencilOnly, forKey: "tafelbild.pencilOnly") }
    }
    /// Element, dessen Einstellungsblatt gerade offen ist.
    @Published var settingsWidgetID: String?
    /// Der Sitzplan, dessen Plätze gerade angeordnet werden.
    ///
    /// An der Wurzel und nicht im Einstellungsblatt: Ein Blatt auf dem iPad
    /// ist ein Kärtchen in der Bildschirmmitte, und der Grundriss bekam
    /// darin ein Drittel der Höhe und ein Fünftel der Breite — zu wenig,
    /// um dreißig Tische mit dem Finger zu treffen (gemeldet 08/2026).
    /// Von hier aus geht er über die ganze Fläche.
    @Published var sitzplanWidgetID: String?
    /// Element, für das gerade „Auf eine andere Tafel“ offen ist.
    @Published var uebertragenWidgetID: String?

    let engine = CloudSyncEngine()

    private let defaults = UserDefaults.standard
    private var saveTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var mediaFetches = Set<String>()
    /// Die Beispieltafel wartet auf den ersten Abgleich — sonst entstünde
    /// auf einem zweiten Gerät eine zweite Tafel neben der bereits
    /// vorhandenen.
    private var starterPending = false

    // MARK: - Start

    private init() {
        syncEnabled = defaults.object(forKey: "syncEnabled") as? Bool ?? true
        pencilOnly = defaults.bool(forKey: "tafelbild.pencilOnly")
        profileName = defaults.string(forKey: "profileName") ?? ""
        activeBoardID = defaults.string(forKey: "activeBoardID") ?? ""
        ladeAblage()

        boards = Self.loadJSON([Board].self, from: Self.boardsURL) ?? []
        nameLists = Self.loadJSON([NameList].self, from: Self.nameListsURL) ?? []

        myUserID = defaults.string(forKey: "sync.userID")

        // Beispieltafel: Auf einem frisch eingerichteten Gerät zuerst den
        // Abgleich abwarten — sonst steht die Beispieltafel neben den
        // Tafeln, die gleich aus iCloud eintreffen.
        if boards.isEmpty && nameLists.isEmpty && !defaults.bool(forKey: "starterCreated") {
            if syncEnabled {
                starterPending = true
            } else {
                createStarterContent()
            }
        }

        if activeBoard == nil { activeBoardID = visibleBoards.first?.id ?? "" }

        let abgleich = syncEnabled
        engine.enabled = abgleich
        syncStatus = abgleich ? .idle : .off
        wireEngine()
        guard abgleich else { return }
        uploadAfterUpdateIfNeeded()
        engine.ensureSubscription()
        engine.syncNow()
        pruneUnusedMedia()
        Task { await ensureMediaForVisibleBoards() }
    }

    /// Form der hochgeladenen Daten. Wird sie erhöht, lädt jedes Gerät seinen
    /// Bestand beim nächsten Start einmal neu hoch — so kommen Neuerungen wie
    /// die mitgereisten Namenslisten auch bei Tafeln an, die sich seit dem
    /// Update nicht geändert haben. Ohne das müsste man von Hand nachhelfen.
    private static let uploadFormat = 2

    private func uploadAfterUpdateIfNeeded() {
        guard syncEnabled else { return }
        guard defaults.integer(forKey: "sync.uploadFormat") < Self.uploadFormat else { return }
        defaults.set(Self.uploadFormat, forKey: "sync.uploadFormat")
        for board in boards where !board.deleted && isMember(of: board) {
            engine.enqueue(kind: .board, entityId: board.id)
        }
        for list in nameLists where !list.deleted {
            engine.enqueue(kind: .nameList, entityId: list.id)
        }
    }

    /// Legt die Beispieltafel samt Namensliste an (erster Start).
    private func createStarterContent() {
        guard !defaults.bool(forKey: "starterCreated") else { return }
        let list = StarterContent.makeNameList(owner: profileName)
        var board = StarterContent.makeBoard(owner: profileName)
        board.ownerUserID = myUserID ?? ""
        // Beispiel-Namensliste gleich im Zufallsgenerator hinterlegen.
        for index in board.widgets.indices {
            if case .namePicker(var content) = board.widgets[index].content {
                content.listID = list.id
                board.widgets[index].content = .namePicker(content)
            }
        }
        nameLists.append(list)
        boards.append(board)
        ownBoardIDs.insert(board.id)
        activeBoardID = board.id
        defaults.set(true, forKey: "starterCreated")
        starterPending = false
        saveNow()
        engine.enqueue(kind: .nameList, entityId: list.id)
        engine.enqueue(kind: .board, entityId: board.id)
    }

    /// Nach dem ersten Abgleich entscheiden, ob es eine Beispieltafel braucht.
    /// Nach jedem Abgleich: fehlende Bilder, Töne und Namenslisten nachholen.
    private func fetchMissingContent() {
        Task {
            await ensureMediaForVisibleBoards()
            await fetchMissingNameLists()
        }
    }

    private func finishFirstSync() {
        guard starterPending else { return }
        starterPending = false
        if visibleBoards.isEmpty {
            createStarterContent()
        } else {
            defaults.set(true, forKey: "starterCreated")
            if activeBoard == nil { activeBoardID = visibleBoards.first?.id ?? "" }
        }
    }

    private func wireEngine() {
        // Die Engine ruft beide Blöcke bereits auf dem Main-Thread auf;
        // assumeIsolated macht das dem Compiler klar.
        engine.onStatusChange = { [weak self] status in
            MainActor.assumeIsolated { self?.syncStatus = status }
        }
        engine.onRemoteChanges = { [weak self] changes in
            MainActor.assumeIsolated { self?.applyRemote(changes) }
        }
        engine.onSyncFinished = { [weak self] in
            MainActor.assumeIsolated {
                self?.finishFirstSync()
                self?.fetchMissingContent()
            }
        }
        engine.onUserIDChange = { [weak self] userID in
            MainActor.assumeIsolated { self?.adoptUserID(userID) }
        }
        // Zu welcher geteilten Tafel eine Mediendatei gehört. Nur was an der
        // Tafel hängt, reist mit einer Freigabe mit — sonst käme die Tafel bei
        // der Kollegin an, aber alle Bildrahmen blieben leer.
        engine.elternProvider = { [weak self] datei in
            guard let self else { return nil }
            let suche: () -> String? = {
                MainActor.assumeIsolated {
                    self.boards.first {
                        !$0.deleted && $0.geteilt && $0.syncedMedia.contains(datei)
                    }?.id
                }
            }
            if Thread.isMainThread { return suche() }
            return DispatchQueue.main.sync(execute: suche)
        }
        engine.onFreigabenAenderung = { [weak self] in
            MainActor.assumeIsolated { self?.syncNow() }
        }
        engine.payloadProvider = { [weak self] kind, entityId in
            guard let self else { return nil }
            if Thread.isMainThread {
                return MainActor.assumeIsolated { self.payload(kind: kind, entityId: entityId) }
            }
            return DispatchQueue.main.sync {
                MainActor.assumeIsolated { self.payload(kind: kind, entityId: entityId) }
            }
        }
    }

    func syncNow() {
        engine.syncNow()
        Task { await ensureMediaForVisibleBoards() }
    }

    func appBecameActive() {
        syncNow()
        resetDailyChecklistsIfNeeded()
        startAutoRefresh()
    }

    /// Solange die Tafel zu sehen ist, alle 15 Sekunden nach Änderungen
    /// schauen — eine Tafel hängt oft eine ganze Stunde am Beamer, ohne dass
    /// jemand die App wechselt.
    func startAutoRefresh() {
        stopAutoRefresh()
        guard syncEnabled else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled, let self, self.syncEnabled else { return }
                self.engine.syncNow()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Persistenz

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private static var boardsURL: URL { documentsURL.appendingPathComponent("tafelbild-boards.json") }
    private static var nameListsURL: URL { documentsURL.appendingPathComponent("tafelbild-namelists.json") }

    private static func loadJSON<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func saveJSON<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Sammelt Änderungen kurz, damit Ziehen und Tippen nicht bei jedem
    /// Bildaufbau auf die Festplatte schreiben.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        Self.saveJSON(boards, to: Self.boardsURL)
        Self.saveJSON(nameLists, to: Self.nameListsURL)
    }

    // MARK: - Sichtbarkeit

    /// IDs der auf diesem Gerät angelegten bzw. beigetretenen Tafeln.
    private var ownBoardIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: "ownBoardIDs") ?? []) }
        set { defaults.set(Array(newValue), forKey: "ownBoardIDs") }
    }

    /// Wem gehört eine Tafel bzw. wer darf sie sehen?
    ///
    /// Maßgeblich ist die iCloud-Kennung: Sie ist auf allen Geräten derselben
    /// Apple-ID gleich, deshalb taucht eine Tafel dort ohne jede Einstellung
    /// auf. Dazu kommen die auf diesem Gerät angelegten Tafeln und — für
    /// Bestandsdaten — der eingetragene Anzeigename.
    private func isMember(of board: Board) -> Bool {
        if ownBoardIDs.contains(board.id) { return true }
        if let me = myUserID, !me.isEmpty {
            if board.ownerUserID == me { return true }
            if board.memberUserIDs.contains(me) { return true }
        }
        guard let name = profileName.nonEmpty?.lowercased() else { return false }
        return board.members.contains { $0.trimmed.lowercased() == name }
    }

    /// Die iCloud-Kennung steht (erstmals) fest: eigene Tafeln damit stempeln,
    /// damit sie auf den anderen Geräten desselben Kontos auftauchen.
    private func adoptUserID(_ userID: String) {
        guard !userID.isEmpty else { return }
        myUserID = userID
        var changed = false
        for index in boards.indices where ownBoardIDs.contains(boards[index].id) {
            if boards[index].ownerUserID.isEmpty {
                boards[index].ownerUserID = userID
                boards[index].updatedAtMs = Date.nowMs
                engine.enqueue(kind: .board, entityId: boards[index].id)
                changed = true
            } else if boards[index].ownerUserID != userID,
                      !boards[index].memberUserIDs.contains(userID) {
                // Beigetretene Tafel: eigene Kennung als Mitglied ergänzen.
                boards[index].memberUserIDs.append(userID)
                boards[index].updatedAtMs = Date.nowMs
                engine.enqueue(kind: .board, entityId: boards[index].id)
                changed = true
            }
        }
        if changed { scheduleSave() }
        if activeBoard == nil { activeBoardID = visibleBoards.first?.id ?? "" }
    }

    var visibleBoards: [Board] {
        boards.filter { !$0.deleted && isMember(of: $0) }
            .sorted { $0.createdAtMs < $1.createdAtMs }
    }

    var activeBoard: Board? {
        visibleBoards.first { $0.id == activeBoardID } ?? visibleBoards.first
    }

    var visibleNameLists: [NameList] {
        nameLists.filter { !$0.deleted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Anzahl aller (auch fremder) Tafeln im lokalen Bestand — für die Diagnose.
    var allBoardsCount: Int { boards.filter { !$0.deleted }.count }

    func board(_ id: String) -> Board? { boards.first { $0.id == id } }
    func nameList(_ id: String?) -> NameList? {
        guard let id else { return nil }
        return nameLists.first { $0.id == id && !$0.deleted }
    }

    /// Trägt den eigenen Namen in alle eigenen Tafeln ein — z. B. wenn der
    /// Name erst nachträglich in den Einstellungen gesetzt wird.
    private func adoptOwnBoards() {
        guard let me = profileName.nonEmpty else { return }
        var changed = false
        for index in boards.indices where ownBoardIDs.contains(boards[index].id) {
            if !boards[index].members.contains(where: { $0.trimmed.lowercased() == me.lowercased() }) {
                boards[index].members.append(me)
                boards[index].updatedAtMs = Date.nowMs
                engine.enqueue(kind: .board, entityId: boards[index].id)
                changed = true
            }
            if boards[index].owner.isEmpty {
                boards[index].owner = me
                changed = true
            }
        }
        if changed { scheduleSave() }
    }

    // MARK: - Tafeln

    @discardableResult
    func createBoard(name: String = "Neue Tafel", emoji: String = "🌟") -> Board {
        var board = Board(name: name, emoji: emoji, owner: profileName)
        if let me = profileName.nonEmpty { board.members = [me] }
        board.ownerUserID = myUserID ?? ""
        boards.append(board)
        ownBoardIDs.insert(board.id)
        activeBoardID = board.id
        touch(board.id)
        return board
    }

    @discardableResult
    func duplicateBoard(_ board: Board) -> Board {
        var copy = board
        copy.id = UUID().uuidString
        copy.name = board.name + " (Kopie)"
        copy.joinCode = Board.makeJoinCode()
        copy.createdAtMs = Date.nowMs
        copy.owner = profileName
        copy.members = profileName.nonEmpty.map { [$0] } ?? []
        copy.ownerUserID = myUserID ?? ""
        copy.memberUserIDs = []
        copy.widgets = board.widgets.map { widget in
            var new = widget
            new.id = UUID().uuidString
            return new
        }
        boards.append(copy)
        ownBoardIDs.insert(copy.id)
        activeBoardID = copy.id
        touch(copy.id)
        return copy
    }

    func updateBoard(_ board: Board) {
        guard let index = boards.firstIndex(where: { $0.id == board.id }) else { return }
        boards[index] = board
        touch(board.id)
    }

    func deleteBoard(_ board: Board) {
        guard let index = boards.firstIndex(where: { $0.id == board.id }) else { return }
        let mine = boards[index].ownerUserID.isEmpty
            ? boards[index].owner.trimmed.lowercased() == profileName.trimmed.lowercased()
            : boards[index].ownerUserID == (myUserID ?? "")
        if mine {
            boards[index].deleted = true
        } else {
            // Fremde Tafel: nur die eigene Mitgliedschaft beenden, damit sie
            // bei den anderen bestehen bleibt.
            if let me = myUserID { boards[index].memberUserIDs.removeAll { $0 == me } }
            if let name = profileName.nonEmpty {
                boards[index].members.removeAll { $0.trimmed.lowercased() == name.lowercased() }
            }
        }
        var ids = ownBoardIDs
        ids.remove(board.id)
        ownBoardIDs = ids
        touch(board.id)
        if activeBoardID == board.id { activeBoardID = visibleBoards.first?.id ?? "" }
    }

    /// Merkt eine Änderung an einer Tafel vor: Zeitstempel, Speichern, Hochladen.
    /// Eine Tafel ändern — der einzige Weg von außerhalb dieser Datei.
    ///
    /// `boards` hat einen dateiprivaten Setter, damit niemand daran vorbei
    /// schreibt und den Zeitstempel vergisst. Erweiterungen in anderen
    /// Dateien (der Geburtstagsdienst) brauchen trotzdem Zugriff — sie
    /// bekommen ihn hier, mit `touch` in der eigenen Hand.
    func aendere(_ boardID: String, _ arbeit: (inout Board) -> Void) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
        arbeit(&boards[index])
    }

    /// Nicht `private`: Der Geburtstagsdienst liegt in einer eigenen Datei
    /// und käme sonst nicht heran (`private` gilt in Swift dateiweit).
    func touch(_ boardID: String, sync: Bool = true) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
        boards[index].updatedAtMs = Date.nowMs
        // Wer zuletzt geschrieben hat, entscheidet beim Empfänger darüber,
        // ob die Anordnung mitzählt (eigenes Gerät) oder nicht (geteilt).
        boards[index].zuletztVon = myUserID ?? ""
        scheduleSave()
        if sync { engine.enqueue(kind: .board, entityId: boardID) }
    }

    // MARK: - Elemente

    func widget(_ widgetID: String, in boardID: String) -> BoardWidget? {
        board(boardID)?.widgets.first { $0.id == widgetID }
    }

    @discardableResult
    func addWidget(kind: WidgetKind, to boardID: String) -> BoardWidget? {
        guard let boardIndex = boards.firstIndex(where: { $0.id == boardID }) else { return nil }
        var widget = BoardWidget(content: .makeDefault(for: kind))
        let size = kind.defaultSize
        widget.width = size.width
        widget.height = size.height
        let spot = freeSpot(for: size, on: boards[boardIndex], seite: aktiveSeitenID)
        widget.x = spot.x
        widget.y = spot.y
        widget.z = (boards[boardIndex].widgets.map(\.z).max() ?? 0) + 1
        // Neue Namensziehung gleich mit der ersten Liste verbinden.
        if case .namePicker(var content) = widget.content, content.listID == nil {
            content.listID = visibleNameLists.first?.id
            widget.content = .namePicker(content)
        }
        // Ein Sitzplan ohne Liste zeigt leere Kästchen — auch er bekommt
        // gleich die erste.
        if case .sitzplan(var content) = widget.content, content.listID == nil {
            content.listID = visibleNameLists.first?.id
            widget.content = .sitzplan(content)
        }
        widget.clampToCanvas(hoehe: boards[boardIndex].hoehe)
        // Auf der Seite anlegen, die gerade zu sehen ist.
        widget.pageID = aktiveSeitenID
        // Wer es angelegt hat — daran hängt auf geteilten Tafeln das
        // Löschrecht (siehe `Loeschrecht`).
        widget.erstelltVon = myUserID ?? ""
        boards[boardIndex].widgets.append(widget)
        selectedWidgetID = widget.id
        touch(boardID)
        return widget
    }

    /// Sucht einen möglichst freien Platz für ein neues Element.
    // MARK: - Seiten

    /// Sorgt dafür, dass die Seitenliste wirklich gefüllt ist.
    ///
    /// Alte Tafeln haben keine Seiten eingetragen — das heißt „genau eine".
    /// Sobald es mehr werden, muss die erste Seite echt werden. Dabei bekommen
    /// **alle** Elemente eine ausdrückliche Seitenzugehörigkeit: Sonst würden
    /// sie beim späteren Löschen der ersten Seite auf die dann erste springen,
    /// weil „leer" ja „erste Seite" bedeutet.
    /// Siehe `touch` — auch das braucht der Geburtstagsdienst.
    func stelleSeitenSicher(_ index: Int) {
        guard boards[index].pages.isEmpty else { return }
        let erste = BoardPage(name: "", drawing: boards[index].drawing)
        boards[index].pages = [erste]
        for i in boards[index].widgets.indices where boards[index].widgets[i].pageID.isEmpty {
            boards[index].widgets[i].pageID = erste.id
        }
    }

    /// Legt eine weitere Seite an und wechselt gleich dorthin.
    @discardableResult
    func seiteAnlegen(boardID: String) -> String? {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return nil }
        stelleSeitenSicher(index)
        let neue = BoardPage()
        boards[index].pages.append(neue)
        aktiveSeitenID = neue.id
        selectedWidgetID = nil
        touch(boardID)
        return neue.id
    }

    func seiteUmbenennen(_ seite: String, auf name: String, boardID: String) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
        stelleSeitenSicher(index)
        guard let seitenIndex = boards[index].pages.firstIndex(where: { $0.id == seite }) else { return }
        boards[index].pages[seitenIndex].name = name.trimmingCharacters(in: .whitespaces)
        touch(boardID)
    }

    /// Eine Seite nur für mich ausblenden — oder wieder zeigen.
    ///
    /// **Nur für mich**, wie beim Ausblenden eines Elements: Auf einer
    /// geteilten Tafel darf jede für sich entscheiden, welche Seiten im
    /// Reiter stehen, ohne sie den anderen wegzunehmen. Der Wert reist
    /// deshalb nicht mit (siehe `Board.mitFremdemInhalt`).
    ///
    /// Die letzte sichtbare Seite lässt sich nicht ausblenden: Der Reiter
    /// wäre leer, und die Tafel zeigte nichts mehr.
    func seiteVerstecken(_ seite: String, boardID: String, versteckt: Bool) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
        stelleSeitenSicher(index)
        guard let seitenIndex = boards[index].pages.firstIndex(where: { $0.id == seite })
        else { return }
        if versteckt {
            let offen = boards[index].pages.filter { !$0.versteckt }.count
            guard offen > 1 else {
                showStatus("Die letzte sichtbare Seite kann nicht ausgeblendet werden.")
                return
            }
        }
        boards[index].pages[seitenIndex].versteckt = versteckt
        // Steht man gerade auf der Seite, die verschwindet, wandert man
        // auf die erste sichtbare — sonst bliebe eine leere Tafel stehen.
        if versteckt, aktiveSeitenID == seite,
           let erste = boards[index].pages.first(where: { !$0.versteckt }) {
            aktiveSeitenID = erste.id
        }
        // **Kein `touch`.** Ausgeblendet ist eine Entscheidung dieses
        // Geräts; der Inhalt der Tafel hat sich nicht geändert. Ein
        // Zeitstempel beanspruchte beim Abgleich einen Vorrang, den es hier
        // nicht gibt — und lüde die Tafel obendrein hoch. Gesichert wird
        // trotzdem, sonst wäre die Entscheidung beim nächsten Start weg.
        scheduleSave()
    }

    /// Löscht eine Seite samt ihrer Elemente. Die letzte bleibt stehen —
    /// eine Tafel ohne Seite gibt es nicht.
    func seiteLoeschen(_ seite: String, boardID: String) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
        stelleSeitenSicher(index)
        guard boards[index].pages.count > 1,
              let seitenIndex = boards[index].pages.firstIndex(where: { $0.id == seite })
        else { return }
        // Eine Seite zu löschen heißt, alles darauf zu löschen — also gilt
        // dieselbe Regel. Sonst wäre der Umweg über die Seite ein Schlupfloch.
        let ich = myUserID ?? ""
        let darauf = boards[index].widgets.filter { boards[index].liegtAuf($0, seite: seite) }
        let fremdes = darauf.filter { !boards[index].darfLoeschen($0, wer: ich) }
        guard fremdes.isEmpty else {
            showStatus("Auf dieser Seite liegen \(fremdes.count) Element(e), die jemand "
                       + "anderes angelegt hat. Die Seite lässt sich deshalb nicht löschen.")
            return
        }
        for element in darauf { merkeGeburtstagWeg(element, boardIndex: index) }
        boards[index].widgets.removeAll { $0.pageID == seite }
        boards[index].pages.remove(at: seitenIndex)
        // Auf die benachbarte Seite wechseln, nicht ins Leere.
        let ziel = min(seitenIndex, boards[index].pages.count - 1)
        aktiveSeitenID = boards[index].pages[ziel].id
        selectedWidgetID = nil
        touch(boardID)
    }

    func seitenVerschieben(from quelle: IndexSet, to ziel: Int, boardID: String) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
        stelleSeitenSicher(index)
        boards[index].pages.move(fromOffsets: quelle, toOffset: ziel)
        touch(boardID)
    }

    /// Kopiert eine Seite samt Elementen — praktisch für wiederkehrende Stunden.
    @discardableResult
    func seiteDuplizieren(_ seite: String, boardID: String) -> String? {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return nil }
        stelleSeitenSicher(index)
        guard let seitenIndex = boards[index].pages.firstIndex(where: { $0.id == seite })
        else { return nil }
        var neue = boards[index].pages[seitenIndex]
        neue.id = UUID().uuidString
        neue.name = boards[index].seitenName(seite) + " (Kopie)"
        let kopien = boards[index].widgets(auf: seite).map { alt -> BoardWidget in
            var neu = alt
            neu.id = UUID().uuidString
            // Neue Kennung heißt: neues Element. Es gehört dem, der es hier
            // anlegt (siehe `Loeschrecht`).
            neu.erstelltVon = myUserID ?? ""
            neu.pageID = neue.id
            return neu
        }
        boards[index].pages.insert(neue, at: seitenIndex + 1)
        boards[index].widgets.append(contentsOf: kopien)
        aktiveSeitenID = neue.id
        selectedWidgetID = nil
        touch(boardID)
        return neue.id
    }

    // MARK: - Zwischenablage

    /// Was zuletzt kopiert wurde.
    ///
    /// Bewusst eine echte Zwischenablage und nicht nur „Duplizieren": Wer
    /// ein Element woanders haben will, denkt in Kopieren und Einfügen — auf
    /// einer anderen Seite, auf einer anderen Tafel, auch Tage später. Sie
    /// übersteht deshalb den Neustart (JSON in den Einstellungen des Geräts).
    ///
    /// Sie liegt **auf dem Gerät**, nicht in iCloud. Der Weg zu einer
    /// Kollegin führt über eine geteilte Tafel: dort einfügen, sie kopiert
    /// es von da aus auf ihre eigene.
    @Published private(set) var ablage: BoardWidget?

    /// Wie das Kopierte heißt — für die Leiste und die Rückmeldung.
    var ablageName: String { ablage?.kind.title ?? "" }

    private func ladeAblage() {
        guard let daten = defaults.data(forKey: "ablageWidget") else { return }
        ablage = try? JSONDecoder().decode(BoardWidget.self, from: daten)
    }

    /// Ein Element in die Zwischenablage legen. Das Element bleibt stehen.
    func kopiereWidget(_ widgetID: String, in boardID: String) {
        guard let widget = board(boardID)?.widgets.first(where: { $0.id == widgetID })
        else { return }
        ablage = widget
        defaults.set(try? JSONEncoder().encode(widget), forKey: "ablageWidget")
        showStatus("„\(ablageName)“ kopiert — unten in der Leiste steht jetzt „Einfügen“.")
    }

    /// Das Kopierte auf der Seite ablegen, die gerade zu sehen ist.
    ///
    /// Was dazugehört, kommt mit: Namenslisten liegen ohnehin neben den
    /// Tafeln, und Klang-, Bild- und Kameradateien stellt die Zieltafel neu
    /// in die Warteschlange zum Hochladen (`ladeMedienNach`).
    @discardableResult
    func fuegeEin(in boardID: String) -> BoardWidget? {
        guard var neu = ablage,
              let index = boards.firstIndex(where: { $0.id == boardID })
        else { return nil }
        stelleSeitenSicher(index)
        let seite = boards[index].seiten.contains { $0.id == aktiveSeitenID }
            ? aktiveSeitenID : boards[index].ersteSeitenID

        neu.id = UUID().uuidString
        neu.erstelltVon = myUserID ?? ""
        neu.pageID = seite
        // Ausgeblendet oder festgesteckt einzufügen wäre eine Falle: Das
        // Element wäre da, ließe sich aber nicht bewegen oder gar nicht
        // sehen — und niemand wüsste, warum.
        neu.versteckt = false
        neu.locked = false
        neu.z = (boards[index].widgets.map(\.z).max() ?? 0) + 1
        let platz = freeSpot(for: CGSize(width: neu.width, height: neu.height),
                             on: boards[index], seite: seite)
        neu.x = platz.x
        neu.y = platz.y
        neu.clampToCanvas(hoehe: boards[index].hoehe)
        boards[index].widgets.append(neu)
        selectedWidgetID = neu.id
        touch(boardID)
        ladeMedienNach(boardID)
        return neu
    }

    /// Zwischenablage leeren.
    func leereAblage() {
        ablage = nil
        defaults.removeObject(forKey: "ablageWidget")
    }

    // MARK: - Auf eine andere Tafel übertragen

    /// Legt ein Element auf einer anderen Tafel ab.
    ///
    /// Was das Element braucht, kommt von selbst mit:
    ///
    /// * **Namenslisten** liegen ohnehin neben den Tafeln und gelten für
    ///   alle. Beim Hochladen nimmt jede Tafel Kopien der Listen mit, die
    ///   ihre Elemente benutzen (siehe `payload`) — die Zieltafel ist damit
    ///   auch für Kolleginnen vollständig.
    /// * **Klang-, Bild- und Kameradateien** liegen unter ihrem Namen im
    ///   Ordner der App; das Element trägt nur den Namen. Neu ist, dass die
    ///   Zieltafel sie jetzt auch braucht — deshalb wandern sie hier in die
    ///   Warteschlange zum Hochladen.
    ///
    /// - Parameter kopieren: `true` lässt das Element stehen, `false`
    ///   verschiebt es.
    @discardableResult
    func uebertrageWidget(_ widgetID: String, von quelle: String, nach ziel: String,
                          seite: String? = nil, kopieren: Bool) -> Bool {
        guard let quellIndex = boards.firstIndex(where: { $0.id == quelle }),
              let zielIndex = boards.firstIndex(where: { $0.id == ziel }),
              let widget = boards[quellIndex].widgets.first(where: { $0.id == widgetID })
        else { return false }

        stelleSeitenSicher(zielIndex)
        let zielSeite = seite ?? boards[zielIndex].ersteSeitenID
        // Auf dieselbe Seite derselben Tafel gibt es nichts zu übertragen —
        // dafür ist „Duplizieren" da.
        guard quelle != ziel || zielSeite != widget.pageID else { return false }

        var neu = widget
        neu.id = UUID().uuidString
        neu.erstelltVon = myUserID ?? ""
        neu.pageID = zielSeite
        neu.z = (boards[zielIndex].widgets.map(\.z).max() ?? 0) + 1
        // Ausgeblendetes wäre auf der neuen Tafel unsichtbar und niemand
        // wüsste, dass es da ist.
        neu.versteckt = false
        neu.clampToCanvas(hoehe: boards[zielIndex].hoehe)
        boards[zielIndex].widgets.append(neu)

        if !kopieren {
            boards[quellIndex].widgets.removeAll { $0.id == widgetID }
            if selectedWidgetID == widgetID { selectedWidgetID = nil }
            touch(quelle)
        }
        touch(ziel)
        ladeMedienNach(ziel)
        return true
    }

    /// Legt eine ganze Seite auf einer anderen Tafel ab — samt ihrer
    /// Elemente und ihrer Handschrift.
    ///
    /// Die letzte Seite einer Tafel lässt sich nur kopieren, nicht
    /// verschieben: Eine Tafel ohne Seite gibt es nicht.
    @discardableResult
    func uebertrageSeite(_ seite: String, von quelle: String, nach ziel: String,
                         kopieren: Bool) -> Bool {
        guard quelle != ziel,
              let quellIndex = boards.firstIndex(where: { $0.id == quelle }),
              let zielIndex = boards.firstIndex(where: { $0.id == ziel })
        else { return false }
        stelleSeitenSicher(quellIndex)
        stelleSeitenSicher(zielIndex)
        guard let vorlage = boards[quellIndex].pages.first(where: { $0.id == seite })
        else { return false }
        let darfWeg = kopieren || boards[quellIndex].pages.count > 1
        guard darfWeg else { return false }

        var neueSeite = vorlage
        neueSeite.id = UUID().uuidString
        if neueSeite.name.isEmpty {
            neueSeite.name = boards[quellIndex].seitenName(seite)
        }
        var hoechstes = boards[zielIndex].widgets.map(\.z).max() ?? 0
        let kopien = boards[quellIndex].widgets(auf: seite, mitVersteckten: true).map {
            alt -> BoardWidget in
            var neu = alt
            neu.id = UUID().uuidString
            // Neue Kennung heißt: neues Element. Es gehört dem, der es hier
            // anlegt (siehe `Loeschrecht`).
            neu.erstelltVon = myUserID ?? ""
            neu.pageID = neueSeite.id
            hoechstes += 1
            neu.z = hoechstes
            return neu
        }
        boards[zielIndex].pages.append(neueSeite)
        boards[zielIndex].widgets.append(contentsOf: kopien)

        if !kopieren {
            boards[quellIndex].widgets.removeAll { $0.pageID == seite }
            boards[quellIndex].pages.removeAll { $0.id == seite }
            if aktiveSeitenID == seite {
                aktiveSeitenID = boards[quellIndex].ersteSeitenID
            }
            selectedWidgetID = nil
            touch(quelle)
        }
        touch(ziel)
        ladeMedienNach(ziel)
        return true
    }

    /// Stellt die Dateien einer Tafel wieder in die Warteschlange.
    private func ladeMedienNach(_ boardID: String) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
        for name in boards[index].syncedMedia where hasMedia(name) {
            engine.enqueue(kind: .media, entityId: name)
        }
    }

    /// Handschrift einer Seite sichern.
    func setzeHandschrift(_ text: String, seite: String, boardID: String) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
        if let seitenIndex = boards[index].pages.firstIndex(where: { $0.id == seite }) {
            guard boards[index].pages[seitenIndex].drawing != text else { return }
            boards[index].pages[seitenIndex].drawing = text
        } else {
            // Tafel ohne eingetragene Seiten — die Handschrift der einen Seite
            // bleibt dort, wo sie immer stand.
            guard boards[index].drawing != text else { return }
            boards[index].drawing = text
        }
        touch(boardID)
    }

    /// Die Handschrift der Seite, die gerade zu sehen ist, ganz entfernen.
    ///
    /// Einzeln wegzuradieren ist mühsam, wenn die Tafel voll ist. Gedacht
    /// als „Schwamm über die Tafel" am Ende der Stunde — deshalb fragt die
    /// Ansicht vorher nach.
    func wischeSeiteFrei(boardID: String) {
        guard let tafel = board(boardID) else { return }
        let seite = tafel.seiten.contains { $0.id == aktiveSeitenID }
            ? aktiveSeitenID : tafel.ersteSeitenID
        setzeHandschrift("", seite: seite, boardID: boardID)
    }

    /// Ist auf der Seite, die gerade zu sehen ist, überhaupt etwas
    /// geschrieben?
    func hatHandschrift(boardID: String) -> Bool {
        guard let tafel = board(boardID) else { return false }
        let seite = tafel.seiten.contains { $0.id == aktiveSeitenID }
            ? aktiveSeitenID : tafel.ersteSeitenID
        return !tafel.handschrift(auf: seite).isEmpty
    }

    /// In welche Richtung zuletzt geblättert wurde: 1 = vorwärts,
    /// -1 = zurück. Die Tafel wandert dadurch dorthin, wo die neue Seite
    /// herkommt — beim Wischen wie beim Tippen auf die Leiste.
    @Published var seitenRichtung = 1

    /// Auf eine Seite wechseln.
    func zeigeSeite(_ seite: String) {
        guard aktiveSeitenID != seite else { return }
        if let seiten = activeBoard?.seiten {
            let alt = seiten.firstIndex { $0.id == aktiveSeitenID } ?? 0
            let neu = seiten.firstIndex { $0.id == seite } ?? alt
            seitenRichtung = neu >= alt ? 1 : -1
        }
        selectedWidgetID = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            aktiveSeitenID = seite
        }
        Haptics.tap()
    }

    /// Eine Seite weiter (1) oder zurück (-1).
    ///
    /// Ohne Umlauf: Am Anfang zurück oder am Ende weiter passiert nichts.
    /// Wer wischt, soll wissen, wo er ist — ein Sprung von der letzten auf
    /// die erste Seite überrascht mitten im Unterricht.
    func blaettere(_ richtung: Int, boardID: String) {
        guard let seiten = board(boardID)?.seiten, seiten.count > 1 else { return }
        let jetzt = seiten.firstIndex { $0.id == aktiveSeitenID } ?? 0
        let ziel = jetzt + richtung
        guard seiten.indices.contains(ziel) else { return }
        zeigeSeite(seiten[ziel].id)
    }

    /// Beim Tafelwechsel auf deren erste Seite stellen.
    func stelleSeiteAufAnfang(_ board: Board) {
        if !board.seiten.contains(where: { $0.id == aktiveSeitenID }) {
            aktiveSeitenID = board.ersteSeitenID
        }
    }

    /// Sucht einen möglichst freien Platz — nur gegen die Elemente derselben
    /// Seite, sonst wiche ein neues Element Dingen aus, die gar nicht zu sehen
    /// sind.
    private func freeSpot(for size: CGSize, on board: Board, seite: String) -> CGPoint {
        let step = Layout.grid * 2
        let boxWidth = Double(size.width)
        let boxHeight = Double(size.height)
        var best = CGPoint(x: 60, y: 60)
        var bestOverlap = Double.greatestFiniteMagnitude
        var y = 40.0
        while y + boxHeight <= board.hoehe - 40 {
            var x = 40.0
            while x + boxWidth <= Layout.canvasWidth - 40 {
                let candidate = CGRect(x: x, y: y, width: boxWidth, height: boxHeight)
                let overlap = board.widgets(auf: seite).reduce(0.0) { sum, widget in
                    let intersection = widget.rect.intersection(candidate)
                    return sum + (intersection.isNull ? 0 : Double(intersection.width * intersection.height))
                }
                if overlap == 0 { return CGPoint(x: x, y: y) }
                if overlap < bestOverlap {
                    bestOverlap = overlap
                    best = CGPoint(x: x, y: y)
                }
                x += step
            }
            y += step
        }
        return best
    }

    /// Ändert ein Element. `transient` = laufende Geste: nur im Speicher,
    /// ohne Schreiben und ohne Hochladen.
    func updateWidget(_ widgetID: String, in boardID: String, transient: Bool = false,
                      _ change: (inout BoardWidget) -> Void) {
        guard let boardIndex = boards.firstIndex(where: { $0.id == boardID }),
              let widgetIndex = boards[boardIndex].widgets.firstIndex(where: { $0.id == widgetID })
        else { return }
        change(&boards[boardIndex].widgets[widgetIndex])
        if !transient { touch(boardID) }
    }

    /// Legt ein Bildelement mit einer schon vorhandenen Mediendatei an.
    ///
    /// Gebraucht von der Dokumentenkamera: Das eingefrorene Bild bleibt als
    /// eigenes Element auf der Tafel stehen, während die Kamera weiterläuft.
    @discardableResult
    func legeBildAb(datei: String, boardID: String) -> BoardWidget? {
        guard let widget = addWidget(kind: .image, to: boardID) else { return nil }
        setContent(.image(ImageContent(fileName: datei)), widgetID: widget.id, boardID: boardID)
        return widget
    }

    func setContent(_ content: WidgetContent, widgetID: String, boardID: String) {
        updateWidget(widgetID, in: boardID) { $0.content = content }
    }

    /// Abschluss einer Zieh- oder Größengeste: jetzt sichern und hochladen.
    func commitLayout(boardID: String) {
        touch(boardID)
    }

    /// Element nur für mich ausblenden — auf einer geteilten Tafel bleibt
    /// es für die anderen stehen.
    func verstecke(_ widgetID: String, in boardID: String) {
        updateWidget(widgetID, in: boardID) { $0.versteckt = true }
        if selectedWidgetID == widgetID { selectedWidgetID = nil }
    }

    func zeigeWieder(_ widgetID: String, in boardID: String) {
        updateWidget(widgetID, in: boardID) { $0.versteckt = false }
    }

    func zeigeAlleWieder(boardID: String) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
        for i in boards[index].widgets.indices { boards[index].widgets[i].versteckt = false }
        touch(boardID)
    }

    /// Darf ich dieses Element löschen? Für die Oberfläche — der Knopf soll
    /// gar nicht erst dastehen, wenn er nichts bewirkt.
    func darfLoeschen(_ widget: BoardWidget, in boardID: String) -> Bool {
        guard let board = board(boardID) else { return false }
        return board.darfLoeschen(widget, wer: myUserID ?? "")
    }

    // MARK: - Zurücksetzen

    /// Ein Element wieder auf „unbenutzt" stellen.
    ///
    /// Was dabei verschwindet, steht in `WidgetContent.unbenutzt(_:)`: der
    /// Ablauf, nie die Einrichtung und nie ein Archiv. Die Vorgabe
    /// `.ergebnis` lässt beim Zufälligen Namen das Gedächtnis stehen.
    @discardableResult
    func setzeZurueck(_ widgetID: String, in boardID: String,
                      tiefe: Ruecksetztiefe = .ergebnis) -> Bool {
        guard let boardIndex = boards.firstIndex(where: { $0.id == boardID }),
              let stelle = boards[boardIndex].widgets.firstIndex(where: { $0.id == widgetID }),
              boards[boardIndex].widgets[stelle].content.benutzt(tiefe)
        else { return false }
        boards[boardIndex].widgets[stelle].content =
            boards[boardIndex].widgets[stelle].content.unbenutzt(tiefe)
        touch(boardID)
        return true
    }

    /// Alle Elemente einer Seite — oder der ganzen Tafel, wenn `pageID`
    /// leer bleibt.
    ///
    /// Gibt zurück, wie viele tatsächlich etwas zu vergessen hatten. Die
    /// Zahl steht hinterher in der Statusmeldung: Wer zurücksetzt, will
    /// wissen, ob etwas passiert ist.
    @discardableResult
    func setzeZurueck(boardID: String, pageID: String? = nil,
                      tiefe: Ruecksetztiefe = .ergebnis) -> Int {
        guard let boardIndex = boards.firstIndex(where: { $0.id == boardID })
        else { return 0 }
        var anzahl = 0
        let tafel = boards[boardIndex]
        for stelle in boards[boardIndex].widgets.indices {
            let widget = boards[boardIndex].widgets[stelle]
            // Über `liegtAuf` und nicht über einen Vergleich der Kennung:
            // Ein leeres `pageID` gehört zur ersten Seite.
            if let pageID, !tafel.liegtAuf(widget, seite: pageID) { continue }
            guard widget.content.benutzt(tiefe) else { continue }
            boards[boardIndex].widgets[stelle].content = widget.content.unbenutzt(tiefe)
            anzahl += 1
        }
        if anzahl > 0 { touch(boardID) }
        return anzahl
    }

    /// Wie viele Elemente hier gerade etwas Benutztes tragen.
    func benutzteElemente(boardID: String, pageID: String? = nil,
                          tiefe: Ruecksetztiefe = .ergebnis) -> Int {
        guard let board = board(boardID) else { return 0 }
        return board.widgets.filter { widget in
            if let pageID, !board.liegtAuf(widget, seite: pageID) { return false }
            return widget.content.benutzt(tiefe)
        }.count
    }

    func removeWidget(_ widgetID: String, from boardID: String) {
        guard let boardIndex = boards.firstIndex(where: { $0.id == boardID }),
              let widget = boards[boardIndex].widgets.first(where: { $0.id == widgetID })
        else { return }
        // Auch hier prüfen und nicht nur in der Oberfläche: Sonst
        // verschwände das Element auf diesem Gerät und käme beim nächsten
        // Abgleich wieder — das sähe nach einem Fehler aus.
        guard boards[boardIndex].darfLoeschen(widget, wer: myUserID ?? "") else {
            showStatus("Dieses Element hat jemand anderes angelegt. Ausblenden geht, "
                       + "löschen nicht.")
            return
        }
        merkeGeburtstagWeg(widget, boardIndex: boardIndex)
        boards[boardIndex].widgets.removeAll { $0.id == widgetID }
        if selectedWidgetID == widgetID { selectedWidgetID = nil }
        touch(boardID)
    }

    /// Hält fest, dass eine Geburtstagsseite oder ihr Hinweis weggeräumt
    /// wurde — sonst legt der Dienst sie beim nächsten Aktivwerden wieder
    /// an, solange der Geburtstag läuft.
    ///
    /// Wird die **Feier** gelöscht, geht der kleine Hinweis auf der ersten
    /// Seite gleich mit: Er zeigte danach auf eine Seite, die es nicht
    /// mehr gibt, und ein Knopf, der ins Leere führt, ist schlimmer als
    /// keiner.
    private func merkeGeburtstagWeg(_ widget: BoardWidget, boardIndex: Int) {
        guard case .geburtstag(let inhalt) = widget.content else { return }
        var merker = boards[boardIndex].geburtstagWeg
        func vormerken(_ eintrag: String) {
            if !merker.contains(eintrag) { merker.append(eintrag) }
        }
        vormerken(Geburtstagsmerker.fuer(inhalt))
        if !inhalt.hinweis {
            vormerken(Geburtstagsmerker.hinweis(inhalt.eintragID, inhalt.jahr))
            boards[boardIndex].widgets.removeAll { anderes in
                guard case .geburtstag(let i) = anderes.content else { return false }
                return i.hinweis && i.eintragID == inhalt.eintragID && i.jahr == inhalt.jahr
            }
        }
        boards[boardIndex].geburtstagWeg = merker
    }

    func duplicateWidget(_ widgetID: String, in boardID: String) {
        guard let boardIndex = boards.firstIndex(where: { $0.id == boardID }),
              let source = boards[boardIndex].widgets.first(where: { $0.id == widgetID })
        else { return }
        var copy = source
        copy.id = UUID().uuidString
        // Eine Kopie gehört dem, der sie macht — nicht dem Urheber des
        // Originals. Sonst könnte man sie hinterher nicht mehr loswerden.
        copy.erstelltVon = myUserID ?? ""
        copy.x = min(source.x + 40, Layout.canvasWidth - source.width)
        copy.y = min(source.y + 40, boards[boardIndex].hoehe - source.height)
        copy.z = (boards[boardIndex].widgets.map(\.z).max() ?? 0) + 1
        boards[boardIndex].widgets.append(copy)
        selectedWidgetID = copy.id
        touch(boardID)
    }

    func bringToFront(_ widgetID: String, in boardID: String) {
        guard let boardIndex = boards.firstIndex(where: { $0.id == boardID }) else { return }
        let top = (boards[boardIndex].widgets.map(\.z).max() ?? 0) + 1
        updateWidget(widgetID, in: boardID) { $0.z = top }
    }

    /// Wechselt das Seitenverhältnis der Tafel.
    ///
    /// Die Breite bleibt bei 1600 Punkten; nur die Höhe ändert sich. Wer
    /// beim Wechsel auf ein flacheres Format unten überstand, rückt herein —
    /// besser, als unsichtbar zu werden.
    func setzeFormat(_ format: Tafelformat, boardID: String) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }),
              boards[index].format != format
        else { return }
        boards[index].format = format
        boards[index].passeElementeAn()
        touch(boardID)
    }

    /// Verschiebt ein Element in der Reihenfolge um einen Platz.
    ///
    /// Gedacht für die Listenansicht, wo die Elemente untereinander stehen
    /// und die Reihenfolge das ist, was man sieht. Geordnet wird nach `z` —
    /// derselben Zahl, die auf der Tafel entscheidet, was vorn liegt. Ein
    /// Zug in der Liste ist deshalb zugleich ein Zug nach vorn oder hinten;
    /// es gibt nur eine Reihenfolge, und das soll auch so bleiben.
    ///
    /// Vor dem Tausch bekommt die Seite lückenlose Nummern. Sonst liefe der
    /// Tausch dort ins Leere, wo zwei Elemente dieselbe Zahl tragen — bei
    /// Tafeln aus früheren Fassungen kommt das vor.
    func verschiebe(_ widgetID: String, in boardID: String, umEinen richtung: Int) {
        guard richtung != 0,
              let boardIndex = boards.firstIndex(where: { $0.id == boardID }),
              let widget = boards[boardIndex].widgets.first(where: { $0.id == widgetID })
        else { return }

        let seite = widget.pageID.isEmpty ? boards[boardIndex].ersteSeitenID : widget.pageID
        var reihe = boards[boardIndex].widgets(auf: seite, mitVersteckten: true)
        guard let stelle = reihe.firstIndex(where: { $0.id == widgetID }) else { return }
        let ziel = stelle + richtung
        guard ziel >= 0, ziel < reihe.count else { return }

        reihe.swapAt(stelle, ziel)
        for (nummer, element) in reihe.enumerated() {
            guard let index = boards[boardIndex].widgets.firstIndex(where: { $0.id == element.id })
            else { continue }
            boards[boardIndex].widgets[index].z = nummer
        }
        touch(boardID)
    }

    func sendToBack(_ widgetID: String, in boardID: String) {
        guard let boardIndex = boards.firstIndex(where: { $0.id == boardID }) else { return }
        let bottom = (boards[boardIndex].widgets.map(\.z).min() ?? 0) - 1
        updateWidget(widgetID, in: boardID) { $0.z = bottom }
    }

    // MARK: - Namenslisten

    @discardableResult
    func createNameList(name: String, entries: [NameEntry] = []) -> NameList {
        let list = NameList(name: name, entries: entries, owner: profileName)
        nameLists.append(list)
        scheduleSave()
        engine.enqueue(kind: .nameList, entityId: list.id)
        return list
    }

    func updateNameList(_ list: NameList) {
        var updated = list
        updated.updatedAtMs = Date.nowMs
        if let index = nameLists.firstIndex(where: { $0.id == list.id }) {
            nameLists[index] = updated
        } else {
            nameLists.append(updated)
        }
        scheduleSave()
        engine.enqueue(kind: .nameList, entityId: updated.id)
        // Tafeln, die diese Liste benutzen, tragen eine Kopie — also mit
        // hochladen, damit die Änderung auch über sie ankommt.
        for board in boards where !board.deleted && board.referencedListIDs.contains(updated.id) {
            engine.enqueue(kind: .board, entityId: board.id)
        }
    }

    /// Legt eine Kopie der Liste an.
    ///
    /// Praktisch, wenn eine Klasse in zwei Fassungen gebraucht wird — die
    /// ganze Klasse und dieselbe ohne die Kinder aus dem Förderunterricht,
    /// oder ein Jahrgang, bei dem nur ein paar Namen abweichen.
    ///
    /// **Alles bekommt neue Kennungen**: die Liste selbst, jeder Name und
    /// jedes Merkmal. Sonst zögen zwei Listen an denselben Einträgen, und
    /// eine Ziehung wüsste nicht, welche gemeint ist.
    @discardableResult
    func duplicateNameList(_ list: NameList) -> NameList {
        var kopie = list
        kopie.id = UUID().uuidString
        kopie.name = Self.naechsterKopiename(list.name, vorhanden: visibleNameLists.map(\.name))
        kopie.owner = profileName
        kopie.deleted = false
        kopie.updatedAtMs = Date.nowMs

        // Merkmale bekommen neue Kennungen; die Werte an den Namen wandern
        // über diese Zuordnung mit.
        var neueMerkmalIDs: [String: String] = [:]
        for index in kopie.merkmale.indices {
            let alt = kopie.merkmale[index].id
            let neu = UUID().uuidString
            neueMerkmalIDs[alt] = neu
            kopie.merkmale[index].id = neu
        }
        for index in kopie.entries.indices {
            kopie.entries[index].id = UUID().uuidString
            var werte: [String: String] = [:]
            for (merkmalID, wert) in kopie.entries[index].merkmale {
                guard let neu = neueMerkmalIDs[merkmalID] else { continue }
                werte[neu] = wert
            }
            kopie.entries[index].merkmale = werte
        }

        nameLists.append(kopie)
        scheduleSave()
        engine.enqueue(kind: .nameList, entityId: kopie.id)
        return kopie
    }

    /// „Klasse 3b" → „Klasse 3b (Kopie)" → „Klasse 3b (Kopie 2)" …
    private static func naechsterKopiename(_ name: String, vorhanden: [String]) -> String {
        let erste = name + " (Kopie)"
        guard vorhanden.contains(erste) else { return erste }
        var nummer = 2
        while vorhanden.contains("\(name) (Kopie \(nummer))") { nummer += 1 }
        return "\(name) (Kopie \(nummer))"
    }

    func deleteNameList(_ list: NameList) {
        var updated = list
        updated.deleted = true
        updateNameList(updated)
    }

    // MARK: - Freigabe

    /// Gehört die Tafel jemand anderem? Dann bin ich hier zu Gast.
    func istGast(_ board: Board) -> Bool {
        engine.istFremd(boardID: board.id)
    }

    /// Bringt die Tafel in die iCloud — **bevor** das Teilen-Blatt aufgeht.
    ///
    /// Das gehört hierher und nicht in den Vorbereitungs-Rückruf des Blattes.
    /// Der Rückruf hat es eilig: Nachrichten und Mail warten darauf, dass die
    /// Freigabe fertig wird, und zeigen so lange eine Sanduhr. Wer dort erst
    /// noch alles Wartende hochlädt — bei Bildern und Klängen schnell etliche
    /// Sekunden —, überzieht die Geduld und bekommt „Es konnte kein Link zum
    /// Teilen erstellt werden" (gemeldet in 1.0.61).
    ///
    /// Also: Hier wird gewartet, mit Fortschrittsanzeige im Blatt. Danach ist
    /// nur noch die Freigabe selbst anzulegen.
    func tafelHochladen(_ board: Board) async {
        if let stelle = boards.firstIndex(where: { $0.id == board.id }), !boards[stelle].geteilt {
            boards[stelle].geteilt = true
            touch(board.id)
        }
        await engine.pushJetzt()

        // Jetzt erst die Dateien: Sie hängen sich an den Datensatz der Tafel,
        // und den muss es dafür schon geben — sonst weist CloudKit den
        // Verweis ab. Erst danach reisen Bilder und Klänge mit der Freigabe.
        if let stelle = boards.firstIndex(where: { $0.id == board.id }) {
            for datei in boards[stelle].syncedMedia where hasMedia(datei) {
                engine.enqueue(kind: .media, entityId: datei)
            }
        }
        await engine.pushJetzt()
    }

    /// Legt die Freigabe an (oder liefert die vorhandene) und merkt sich am
    /// Board, dass es geteilt ist — daran hängen sich Bilder und Klänge,
    /// damit sie mitreisen.
    ///
    /// Gerufen, bevor das Teilen-Blatt aufgeht; das Ergebnis wird ihm fertig
    /// gereicht. Hält sich kurz: Alles Langsame ist in `tafelHochladen` schon
    /// erledigt.
    func bereiteFreigabeVor(fuer board: Board) async -> Result<CKShare, Error> {
        let ergebnis = await engine.bereiteFreigabeVor(fuer: board.id, titel: board.name)
        if case .failure = ergebnis, let stelle = boards.firstIndex(where: { $0.id == board.id }) {
            boards[stelle].geteilt = false
            touch(board.id)
        }
        return ergebnis
    }

    /// Wer diese Tafel sehen darf — aus der Freigabe gelesen, nicht aus
    /// `Board.members` (siehe `CloudSyncEngine.Teilnehmer`).
    func teilnehmer(fuer board: Board) async -> [CloudSyncEngine.Teilnehmer] {
        await engine.teilnehmer(fuer: board.id)
    }

    /// Nimmt einer einzelnen Person den Zugriff. Für alle anderen bleibt die
    /// Freigabe bestehen.
    func teilnehmerEntfernen(_ kennung: String, von board: Board) async -> Bool {
        let geklappt = await engine.entferneTeilnehmer(kennung, von: board.id)
        guard geklappt, let stelle = boards.firstIndex(where: { $0.id == board.id })
        else { return geklappt }
        // Die Anzeigeliste mitziehen, damit die Tafel nicht weiter jemanden
        // nennt, der gar nicht mehr herankommt.
        boards[stelle].memberUserIDs.removeAll { $0 == kennung }
        touch(board.id)
        return true
    }

    /// Nimmt die Freigabe zurück: Die Tafel verschwindet bei allen anderen,
    /// bleibt hier aber unangetastet stehen.
    func freigabeWiderrufen(fuer board: Board) async -> Bool {
        let geklappt = await engine.widerrufeFreigabe(fuer: board.id)
        if geklappt, let stelle = boards.firstIndex(where: { $0.id == board.id }) {
            boards[stelle].geteilt = false
            boards[stelle].memberUserIDs = []
            if let name = profileName.nonEmpty {
                boards[stelle].members = [name]
            } else {
                boards[stelle].members = []
            }
            touch(board.id)
            showStatus("Freigabe zurückgenommen.")
        }
        return geklappt
    }

    /// Beendet die eigene Teilnahme an einer fremden Tafel.
    func freigabeVerlassen(fuer board: Board) async -> Bool {
        let geklappt = await engine.verlasseFreigabe(fuer: board.id)
        guard geklappt else { return false }
        boards.removeAll { $0.id == board.id }
        var ids = ownBoardIDs
        ids.remove(board.id)
        ownBoardIDs = ids
        if activeBoardID == board.id { activeBoardID = visibleBoards.first?.id ?? "" }
        saveNow()
        showStatus("Du nimmst an dieser Tafel nicht mehr teil.")
        return true
    }

    /// Macht aus einer geteilten Tafel eine eigene — vollständig abgekoppelt.
    ///
    /// Das ist der Weg, um eine vorbereitete Tafel weiterzugeben: Die Kollegin
    /// übernimmt sie einmal und arbeitet danach für sich. Deshalb bekommt
    /// **alles** neue Kennungen — die Tafel, ihre Elemente und, wichtig, auch
    /// die Namenslisten. Ohne neue Listen-Kennungen zeigten beide Tafeln
    /// weiter auf dieselbe Liste, und die Namen der einen Klasse stünden in
    /// der anderen.
    @discardableResult
    func alsEigeneUebernehmen(_ board: Board) -> Board {
        var kopie = board
        kopie.id = UUID().uuidString
        kopie.joinCode = Board.makeJoinCode()
        kopie.geteilt = false
        kopie.owner = profileName
        kopie.ownerUserID = myUserID ?? ""
        kopie.members = profileName.nonEmpty.map { [$0] } ?? []
        kopie.memberUserIDs = []
        kopie.zuletztVon = myUserID ?? ""
        kopie.createdAtMs = Date.nowMs
        kopie.updatedAtMs = Date.nowMs
        kopie.embeddedLists = []

        // Die Namenslisten mitkopieren, jede unter neuer Kennung.
        var listenkarte: [String: String] = [:]
        for alteID in board.referencedListIDs {
            guard let vorlage = nameLists.first(where: { $0.id == alteID && !$0.deleted }) else { continue }
            var neue = vorlage
            neue.id = UUID().uuidString
            neue.owner = profileName
            neue.updatedAtMs = Date.nowMs
            nameLists.append(neue)
            listenkarte[alteID] = neue.id
            engine.enqueue(kind: .nameList, entityId: neue.id)
        }

        kopie.widgets = board.widgets.map { element in
            var neu = element
            neu.id = UUID().uuidString
            if case .namePicker(var inhalt) = neu.content {
                if let alt = inhalt.listID, let ersatz = listenkarte[alt] { inhalt.listID = ersatz }
                neu.content = .namePicker(inhalt)
            }
            if case .sitzplan(var inhalt) = neu.content {
                if let alt = inhalt.listID, let ersatz = listenkarte[alt] { inhalt.listID = ersatz }
                neu.content = .sitzplan(inhalt)
            }
            return neu
        }

        boards.append(kopie)
        var ids = ownBoardIDs
        ids.insert(kopie.id)
        ownBoardIDs = ids
        activeBoardID = kopie.id
        touch(kopie.id)
        // Die Dateien liegen schon auf dem Gerät (sie kamen mit der Freigabe),
        // gehören jetzt aber auch in die eigene iCloud.
        for datei in kopie.syncedMedia where hasMedia(datei) {
            engine.enqueue(kind: .media, entityId: datei)
        }
        showStatus("„\(kopie.name)“ ist jetzt deine eigene Tafel.")
        return kopie
    }

    /// Eine Einladung ist angekommen (iOS hat den Freigabe-Link geöffnet).
    func nimmFreigabeAn(_ metadaten: CKShare.Metadata...) {
        engine.nimmAn(metadaten) { [weak self] geklappt in
            MainActor.assumeIsolated {
                guard let self else { return }
                if geklappt {
                    self.showStatus("Einladung angenommen — die Tafel wird geladen.")
                    self.syncNow()
                } else {
                    self.showStatus("Die Einladung ließ sich nicht annehmen. "
                                    + "Ist auf diesem Gerät ein iCloud-Konto angemeldet?")
                }
            }
        }
    }

    // MARK: - Sicherungsdatei

    /// Alle Tafeln und Namenslisten als eine Datei — für ein Backup oder
    /// den Wechsel auf ein anderes Gerät.
    struct BackupFile: Codable {
        var app: String = "tafelbild"
        /// 1 = nur Tafeln und Listen, 2 = mit Dateien.
        var version: Int = 2
        var createdAt: String = ""
        var boards: [Board] = []
        var lists: [NameList] = []
        /// Bilder, Klänge und Kamerabilder — Dateiname → Inhalt als Base64.
        ///
        /// Bewusst in derselben Datei: Eine Sicherung, die stillschweigend
        /// die Bilder verliert, ist eine Falle. Ein Archiv aus mehreren
        /// Dateien wäre kleiner, aber iOS bringt kein Auspacken mit — eine
        /// Sicherung, die sich nicht überall einlesen lässt, taugt nichts.
        ///
        /// **Optional**, damit ältere Sicherungen (Fassung 1) weiter gelesen
        /// werden: Der erzeugte Leser wirft sonst bei einem fehlenden
        /// Schlüssel, auch wenn ein Vorgabewert dasteht.
        var medien: [String: String]?
    }

    /// Schreibt die Sicherung in eine Datei und gibt deren Adresse zurück.
    ///
    /// **Mit Dateien** (Fassung 2). Vorher enthielt sie nur Tafeln und
    /// Listen; wer damit auf ein anderes Gerät zog, stand dort vor leeren
    /// Bildrahmen und stummen Klangfeldern, ohne dass die App etwas gesagt
    /// hätte.
    func writeBackup() -> URL? {
        var file = BackupFile()
        file.createdAt = ISO8601DateFormatter().string(from: Date())
        file.boards = visibleBoards
        file.lists = visibleNameLists

        // Alle Dateien, auf die die gesicherten Tafeln zeigen. Videos sind
        // nicht dabei: Die liegen dort, wo sie ausgewählt wurden, und die
        // App hat nur ihren Namen (siehe `syncedMedia`).
        var medien: [String: String] = [:]
        var bytes = 0
        for name in Set(visibleBoards.flatMap { $0.syncedMedia }) {
            guard let daten = try? Data(contentsOf: MediaStore.url(name)) else { continue }
            medien[name] = daten.base64EncodedString()
            bytes += daten.count
        }
        file.medien = medien.isEmpty ? nil : medien

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(file) else {
            showStatus("Die Sicherung konnte nicht erstellt werden.")
            return nil
        }
        if !medien.isEmpty {
            let mb = Double(bytes) / 1_048_576
            showStatus(String(format: "Sicherung mit %d Datei(en), rund %.1f MB.",
                              medien.count, mb))
        }
        let name = "Tafelbild-Sicherung-" + Self.dayStamp() + ".json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            showStatus("Die Sicherung konnte nicht geschrieben werden.")
            return nil
        }
        return url
    }

    /// Liest eine Sicherung ein. Bestehende Tafeln bleiben stehen; alles
    /// Eingelesene bekommt neue Kennungen, damit nichts überschrieben wird.
    @discardableResult
    func readBackup(from url: URL) -> (boards: Int, lists: Int)? {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(BackupFile.self, from: data) else {
            showStatus("Die Datei konnte nicht gelesen werden.")
            return nil
        }

        // Dateien zuerst wegschreiben: Die Tafeln zeigen mit ihrem Namen
        // darauf, und der bleibt beim Einlesen unverändert. Liegt eine Datei
        // schon da, bleibt sie — die Namen sind Zufallskennungen, gleicher
        // Name heißt gleiche Datei.
        var neueDateien = 0
        for (name, base64) in file.medien ?? [:] {
            guard !MediaStore.exists(name), let daten = Data(base64Encoded: base64) else { continue }
            guard (try? daten.write(to: MediaStore.url(name), options: .atomic)) != nil else { continue }
            engine.enqueue(kind: .media, entityId: name)
            neueDateien += 1
        }

        // Namenslisten zuerst: Die Tafeln zeigen auf ihre Kennungen.
        var listMap: [String: String] = [:]
        var neueListen = 0
        for var list in file.lists where !list.deleted {
            let alt = list.id
            list.id = UUID().uuidString
            list.owner = profileName
            list.updatedAtMs = Date.nowMs
            list.deleted = false
            listMap[alt] = list.id
            updateNameList(list)
            neueListen += 1
        }

        var neueTafeln = 0
        for var board in file.boards where !board.deleted {
            board.id = UUID().uuidString
            board.joinCode = Board.makeJoinCode()
            board.owner = profileName
            board.ownerUserID = myUserID ?? ""
            board.memberUserIDs = []
            board.members = profileName.nonEmpty.map { [$0] } ?? []
            board.createdAtMs = Date.nowMs
            board.updatedAtMs = Date.nowMs
            board.embeddedLists = []
            board.deleted = false
            for index in board.widgets.indices {
                board.widgets[index].id = UUID().uuidString
                if case .namePicker(var content) = board.widgets[index].content {
                    if let alt = content.listID, let neu = listMap[alt] { content.listID = neu }
                    board.widgets[index].content = .namePicker(content)
                }
                if case .sitzplan(var content) = board.widgets[index].content {
                    if let alt = content.listID, let neu = listMap[alt] { content.listID = neu }
                    board.widgets[index].content = .sitzplan(content)
                }
            }
            boards.append(board)
            ownBoardIDs.insert(board.id)
            touch(board.id)
            neueTafeln += 1
        }

        saveNow()
        if activeBoard == nil { activeBoardID = visibleBoards.first?.id ?? "" }
        let dateien = neueDateien > 0 ? ", \(neueDateien) Datei(en)" : ""
        showStatus("\(neueTafeln) Tafeln und \(neueListen) Listen eingelesen\(dateien).")
        return (neueTafeln, neueListen)
    }

    private static func dayStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Medien

    func hasMedia(_ fileName: String) -> Bool {
        MediaStore.exists(fileName)
    }

    /// Legt eine große Datei (Video) lokal ab, ohne sie hochzuladen.
    /// Videos bleiben auf dem Gerät; geteilt wird stattdessen ein Link.
    @discardableResult
    func saveLocalMedia(from source: URL, fileExtension: String) -> String? {
        let name = UUID().uuidString + "." + fileExtension.lowercased()
        let target = MediaStore.url(name)
        let needsAccess = source.startAccessingSecurityScopedResource()
        defer { if needsAccess { source.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.copyItem(at: source, to: target)
        } catch {
            showStatus("Die Datei konnte nicht übernommen werden.")
            return nil
        }
        return name
    }

    /// Platzbedarf aller abgelegten Dateien in Byte.
    var mediaBytes: Int64 {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: MediaStore.directory.path) else { return 0 }
        var total: Int64 = 0
        for entry in entries {
            let values = try? MediaStore.url(entry).resourceValues(forKeys: [.fileSizeKey])
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    /// Entfernt Dateien, die keine Tafel mehr braucht. Gibt die Anzahl zurück.
    @discardableResult
    func removeUnusedMedia() -> Int {
        var referenced = Set<String>()
        for board in boards where !board.deleted { referenced.formUnion(board.referencedMedia) }
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: MediaStore.directory.path) else { return 0 }
        var removed = 0
        for entry in entries where !referenced.contains(entry) {
            if (try? fm.removeItem(at: MediaStore.url(entry))) != nil { removed += 1 }
            MediaCache.shared.forget(entry)
        }
        return removed
    }

    /// Legt eine Datei lokal ab und stellt sie zum Hochladen in die Warteschlange.
    @discardableResult
    func saveMedia(data: Data, fileExtension: String) -> String? {
        let name = UUID().uuidString + "." + fileExtension.lowercased()
        let url = MediaStore.url(name)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            showStatus("Datei konnte nicht gespeichert werden.")
            return nil
        }
        engine.enqueue(kind: .media, entityId: name)
        return name
    }

    /// Holt fehlende Bilder/Töne der sichtbaren Tafeln aus iCloud nach.
    func ensureMediaForVisibleBoards() async {
        guard syncEnabled else { return }
        var wanted = Set<String>()
        for board in visibleBoards { wanted.formUnion(board.syncedMedia) }
        for name in wanted where !hasMedia(name) && !mediaFetches.contains(name) {
            mediaFetches.insert(name)
            let ok = await engine.fetchMedia(fileName: name, to: MediaStore.url(name))
            mediaFetches.remove(name)
            if ok { objectWillChange.send() }
        }
    }

    /// Lädt Namenslisten nach, auf die sichtbare Tafeln verweisen, die aber
    /// lokal fehlen. Das passiert gezielt über die Kennung — dadurch kommt
    /// eine Liste auch dann an, wenn sie beim Delta-Abgleich durchs Raster
    /// gefallen ist (etwa weil sie später hochgeladen wurde, als ihr
    /// Zeitstempel sagt).
    func fetchMissingNameLists() async {
        guard syncEnabled else { return }
        var gesucht = Set<String>()
        for board in visibleBoards {
            for widget in board.widgets {
                if case .namePicker(let content) = widget.content,
                   let listID = content.listID,
                   nameList(listID) == nil {
                    gesucht.insert(listID)
                }
                if case .sitzplan(let content) = widget.content,
                   let listID = content.listID,
                   nameList(listID) == nil {
                    gesucht.insert(listID)
                }
            }
        }
        guard !gesucht.isEmpty else { return }
        let geholt = await engine.fetchEntities(kind: .nameList, ids: Array(gesucht))
        guard !geholt.isEmpty else { return }
        applyRemote(geholt)
    }

    /// Stellt den gesamten eigenen Bestand erneut zum Hochladen ein —
    /// Reparaturbefehl, falls ein Datensatz nie in der Cloud angekommen ist.
    func reuploadEverything() {
        for board in boards where !board.deleted {
            engine.enqueue(kind: .board, entityId: board.id)
        }
        for list in nameLists where !list.deleted {
            engine.enqueue(kind: .nameList, entityId: list.id)
        }
        var medien = Set<String>()
        for board in boards where !board.deleted { medien.formUnion(board.syncedMedia) }
        for name in medien where hasMedia(name) {
            engine.enqueue(kind: .media, entityId: name)
        }
        showStatus("Alles wird neu hochgeladen ...")
        engine.syncNow()
    }

    /// Holt den kompletten Bestand erneut aus der Cloud.
    func reloadEverything() {
        engine.requestFullPull()
        showStatus("Alles wird neu geladen ...")
        engine.syncNow()
        Task {
            await ensureMediaForVisibleBoards()
            await fetchMissingNameLists()
        }
    }

    /// Räumt Dateien weg, die keine Tafel mehr braucht (nur ältere als eine
    /// Stunde, damit gerade importierte Dateien sicher überleben).
    private func pruneUnusedMedia() {
        var referenced = Set<String>()
        for board in boards where !board.deleted { referenced.formUnion(board.referencedMedia) }
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: MediaStore.directory.path) else { return }
        let cutoff = Date().addingTimeInterval(-3600)
        for entry in entries where !referenced.contains(entry) {
            let url = MediaStore.url(entry)
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            if created < cutoff { try? fm.removeItem(at: url) }
        }
    }

    // MARK: - Tagesablauf

    /// Setzt Checklisten mit „täglich zurücksetzen" beim ersten Start des Tages frei.
    func resetDailyChecklistsIfNeeded() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        var changed = false
        for boardIndex in boards.indices {
            for widgetIndex in boards[boardIndex].widgets.indices {
                guard case .checklist(var content) = boards[boardIndex].widgets[widgetIndex].content,
                      content.resetDaily, content.lastResetDay != today else { continue }
                content.lastResetDay = today
                for itemIndex in content.items.indices { content.items[itemIndex].done = false }
                boards[boardIndex].widgets[widgetIndex].content = .checklist(content)
                changed = true
            }
        }
        if changed { scheduleSave() }
    }

    // MARK: - Rückmeldungen

    func showStatus(_ message: String) {
        statusMessage = message
        statusTask?.cancel()
        statusTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.statusMessage = nil
        }
    }

    // MARK: - Cloud-Anbindung

    private func payload(kind: EntityKind, entityId: String) -> (payloadJSON: String, updatedAtMs: Int64, author: String, assetURL: URL?)? {
        let encoder = JSONEncoder()
        switch kind {
        case .board:
            guard var board = boards.first(where: { $0.id == entityId }) else { return nil }
            // Gelöscht heißt gelöscht: Dann geht nur noch ein leerer Vermerk
            // hinaus. Bisher wurde die Tafel mit allem Inhalt erneut
            // hochgeladen — samt Namensliste — und blieb so für immer im
            // Bereich der App stehen. Der Vermerk trägt nur, was die anderen
            // Geräte zum Verstehen brauchen: Kennung, Löschzeichen, Zeit.
            if board.deleted {
                board = board.grabstein()
            } else {
                // Die Tafel nimmt Kopien ihrer Namenslisten mit — so ist sie
                // beim Empfänger sofort vollständig, ganz gleich, was sonst
                // ankommt.
                board.embeddedLists = board.referencedListIDs.compactMap { listID in
                    nameLists.first { $0.id == listID && !$0.deleted }
                }
            }
            guard let data = try? encoder.encode(board),
                  let json = String(data: data, encoding: .utf8) else { return nil }
            return (json, board.updatedAtMs, board.deleted ? "" : profileName, nil)
        case .nameList:
            guard var list = nameLists.first(where: { $0.id == entityId }) else { return nil }
            if list.deleted { list = list.grabstein() }
            guard let data = try? encoder.encode(list),
                  let json = String(data: data, encoding: .utf8) else { return nil }
            return (json, list.updatedAtMs, list.deleted ? "" : profileName, nil)
        case .media:
            let url = MediaStore.url(entityId)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return ("", Date.nowMs, profileName, url)
        }
    }

    /// Entscheidet, wie viel einer ankommenden Fassung gilt.
    ///
    /// Von einem eigenen Gerät zählt alles — dort soll ja jede Änderung
    /// ankommen, auch das Umräumen. Von jemand anderem zählt nur der
    /// Inhalt; die eigene Anordnung bleibt stehen (siehe
    /// `Board.mitFremdemInhalt`).
    ///
    /// Ohne iCloud-Kennung (kein Konto, alter Stand) gilt die vorsichtigere
    /// Regel: lieber die eigene Anordnung behalten als sie unter der Hand
    /// verstellt zu bekommen.
    private func zusammengefuehrt(vorhanden: Board, fremd: Board) -> Board {
        if let ich = myUserID, !ich.isEmpty, fremd.zuletztVon == ich {
            return fremd
        }
        // Eine Tafel, die nur mir gehört, ist kein Fall für die Trennung:
        // Da kommt ohnehin nur mein eigener Stand zurück.
        if fremd.memberUserIDs.count <= 1, fremd.zuletztVon.isEmpty,
           fremd.ownerUserID == (myUserID ?? "") {
            return fremd
        }
        var vereint = vorhanden.mitFremdemInhalt(fremd)
        // Die Löschregel gehört der Besitzerin. Ein Gerät mit älterem Stand
        // kennt das Feld gar nicht und schickte sonst stillschweigend die
        // Vorgabe zurück — die Einstellung spränge dann immer wieder um.
        if let ich = myUserID, !ich.isEmpty, vereint.ownerUserID == ich {
            vereint.loeschrecht = vorhanden.loeschrecht
        }
        return vereint
    }

    private func applyRemote(_ changes: [RemoteEntity]) {
        let decoder = JSONDecoder()
        var changed = false

        for change in changes {
            guard let data = change.payloadJSON.data(using: .utf8) else { continue }
            switch change.kind {
            case .board:
                guard let incoming = try? decoder.decode(Board.self, from: data) else { continue }
                // Mitgereiste Namenslisten in den gemeinsamen Bestand übernehmen.
                for list in incoming.embeddedLists where !list.deleted {
                    if let index = nameLists.firstIndex(where: { $0.id == list.id }) {
                        if list.updatedAtMs > nameLists[index].updatedAtMs {
                            nameLists[index] = list
                            changed = true
                        }
                    } else {
                        nameLists.append(list)
                        changed = true
                    }
                }
                // Lokal ohne die Kopien speichern — die Listen stehen jetzt
                // im gemeinsamen Bestand.
                var board = incoming
                board.embeddedLists = []
                if let index = boards.firstIndex(where: { $0.id == board.id }) {
                    if board.updatedAtMs > boards[index].updatedAtMs {
                        let vereint = zusammengefuehrt(vorhanden: boards[index], fremd: board)
                        // Sind Elemente stehen geblieben, die die Gegenseite
                        // gelöscht hatte, kennt sie diesen Stand nicht — er
                        // muss zurück, sonst bleiben die Geräte auseinander.
                        let gerettet = vereint.widgets.count > board.widgets.count
                        boards[index] = vereint
                        if gerettet {
                            boards[index].updatedAtMs = Date.nowMs
                            boards[index].zuletztVon = myUserID ?? ""
                            engine.enqueue(kind: .board, entityId: board.id)
                        }
                        changed = true
                    }
                } else {
                    // Zum ersten Mal da: genau so übernehmen, wie sie
                    // gedacht ist — mit Anordnung, Farben und allem.
                    boards.append(board)
                    changed = true
                }
                // Aus einer Freigabe? Dann gehört sie jemand anderem, und
                // weder meine iCloud-Kennung noch mein Name stehen darin —
                // ohne diesen Vermerk bliebe sie unsichtbar. Zugleich trage
                // ich mich ein, damit die Besitzerin sieht, wer mitmacht.
                if engine.istFremd(boardID: board.id) {
                    var ids = ownBoardIDs
                    if !ids.contains(board.id) {
                        ids.insert(board.id)
                        ownBoardIDs = ids
                    }
                    if let stelle = boards.firstIndex(where: { $0.id == board.id }) {
                        var eingetragen = false
                        if let me = myUserID, !me.isEmpty,
                           boards[stelle].ownerUserID != me,
                           !boards[stelle].memberUserIDs.contains(me) {
                            boards[stelle].memberUserIDs.append(me)
                            eingetragen = true
                        }
                        if let name = profileName.nonEmpty,
                           !boards[stelle].members.contains(where: { $0.trimmed.lowercased() == name.lowercased() }) {
                            boards[stelle].members.append(name)
                            eingetragen = true
                        }
                        if eingetragen {
                            boards[stelle].updatedAtMs = Date.nowMs
                            engine.enqueue(kind: .board, entityId: board.id)
                            changed = true
                        }
                    }
                }
            case .nameList:
                guard let incoming = try? decoder.decode(NameList.self, from: data) else { continue }
                if let index = nameLists.firstIndex(where: { $0.id == incoming.id }) {
                    if incoming.updatedAtMs > nameLists[index].updatedAtMs {
                        nameLists[index] = incoming
                        changed = true
                    }
                } else {
                    nameLists.append(incoming)
                    changed = true
                }
            case .media:
                // Dateien werden bei Bedarf einzeln geholt, nicht im Delta.
                continue
            }
        }

        if changed {
            if activeBoard == nil { activeBoardID = visibleBoards.first?.id ?? "" }
            saveNow()
            Task { await ensureMediaForVisibleBoards() }
        }
    }
}
