import SwiftUI

// STAN-Hub: Crew, Bingo, Challenges, Punkte, Bucket List, Tagesfrage.

struct CrewHubView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            List {
                Section("Gemeinsam") {
                    NavigationLink { DailyQuestionView() } label: {
                        Label("Tagesfrage", systemImage: "questionmark.bubble")
                    }
                    NavigationLink { AwardsView() } label: {
                        Label("Canada Awards", systemImage: "rosette")
                    }
                    NavigationLink { BucketListView() } label: {
                        Label("Bucket List", systemImage: "star.circle")
                    }
                    NavigationLink { SoundtrackView() } label: {
                        Label("Soundtrack", systemImage: "music.note.list")
                    }
                    NavigationLink { TravelBookView() } label: {
                        Label("STAN Roadbook", systemImage: "book.closed")
                    }
                }

                if store.showsGames {
                    Section("Spiel & Challenges") {
                        NavigationLink { BingoView() } label: {
                            Label("Canada Bingo", systemImage: "square.grid.3x3")
                        }
                        NavigationLink { ChallengesView() } label: {
                            Label("Roadtrip Challenges", systemImage: "flag.checkered")
                        }
                        NavigationLink { ScoreView() } label: {
                            Label("Roadtrip Score & Erfolge", systemImage: "trophy")
                        }
                    }
                }

                Section("Canada Crew") {
                    ForEach(TravelData.crewNames, id: \.self) { name in
                        HStack {
                            Circle()
                                .fill(Theme.memberColor(name))
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.subheadline.weight(.semibold))
                                Text((TravelData.memberInterests[name] ?? []).joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if name == TravelData.adminName {
                                RoleBadge(role: .admin)
                            }
                            if store.showsGames {
                                Text("\(store.score(member: name)) P")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.lakeBlue)
                            }
                        }
                    }
                }

                if !store.activeViewerProfiles.isEmpty {
                    Section("Reist von zu Hause mit") {
                        ForEach(store.activeViewerProfiles) { viewer in
                            HStack {
                                Text(viewer.displayName)
                                    .font(.subheadline)
                                Spacer()
                                RoleBadge(role: AccessRole(rawValue: viewer.role) ?? .family)
                            }
                        }
                    }
                }
            }
            .navigationTitle("STAN on Tour")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SyncStatusDot() }
            }
        }
    }
}

// MARK: - Canada Bingo

struct BingoView: View {
    @EnvironmentObject private var store: AppStore
    @State private var viewedMember = TravelData.adminName

    private var canToggle: Bool {
        store.isCrew && (viewedMember == store.deviceUser.name || store.isAdmin)
    }

