import SwiftUI
import PhotosUI

/// Anlegen und Bearbeiten einer Karte.
struct CardFormView: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss

    let existing: Card?

    @State private var card: Card
    @State private var color: Color
    @State private var photo: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var barcodePhotoItem: PhotosPickerItem?
    @State private var showsScanner = false
    @State private var scanHint: String?
    @State private var detectionRunning = false
    @State private var walletDisplay: WalletDisplay
    @State private var groupName: String

    /// Darstellung des Passes in der Wallet.
    enum WalletDisplay: String, CaseIterable, Identifiable {
        case single, group, pile

        var id: String { rawValue }

        var label: String {
            switch self {
            case .single: return "Einzeln"
            case .group: return "Eigener Stapel"
            case .pile: return "Bei allen anderen"
            }
        }

        var explanation: String {
            switch self {
            case .single:
                return "Die Karte erscheint als eigene Kachel in der Wallet."
            case .group:
                return "Karten mit demselben Stapel-Namen liegen in der Wallet übereinander — Kachel antippen und durchblättern. Als Kachel zeigt Wallet eine der Karten aus dem Stapel."
            case .pile:
                return "Die Karte liegt im großen Stapel mit allen anderen Karten ohne Einzeldarstellung."
            }
        }
    }

    init(existing: Card?) {
        self.existing = existing
        let initial = existing ?? Card()
        _card = State(initialValue: initial)
        _color = State(initialValue: Color(hex: initial.colorHex))
        if let group = initial.walletGroupName {
            _walletDisplay = State(initialValue: .group)
            _groupName = State(initialValue: group)
        } else {
            _walletDisplay = State(initialValue: initial.showsSeparatelyInWallet ? .single : .pile)
            _groupName = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kartentyp") {
                    Picker("Typ", selection: $card.kind) {
                        ForEach(CardKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(card.kind == .photo
                         ? "Das Foto deiner Karte wird sichtbar auf dem Wallet-Pass angezeigt."
                         : "Der Code wird im Wallet-Pass angezeigt und kann an Scannern vorgezeigt werden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Beschriftung") {
                    TextField("Name der Karte (z. B. Stadtbibliothek)", text: $card.title)
                    TextField("Zusatz (z. B. Jahreskarte 2026)", text: $card.subtitle)
                    TextField("Name auf der Karte (optional)", text: $card.memberName)
                    TextField("Kartennummer (optional)", text: $card.memberNumber)
                }

                if card.kind == .photo {
                    photoSection
                }

                barcodeSection

                Section("Aussehen") {
                    ColorPicker("Passfarbe", selection: $color, supportsOpacity: false)
                }

                Section("Darstellung in der Wallet") {
                    Picker("In der Wallet", selection: $walletDisplay) {
                        ForEach(WalletDisplay.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    if walletDisplay == .group {
                        TextField("Name des Stapels (z. B. Einkauf)", text: $groupName)
                        if !existingGroups.isEmpty {
                            Menu("Vorhandenen Stapel wählen") {
                                ForEach(existingGroups, id: \.self) { name in
                                    Button(name) { groupName = name }
                                }
                            }
                        }
                    }
                    Text(walletDisplay.explanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Notiz (Rückseite des Passes)") {
                    TextField("Notiz", text: $card.note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(existing == nil ? "Neue Karte" : "Karte bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showsScanner) {
                ScannerView { result in
                    apply(result)
                    showsScanner = false
                }
            }
            .onChange(of: photoItem) { _, item in
                loadPhoto(from: item)
            }
            .onChange(of: barcodePhotoItem) { _, item in
                detectBarcode(from: item)
            }
            .task {
                if let existing, existing.kind == .photo {
                    photo = store.photo(for: existing)
                }
            }
        }
    }

    private var photoSection: some View {
        Section("Kartenfoto") {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(photo == nil ? "Foto auswählen" : "Foto ersetzen", systemImage: "photo.on.rectangle")
            }
            Text("Tipp: Karte flach hinlegen und formatfüllend fotografieren.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var barcodeSection: some View {
        Section(card.kind == .photo ? "Barcode (optional)" : "Code") {
            Picker("Format", selection: $card.barcodeFormat) {
                ForEach(BarcodeFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            TextField("Inhalt des Codes", text: $card.barcodeMessage, axis: .vertical)
                .font(.body.monospaced())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            HStack {
                Button {
                    showsScanner = true
                } label: {
                    Label("Scannen", systemImage: "camera.viewfinder")
                }
                .buttonStyle(.bordered)

                PhotosPicker(selection: $barcodePhotoItem, matching: .images) {
                    Label("Aus Foto", systemImage: "photo.badge.magnifyingglass")
                }
                .buttonStyle(.bordered)

                if detectionRunning {
                    ProgressView()
                }
            }

            if let scanHint {
                Text(scanHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if card.hasBarcode,
               let preview = Barcode.previewImage(message: card.barcodeMessage, format: card.barcodeFormat) {
                Image(uiImage: preview)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxHeight: 140)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var canSave: Bool {
        let hasTitle = !card.title.trimmingCharacters(in: .whitespaces).isEmpty
        switch card.kind {
        case .barcode:
            return hasTitle && card.hasBarcode
        case .photo:
            return hasTitle && photo != nil
        }
    }

    private func apply(_ result: Barcode.DetectionResult) {
        card.barcodeMessage = result.message
        card.barcodeFormat = result.format
        if let original = result.convertedFrom {
            scanHint = "Erkannt als \(original) — in der Wallet als Code 128 hinterlegt (gleicher Zahlencode)."
        } else {
            scanHint = "Code erkannt."
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                photo = image
            }
        }
    }

    private func detectBarcode(from item: PhotosPickerItem?) {
        guard let item else { return }
        detectionRunning = true
        Task {
            defer { detectionRunning = false }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                scanHint = "Das Foto konnte nicht geladen werden."
                return
            }
            if let result = await Barcode.detect(in: image) {
                apply(result)
            } else {
                scanHint = "Im Foto wurde kein Barcode gefunden."
            }
        }
    }

    /// Stapel-Namen der übrigen Karten als Auswahlhilfe.
    private var existingGroups: [String] {
        var names: [String] = []
        for other in store.cards where other.id != card.id {
            if let name = other.walletGroupName, !names.contains(name) {
                names.append(name)
            }
        }
        return names.sorted()
    }

    private func save() {
        card.colorHex = colorAsHex()
        card.title = card.title.trimmingCharacters(in: .whitespaces)
        card.barcodeMessage = card.barcodeMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        switch walletDisplay {
        case .single:
            card.separateInWallet = true
            card.walletGroup = nil
        case .pile:
            card.separateInWallet = false
            card.walletGroup = nil
        case .group:
            let name = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
            card.separateInWallet = true
            card.walletGroup = name.isEmpty ? nil : name
        }
        if card.kind == .photo, let photo {
            card.photoFilename = store.savePhoto(photo, for: card.id)
        }
        if existing == nil {
            store.add(card)
        } else {
            store.update(card)
        }
        dismiss()
    }

    private func colorAsHex() -> String {
        let resolved = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color.hexString(r: Double(r), g: Double(g), b: Double(b))
    }
}
