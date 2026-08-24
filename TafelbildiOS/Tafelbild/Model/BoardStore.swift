import Foundation
import SwiftUI

// Zentraler Zustand der App: Tafeln, Namenslisten, Mediendateien,
// Persistenz (JSON im Documents-Ordner) und die CloudKit-Anbindung.
//
// Sichtbar ist eine Tafel, wenn der eigene Anzeigename in ihrer
// Mitgliederliste steht oder sie auf diesem Gerät angelegt wurde. Dadurch
// funktioniert die App auch ohne eingetragenen Namen, und geteilte Tafeln
// tauchen nach dem Beitritt per Einladungscode automatisch auf.

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

    /// Kennung des angemeldeten iCloud-Kontos. Sie ist auf allen Geräten
    /// derselben Apple-ID gleich und entscheidet, welche Tafeln mir gehören.
    @Published private(set) var myUserID: String?

    // Reine Bedienzustände (werden nicht gespeichert)
    @Published var editing: Bool = false
    @Published var selectedWidgetID: String?
    @Published var presenting: Bool = false
    /// Schreiben und Markieren auf der Tafel ist eingeschaltet.
    @Published var drawing: Bool = false
    /// Nur der Apple Pencil schreibt — der Finger bleibt zum Bedienen frei.
    @Published var pencilOnly: Bool {
        didSet { UserDefaults.standard.set(pencilOnly, forKey: "tafelbild.pencilOnly") }
    }
    /// Element, dessen Einstellungsblatt gerade offen ist.
    @Published var settingsWidgetID: String?

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

        engine.enabled = syncEnabled
        syncStatus = syncEnabled ? .idle : .off
        wireEngine()
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
    private func touch(_ boardID: String, sync: Bool = true) {
        guard let index = boards.firstIndex(where: { $0.id == boardID }) else { return }
        boards[index].updatedAtMs = Date.nowMs
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
        let spot = freeSpot(for: size, on: boards[boardIndex])
        widget.x = spot.x
        widget.y = spot.y
        widget.z = (boards[boardIndex].widgets.map(\.z).max() ?? 0) + 1
        // Neue Namensziehung gleich mit der ersten Liste verbinden.
        if case .namePicker(var content) = widget.content, content.listID == nil {
            content.listID = visibleNameLists.first?.id
            widget.content = .namePicker(content)
        }
        widget.clampToCanvas()
        boards[boardIndex].widgets.append(widget)
        selectedWidgetID = widget.id
        touch(boardID)
        return widget
    }

    /// Sucht einen möglichst freien Platz für ein neues Element.
    private func freeSpot(for size: CGSize, on board: Board) -> CGPoint {
        let step = Layout.grid * 2
        let boxWidth = Double(size.width)
        let boxHeight = Double(size.height)
        var best = CGPoint(x: 60, y: 60)
        var bestOverlap = Double.greatestFiniteMagnitude
        var y = 40.0
        while y + boxHeight <= Layout.canvasHeight - 40 {
            var x = 40.0
            while x + boxWidth <= Layout.canvasWidth - 40 {
                let candidate = CGRect(x: x, y: y, width: boxWidth, height: boxHeight)
                let overlap = board.widgets.reduce(0.0) { sum, widget in
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

    func setContent(_ content: WidgetContent, widgetID: String, boardID: String) {
        updateWidget(widgetID, in: boardID) { $0.content = content }
    }

    /// Abschluss einer Zieh- oder Größengeste: jetzt sichern und hochladen.
    func commitLayout(boardID: String) {
        touch(boardID)
    }

    func removeWidget(_ widgetID: String, from boardID: String) {
        guard let boardIndex = boards.firstIndex(where: { $0.id == boardID }) else { return }
        boards[boardIndex].widgets.removeAll { $0.id == widgetID }
        if selectedWidgetID == widgetID { selectedWidgetID = nil }
        touch(boardID)
    }

    func duplicateWidget(_ widgetID: String, in boardID: String) {
        guard let boardIndex = boards.firstIndex(where: { $0.id == boardID }),
              let source = boards[boardIndex].widgets.first(where: { $0.id == widgetID })
        else { return }
        var copy = source
        copy.id = UUID().uuidString
        copy.x = min(source.x + 40, Layout.canvas.width - source.width)
        copy.y = min(source.y + 40, Layout.canvas.height - source.height)
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

    func deleteNameList(_ list: NameList) {
        var updated = list
        updated.deleted = true
        updateNameList(updated)
    }

    // MARK: - Teilen

    /// Beitritt per Einladungscode. Sucht zuerst lokal, dann in der Cloud.
    func joinBoard(code: String, completion: @escaping (Bool) -> Void) {
        let normalized = code.uppercased().trimmed
        guard normalized.count >= 4 else {
            completion(false)
            return
        }
        if adoptBoard(withCode: normalized) {
            completion(true)
            return
        }
        engine.fetchBoards { [weak self] remote in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.applyRemote(remote)
                completion(self.adoptBoard(withCode: normalized))
            }
        }
    }

    private func adoptBoard(withCode code: String) -> Bool {
        guard let index = boards.firstIndex(where: { $0.joinCode.uppercased() == code && !$0.deleted }) else {
            return false
        }
        var ids = ownBoardIDs
        ids.insert(boards[index].id)
        ownBoardIDs = ids
        var changed = false
        if let me = myUserID, !me.isEmpty,
           boards[index].ownerUserID != me,
           !boards[index].memberUserIDs.contains(me) {
            boards[index].memberUserIDs.append(me)
            changed = true
        }
        if let name = profileName.nonEmpty,
           !boards[index].members.contains(where: { $0.trimmed.lowercased() == name.lowercased() }) {
            boards[index].members.append(name)
            changed = true
        }
        if changed { touch(boards[index].id) } else { scheduleSave() }
        activeBoardID = boards[index].id
        Task { await ensureMediaForVisibleBoards() }
        showStatus("Tafel „\(boards[index].name)“ hinzugefügt.")
        return true
    }

    func shareText(for board: Board) -> String {
        """
        Ich teile die Tafel „\(board.name)“ aus der App Tafelbild mit dir.
        Einladungscode: \(board.joinCode)

        In der App: Tafel-Menü → „Tafel beitreten“ → Code eingeben.
        Oder diesen Link auf dem iPad öffnen: tafelbild://join/\(board.joinCode)
        """
    }

    // MARK: - Sicherungsdatei

    /// Alle Tafeln und Namenslisten als eine Datei — für ein Backup oder
    /// den Wechsel auf ein anderes Gerät.
    struct BackupFile: Codable {
        var app: String = "tafelbild"
        var version: Int = 1
        var createdAt: String = ""
        var boards: [Board] = []
        var lists: [NameList] = []
    }

    /// Schreibt die Sicherung in eine Datei und gibt deren Adresse zurück.
    func writeBackup() -> URL? {
        var file = BackupFile()
        file.createdAt = ISO8601DateFormatter().string(from: Date())
        file.boards = visibleBoards
        file.lists = visibleNameLists
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(file) else {
            showStatus("Die Sicherung konnte nicht erstellt werden.")
            return nil
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
            }
            boards.append(board)
            ownBoardIDs.insert(board.id)
            touch(board.id)
            neueTafeln += 1
        }

        saveNow()
        if activeBoard == nil { activeBoardID = visibleBoards.first?.id ?? "" }
        showStatus("\(neueTafeln) Tafeln und \(neueListen) Listen eingelesen.")
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
            // Die Tafel nimmt Kopien ihrer Namenslisten mit — so ist sie beim
            // Empfänger sofort vollständig, ganz gleich, was sonst ankommt.
            board.embeddedLists = board.referencedListIDs.compactMap { listID in
                nameLists.first { $0.id == listID && !$0.deleted }
            }
            guard let data = try? encoder.encode(board),
                  let json = String(data: data, encoding: .utf8) else { return nil }
            return (json, board.updatedAtMs, profileName, nil)
        case .nameList:
            guard let list = nameLists.first(where: { $0.id == entityId }),
                  let data = try? encoder.encode(list),
                  let json = String(data: data, encoding: .utf8) else { return nil }
            return (json, list.updatedAtMs, profileName, nil)
        case .media:
            let url = MediaStore.url(entityId)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return ("", Date.nowMs, profileName, url)
        }
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
                        boards[index] = board
                        changed = true
                    }
                } else {
                    boards.append(board)
                    changed = true
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