    var body: some View {
        List {
            Section {
                Picker("Mitglied", selection: $viewedMember) {
                    ForEach(TravelData.crewNames, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)

                let done = store.donebingoTasks(member: viewedMember)
                HStack {
                    Text("\(done.count) von \(TravelData.bingoTasks.count) Feldern")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    PointsBadge(points: done.reduce(0) { $0 + $1.points })
                }
            }

            ForEach(TravelData.bingoCategories, id: \.self) { category in
                Section(category) {
                    ForEach(TravelData.bingoTasks.filter { $0.category == category }) { task in
                        let isDone = store.bingoState(member: viewedMember, taskId: task.id)?.done ?? false
                        Button {
                            if canToggle {
                                store.toggleBingo(member: viewedMember, taskId: task.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: isDone ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(isDone ? Theme.forestGreen : .secondary)
                                Text(task.title)
                                    .foregroundStyle(.primary)
                                    .strikethrough(isDone)
                                Spacer()
                                PointsBadge(points: task.points)
                            }
                        }
                        .disabled(!canToggle)
                    }
                }
            }
        }
        .navigationTitle("Canada Bingo")
        .onAppear {
            if store.isCrew { viewedMember = store.deviceUser.name }
        }
    }
}

// MARK: - Roadtrip Challenges

struct ChallengesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var viewedMember = TravelData.adminName

    private var canToggle: Bool {
        store.isCrew && (viewedMember == store.deviceUser.name || store.isAdmin)
    }

    var body: some View {
        List {
            Section {
                Picker("Mitglied", selection: $viewedMember) {
                    ForEach(TravelData.crewNames, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)

                let done = store.doneChallenges(member: viewedMember)
                HStack {
                    Text("\(done.count) von \(TravelData.challenges.count) Challenges")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    PointsBadge(points: done.reduce(0) { $0 + $1.points })
                }
            }

            ForEach(TravelData.stations) { station in
                let stationChallenges = TravelData.challenges.filter { $0.stationId == station.id }
                if !stationChallenges.isEmpty {
                    Section(station.name) {
                        ForEach(stationChallenges) { challenge in
                            let isDone = store.challengeState(member: viewedMember, challengeId: challenge.id)?.done ?? false
                            Button {
                                if canToggle {
                                    store.toggleChallenge(member: viewedMember, challengeId: challenge.id)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isDone ? Theme.forestGreen : .secondary)
                                    Text(challenge.title)
                                        .foregroundStyle(.primary)
                                        .strikethrough(isDone)
                                    Spacer()
                                    PointsBadge(points: challenge.points)
                                }
                            }
                            .disabled(!canToggle)
                        }
                    }
                }
            }
        }
        .navigationTitle("Challenges")
        .onAppear {
            if store.isCrew { viewedMember = store.deviceUser.name }
        }
    }
}

// MARK: - Score & Erfolge

struct ScoreView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            Section("Roadtrip Score") {
                let board = store.leaderboard
                ForEach(board) { entry in
                    let index = board.firstIndex(of: entry) ?? 0
                    HStack {
                        Text(index == 0 ? "🏆" : "\(index + 1).")
                            .font(.headline)
                            .frame(width: 34, alignment: .leading)
                        MemberChip(name: entry.member)
                        Spacer()
                        Text("\(entry.score) Punkte")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.lakeBlue)
                    }
                }
            }

            ForEach(TravelData.crewNames, id: \.self) { member in
                let earned = store.earnedAchievements(member: member)
                Section("Erfolge – \(member)") {
                    if earned.isEmpty {
                        Text("Noch keine Erfolge freigeschaltet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(earned) { achievement in
                        HStack(spacing: 10) {
                            Text(achievement.icon)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(achievement.condition)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            PointsBadge(points: achievement.points)
                        }
                    }
                }
            }
        }
        .navigationTitle("Score & Erfolge")
    }
}

// MARK: - Bucket List

struct BucketListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var newItemText = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Neuer Wunsch ...", text: $newItemText)
                    Button {
                        store.addBucketItem(newItemText)
                        newItemText = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Theme.canadaRed)
                    }
                    .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty || !store.isCrew)
                }
            }

            Section("Wünsche") {
                ForEach(store.visibleBucketList) { item in
                    BucketListRow(item: item)
                }
            }
        }
        .navigationTitle("Bucket List")
    }
}

struct BucketListRow: View {
    @EnvironmentObject private var store: AppStore
    let item: BucketItem
    @State private var showsPhotoPicker = false

