import SwiftUI

// Startseite – Tageszentrum wie in der PWA, mit eigener Variante für Betrachter.

struct HomeView: View {
    @EnvironmentObject private var store: AppStore

    private var now: Date { Date() }
    private var isBeforeTrip: Bool { now < TravelData.tripStart }
    private var isAfterTrip: Bool { now > TravelData.tripEnd.addingTimeInterval(86_400) }
    private var currentStation: Station? { TravelData.currentStation(on: now) }
    private var nextStation: Station? { TravelData.nextStation(on: now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard

                    if store.isViewer {
                        viewerInfoCard
                    }

                    if let question = store.todaysQuestion() {
                        dailyQuestionCard(question)
                    }

                    stationCard
                    messagesCard
                    latestPhotoCard
                    activityCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(TravelData.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        SyncStatusDot()
                        NavigationLink {
                            NoticesView()
                        } label: {
                            Image(systemName: "bell")
                                .overlay(alignment: .topTrailing) {
                                    if store.unreadNoticeCount > 0 {
                                        Circle().fill(.red).frame(width: 8, height: 8)
                                    }
                                }
                        }
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Karten

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TravelData.eyebrow)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.canadaRed)
                        .textCase(.uppercase)
                    Text("Hallo \(store.deviceUser.name)!")
                        .font(.title2.bold())
                }
                Spacer()
                RoleBadge(role: store.deviceUser.role)
            }

            if isBeforeTrip {
                let days = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: now), to: TravelData.tripStart).day ?? 0)
                Label("\(days) Tage bis zum Abflug am 4. August 2026", systemImage: "airplane.departure")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.lakeBlue)
            } else if isAfterTrip {
                Label("Die Reise ist vorbei – Zeit für das Roadbook!", systemImage: "book")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.forestGreen)
            } else {
                let day = (Calendar.current.dateComponents([.day], from: TravelData.tripStart, to: now).day ?? 0) + 1
                Label("Reisetag \(day) – mitten im Abenteuer", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.canadaRed)
            }
        }
        .card()
    }

    private var viewerInfoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Du reist von zu Hause mit", systemImage: "binoculars")
                .font(.subheadline.weight(.semibold))
            Text(store.deviceUser.role == .family
                 ? "Als Familie siehst du Journal, Fotos, Karte, Bingo und Challenges – und kannst der Crew schreiben."
                 : "Als Begleiter siehst du Journal, Fotos und die Karte – und kannst der Crew schreiben.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private func dailyQuestionCard(_ question: DailyQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Tagesfrage", subtitle: "von \(question.author)")
            Text(question.question)
                .font(.body.weight(.medium))
            NavigationLink {
                DailyQuestionView()
            } label: {
                Text("\(store.answers(for: question).count) Antworten – mitmachen")
                    .font(.footnote.weight(.semibold))
            }
        }
        .card()
    }

    private var stationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: isBeforeTrip ? "Erste Station" : "Aktuelle Station")
            if let station = currentStation ?? TravelData.stations.first {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(station.name)
                            .font(.title3.bold())
                        Spacer()
                        Text(Self.dayLabel(station.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(station.notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let next = nextStation {
                        Label("Danach: \(next.name) ab \(Self.dayLabel(next.date))", systemImage: "arrow.right.circle")
                            .font(.caption)
                            .foregroundStyle(Theme.lakeBlue)
                    }
                }
            }
            HStack {
                NavigationLink("Reiseplan") { PlanView() }
                    .buttonStyle(.bordered)
                NavigationLink("Karte & Route") { TripMapView() }
                    .buttonStyle(.bordered)
                NavigationLink { WeatherView() } label: {
                    Label("Wetter", systemImage: "cloud.sun")
                }
                .buttonStyle(.bordered)
            }
            .font(.footnote)
        }
        .card()
    }

    private var messagesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Nachrichten")
            let unread = store.totalUnreadMessages
            if unread > 0 {
                Label("\(unread) neue Nachricht\(unread == 1 ? "" : "en")", systemImage: "bubble.left.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.canadaRed)
            } else {
                Text("Keine neuen Nachrichten.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var latestPhotoCard: some View {
        Group {
            if let photo = store.visiblePhotos.first,
               let image = UIImage(contentsOfFile: store.photoFileURL(photo).path) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Neuestes Foto", subtitle: "von \(photo.author)")
                    NavigationLink {
                        PhotoAlbumView()
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if !photo.caption.isEmpty {
                        Text(photo.caption)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .card()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Fotoalbum")
                    Text("Noch keine Fotos – das erste Bild wartet!")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    NavigationLink("Album öffnen") { PhotoAlbumView() }
                        .buttonStyle(.bordered)
                        .font(.footnote)
                }
                .card()
            }
        }
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Aktivität")
            let items = store.notices.filter { $0.kind == "activity" }.prefix(5)
            if items.isEmpty {
                Text("Noch keine neue Aktivität.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(items)) { notice in
                    HStack {
                        Text(notice.text)
                            .font(.footnote)
                        Spacer()
                        Text(notice.createdAt, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .card()
    }

    static func dayLabel(_ isoDay: String) -> String {
        guard let date = TravelData.isoDay.date(from: isoDay) else { return isoDay }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEE, d. MMMM"
        return formatter.string(from: date)
    }
}
