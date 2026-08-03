import SwiftUI
import UIKit

enum AppTab: String, CaseIterable {
    case eintraege
    case statistiken
    case karte
    case suche

    var label: String {
        switch self {
        case .eintraege: return "Einträge"
        case .statistiken: return "Statistiken"
        case .karte: return "Karte"
        case .suche: return "Suche"
        }
    }

    var symbol: String {
        switch self {
        case .eintraege: return "list.bullet.rectangle.fill"
        case .statistiken: return "chart.pie.fill"
        case .karte: return "map.fill"
        case .suche: return "magnifyingglass"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @State private var tab: AppTab = .eintraege
    @State private var showNameSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            Group {
                switch tab {
                case .eintraege: EntriesView()
                case .statistiken: StatsView()
                case .karte: MapScreen()
                case .suche: SearchView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomTabBar(selection: $tab)
        }
        .onAppear {
            if store.profileName.trimmed.isEmpty { showNameSheet = true }
        }
        .sheet(isPresented: $showNameSheet) {
            NameSheet()
                .environmentObject(store)
        }
    }
}

// MARK: - Untere Tab-Leiste (Kapsel + Such-Knopf, wie im Vorbild)

struct BottomTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach([AppTab.eintraege, .statistiken, .karte], id: \.self) { tab in
                    Button {
                        selection = tab
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 20, weight: .semibold))
                            Text(tab.label)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(selection == tab ? Theme.accent : Theme.textDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(selection == tab ? Theme.cardSoft : Color.clear)
                                .padding(4)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Capsule().fill(Theme.card.opacity(0.96)))
            .overlay(Capsule().stroke(Theme.separator, lineWidth: 1))

            Button {
                selection = .suche
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selection == .suche ? Theme.accent : Theme.textPrimary)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Theme.card.opacity(0.96)))
                    .overlay(Circle().stroke(Theme.separator, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }
}

// MARK: - Profilname (für gemeinsame Reisen)

struct NameSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 22) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 54))
                    .foregroundStyle(Theme.accent)
                Text("Wie heißt du?")
                    .font(.title2.bold())
                Text("Dein Name steht an deinen Einträgen, damit bei gemeinsamen Reisen klar ist, wer was bezahlt hat.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textDim)
                    .multilineTextAlignment(.center)
                TextField("Dein Name", text: $name)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .cardStyle(Theme.cardSoft)
                    .submitLabel(.done)
                    .onSubmit(save)
                Button(action: save) {
                    Text("Los geht's")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Theme.accent))
                        .foregroundStyle(.white)
                }
                .disabled(name.trimmed.isEmpty)
                .opacity(name.trimmed.isEmpty ? 0.5 : 1)
                Spacer()
            }
            .padding(24)
            .padding(.top, 30)
        }
        .interactiveDismissDisabled(store.profileName.trimmed.isEmpty)
    }

    private func save() {
        guard let value = name.nonEmpty else { return }
        store.profileName = value
        if let trip = store.activeTrip {
            store.registerParticipant(in: trip.id)
        }
        dismiss()
    }
}

// MARK: - Teilen-Hülle (CSV, Texte)

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
