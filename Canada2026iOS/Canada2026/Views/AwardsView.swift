import SwiftUI

// Canada Awards – tägliche Abstimmungen wie in der PWA: pro Kategorie
// stimmt jedes Crew-Mitglied für ein Mitglied, Ergebnisse live.

struct AwardsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedDay = TravelData.isoDay.string(from: Date())

    private var canVote: Bool { store.isCrew }

    var body: some View {
        List {
            Section {
                DatePicker(
                    "Tag",
                    selection: Binding(
                        get: { TravelData.isoDay.date(from: selectedDay) ?? Date() },
                        set: { selectedDay = TravelData.isoDay.string(from: $0) }
                    ),
                    displayedComponents: .date
                )
            } footer: {
                Text("Awards entstehen aus Tagesfrage und Tagesgeschehen. Jede Person der Crew hat pro Kategorie eine Stimme.")
            }

            ForEach(TravelData.awardTemplates, id: \.self) { category in
                Section(category) {
                    let votes = store.awardVotes(day: selectedDay, category: category)
                    let winners = store.awardWinners(day: selectedDay, category: category)

                    if canVote {
                        Picker("Meine Stimme", selection: voteBinding(category: category)) {
                            Text("Noch offen").tag("")
                            ForEach(TravelData.crewNames, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    }

                    ForEach(TravelData.crewNames, id: \.self) { name in
                        let count = votes.values.filter { $0 == name }.count
                        HStack {
                            MemberChip(name: name)
                            if winners.contains(name) && count > 0 {
                                Text("🏆")
                            }
                            Spacer()
                            Text("\(count) Stimme\(count == 1 ? "" : "n")")
                                .font(.caption)
                                .foregroundStyle(count > 0 ? Theme.lakeBlue : .secondary)
                        }
                    }

                    if votes.isEmpty {
                        Text("Noch keine Stimmen für diesen Tag.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Canada Awards")
    }

    private func voteBinding(category: String) -> Binding<String> {
        Binding(
            get: {
                store.awardVotes(day: selectedDay, category: category)[store.deviceUser.name] ?? ""
            },
            set: { newValue in
                store.castAwardVote(day: selectedDay, category: category, votedFor: newValue)
            }
        )
    }
}