    private var voted: Bool { item.voteList.contains(store.deviceUser.name) }
    private var linkedPhoto: PhotoItem? {
        guard let photoId = item.photoId, !photoId.isEmpty else { return nil }
        return store.data.photos.first { $0.id == photoId && !$0.deleted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Button {
                    if store.isCrew { store.toggleBucketItem(item) }
                } label: {
                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.done ? Theme.forestGreen : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!store.isCrew)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.text)
                        .strikethrough(item.done)
                    Text([
                        "\(item.voteList.count) Stimme\(item.voteList.count == 1 ? "" : "n")",
                        item.done && !item.doneBy.isEmpty ? "Erledigt von \(item.doneBy)" : "Idee von \(item.addedBy)"
                    ].joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let photo = linkedPhoto,
                   let image = UIImage(contentsOfFile: store.photoFileURL(photo).path) {
                    NavigationLink {
                        PhotoDetailView(photoId: photo.id)
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            if store.isCrew {
                HStack(spacing: 10) {
                    Button(voted ? "Stimme entfernen" : "Dafür stimmen") {
                        store.toggleBucketVote(item)
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)

                    Button(linkedPhoto == nil ? "Foto verknüpfen" : "Foto ändern") {
                        showsPhotoPicker = true
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 2)
        .swipeActions {
            if store.isCrew && (item.addedBy == store.deviceUser.name || store.isAdmin) {
                Button(role: .destructive) {
                    store.deleteBucketItem(item)
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showsPhotoPicker) {
            BucketPhotoPickerSheet(item: item)
        }
    }
}

/// Foto aus dem gemeinsamen Album mit einem Bucket-List-Wunsch verknüpfen.
struct BucketPhotoPickerSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let item: BucketItem

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.visiblePhotos.isEmpty {
                    Text("Noch keine Fotos im Album.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 60)
                }
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(store.visiblePhotos) { photo in
                        Button {
                            store.linkBucketPhoto(item, photoId: photo.id)
                            dismiss()
                        } label: {
                            PhotoThumbnail(photo: photo)
                        }
                    }
                }
                .padding(4)
            }
            .navigationTitle("Foto wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                if item.photoId != nil && !(item.photoId ?? "").isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Entfernen") {
                            store.linkBucketPhoto(item, photoId: "")
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Tagesfrage

struct DailyQuestionView: View {
    @EnvironmentObject private var store: AppStore
    @State private var newQuestion = ""
    @State private var answerText = ""

    private var today: String { TravelData.isoDay.string(from: Date()) }

    var body: some View {
        List {
            if let question = store.todaysQuestion() {
                Section("Frage des Tages") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(question.question)
                            .font(.body.weight(.semibold))
                        Text("gestellt von \(question.author)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                Section("Antworten") {
                    let answers = store.answers(for: question)
                    if answers.isEmpty {
                        Text("Noch keine Antworten.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(answers) { answer in
                        VStack(alignment: .leading, spacing: 4) {
                            MemberChip(name: answer.author)
                            Text(answer.text)
                                .font(.body)
                        }
                        .padding(.vertical, 2)
                    }

                    HStack {
                        TextField("Deine Antwort ...", text: $answerText, axis: .vertical)
                        Button {
                            store.answerDailyQuestion(question, text: answerText)
                            answerText = ""
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(Theme.canadaRed)
                        }
                        .disabled(answerText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            } else {
                Section("Frage des Tages") {
                    Text("Heute gibt es noch keine Tagesfrage.")
                        .foregroundStyle(.secondary)
                }
            }

            if store.isCrew {
                Section("Neue Tagesfrage stellen") {
                    TextField("Eigene Frage ...", text: $newQuestion, axis: .vertical)
                    Button("Frage stellen") {
                        store.setDailyQuestion(newQuestion)
                        newQuestion = ""
                    }
                    .disabled(newQuestion.trimmingCharacters(in: .whitespaces).isEmpty)

                    ForEach(TravelData.dailyQuestionTemplates, id: \.self) { template in
                        Button {
                            store.setDailyQuestion(template)
                        } label: {
                            Label(template, systemImage: "sparkles")
                                .font(.footnote)
                        }
                    }
                }
            }
        }
        .navigationTitle("Tagesfrage")
    }
}

// MARK: - Soundtrack

struct SoundtrackView: View {
    @EnvironmentObject private var store: AppStore
    @State private var title = ""
    @State private var artist = ""
    @State private var url = ""

    var body: some View {
        List {
            Section("Reise-Soundtrack") {
                if store.visibleSoundtrack.isEmpty {
                    Text("Noch keine Songs – sammelt euren Kanada-Soundtrack!")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(store.visibleSoundtrack) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                            Text(item.artist.isEmpty ? "hinzugefügt von \(item.addedBy)" : "\(item.artist) · von \(item.addedBy)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let linkURL = URL(string: item.url), !item.url.isEmpty {
                            Link(destination: linkURL) {
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Theme.forestGreen)
                            }
                        }
                    }
                    .swipeActions {
                        if store.isCrew && (item.addedBy == store.deviceUser.name || store.isAdmin) {
                            Button(role: .destructive) {
                                store.deleteSoundtrackItem(item)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if store.isCrew {
                Section("Song hinzufügen") {
                    TextField("Titel", text: $title)
                    TextField("Artist (optional)", text: $artist)
                    TextField("Spotify-/Musik-Link (optional)", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Hinzufügen") {
                        store.addSoundtrackItem(title: title, artist: artist, url: url)
                        title = ""
                        artist = ""
                        url = ""
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle("Soundtrack")
    }
}
