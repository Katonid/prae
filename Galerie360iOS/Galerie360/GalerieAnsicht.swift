import Photos
import PhotosUI
import SwiftUI

/// Eine Galerie: links ihre Alben und Ordner (Unteralben eingerückt), rechts das gewählte Album.
struct GalerieAnsicht: View {
    let galerie: GalerieInfo
    let schliessen: () -> Void
    @Environment(FotoBibliothek.self) private var bibliothek
    @State private var baum: [Knoten] = []
    @State private var auswahl: String?
    @State private var frage: Frage?
    @State private var eingabe = ""
    @State private var loeschen: Knoten?
    @State private var galerieLoeschen = false
    @State private var meldung: String?

    /// Was der Namensdialog gerade erfragt.
    enum Frage: Identifiable {
        case neuesAlbum(in: String), neuerOrdner(in: String), umbenennen(Knoten), galerieUmbenennen
        var id: String {
            switch self {
            case .neuesAlbum(let e): return "a" + e
            case .neuerOrdner(let e): return "o" + e
            case .umbenennen(let k): return "u" + k.id
            case .galerieUmbenennen: return "g"
            }
        }
    }

    private var titel: String { bibliothek.galerien.first { $0.id == galerie.id }?.titel ?? galerie.titel }

    var body: some View {
        NavigationSplitView {
            List(selection: $auswahl) {
                if baum.isEmpty {
                    Text("Noch kein Album. Mit + ein Album anlegen.").foregroundStyle(.secondary)
                }
                ForEach(baum) { k in
                    zeile(k)
                        .padding(.leading, CGFloat(k.tiefe) * 18)
                        .tag(k.id)
                        .contextMenu { kontext(k) }
                }
            }
            .navigationTitle(titel)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { schliessen() } label: { Label("Galerien", systemImage: "chevron.left") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { fragen(.neuesAlbum(in: galerie.id)) } label: { Label("Neues Album", systemImage: "rectangle.stack.badge.plus") }
                        Button { fragen(.neuerOrdner(in: galerie.id)) } label: { Label("Neuer Ordner für Unteralben", systemImage: "folder.badge.plus") }
                    } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { eingabe = titel; frage = .galerieUmbenennen } label: { Label("Galerie umbenennen …", systemImage: "pencil") }
                        Button(role: .destructive) { galerieLoeschen = true } label: { Label("Galerie löschen …", systemImage: "trash") }
                    } label: { Label("Galerie", systemImage: "ellipsis.circle") }
                }
            }
        } detail: {
            if let id = auswahl, let k = baum.first(where: { $0.id == id }) {
                if k.art == .album {
                    AlbumAnsicht(albumId: k.id, titel: k.titel, alleAlben: baum.filter { $0.art == .album })
                        .id(k.id)
                } else {
                    ContentUnavailableView {
                        Label(k.titel, systemImage: "folder")
                    } description: {
                        Text("Ein Ordner für Unteralben. Links ein Album darin wählen — oder eines anlegen.")
                    } actions: {
                        Button("Neues Album in diesem Ordner") { fragen(.neuesAlbum(in: k.id)) }
                    }
                }
            } else {
                ContentUnavailableView("Album wählen", systemImage: "rectangle.stack", description: Text("Links ein Album antippen."))
            }
        }
        .task(id: bibliothek.stand) {
            baum = bibliothek.baum(galerie.id)
            if auswahl == nil || !baum.contains(where: { $0.id == auswahl }) {
                auswahl = baum.first { $0.art == .album }?.id
            }
        }
        .alert(frageTitel, isPresented: Binding(get: { frage != nil }, set: { if !$0 { frage = nil } })) {
            TextField("Name", text: $eingabe)
            Button("Abbrechen", role: .cancel) {}
            Button("OK") { if let f = frage { ausfuehren(f) } }
        }
        .confirmationDialog(loeschen.map { "„\($0.titel)“ löschen?" } ?? "",
                            isPresented: Binding(get: { loeschen != nil }, set: { if !$0 { loeschen = nil } }),
                            titleVisibility: .visible) {
            Button(loeschen?.art == .ordner ? "Ordner mit seinen Alben löschen" : "Album löschen", role: .destructive) {
                if let k = loeschen { Task { await tun { try await bibliothek.loeschen(k.id) } } }
            }
        } message: {
            Text("Nur das Album bzw. der Ordner verschwindet — die Fotos und Videos bleiben in deiner Mediathek.")
        }
        .confirmationDialog("Galerie „\(titel)“ löschen?", isPresented: $galerieLoeschen, titleVisibility: .visible) {
            Button("Galerie mit ihren Alben löschen", role: .destructive) {
                Task {
                    await tun {
                        try await bibliothek.loeschen(galerie.id)
                        if bibliothek.ordner(galerie.id) == nil { schliessen() }
                    }
                }
            }
        } message: {
            Text("Der Ordner und die Alben darin verschwinden aus der Fotos-App — die Fotos und Videos selbst bleiben in deiner Mediathek.")
        }
        .alert("Hinweis", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(meldung ?? "") }
    }

    private func zeile(_ k: Knoten) -> some View {
        HStack(spacing: 10) {
            if k.art == .ordner {
                Image(systemName: "folder")
                    .frame(width: 44, height: 28)
                    .foregroundStyle(Color.accentColor)
            } else {
                AlbumVorschau(albumId: k.id)
                    .frame(width: 44, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(k.titel).lineLimit(1)
                if k.art == .album {
                    Text(k.anzahl == 1 ? "1 Aufnahme" : "\(k.anzahl) Aufnahmen").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func kontext(_ k: Knoten) -> some View {
        Button { eingabe = k.titel; frage = .umbenennen(k) } label: { Label("Umbenennen …", systemImage: "pencil") }
        if k.art == .ordner {
            Button { fragen(.neuesAlbum(in: k.id)) } label: { Label("Neues Album darin", systemImage: "rectangle.stack.badge.plus") }
            Button { fragen(.neuerOrdner(in: k.id)) } label: { Label("Neuer Ordner darin", systemImage: "folder.badge.plus") }
        }
        Button(role: .destructive) { loeschen = k } label: { Label("Löschen …", systemImage: "trash") }
    }

    private var frageTitel: String {
        switch frage {
        case .neuesAlbum: return "Neues Album"
        case .neuerOrdner: return "Neuer Ordner für Unteralben"
        case .umbenennen: return "Umbenennen"
        case .galerieUmbenennen: return "Galerie umbenennen"
        case nil: return ""
        }
    }

    private func fragen(_ f: Frage) {
        eingabe = ""
        frage = f
    }

    private func ausfuehren(_ f: Frage) {
        let t = eingabe.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        Task {
            await tun {
                switch f {
                case .neuesAlbum(let e):
                    if let id = try await bibliothek.albumAnlegen(t, in: e) { auswahl = id }
                case .neuerOrdner(let e):
                    _ = try await bibliothek.unterordnerAnlegen(t, in: e)
                case .umbenennen(let k):
                    try await bibliothek.umbenennen(k.id, t)
                case .galerieUmbenennen:
                    try await bibliothek.umbenennen(galerie.id, t)
                }
            }
        }
    }

    private func tun(_ f: () async throws -> Void) async {
        do { try await f() } catch {
            // Abbrechen in der Rückfrage von iOS (Löschen) ist kein Fehler.
            if (error as NSError).code != 3072 { meldung = error.localizedDescription }
        }
    }
}

/// Ein Album: Aufnahmen als Raster; „Bearbeiten" zum Ordnen und Entfernen.
struct AlbumAnsicht: View {
    let albumId: String
    let titel: String
    let alleAlben: [Knoten]
    @Environment(FotoBibliothek.self) private var bibliothek
    @Environment(Notizen.self) private var notizen
    @State private var aufnahmen: [PHAsset] = []
    @State private var bearbeiten = false
    @State private var auswahlFotos: [PhotosPickerItem] = []
    @State private var betrachter: BetrachterZiel?
    @State private var titelAendern: PHAsset?
    @State private var eingabe = ""
    @State private var meldung: String?

    var body: some View {
        Group {
            if bearbeiten { liste } else { raster }
        }
        .navigationTitle(titel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                PhotosPicker(selection: $auswahlFotos, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
                    Label("Aus der Mediathek hinzufügen", systemImage: "plus")
                }
                Menu {
                    Button("Nach Aufnahmedatum, älteste zuerst") { sortieren(.datumAlt) }
                    Button("Nach Aufnahmedatum, neueste zuerst") { sortieren(.datumNeu) }
                    Button("Nach Titel (A–Z)") { sortieren(.titel) }
                    Button("Reihenfolge umkehren") { sortieren(.umkehren) }
                } label: { Label("Sortieren", systemImage: "arrow.up.arrow.down") }
                Button(bearbeiten ? "Fertig" : "Bearbeiten") { withAnimation { bearbeiten.toggle() } }
            }
        }
        .task(id: bibliothek.stand) { aufnahmen = bibliothek.aufnahmen(albumId) }
        .onChange(of: auswahlFotos) { _, neu in
            let ids = neu.compactMap(\.itemIdentifier)
            guard !neu.isEmpty else { return }
            auswahlFotos = []
            if ids.isEmpty {
                meldung = "Die Auswahl kam ohne Verweis auf die Mediathek an. Bitte Vollzugriff auf Fotos erlauben."
                return
            }
            Task { await tun { try await bibliothek.hinzufuegen(ids, zu: albumId) } }
        }
        .fullScreenCover(item: $betrachter) { z in
            BetrachterAnsicht(albumTitel: titel, aufnahmen: aufnahmen, startIndex: z.index)
        }
        .alert("Titel ändern", isPresented: Binding(get: { titelAendern != nil }, set: { if !$0 { titelAendern = nil } })) {
            TextField("Titel", text: $eingabe)
            Button("Abbrechen", role: .cancel) {}
            Button("Übernehmen") { if let a = titelAendern { notizen.setzeTitel(a.localIdentifier, eingabe) } }
        }
        .alert("Hinweis", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(meldung ?? "") }
    }

    private var raster: some View {
        ScrollView {
            if aufnahmen.isEmpty {
                ContentUnavailableView("Noch leer", systemImage: "photo.badge.plus",
                                       description: Text("Mit + Fotos und Videos aus deiner Mediathek hinzufügen. Sie werden nicht kopiert, nur ins Album aufgenommen."))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 14)], spacing: 18) {
                ForEach(Array(aufnahmen.enumerated()), id: \.element.localIdentifier) { i, a in
                    Button { betrachter = BetrachterZiel(index: i) } label: {
                        Kachel(asset: a, albumbild: notizen.albumbild(albumId) == a.localIdentifier)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { kontext(a) }
                }
            }
            .padding()
        }
    }

    private var liste: some View {
        List {
            Section {
                ForEach(aufnahmen, id: \.localIdentifier) { a in
                    HStack(spacing: 12) {
                        AssetBild(asset: a, groesse: CGSize(width: 160, height: 100))
                            .frame(width: 80, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading) {
                            Text(notizen.titel(a.localIdentifier) ?? datumText(a.creationDate)).lineLimit(1)
                            Text(a.mediaType == .video ? "Video · " + zeitText(a.duration) : "Foto").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove { von, nach in
                    aufnahmen.move(fromOffsets: von, toOffset: nach)
                    Task { await tun { try await bibliothek.reihenfolge(albumId, von: von, nach: nach) } }
                }
                .onDelete { idx in
                    let weg = idx.map { aufnahmen[$0] }
                    Task { await tun { try await bibliothek.entfernen(weg, aus: albumId) } }
                }
            } footer: {
                Text("Am Griff ziehen ändert die Reihenfolge (auch in der Fotos-App). Nach links wischen nimmt die Aufnahme aus dem Album — in der Mediathek bleibt sie.")
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    @ViewBuilder
    private func kontext(_ a: PHAsset) -> some View {
        let id = a.localIdentifier
        Button { eingabe = notizen.titel(id) ?? ""; titelAendern = a } label: { Label("Titel ändern …", systemImage: "pencil") }
        Button {
            notizen.setzeAlbumbild(albumId, notizen.albumbild(albumId) == id ? nil : id)
        } label: { Label(notizen.albumbild(albumId) == id ? "Albumbild ✓" : "Als Albumbild", systemImage: "star") }
        let ziele = alleAlben.filter { $0.id != albumId }
        if !ziele.isEmpty {
            Menu {
                ForEach(ziele) { z in
                    Button(String(repeating: "  ", count: z.tiefe) + z.titel) {
                        Task { await tun { try await bibliothek.verschieben(a, von: albumId, nach: z.id) } }
                    }
                }
            } label: { Label("Verschieben nach", systemImage: "folder") }
        }
        Button(role: .destructive) {
            Task { await tun { try await bibliothek.entfernen([a], aus: albumId) } }
        } label: { Label("Aus dem Album nehmen", systemImage: "minus.circle") }
    }

    private func sortieren(_ art: Sortierung) {
        let neu = art.ordne(aufnahmen, datum: { $0.creationDate }, titel: { notizen.titel($0.localIdentifier) ?? "" })
        Task { await tun { try await bibliothek.ordnen(albumId, neu) } }
    }

    private func tun(_ f: () async throws -> Void) async {
        do { try await f() } catch {
            if (error as NSError).code != 3072 { meldung = error.localizedDescription }
        }
    }
}

struct BetrachterZiel: Identifiable {
    let index: Int
    var id: Int { index }
}

struct Kachel: View {
    let asset: PHAsset
    var albumbild = false
    @Environment(Notizen.self) private var notizen

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AssetBild(asset: asset, groesse: CGSize(width: 640, height: 400))
                .aspectRatio(16 / 10, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomLeading) {
                    Label(asset.mediaType == .video ? zeitText(asset.duration) : "360°",
                          systemImage: asset.mediaType == .video ? "video" : "camera")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.black.opacity(0.55), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    if albumbild {
                        Image(systemName: "star.fill").font(.caption).padding(6)
                            .background(Color.accentColor, in: Circle()).foregroundStyle(.white).padding(8)
                    }
                }
            if let t = notizen.titel(asset.localIdentifier) {
                Text(t).font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            Text(datumText(asset.creationDate)).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Vorschau eines Albums für die Seitenleiste: das Albumbild, sonst die erste Aufnahme.
struct AlbumVorschau: View {
    let albumId: String
    @Environment(FotoBibliothek.self) private var bibliothek
    @Environment(Notizen.self) private var notizen
    @State private var asset: PHAsset?

    var body: some View {
        AssetBild(asset: asset, groesse: CGSize(width: 120, height: 76))
            .task(id: "\(albumId)-\(bibliothek.stand)-\(notizen.albumbild(albumId) ?? "")") {
                let alle = bibliothek.aufnahmen(albumId)
                asset = alle.first { $0.localIdentifier == notizen.albumbild(albumId) } ?? alle.first
            }
    }
}
