import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var certStore: CertStore
    @State private var showsForm = false
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if store.cards.isEmpty {
                    emptyState
                } else {
                    cardList
                }
            }
            .navigationTitle("Kartenwallet")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsSettings = true
                    } label: {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsForm = true
                    } label: {
                        Label("Neue Karte", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showsForm) {
                CardFormView(existing: nil)
            }
            .sheet(isPresented: $showsSettings) {
                SettingsView()
            }
        }
    }

    private var cardList: some View {
        ScrollView {
            VStack(spacing: 14) {
                if !certStore.isReady {
                    certHint
                }
                ForEach(store.cards) { card in
                    NavigationLink(value: card.id) {
                        CardTileView(card: card)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: UUID.self) { id in
            if let card = store.cards.first(where: { $0.id == id }) {
                CardDetailView(cardID: card.id)
            }
        }
    }

    private var certHint: some View {
        Button {
            showsSettings = true
        } label: {
            Label("Zertifikat einrichten, um Karten in die Wallet zu legen",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Noch keine Karten")
                .font(.title2.bold())
            Text("Lege QR-Codes, Barcodes oder Fotos deiner Kundenkarten an und füge sie der Apple Wallet hinzu.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showsForm = true
            } label: {
                Label("Erste Karte anlegen", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            if !certStore.isReady {
                Button("Zuerst Zertifikat einrichten") {
                    showsSettings = true
                }
                .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Kachel in der Liste — angelehnt an die Pass-Optik.
struct CardTileView: View {
    @EnvironmentObject private var store: CardStore
    let card: Card

    var body: some View {
        let (_, isDark) = contrastingTextColor(forHex: card.colorHex)
        let textColor: Color = isDark ? .black : .white

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(card.title.isEmpty ? "Karte" : card.title)
                    .font(.headline)
                Spacer()
                Image(systemName: card.kind == .photo ? "photo" : "qrcode")
                    .font(.subheadline)
                    .opacity(0.8)
            }
            if !card.subtitle.isEmpty {
                Text(card.subtitle)
                    .font(.subheadline)
                    .opacity(0.85)
            }
            if card.kind == .photo, let photo = store.photo(for: card) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if !card.memberNumber.isEmpty {
                Text(card.memberNumber)
                    .font(.footnote.monospaced())
                    .opacity(0.85)
            }
        }
        .foregroundStyle(textColor)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: card.colorHex), in: RoundedRectangle(cornerRadius: 16))
    }
}
