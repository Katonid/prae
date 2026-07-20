import Foundation
import SwiftUI
import Combine

// Zentraler App-Zustand: lokale Persistenz (offline-first) plus CloudKit-Sync.

@MainActor
final class AppStore: ObservableObject {
    @Published var data = TripData()
    @Published var deviceUser = DeviceUser()
    @Published var notices: [AppNotice] = []
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var pendingChanges: Int = 0

    let engine = CloudSyncEngine()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    private var saveWorkItem: DispatchWorkItem?

    // MARK: - Dateipfade

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var dataFileURL: URL { documentsURL.appendingPathComponent("tripData.json") }
    static var noticesFileURL: URL { documentsURL.appendingPathComponent("notices.json") }
    static var photosDirectory: URL {
        let url = documentsURL.appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func photoFileURL(_ photo: PhotoItem) -> URL {
        Self.photosDirectory.appendingPathComponent(photo.fileName)
    }

    // MARK: - Initialisierung

    init() {
        load()
        wireEngine()
        engine.ensureSubscription()
        engine.syncNow()
    }

    private func wireEngine() {
        engine.payloadProvider = { [weak self] kind, entityId in
            guard let self else { return nil }
            // Der Provider läuft auf einer Hintergrund-Queue; Zugriff auf den
            // Store-Zustand deshalb synchron auf den Main-Thread bündeln.
            if Thread.isMainThread {
                return MainActor.assumeIsolated { self.payload(for: kind, entityId: entityId) }
            }
            return DispatchQueue.main.sync {
                MainActor.assumeIsolated { self.payload(for: kind, entityId: entityId) }
            }
        }
        engine.onRemoteChanges = { [weak self] changes in
            self?.applyRemoteChanges(changes)
        }
        engine.onStatusChange = { [weak self] status in
            guard let self else { return }
            self.syncStatus = status
            self.lastSyncDate = self.engine.lastSyncDate
            self.pendingChanges = self.engine.pendingCount
        }
    }

    // MARK: - Laden & Speichern

    private func load() {
        if let raw = try? Data(contentsOf: Self.dataFileURL),
           let loaded = try? decoder.decode(TripData.self, from: raw) {
            data = loaded
        }
        if let raw = try? Data(contentsOf: Self.noticesFileURL),
           let loaded = try? decoder.decode([AppNotice].self, from: raw) {
            notices = loaded
        }
        if let raw = UserDefaults.standard.data(forKey: "deviceUser"),
           let loaded = try? decoder.decode(DeviceUser.self, from: raw) {
            deviceUser = loaded
        }
        lastSyncDate = engine.lastSyncDate
        pendingChanges = engine.pendingCount
    }

    private func persist() {
        saveWorkItem?.cancel()
        let snapshotData = data
        let snapshotNotices = notices
        let item = DispatchWorkItem { [encoder] in
            if let raw = try? encoder.encode(snapshotData) {
                try? raw.write(to: Self.dataFileURL, options: .atomic)
            }
            if let raw = try? encoder.encode(snapshotNotices) {
                try? raw.write(to: Self.noticesFileURL, options: .atomic)
            }
        }
        saveWorkItem = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private func persistDeviceUser() {
        if let raw = try? encoder.encode(deviceUser) {
            UserDefaults.standard.set(raw, forKey: "deviceUser")
        }
    }

    // MARK: - Anmeldung & Rollen

    var isLoggedIn: Bool { deviceUser.selected && !deviceUser.name.isEmpty }
    var isCrew: Bool { deviceUser.isCrew }
    var isAdmin: Bool { deviceUser.isAdmin }
    var isViewer: Bool { deviceUser.isViewer }
    /// Begleiter sehen kein Bingo und keine Challenges.
    var showsGames: Bool { deviceUser.role != .companion }

    enum LoginError: LocalizedError {
        case wrongCode
        case missingName

        var errorDescription: String? {
            switch self {
            case .wrongCode: return "Der Zugangscode ist nicht korrekt."
            case .missingName: return "Bitte gib einen Namen ein."
            }
        }
    }

    func loginCrew(member: String, code: String) throws {
        let clean = code.trimmingCharacters(in: .whitespaces).uppercased()
        // Persönlicher Einladungscode im PWA-Format (z. B. CANADA2026-ANDR-EA26):
        // bestimmt das Mitglied direkt, unabhängig von der Auswahl.
        var resolvedMember = member
        if let matched = crewMember(forInviteCode: clean) {
            resolvedMember = matched
        } else {
            guard clean == data.config.crewCode.uppercased() else {
                throw LoginError.wrongCode
            }
        }
        deviceUser = DeviceUser(
            name: resolvedMember,
            role: resolvedMember == TravelData.adminName ? .admin : .crew,
            viewerId: "",
            selected: true
        )
        persistDeviceUser()
        addNotice(kind: "system", text: "Angemeldet als \(resolvedMember) (\(deviceUser.role.label))", view: "home")
    }

    /// Prüft einen persönlichen Einladungscode: exakter Treffer aus der
    /// Konfiguration gewinnt; sonst zählt das PWA-Format mit Mitglieds-Kürzel.
    private func crewMember(forInviteCode code: String) -> String? {
        if let entry = data.config.effectiveMemberCodes.first(where: { !$0.value.isEmpty && $0.value.uppercased() == code }) {
            return entry.key
        }
        guard let member = InviteCode.crewMember(for: code) else { return nil }
        // Hat der Admin für dieses Mitglied einen festen Code hinterlegt,
        // zählt nur noch dieser (bereits oben geprüft).
        let pinned = data.config.effectiveMemberCodes[member] ?? ""
        return pinned.isEmpty ? member : nil
    }

    func loginViewer(name: String, role: AccessRole, code: String) throws {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { throw LoginError.missingName }
        let expected = role == .family ? data.config.familyCode : data.config.companionCode
        guard code.trimmingCharacters(in: .whitespaces).uppercased() == expected.uppercased() else {
            throw LoginError.wrongCode
        }
        var profile = data.viewerProfiles.first {
            !$0.deleted && $0.displayName.lowercased() == cleanName.lowercased() && $0.role == role.rawValue
        }
        if profile == nil {
            var created = ViewerProfile()
            created.displayName = cleanName
            created.role = role.rawValue
            data.viewerProfiles.append(created)
            profile = created
            touch(.viewerProfile, created.id)
        }
        deviceUser = DeviceUser(name: cleanName, role: role, viewerId: profile?.id ?? "", selected: true)
        persistDeviceUser()
        addNotice(kind: "system", text: "Angemeldet als \(cleanName) (\(role.label))", view: "home")
    }

    func logout() {
        deviceUser = DeviceUser()
        persistDeviceUser()
    }

    // MARK: - Sync-Hilfen

    /// Markiert eine Entität als geändert: lokal speichern und in die Cloud-Outbox legen.
    private func touch(_ kind: EntityKind, _ entityId: String) {
        persist()
        engine.enqueue(kind: kind, entityId: entityId)
        pendingChanges = engine.pendingCount
    }

    func syncNow() {
        engine.syncNow()
    }

    private func encodeEntity<T: Encodable>(_ value: T) -> String {
        guard let raw = try? encoder.encode(value) else { return "{}" }
        return String(data: raw, encoding: .utf8) ?? "{}"
    }

    private func payload(for kind: EntityKind, entityId: String) -> (payloadJSON: String, updatedAtMs: Int64, author: String, assetURL: URL?)? {
        func ms(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }
        switch kind {
        case .message:
            guard let item = data.messages.first(where: { $0.id == entityId }) else { return nil }
            return (encodeEntity(item), ms(item.updatedAt), item.author, nil)
        case .journal:
            guard let item = data.journal.first(where: { $0.id == entityId }) else { return nil }
            return (encodeEntity(item), ms(item.updatedAt), item.author, nil)
        case .photo:
            guard let item = data.photos.first(where: { $0.id == entityId }) else { return nil }
            let url = photoFileURL(item)
            return (encodeEntity(item), ms(item.updatedAt), item.author, item.deleted ? nil : url)
        case .expense:
            guard let item = data.expenses.first(where: { $0.id == entityId }) else { return nil }
            return (encodeEntity(item), ms(item.updatedAt), item.paidBy, nil)
        case .check:
            guard let item = data.checks.first(where: { $0.id == entityId }) else { return nil }
            return (encodeEntity(item), ms(item.updatedAt), item.doneBy, nil)
        case .bingo:
            guard let item = data.bingo.first(where: { $0.id == entityId }) else { return nil }
            return (encodeEntity(item), ms(item.updatedAt), item.member, nil)
        case .challenge:
            guard let item = data.challenges.first(where: { $0.id == entityId }) else { return nil }
            return (encodeEntity(item), ms(item.updatedAt), item.member, nil)
        case .trail:
            guard let item = data.trail.first(where: { $0.id == entityId }) else { return nil }
            return (encodeEntity(item), ms(item.updatedAt), item.member, nil)
        case .bucket:
            guard let item = data.bucketList.first(where: { $0.id == entityId }) else { return nil }
            return (encodeEntity(item), ms(item.updatedAt), item.addedBy, nil)
        case .dailyQuestion:
            guard let item = data.dailyQuestions.first(where: { $0.id == entityId }) else { return nil }
            return (encodeEntity(item), ms(item.updatedAt), item.author, nil)
        case .dailyAnswer:
            guard let item = data.dailyAnswers.first(where: { $0.id == entityId }) else { return nil }
            return (encodeEntity(item), ms(item.updatedAt), item.author, nil)
        case .soundtrack:
            guard let item = data.soundtrack.first(where: { $0.id == entityId }) else { return nil }
            return (encodeEntity(item), ms(item.updatedAt), item.addedBy, nil)
        case .viewerProfile:
            guard let item = data.viewerProfiles.first(where: { $0.id == entityId }) else { return nil }
            return (encodeEntity(item), ms(item.updatedAt), item.displayName, nil)
        case .config:
            return (encodeEntity(data.config), Int64(data.config.updatedAt.timeIntervalSince1970 * 1000), deviceUser.name, nil)
        }
    }

    private func applyRemoteChanges(_ changes: [RemoteEntity]) {
        var changed = false
        for change in changes {
            guard let raw = change.payloadJSON.data(using: .utf8) else { continue }
            switch change.kind {
            case .message:
                if let item = try? decoder.decode(ChatMessage.self, from: raw) {
                    changed = merge(&data.messages, item, isNewer: { $0.updatedAt < item.updatedAt }) || changed
                    if item.author != deviceUser.name && !item.deleted {
                        noteActivityOnce(id: "msg-\(item.id)", text: "Neue Nachricht von \(item.author)", view: "messages")
                    }
                }
            case .journal:
                if let item = try? decoder.decode(JournalEntry.self, from: raw) {
                    changed = merge(&data.journal, item, isNewer: { $0.updatedAt < item.updatedAt }) || changed
                    if item.author != deviceUser.name && !item.deleted {
                        noteActivityOnce(id: "journal-\(item.id)", text: "Neuer Journal-Eintrag von \(item.author)", view: "diary")
                    }
                }
            case .photo:
                if let item = try? decoder.decode(PhotoItem.self, from: raw) {
                    changed = merge(&data.photos, item, isNewer: { $0.updatedAt < item.updatedAt }) || changed
                    if let assetURL = change.assetURL {
                        let target = photoFileURL(item)
                        if !FileManager.default.fileExists(atPath: target.path) {
                            try? FileManager.default.copyItem(at: assetURL, to: target)
                        }
                    }
                    if item.author != deviceUser.name && !item.deleted {
                        noteActivityOnce(id: "photo-\(item.id)", text: "Neues Foto von \(item.author)", view: "photoAlbum")
                    }
                }
            case .expense:
                if let item = try? decoder.decode(Expense.self, from: raw) {
                    changed = merge(&data.expenses, item, isNewer: { $0.updatedAt < item.updatedAt }) || changed
                }
            case .check:
                if let item = try? decoder.decode(CheckState.self, from: raw) {
                    changed = merge(&data.checks, item, isNewer: { $0.updatedAt < item.updatedAt }) || changed
                }
            case .bingo:
                if let item = try? decoder.decode(BingoState.self, from: raw) {
                    changed = merge(&data.bingo, item, isNewer: { $0.updatedAt < item.updatedAt }) || changed
                }
            case .challenge:
                if let item = try? decoder.decode(ChallengeState.self, from: raw) {
                    changed = merge(&data.challenges, item, isNewer: { $0.updatedAt < item.updatedAt }) || changed
                }
            case .trail:
                if let item = try? decoder.decode(TrailPoint.self, from: raw) {
                    changed = merge(&data.trail, item, isNewer: { $0.updatedAt < item.updatedAt }) || changed
                }
            case .bucket:
                if let item = try? decoder.decode(BucketItem.self, from: raw) {
                    changed = merge(&data.bucketList, item, isNewer: { $0.updatedAt < item.updatedAt }) || changed
                }
            case .dailyQuestion:
                if let item = try? decoder.decode(DailyQuestion.self, from: raw) {
                    changed = merge(&data.dailyQuestions, item, isNewer: { $0.updatedAt < item.updatedAt }) || changed
                    if item.author != deviceUser.name && !item.deleted {
                        noteActivityOnce(id: "dq-\(item.id)", text: "Neue Tagesfrage von \(item.author)", view: "dailyQuestion")
                    }
                }
            case .dailyAnswer:
                if let item = try? decoder.decode(DailyAnswer.self, from: raw) {
                    changed = merge(&data.dailyAnswers, item, isNewer: { $0.updatedAt < item.updatedAt }) || changed
                }
            case .soundtrack:
                if let item = try? decoder.decode(SoundtrackItem.self, from: raw) {
                    changed = merge(&data.soundtrack, item, isNewer: { $0.updatedAt < item.updatedAt }) || changed
                }
            case .viewerProfile:
                if let item = try? decoder.decode(ViewerProfile.self, from: raw) {
                    changed = merge(&data.viewerProfiles, item, isNewer: { $0.updatedAt < item.updatedAt }) || changed
                }
            case .config:
                if let item = try? decoder.decode(SharedConfig.self, from: raw), item.updatedAt > data.config.updatedAt {
                    data.config = item
                    changed = true
                }
            }
        }
        if changed { persist() }
        lastSyncDate = engine.lastSyncDate
        pendingChanges = engine.pendingCount
    }

    private func merge<T: Identifiable & Equatable>(_ array: inout [T], _ item: T, isNewer: (T) -> Bool) -> Bool {
        if let index = array.firstIndex(where: { $0.id == item.id }) {
            guard isNewer(array[index]), array[index] != item else { return false }
            array[index] = item
            return true
        }
        array.append(item)
        return true
    }

    // MARK: - Hinweise

    func addNotice(kind: String, text: String, view: String) {
        notices.insert(AppNotice(kind: kind, text: text, view: view), at: 0)
        if notices.count > 100 { notices = Array(notices.prefix(100)) }
        persist()
    }

    private func noteActivityOnce(id: String, text: String, view: String) {
        guard !notices.contains(where: { $0.id == id }) else { return }
        notices.insert(AppNotice(id: id, kind: "activity", text: text, view: view), at: 0)
        if notices.count > 100 { notices = Array(notices.prefix(100)) }
    }

    var unreadNoticeCount: Int { notices.filter { !$0.read }.count }

    func markNoticesRead() {
        guard notices.contains(where: { !$0.read }) else { return }
        notices = notices.map { notice in
            var copy = notice
            copy.read = true
            return copy
        }
        persist()
    }

    // MARK: - Nachrichten

    struct ChatChannel: Identifiable, Equatable {
        let id: String
        let title: String
    }

    var availableChannels: [ChatChannel] {
        isCrew
            ? [ChatChannel(id: "crew", title: "STAN Crew"), ChatChannel(id: "all", title: "Alle zusammen")]
            : [ChatChannel(id: "all", title: "Alle zusammen")]
    }

    func messages(in channel: String) -> [ChatMessage] {
        data.messages
            .filter { $0.channel == channel && !$0.deleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func sendMessage(_ text: String, channel: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var message = ChatMessage()
        message.channel = channel
        message.author = deviceUser.name
        message.authorRole = deviceUser.role.rawValue
        message.text = clean
        data.messages.append(message)
        touch(.message, message.id)
        markChannelRead(channel)
    }

    func deleteMessage(_ message: ChatMessage) {
        guard let index = data.messages.firstIndex(where: { $0.id == message.id }) else { return }
        data.messages[index].deleted = true
        data.messages[index].updatedAt = Date()
        touch(.message, message.id)
    }

    private func lastReadKey(_ channel: String) -> String { "lastRead.\(channel)" }

    func markChannelRead(_ channel: String) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastReadKey(channel))
        objectWillChange.send()
    }

    func unreadCount(channel: String) -> Int {
        let lastRead = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: lastReadKey(channel)))
        return messages(in: channel).filter { $0.createdAt > lastRead && $0.author != deviceUser.name }.count
    }

