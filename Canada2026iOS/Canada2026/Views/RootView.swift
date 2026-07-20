import SwiftUI

// Einstieg: Zugangs-Gate mit Rollenwahl, danach Tab-Navigation wie in der PWA.

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        if store.isLoggedIn {
            MainTabView()
        } else {
            AccessGateView()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Start", systemImage: "house.fill") }

            TravelHubView()
                .tabItem { Label("Reise", systemImage: "map.fill") }

            JournalView()
                .tabItem { Label("Journal", systemImage: "book.fill") }

            MessagesView()
                .tabItem { Label("Nachrichten", systemImage: "bubble.left.and.bubble.right.fill") }
                .badge(store.totalUnreadMessages)

            CrewHubView()
                .tabItem { Label("STAN", systemImage: "person.3.fill") }
        }
    }
}

// MARK: - Zugangs-Gate

struct AccessGateView: View {
    @EnvironmentObject private var store: AppStore

    private enum Mode: String, CaseIterable, Identifiable {
        case crew = "STAN on Tour"
        case family = "Familie"
        case companion = "Begleiter"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .crew
    @State private var selectedMember = TravelData.crewNames.first ?? "Andreas"
    @State private var viewerName = ""
    @State private var code = ""
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("🍁")
                            .font(.system(size: 56))
                        Text(TravelData.eyebrow)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.canadaRed)
                            .textCase(.uppercase)
                        Text(TravelData.title)
                            .font(.largeTitle.bold())
                        Text("Toronto · Niagara · Picton · Kingston · Thousand Islands · Ottawa · Gatineau")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Wer bist du?")
                            .font(.headline)

                        Picker("Rolle", selection: $mode) {
                            ForEach(Mode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if mode == .crew {
                            Text("Reise-Mitglieder haben Vollzugriff auf alle Bereiche.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Picker("Mitglied", selection: $selectedMember) {
                                ForEach(TravelData.crewNames, id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }
                            .pickerStyle(.segmented)
                        } else {
                            Text(mode == .family
                                 ? "Familie kann mitlesen: Journal, Fotos, Karte, Nachrichten, Bingo und Challenges."
                                 : "Begleiter können mitlesen: Journal, Fotos, Karte und Nachrichten.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            TextField("Dein Name", text: $viewerName)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.words)
                        }

                        SecureField("Zugangscode", text: $code)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Button {
                            login()
                        } label: {
                            Text("Anmelden")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Synchronisation über iCloud", systemImage: "icloud")
                            .font(.subheadline.weight(.semibold))
                        Text("Diese App nutzt CloudKit statt Firebase. Alle Inhalte werden über den gemeinsamen iCloud-Container der App geteilt – dafür muss das Gerät bei iCloud angemeldet sein.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(store.syncStatus.label)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .card()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func login() {
        errorMessage = ""
        do {
            switch mode {
            case .crew:
                try store.loginCrew(member: selectedMember, code: code)
            case .family:
                try store.loginViewer(name: viewerName, role: .family, code: code)
            case .companion:
                try store.loginViewer(name: viewerName, role: .companion, code: code)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
