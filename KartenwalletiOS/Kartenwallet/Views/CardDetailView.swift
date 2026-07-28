import SwiftUI
import PassKit

/// Detailansicht einer Karte mit Pass-Vorschau und
/// „Zu Apple Wallet hinzufügen".
struct CardDetailView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var certStore: CertStore
    @Environment(\.dismiss) private var dismiss

    let cardID: UUID

    @State private var pass: PKPass?
    @State private var passFileURL: URL?
    @State private var showsAddPass = false
    @State private var showsEdit = false
    @State private var showsDeleteConfirm = false
    @State private var errorMessage: String?
    @State private var building = false

    private var card: Card? {
        store.cards.first { $0.id == cardID }
    }

    var body: some View {
        Group {
            if let card {
                content(for: card)
            } else {
                Color.clear
            }
        }
        .navigationTitle(card?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(for card: Card) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                passPreview(for: card)

                addToWalletButton(for: card)

                if let passFileURL {
                    ShareLink(item: passFileURL) {
                        Label("Pass-Datei teilen (.pkpass)", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }

                if !certStore.isReady {
                    Text("Hinweis: Es ist noch kein Pass-Zertifikat eingerichtet (Einstellungen → Zertifikat). Ohne Zertifikat kann kein Pass für die Wallet erzeugt werden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showsEdit = true
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showsDeleteConfirm = true
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showsEdit) {
            CardFormView(existing: card)
        }
        .sheet(isPresented: $showsAddPass) {
            if let pass {
                AddPassView(pass: pass)
            }
        }
        .confirmationDialog("Karte löschen?", isPresented: $showsDeleteConfirm, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                store.delete(card)
                dismiss()
            }
        } message: {
            Text("Ein bereits hinzugefügter Wallet-Pass bleibt in der Wallet, bis du ihn dort entfernst.")
        }
    }

    private func passPreview(for card: Card) -> some View {
        let (_, isDark) = contrastingTextColor(forHex: card.colorHex)
        let textColor: Color = isDark ? .black : .white

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(card.title)
                    .font(.title3.bold())
                Spacer()
                if !card.subtitle.isEmpty {
                    Text(card.subtitle)
                        .font(.subheadline)
                        .opacity(0.85)
                }
            }

            if card.kind == .photo, let photo = store.photo(for: card) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if !card.memberName.isEmpty || !card.memberNumber.isEmpty {
                HStack(spacing: 24) {
                    if !card.memberName.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NAME").font(.caption2).opacity(0.7)
                            Text(card.memberName).font(.subheadline)
                        }
                    }
                    if !card.memberNumber.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("KARTENNUMMER").font(.caption2).opacity(0.7)
                            Text(card.memberNumber).font(.subheadline.monospaced())
                        }
                    }
                    Spacer()
                }
            }

            if card.hasBarcode,
               let preview = Barcode.previewImage(message: card.barcodeMessage, format: card.barcodeFormat) {
                HStack {
                    Spacer()
                    Image(uiImage: preview)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(maxHeight: 150)
                        .padding(10)
                        .background(.white, in: RoundedRectangle(cornerRadius: 10))
                    Spacer()
                }
            }
        }
        .foregroundStyle(textColor)
        .padding(18)
        .background(Color(hex: card.colorHex), in: RoundedRectangle(cornerRadius: 18))
    }

    private func addToWalletButton(for card: Card) -> some View {
        Button {
            buildAndPresent(card: card)
        } label: {
            HStack {
                Image(systemName: "wallet.pass.fill")
                Text(building ? "Pass wird erstellt …" : "Zu Apple Wallet hinzufügen")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.black)
        .disabled(building || !certStore.isReady)
    }

    private func buildAndPresent(card: Card) {
        building = true
        errorMessage = nil
        Task {
            defer { building = false }
            await certStore.ensureWWDR()
            do {
                let photo = card.kind == .photo ? store.photo(for: card) : nil
                let data = try PassBuilder.makePass(for: card, photo: photo, certStore: certStore)

                // Für „Teilen" ablegen
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(card.title.isEmpty ? "Karte" : card.title).pkpass")
                try? data.write(to: url, options: .atomic)
                passFileURL = url

                // PassKit prüft hier bereits die Signatur.
                pass = try PKPass(data: data)
                showsAddPass = true
            } catch let error as PKPassKitError {
                errorMessage = "Wallet hat den Pass nicht akzeptiert (\(error.localizedDescription)). Meist stimmt etwas mit dem Zertifikat nicht — bitte in den Einstellungen prüfen."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Der systemeigene „Pass hinzufügen"-Dialog.
struct AddPassView: UIViewControllerRepresentable {
    let pass: PKPass

    func makeUIViewController(context: Context) -> UIViewController {
        PKAddPassesViewController(pass: pass) ?? UIViewController()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