    var totalUnreadMessages: Int {
        availableChannels.reduce(0) { $0 + unreadCount(channel: $1.id) }
    }

    // MARK: - Journal

    func journalEntries(day: String? = nil) -> [JournalEntry] {
        data.journal
            .filter { !$0.deleted && (day == nil || $0.day == day) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func saveJournalEntry(_ entry: JournalEntry) {
        var copy = entry
        copy.updatedAt = Date()
        if let index = data.journal.firstIndex(where: { $0.id == entry.id }) {
            data.journal[index] = copy
        } else {
            data.journal.append(copy)
        }
        touch(.journal, copy.id)
    }

    func deleteJournalEntry(_ entry: JournalEntry) {
        guard let index = data.journal.firstIndex(where: { $0.id == entry.id }) else { return }
        data.journal[index].deleted = true
        data.journal[index].updatedAt = Date()
        touch(.journal, entry.id)
    }

    // MARK: - Fotos

    var visiblePhotos: [PhotoItem] {
        data.photos.filter { !$0.deleted }.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func addPhoto(imageData: Data, caption: String, bingoTaskId: String = "", challengeId: String = "") -> PhotoItem {
        var item = PhotoItem()
        item.author = deviceUser.name
        item.caption = caption
        item.day = TravelData.isoDay.string(from: Date())
        item.stationId = TravelData.currentStation()?.id ?? ""
        item.bingoTaskId = bingoTaskId
        item.challengeId = challengeId
        try? imageData.write(to: photoFileURL(item), options: .atomic)
        data.photos.append(item)
        touch(.photo, item.id)
        return item
    }

    func updatePhoto(_ photo: PhotoItem) {
        guard let index = data.photos.firstIndex(where: { $0.id == photo.id }) else { return }
        var copy = photo
        copy.updatedAt = Date()
        data.photos[index] = copy
        touch(.photo, copy.id)
    }

    func deletePhoto(_ photo: PhotoItem) {
        guard let index = data.photos.firstIndex(where: { $0.id == photo.id }) else { return }
        data.photos[index].deleted = true
        data.photos[index].updatedAt = Date()
        touch(.photo, photo.id)
    }

    // MARK: - Kosten

    var visibleExpenses: [Expense] {
        data.expenses.filter { !$0.deleted }.sorted { $0.createdAt > $1.createdAt }
    }

    func saveExpense(_ expense: Expense) {
        var copy = expense
        copy.updatedAt = Date()
        if let index = data.expenses.firstIndex(where: { $0.id == expense.id }) {
            data.expenses[index] = copy
        } else {
            data.expenses.append(copy)
        }
        touch(.expense, copy.id)
    }

    func deleteExpense(_ expense: Expense) {
        guard let index = data.expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        data.expenses[index].deleted = true
        data.expenses[index].updatedAt = Date()
        touch(.expense, expense.id)
    }

    // MARK: - Checklisten

    func isChecked(_ checkId: String) -> Bool {
        data.checks.first(where: { $0.id == checkId })?.done ?? false
    }

    func toggleCheck(_ checkId: String) {
        if let index = data.checks.firstIndex(where: { $0.id == checkId }) {
            data.checks[index].done.toggle()
            data.checks[index].doneBy = deviceUser.name
            data.checks[index].updatedAt = Date()
        } else {
            data.checks.append(CheckState(id: checkId, done: true, doneBy: deviceUser.name, updatedAt: Date()))
        }
        touch(.check, checkId)
    }

    // MARK: - Bingo & Challenges

    func bingoState(member: String, taskId: String) -> BingoState? {
        data.bingo.first { $0.member == member && $0.taskId == taskId }
    }

    func toggleBingo(member: String, taskId: String) {
        let id = "\(member)|\(taskId)"
        if let index = data.bingo.firstIndex(where: { $0.id == id }) {
            data.bingo[index].done.toggle()
            data.bingo[index].updatedAt = Date()
        } else {
            data.bingo.append(BingoState(id: id, member: member, taskId: taskId, done: true, photoId: "", updatedAt: Date()))
        }
        touch(.bingo, id)
    }

    func challengeState(member: String, challengeId: String) -> ChallengeState? {
        data.challenges.first { $0.member == member && $0.challengeId == challengeId }
    }

    func toggleChallenge(member: String, challengeId: String) {
        let id = "\(member)|\(challengeId)"
        if let index = data.challenges.firstIndex(where: { $0.id == id }) {
            data.challenges[index].done.toggle()
            data.challenges[index].updatedAt = Date()
        } else {
            data.challenges.append(ChallengeState(id: id, member: member, challengeId: challengeId, done: true, photoId: "", updatedAt: Date()))
        }
        touch(.challenge, id)
    }

    // MARK: - Punkte & Achievements

    func donebingoTasks(member: String) -> [BingoDefinition] {
        TravelData.bingoTasks.filter { task in
            data.bingo.contains { $0.member == member && $0.taskId == task.id && $0.done }
        }
    }

    func doneChallenges(member: String) -> [ChallengeDefinition] {
        TravelData.challenges.filter { challenge in
            data.challenges.contains { $0.member == member && $0.challengeId == challenge.id && $0.done }
        }
    }

    func earnedAchievements(member: String) -> [AchievementDefinition] {
        let bingoDone = donebingoTasks(member: member)
        let challengesDone = doneChallenges(member: member)
        let photoCount = visiblePhotos.filter { $0.author == member }.count
        let stationCount = Set(challengesDone.map { $0.stationId }).count
        let sunItems = (bingoDone.map { $0.title } + challengesDone.map { $0.title })
            .filter { $0.localizedCaseInsensitiveContains("Sonnenauf") || $0.localizedCaseInsensitiveContains("Sonnenunter") }
        return TravelData.achievements.filter { achievement in
            switch achievement.id {
            case "animal-spotter":
                return bingoDone.filter { ["Tiere", "Natur"].contains($0.category) }.count >= 5
            case "photographer":
                return photoCount >= 10
            case "explorer":
                return stationCount >= 5
            case "nature-friend":
                return bingoDone.filter { ["Natur", "Wasser"].contains($0.category) }.count >= 8
            case "city-expert":
                return bingoDone.filter { ["Städte", "Verkehr"].contains($0.category) }.count >= 6
            case "waterfall-hunter":
                return challengesDone.filter { $0.stationId == "niagara-falls" }.count >= 4
            case "island-king":
                return challengesDone.filter { $0.stationId == "thousand-islands" }.count >= 4
            case "canada-pro":
                return bingoDone.count >= 30
            case "sunset-hunter":
                return sunItems.count >= 3
            case "roadtrip-champion":
                return bingoDone.count + challengesDone.count >= 50
            default:
                return false
            }
        }
    }

    func score(member: String) -> Int {
        let bingoPoints = donebingoTasks(member: member).reduce(0) { $0 + $1.points }
        let challengePoints = doneChallenges(member: member).reduce(0) { $0 + $1.points }
        let achievementPoints = earnedAchievements(member: member).reduce(0) { $0 + $1.points }
        return bingoPoints + challengePoints + achievementPoints
    }

    struct ScoreEntry: Identifiable, Equatable {
        let member: String
        let score: Int
        var id: String { member }
    }

    var leaderboard: [ScoreEntry] {
        TravelData.crewNames
            .map { ScoreEntry(member: $0, score: score(member: $0)) }
            .sorted { $0.score > $1.score }
    }

    // MARK: - Reise-Spur

    var visibleTrail: [TrailPoint] {
        data.trail.filter { !$0.deleted }.sorted { $0.createdAt < $1.createdAt }
    }

    func addTrailPoint(lat: Double, lng: Double, note: String) {
        var point = TrailPoint()
        point.member = deviceUser.name
        point.lat = lat
        point.lng = lng
        point.note = note
        data.trail.append(point)
        touch(.trail, point.id)
    }

    func deleteTrailPoint(_ point: TrailPoint) {
        guard let index = data.trail.firstIndex(where: { $0.id == point.id }) else { return }
        data.trail[index].deleted = true
        data.trail[index].updatedAt = Date()
        touch(.trail, point.id)
    }

    // MARK: - Bucket List

    var visibleBucketList: [BucketItem] {
        let custom = data.bucketList.filter { !$0.deleted }
        return custom.sorted { !$0.done && $1.done }
    }

    /// Beim ersten Start die Standard-Bucket-List anlegen (nur einmal pro Gerät nötig,
    /// Duplikate werden über feste IDs vermieden).
    func ensureDefaultBucketList() {
        for (index, text) in TravelData.defaultBucketListItems.enumerated() {
            let id = "bucket-default-\(index + 1)"
            if !data.bucketList.contains(where: { $0.id == id }) {
                var item = BucketItem()
                item.id = id
                item.text = text
                item.addedBy = "Vorlage"
                data.bucketList.append(item)
            }
        }
        persist()
    }

    func addBucketItem(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var item = BucketItem()
        item.text = clean
        item.addedBy = deviceUser.name
        data.bucketList.append(item)
        touch(.bucket, item.id)
    }

    func toggleBucketItem(_ item: BucketItem) {
        guard let index = data.bucketList.firstIndex(where: { $0.id == item.id }) else { return }
        data.bucketList[index].done.toggle()
        data.bucketList[index].doneBy = data.bucketList[index].done ? deviceUser.name : ""
        data.bucketList[index].updatedAt = Date()
        touch(.bucket, item.id)
    }

    func deleteBucketItem(_ item: BucketItem) {
        guard let index = data.bucketList.firstIndex(where: { $0.id == item.id }) else { return }
        data.bucketList[index].deleted = true
        data.bucketList[index].updatedAt = Date()
        touch(.bucket, item.id)
    }

    // MARK: - Tagesfrage

    func todaysQuestion(day: String = TravelData.isoDay.string(from: Date())) -> DailyQuestion? {
        data.dailyQuestions
            .filter { !$0.deleted && $0.day == day }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    func setDailyQuestion(_ question: String, day: String = TravelData.isoDay.string(from: Date())) {
        let clean = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var entry = DailyQuestion()
        entry.day = day
        entry.question = clean
        entry.author = deviceUser.name
        data.dailyQuestions.append(entry)
        touch(.dailyQuestion, entry.id)
    }

    func answers(for question: DailyQuestion) -> [DailyAnswer] {
        data.dailyAnswers
            .filter { !$0.deleted && $0.questionId == question.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func answerDailyQuestion(_ question: DailyQuestion, text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        // Bestehende eigene Antwort aktualisieren statt doppelt anlegen.
        if let index = data.dailyAnswers.firstIndex(where: { $0.questionId == question.id && $0.author == deviceUser.name && !$0.deleted }) {
            data.dailyAnswers[index].text = clean
            data.dailyAnswers[index].updatedAt = Date()
            touch(.dailyAnswer, data.dailyAnswers[index].id)
            return
        }
        var answer = DailyAnswer()
        answer.questionId = question.id
        answer.author = deviceUser.name
        answer.text = clean
        data.dailyAnswers.append(answer)
        touch(.dailyAnswer, answer.id)
    }

    // MARK: - Soundtrack

    var visibleSoundtrack: [SoundtrackItem] {
        data.soundtrack.filter { !$0.deleted }.sorted { $0.createdAt > $1.createdAt }
    }

    func addSoundtrackItem(title: String, artist: String, url: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else { return }
        var item = SoundtrackItem()
        item.title = cleanTitle
        item.artist = artist.trimmingCharacters(in: .whitespaces)
        item.url = url.trimmingCharacters(in: .whitespaces)
        item.addedBy = deviceUser.name
        data.soundtrack.append(item)
        touch(.soundtrack, item.id)
    }

    func deleteSoundtrackItem(_ item: SoundtrackItem) {
        guard let index = data.soundtrack.firstIndex(where: { $0.id == item.id }) else { return }
        data.soundtrack[index].deleted = true
        data.soundtrack[index].updatedAt = Date()
        touch(.soundtrack, item.id)
    }

    // MARK: - Konfiguration (Admin)

    func updateAccessCodes(crew: String, family: String, companion: String) {
        data.config.crewCode = crew.trimmingCharacters(in: .whitespaces).uppercased()
        data.config.familyCode = family.trimmingCharacters(in: .whitespaces).uppercased()
        data.config.companionCode = companion.trimmingCharacters(in: .whitespaces).uppercased()
        data.config.updatedAt = Date()
        touch(.config, "shared")
    }

    func updateMemberCode(member: String, code: String) {
        var codes = data.config.memberCodes ?? SharedConfig.defaultMemberCodes
        codes[member] = code.trimmingCharacters(in: .whitespaces).uppercased()
        data.config.memberCodes = codes
        data.config.updatedAt = Date()
        touch(.config, "shared")
    }

    var activeViewerProfiles: [ViewerProfile] {
        data.viewerProfiles.filter { !$0.deleted }.sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Export

    /// Schreibt den kompletten Datenbestand als JSON-Datei und liefert die URL fürs Teilen.
    func exportFileURL() -> URL? {
        let exportEncoder = JSONEncoder()
        exportEncoder.dateEncodingStrategy = .iso8601
        exportEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let raw = try? exportEncoder.encode(data) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Canada2026-Backup.json")
        do {
            try raw.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
