import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// ZEITUNG UND MELDUNGEN EINES KAPITELS (Kapitelweise, ab 1.0.4).
//
// Vorlage des Nutzers („Simon 18"): Jedes Lebensjahr beginnt mit der
// Titelseite einer Tageszeitung vom Geburtstag, daneben ein kurzer Text,
// danach „Was an diesem Tag geschah" mit Meldungen aus der Welt — Bild,
// Überschrift, zwei, drei Sätze. Bilder und Texte besorgt der Nutzer; hier
// werden sie eingesetzt. Gesetzt wird beim Schließen.
struct KapitelseitenView: View {
    @ObservedObject var werk: Reisewerk
    let tagID: UUID
    @Environment(\.dismiss) private var schliessen

    private enum Ziel: Equatable {
        case zeitung
        case meldung(UUID)
    }

    @State private var mediathekFuer: Ziel?
    @State private var dateienFuer: Ziel?
    @State private var dateiwahl = false
    @State private var fehler: String?

    private var stelle: Int? { werk.tagIndex(tagID) }

    var body: some View {
        NavigationStack {
            if let stelle {
                Form {
                    zeitungsabschnitt(stelle)
                    meldungsabschnitt(stelle)
                    if let fehler {
                        Section { Text(fehler).foregroundStyle(.red) }
                    }
                }
                .navigationTitle("Zeitung und Meldungen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") {
                            werk.neuAnordnen(tagID, erzwingen: false)
                            werk.sofortSichern()
                            schliessen()
                        }
                    }
                }
                .sheet(isPresented: Binding(get: { mediathekFuer != nil },
                                            set: { if !$0 { mediathekFuer = nil } })) {
                    Fotowahl(hoechstzahl: 1) { treffer in
                        let ziel = mediathekFuer
                        mediathekFuer = nil
                        guard let ziel, let erstes = treffer.first else { return }
                        Task { @MainActor in
                            guard let datei = await Self.ladeDatei(erstes) else {
                                fehler = "Das Bild ließ sich nicht laden."
                                return
                            }
                            setzen(werk.grafikAblegen(vonDatei: datei), fuer: ziel)
                            try? FileManager.default.removeItem(at: datei)
                        }
                    }
                    .ignoresSafeArea()
                }
                .fileImporter(isPresented: $dateiwahl, allowedContentTypes: [.image, .pdf]) { ergebnis in
                    guard case .success(let adresse) = ergebnis, let ziel = dateienFuer else { return }
                    let offen = adresse.startAccessingSecurityScopedResource()
                    defer { if offen { adresse.stopAccessingSecurityScopedResource() } }
                    setzen(werk.grafikAblegen(vonDatei: adresse), fuer: ziel)
                }
            } else {
                Text("Dieses Kapitel gibt es nicht mehr.")
            }
        }
    }

    // MARK: Zeitung

    @ViewBuilder
    private func zeitungsabschnitt(_ stelle: Int) -> some View {
        let tag = werk.reise.tage[stelle]
        Section {
            if let id = tag.zeitung, let foto = werk.reise.foto(id) {
                Ladebild(datei: foto.datei, reise: werk.reise.id, kante: 600) { bild in
                    Image(uiImage: bild).resizable().scaledToFit()
                }
                .frame(maxHeight: 260)
                .frame(maxWidth: .infinity)
                Button("Zeitung entfernen", role: .destructive) {
                    werk.merken()
                    werk.reise.tage[stelle].zeitung = nil
                }
            }
            bildknoepfe(.zeitung, beschriftung: tag.zeitung == nil ? "Titelseite wählen" : "Andere Titelseite")
            TextField("Überschrift daneben, z. B. Der Tag deines 10. Geburtstags",
                      text: binden(stelle, \.zeitungstitel), axis: .vertical)
            TextField("Text daneben", text: binden(stelle, \.zeitungstext), axis: .vertical)
                .lineLimit(3...10)
        } header: {
            Text("Zeitung vom Stichtag")
        } footer: {
            Text("Die Titelseite einer Tageszeitung als Foto, Scan oder PDF (davon die erste Seite). Sie steht groß und leicht gedreht auf der ersten Seite des Kapitels, die Überschrift und der Text links daneben.")
        }
    }

    // MARK: Meldungen

    @ViewBuilder
    private func meldungsabschnitt(_ stelle: Int) -> some View {
        let meldungen = werk.reise.tage[stelle].meldungen
        Section {
            ForEach(meldungen) { meldung in
                meldungszeile(stelle, meldung)
            }
            .onDelete { stellen in
                werk.merken()
                werk.reise.tage[stelle].meldungen.remove(atOffsets: stellen)
            }
            Button {
                werk.merken()
                werk.reise.tage[stelle].meldungen.append(Meldung())
            } label: {
                Label("Meldung hinzufügen", systemImage: "plus")
            }
        } header: {
            Text("Was an diesem Tag geschah")
        } footer: {
            Text("Je Seite vier Meldungen im Raster, jede mit Bild, Überschrift und Text. Mehr Meldungen ergeben weitere Seiten.")
        }
    }

    @ViewBuilder
    private func meldungszeile(_ stelle: Int, _ meldung: Meldung) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray5))
                    if let id = meldung.foto, let foto = werk.reise.foto(id) {
                        Ladebild(datei: foto.datei, reise: werk.reise.id, kante: 160) { bild in
                            Image(uiImage: bild).resizable().scaledToFill()
                        }
                    } else {
                        Image(systemName: "photo").foregroundStyle(.secondary)
                    }
                }
                .frame(width: 64, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                TextField("Überschrift", text: meldungsbindung(stelle, meldung.id, \.titel), axis: .vertical)
                    .font(.headline)
            }
            TextField("Zwei, drei Sätze", text: meldungsbindung(stelle, meldung.id, \.text), axis: .vertical)
                .lineLimit(2...8)
            bildknoepfe(.meldung(meldung.id), beschriftung: meldung.foto == nil ? "Bild wählen" : "Anderes Bild")
        }
        .padding(.vertical, 4)
    }

    private func bildknoepfe(_ ziel: Ziel, beschriftung: String) -> some View {
        Menu {
            Button("Aus der Mediathek", systemImage: "photo.on.rectangle") { mediathekFuer = ziel }
            Button("Aus Dateien (Bild oder PDF)", systemImage: "folder") {
                dateienFuer = ziel
                dateiwahl = true
            }
        } label: {
            Label(beschriftung, systemImage: "photo.badge.plus")
        }
    }

    private func setzen(_ id: UUID?, fuer ziel: Ziel) {
        guard let id else {
            fehler = "Die Datei ließ sich nicht lesen."
            return
        }
        fehler = nil
        guard let stelle else { return }
        werk.merken()
        switch ziel {
        case .zeitung:
            werk.reise.tage[stelle].zeitung = id
        case .meldung(let kennung):
            if let i = werk.reise.tage[stelle].meldungen.firstIndex(where: { $0.id == kennung }) {
                werk.reise.tage[stelle].meldungen[i].foto = id
            }
        }
    }

    private func binden(_ stelle: Int, _ pfad: WritableKeyPath<Reisetag, String>) -> Binding<String> {
        Binding(
            get: { werk.reise.tage.indices.contains(stelle) ? werk.reise.tage[stelle][keyPath: pfad] : "" },
            set: { if werk.reise.tage.indices.contains(stelle) { werk.reise.tage[stelle][keyPath: pfad] = $0 } }
        )
    }

    private func meldungsbindung(_ stelle: Int, _ id: UUID,
                                 _ pfad: WritableKeyPath<Meldung, String>) -> Binding<String> {
        Binding(
            get: {
                guard werk.reise.tage.indices.contains(stelle) else { return "" }
                return werk.reise.tage[stelle].meldungen.first { $0.id == id }?[keyPath: pfad] ?? ""
            },
            set: { neu in
                guard werk.reise.tage.indices.contains(stelle),
                      let i = werk.reise.tage[stelle].meldungen.firstIndex(where: { $0.id == id }) else { return }
                werk.reise.tage[stelle].meldungen[i][keyPath: pfad] = neu
            }
        )
    }

    /// Holt die Bilddatei eines Treffers (wie `BildAusFotosView`): als
    /// Datei, nicht als Bytes, und nur einmal fortgesetzt.
    private static func ladeDatei(_ eintrag: PHPickerResult) async -> URL? {
        let anbieter = eintrag.itemProvider
        guard anbieter.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { return nil }
        return await withCheckedContinuation { (fortsetzen: CheckedContinuation<URL?, Never>) in
            let einmal = EinmalSchalter()
            _ = anbieter.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { quelle, _ in
                guard einmal.erstesMal() else { return }
                guard let quelle else {
                    fortsetzen.resume(returning: nil)
                    return
                }
                let art = quelle.pathExtension.isEmpty ? "jpg" : quelle.pathExtension
                let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + art)
                do {
                    try FileManager.default.copyItem(at: quelle, to: ziel)
                    fortsetzen.resume(returning: ziel)
                } catch {
                    fortsetzen.resume(returning: nil)
                }
            }
        }
    }
}

/// Lässt genau einen Durchgang zu — `loadFileRepresentation` darf seinen
/// Rückruf mehrmals rufen, eine Continuation verträgt nur ein `resume`.
final class EinmalSchalter: @unchecked Sendable {
    private let sperre = NSLock()
    private var schonGeschehen = false

    func erstesMal() -> Bool {
        sperre.lock()
        defer { sperre.unlock() }
        if schonGeschehen { return false }
        schonGeschehen = true
        return true
    }
}
