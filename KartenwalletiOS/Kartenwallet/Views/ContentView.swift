import SwiftUI
import PassKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var certStore: CertStore
    @EnvironmentObject private var importer: PassImporter
    @State private var showsForm = false
    @State private var showsSettings = false
    @State private var showsPassImporter = false

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
                    Menu {
                        Button {
                            showsForm = true
                        } label: {
                            Label("Neue Karte anlegen", systemImage: "plus.rectangle")
                        }
                        Button {
                            showsPassImporter = true
                        } label: {
                            Label("Pass-Datei (.pkpass) öffnen", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showsForm) {
                CardFormView(existing: nil)
            }
            .sheet(isPresented: $showsSettings) {
                SettingsView()
            }
            // Bewusst ohne Typfilter: Fremd-Apps können dem Dateityp .pkpass
            // eine eigene Typkennung überstülpen — dann wäre die Datei hier
            // ausgegraut. Ob es wirklich ein gültiger Pass ist, prüft ohnehin
            // PassKit beim Import.
            .fileImporter(
                isPresented: $showsPassImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    importer.importPass(from: url)
                }
            }
            .sheet(isPresented: Binding(
                get: { importer.pendingPass != nil },
                set: { if !$0 { importer.pendingPass = nil } }
            )) {
                if let pass = importer.pendingPass {
                    if PKAddPassesViewController.canAddPasses() {
                        AddPassView(pass: pass)
                    } else {
                        ImportedPassInfoView(pass: pass)
                    }
                }
            }
            .alert("Import fehlgeschlagen", isPresented: Binding(
                get: { importer.errorMessage != nil },
                set: { if !$0 { importer.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importer.errorMessage ?? "")
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

/// Wird gezeigt, wenn eine .pkpass geöffnet wurde, das Gerät aber keine
/// Apple Wallet hat (z. B. iPad).
struct ImportedPassInfoView: View {
    @Environment(\.dismiss) private var dismiss
    let pass: PKPass

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "wallet.pass")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text(pass.localizedName)
                    .font(.title3.bold())
                Text(pass.organizationName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Die Pass-Datei ist gültig. Auf diesem Gerät gibt es aber keine Apple Wallet — zum Hinzufügen die Datei auf einem iPhone öffnen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
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
