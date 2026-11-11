import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Was als Blatt über dem Buch aufgeht.
enum Blatt: Identifiable {
    case einstellungen
    case text(UUID)
    case foto(UUID)
    case frei(UUID)
    case fotowahl

    var id: String {
        switch self {
        case .einstellungen: return "einstellungen"
        case .text(let i): return "text-" + i.uuidString
        case .foto(let i): return "foto-" + i.uuidString
        case .frei(let i): return "frei-" + i.uuidString
        case .fotowahl: return "fotowahl"
        }
    }
}

struct BuchView: View {
    let buchID: UUID

    enum Ansicht: String, CaseIterable, Identifiable {
        case inhalte = "Inhalte"
        case seiten = "Buch"
        var id: String { rawValue }
    }

    @EnvironmentObject private var bibliothek: Bibliothek
    @State private var ansicht = Ansicht.inhalte
    @State private var blatt: Blatt?
    @State private var dateiwahl = false
    @State private var arbeit: String?
    @State private var meldung: String?

    var body: some View {
        let buch = bibliothek.binding(buchID)
        VStack(spacing: 0) {
            Picker("Ansicht", selection: $ansicht) {
                ForEach(Ansicht.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch ansicht {
            case .inhalte:
                InhalteView(buch: buch, oeffnen: { blatt = $0 })
            case .seiten:
                SeitenView(buch: buch, oeffnen: { blatt = $0 })
            }
        }
        .navigationTitle(buch.wrappedValue.titel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button { neuerText(buch) } label: { Label("Neuer Text", systemImage: "square.and.pencil") }
                    Button { fotosWaehlen() } label: { Label("Fotos aus der Mediathek", systemImage: "photo.on.rectangle") }
                    Button { dateiwahl = true } label: { Label("Fotos aus Dateien", systemImage: "folder") }
                    Divider()
                    Button { freieSeiteAmEnde(buch) } label: { Label("Freie Seite am Ende", systemImage: "doc.badge.plus") }
                } label: {
                    Label("Hinzufügen", systemImage: "plus")
                }
                Menu {
                    Button { blatt = .einstellungen } label: { Label("Buch einrichten", systemImage: "slider.horizontal.3") }
                    Button { ausgeben(buch.wrappedValue) } label: { Label("Als PDF ausgeben", systemImage: "square.and.arrow.up") }
                } label: {
                    Label("Mehr", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $blatt) { b in
            blattInhalt(b, buch: buch)
                .environmentObject(bibliothek)
        }
        .fileImporter(isPresented: $dateiwahl, allowedContentTypes: [.image], allowsMultipleSelection: true) { ergebnis in
            ausDateien(ergebnis, buch: buch)
        }
        .overlay {
            if let arbeit {
                ProgressView(arbeit)
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .alert("Hinweis", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
            Button("OK") {}
        } message: {
            Text(meldung ?? "")
        }
    }

    @ViewBuilder
    private func blattInhalt(_ b: Blatt, buch: Binding<Buch>) -> some View {
        switch b {
        case .einstellungen:
            EinstellungenView(buch: buch)
        case .text(let id):
            TextEditorView(buch: buch, id: id)
        case .foto(let id):
            FotoView(buch: buch, id: id)
        case .frei(let id):
            FreieSeiteView(buch: buch, id: id)
        case .fotowahl:
            Fotowahl { ergebnisse in
                blatt = nil
                einlesen(ergebnisse, buch: buch)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Handlungen

    private func neuerText(_ buch: Binding<Buch>) {
        let t = Texteintrag()
        buch.wrappedValue.texte.append(t)
        blatt = .text(t.id)
    }

    private func freieSeiteAmEnde(_ buch: Binding<Buch>) {
        let f = FreieSeite(stelle: .buchEnde)
        buch.wrappedValue.freieSeiten.append(f)
        blatt = .frei(f.id)
    }

    /// Fragt einmal nach dem Mediathekszugriff — er liefert das Datum für
    /// Bilder, deren Datei keines trägt. Ohne ihn geht es trotzdem.
    private func fotosWaehlen() {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
                DispatchQueue.main.async { blatt = .fotowahl }
            }
        } else {
            blatt = .fotowahl
        }
    }

    private func einlesen(_ ergebnisse: [PHPickerResult], buch: Binding<Buch>) {
        guard !ergebnisse.isEmpty else { return }
        arbeit = ergebnisse.count == 1 ? "Foto wird übernommen …" : "\(ergebnisse.count) Fotos werden übernommen …"
        Task { @MainActor in
            let neu = await Fotoeinfuhr.einlesen(ergebnisse)
            buch.wrappedValue.fotos.append(contentsOf: neu)
            arbeit = nil
            let fehlend = ergebnisse.count - neu.count
            if fehlend > 0 {
                meldung = fehlend == 1 ? "Ein Foto ließ sich nicht übernehmen." : "\(fehlend) Fotos ließen sich nicht übernehmen."
            }
        }
    }

    private func ausDateien(_ ergebnis: Result<[URL], Error>, buch: Binding<Buch>) {
        guard case .success(let adressen) = ergebnis else { return }
        var neu: [Fotoeintrag] = []
        for adresse in adressen {
            let zugriff = adresse.startAccessingSecurityScopedResource()
            defer { if zugriff { adresse.stopAccessingSecurityScopedResource() } }
            if let f = Fotoeinfuhr.ausDatei(adresse) { neu.append(f) }
        }
        buch.wrappedValue.fotos.append(contentsOf: neu)
        if neu.count < adressen.count {
            meldung = "\(adressen.count - neu.count) Dateien ließen sich nicht übernehmen."
        }
    }

    private func ausgeben(_ b: Buch) {
        arbeit = "PDF wird gesetzt …"
        Task { @MainActor in
            let ergebnis: Result<URL, Error> = await Task.detached(priority: .userInitiated) {
                Result { try Buchausgabe.pdf(b) }
            }.value
            arbeit = nil
            switch ergebnis {
            case .success(let url):
                Teilen.zeigen([url])
            case .failure(let fehler):
                meldung = "Das PDF ließ sich nicht schreiben: \(fehler.localizedDescription)"
            }
        }
    }
}
