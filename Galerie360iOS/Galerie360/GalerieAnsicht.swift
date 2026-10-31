import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Eine geöffnete Galerie: links die Alben (Unteralben eingerückt), rechts das gewählte Album.
struct GalerieAnsicht: View {
    @Bindable var galerie: Galerie
    let schliessen: () -> Void
    @State private var auswahl: String?
    @State private var umbenennen: Album?
    @State private var neuerName = ""
    @State private var loeschen: Album?
    @State private var titelAendern = false
    @State private var galerieTitel = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $auswahl) {
                ForEach(galerie.baum) { e in
                    HStack(spacing: 10) {
                        Vorschaubild(url: galerie.url(e.album.kartenbild?.vorschau))
                            .frame(width: 44, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.album.anzeigeTitel + (e.album.freigabe == "link" ? " 🔗" : e.album.freigabe == "entwurf" ? " ✎" : ""))
                                .lineLimit(1)
                            Text(e.album.zaehlung).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, CGFloat(e.tiefe) * 18)
                    .tag(e.album.id)
                    .contextMenu {
                        Button { neuerName = e.album.titel; umbenennen = e.album } label: { Label("Umbenennen …", systemImage: "pencil") }
                        Button {
                            auswahl = galerie.albumAnlegen(titel: "Neues Unteralbum", eltern: e.album.id)
                        } label: { Label("Unteralbum anlegen", systemImage: "folder.badge.plus") }
                        if e.album.eltern != nil {
                            Button { galerie.elternSetzen(e.album.id, nil) } label: { Label("Auf die oberste Ebene", systemImage: "arrow.up.to.line") }
                        }
                        Button(role: .destructive) { loeschen = e.album } label: { Label("Album löschen …", systemImage: "trash") }
                    }
                }
            }
            .navigationTitle(galerie.titel)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { schliessen() } label: { Label("Galerien", systemImage: "chevron.left") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { auswahl = galerie.albumAnlegen(titel: "Neues Album", eltern: nil) } label: { Label("Neues Album", systemImage: "plus.rectangle.on.rectangle") }
                        Button { galerieTitel = galerie.titel; titelAendern = true } label: { Label("Galerie umbenennen …", systemImage: "pencil") }
                    } label: { Image(systemName: "plus") }
                }
            }
        } detail: {
            if let id = auswahl, galerie.album(id) != nil {
                AlbumAnsicht(galerie: galerie, albumId: id, auswahl: $auswahl)
                    .id(id)
            } else {
                ContentUnavailableView("Album wählen", systemImage: "rectangle.stack", description: Text("Links ein Album antippen."))
            }
        }
        .onAppear { if auswahl == nil { auswahl = galerie.baum.first?.album.id } }
        .alert("Album umbenennen", isPresented: Binding(get: { umbenennen != nil }, set: { if !$0 { umbenennen = nil } })) {
            TextField("Name", text: $neuerName)
            Button("Abbrechen", role: .cancel) {}
            Button("Umbenennen") { if let a = umbenennen { galerie.albumTitelSetzen(a.id, neuerName) } }
        }
        .alert("Galerie umbenennen", isPresented: $titelAendern) {
            TextField("Name", text: $galerieTitel)
            Button("Abbrechen", role: .cancel) {}
            Button("Umbenennen") { if !galerieTitel.isEmpty { galerie.setzeTitel(galerieTitel) } }
        } message: { Text("Die Links zu den Alben ändern sich dadurch nicht.") }
        .confirmationDialog(loeschen.map { "„\($0.anzeigeTitel)“ löschen?" } ?? "",
                            isPresented: Binding(get: { loeschen != nil }, set: { if !$0 { loeschen = nil } }),
                            titleVisibility: .visible) {
            Button("Album und seine \(loeschen?.medien.count ?? 0) Aufnahmen löschen", role: .destructive) {
                if let a = loeschen {
                    galerie.dateienLoeschen(galerie.albumLoeschen(a.id))
                    if auswahl == a.id { auswahl = galerie.baum.first?.album.id }
                }
            }
        } message: {
            Text("Die Kopien in der Galerie werden gelöscht, deine Originale in Fotos bleiben. Unteralben bleiben erhalten und rücken eine Ebene höher.")
        }
        .alert("Fehler", isPresented: Binding(get: { galerie.fehler != nil }, set: { if !$0 { galerie.fehler = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(galerie.fehler ?? "") }
    }
}

struct BetrachterZiel: Identifiable {
    let index: Int
    var id: Int { index }
}

/// Ein Album: Kopf (Name, Beschreibung, Unteralben), darunter die Aufnahmen als Raster.
/// „Bearbeiten" zeigt eine Liste zum Verschieben (am Griff ziehen) und Löschen.
struct AlbumAnsicht: View {
    @Bindable var galerie: Galerie
    let albumId: String
    @Binding var auswahl: String?
    @State private var bearbeiten = false
    @State private var fotoAuswahl: [PhotosPickerItem] = []
    @State private var dateienWaehlen = false
    @State private var betrachter: BetrachterZiel?
    @State private var importStand: String?
    @State private var umbenennen: Medium?
    @State private var neuerTitel = ""
    @State private var loeschen: Medium?
    @State private var meldung: String?

    private var album: Album? { galerie.album(albumId) }

    var body: some View {
        Group {
            if let album {
                if bearbeiten { bearbeitenListe(album) } else { raster(album) }
            }
        }
        .navigationTitle(album?.anzeigeTitel ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    PhotosPicker(selection: $fotoAuswahl, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
                        Label("Aus Fotos …", systemImage: "photo.on.rectangle")
                    }
                    Button { dateienWaehlen = true } label: { Label("Aus Dateien …", systemImage: "folder") }
                } label: { Label("Hinzufügen", systemImage: "plus") }
                Menu {
                    Button("Nach Aufnahmedatum, älteste zuerst") { galerie.sortieren(album: albumId, .datumAlt) }
                    Button("Nach Aufnahmedatum, neueste zuerst") { galerie.sortieren(album: albumId, .datumNeu) }
                    Button("Nach Titel (A–Z)") { galerie.sortieren(album: albumId, .titel) }
                    Button("Reihenfolge umkehren") { galerie.sortieren(album: albumId, .umkehren) }
                } label: { Label("Sortieren", systemImage: "arrow.up.arrow.down") }
                Button(bearbeiten ? "Fertig" : "Bearbeiten") { withAnimation { bearbeiten.toggle() } }
            }
        }
        .onChange(of: fotoAuswahl) { _, neu in
            guard !neu.isEmpty else { return }
            fotoAuswahl = []
            Task { await importieren(neu) }
        }
        .fileImporter(isPresented: $dateienWaehlen, allowedContentTypes: [.image, .movie], allowsMultipleSelection: true) { ergebnis in
            if case .success(let urls) = ergebnis { Task { await importieren(urls) } }
        }
        .fullScreenCover(item: $betrachter) { z in
            BetrachterAnsicht(galerie: galerie, albumId: albumId, startIndex: z.index)
        }
        .overlay(alignment: .bottom) {
            if let s = importStand {
                HStack(spacing: 10) { ProgressView(); Text(s) }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding()
            }
        }
        .alert("Titel ändern", isPresented: Binding(get: { umbenennen != nil }, set: { if !$0 { umbenennen = nil } })) {
            TextField("Titel", text: $neuerTitel)
            Button("Abbrechen", role: .cancel) {}
            Button("Übernehmen") { if let m = umbenennen { galerie.mediumAendern(m.id) { $0["titel"] = neuerTitel } } }
        }
        .confirmationDialog("Aufnahme entfernen?", isPresented: Binding(get: { loeschen != nil }, set: { if !$0 { loeschen = nil } }), titleVisibility: .visible) {
            Button("Entfernen", role: .destructive) { if let m = loeschen { galerie.dateienLoeschen(galerie.mediumLoeschen(m.id)) } }
        } message: { Text("Die Kopie in der Galerie wird gelöscht, dein Original in Fotos bleibt.") }
        .alert("Hinweis", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(meldung ?? "") }
    }

    // MARK: Raster

    private func raster(_ album: Album) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                kopf(album)
                let kinder = galerie.kinder(von: album.id)
                if !kinder.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(kinder) { k in
                                Button { auswahl = k.id } label: { AlbumKarte(galerie: galerie, album: k) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if album.medien.isEmpty {
                    ContentUnavailableView("Noch leer", systemImage: "photo.badge.plus", description: Text("Mit + Fotos und Videos aus der Fotos-App oder aus Dateien hinzufügen."))
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 14)], spacing: 18) {
                    ForEach(Array(album.medien.enumerated()), id: \.element.id) { i, m in
                        Button { betrachter = BetrachterZiel(index: i) } label: { Kachel(galerie: galerie, medium: m, albumbild: album.titelbild == m.id) }
                            .buttonStyle(.plain)
                            .contextMenu { kontextmenue(m, album) }
                    }
                }
            }
            .padding()
        }
    }

    private func kopf(_ album: Album) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Name des Albums", text: Binding(get: { album.titel }, set: { galerie.albumTitelSetzen(albumId, $0) }))
                .font(.largeTitle.bold())
            TextField("Beschreibung (optional)", text: Binding(get: { album.beschreibung }, set: { t in galerie.albumAendern(albumId) { $0["beschreibung"] = t } }), axis: .vertical)
                .foregroundStyle(.secondary)
            Text(album.zaehlung).font(.footnote).foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func kontextmenue(_ m: Medium, _ album: Album) -> some View {
        Button { neuerTitel = m.titel; umbenennen = m } label: { Label("Titel ändern …", systemImage: "pencil") }
        Button {
            galerie.albumAendern(albumId) { $0["titelbild"] = album.titelbild == m.id ? NSNull() : m.id }
        } label: { Label(album.titelbild == m.id ? "Albumbild ✓" : "Als Albumbild", systemImage: "star") }
        Menu {
            ForEach(galerie.baum.filter { $0.album.id != albumId }) { e in
                Button(String(repeating: "  ", count: e.tiefe) + e.album.anzeigeTitel) { galerie.mediumVerschieben(m.id, nach: e.album.id) }
            }
        } label: { Label("Verschieben nach", systemImage: "folder") }
        Button(role: .destructive) { loeschen = m } label: { Label("Entfernen …", systemImage: "trash") }
    }

    // MARK: Bearbeiten

    private func bearbeitenListe(_ album: Album) -> some View {
        List {
            Section {
                ForEach(album.medien) { m in
                    HStack(spacing: 12) {
                        Vorschaubild(url: galerie.url(m.vorschau))
                            .frame(width: 80, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading) {
                            Text(m.anzeigeTitel).lineLimit(1)
                            Text(m.datum.map(datumText) ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove { galerie.medienVerschieben(album: albumId, von: $0, nach: $1) }
                .onDelete { idx in
                    for i in idx.sorted(by: >) where album.medien.indices.contains(i) {
                        galerie.dateienLoeschen(galerie.mediumLoeschen(album.medien[i].id))
                    }
                }
            } footer: {
                Text("Am Griff ziehen, um die Reihenfolge zu ändern; nach links wischen zum Entfernen.")
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    // MARK: Import

    private func importieren(_ eintraege: [PhotosPickerItem]) async {
        let ordner = galerie.ordner
        for (i, e) in eintraege.enumerated() {
            importStand = "Übernehme \(i + 1) von \(eintraege.count) …"
            do {
                if e.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                    guard let film = try await e.loadTransferable(type: FilmDatei.self) else { continue }
                    defer { try? FileManager.default.removeItem(at: film.url) }
                    let name = film.url.lastPathComponent.components(separatedBy: "-").dropFirst(5).joined(separator: "-")
                    let m = try await Import.video(film.url, name: name.isEmpty ? "video.mp4" : name, ordner: ordner)
                    galerie.mediumHinzufuegen(m, album: albumId)
                } else {
                    guard let daten = try await e.loadTransferable(type: Data.self) else { continue }
                    let m = try await Import.foto(daten: daten, name: nil, ordner: ordner)
                    galerie.mediumHinzufuegen(m, album: albumId)
                }
            } catch {
                meldung = "Eine Aufnahme ließ sich nicht übernehmen: \(error.localizedDescription)"
            }
        }
        importStand = nil
        galerie.jetztSpeichern()
    }

    private func importieren(_ urls: [URL]) async {
        let ordner = galerie.ordner
        for (i, url) in urls.enumerated() {
            importStand = "Übernehme \(i + 1) von \(urls.count) …"
            let zugriff = url.startAccessingSecurityScopedResource()
            defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
            do {
                let typ = UTType(filenameExtension: url.pathExtension)
                if typ?.conforms(to: .movie) == true {
                    let m = try await Import.video(url, name: url.lastPathComponent, ordner: ordner)
                    galerie.mediumHinzufuegen(m, album: albumId)
                } else {
                    let daten = try await Task.detached { try Datei.lesen(url) }.value
                    let m = try await Import.foto(daten: daten, name: url.lastPathComponent, ordner: ordner)
                    galerie.mediumHinzufuegen(m, album: albumId)
                }
            } catch {
                meldung = "„\(url.lastPathComponent)“ ließ sich nicht übernehmen: \(error.localizedDescription)"
            }
        }
        importStand = nil
        galerie.jetztSpeichern()
    }
}

func datumText(_ iso: String) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    guard let d = f.date(from: String(iso.prefix(10))) else { return iso }
    return d.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "de_DE")))
}

struct Kachel: View {
    let galerie: Galerie
    let medium: Medium
    var albumbild = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Vorschaubild(url: galerie.url(medium.vorschau))
                .aspectRatio(16 / 10, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomLeading) {
                    Label(medium.art == .video ? zeitText(medium.dauer) : "360°", systemImage: medium.art == .video ? "video" : "camera")
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
            Text(medium.anzeigeTitel).font(.subheadline.weight(.semibold)).lineLimit(1)
            if let d = medium.datum { Text(datumText(d)).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct AlbumKarte: View {
    let galerie: Galerie
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Vorschaubild(url: galerie.url(album.kartenbild?.vorschau))
                .frame(width: 180, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(album.anzeigeTitel).font(.subheadline.weight(.semibold)).lineLimit(1)
            Text(album.zaehlung).font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: 180)
    }
}

func zeitText(_ s: Double) -> String {
    let g = Int(s.rounded())
    return String(format: "%d:%02d", g / 60, g % 60)
}

/// Vorschaubild aus der Galerie (lädt bei iCloud-Dateien erst herunter), zwischengespeichert.
struct Vorschaubild: View {
    let url: URL?
    @State private var bild: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.secondary.opacity(0.15))
            if let bild {
                Image(uiImage: bild).resizable().scaledToFill()
            }
        }
        .clipped()
        .task(id: url) { bild = await Bildspeicher.shared.bild(url) }
    }
}

actor Bildspeicher {
    static let shared = Bildspeicher()
    private let speicher = NSCache<NSURL, UIImage>()

    func bild(_ url: URL?) async -> UIImage? {
        guard let url else { return nil }
        if let b = speicher.object(forKey: url as NSURL) { return b }
        let geladen = await Task.detached(priority: .utility) { () -> UIImage? in
            guard let d = try? Datei.lesen(url), let b = UIImage(data: d) else { return nil }
            return b.preparingThumbnail(of: CGSize(width: 640, height: 400)) ?? b
        }.value
        if let geladen { speicher.setObject(geladen, forKey: url as NSURL) }
        return geladen
    }
}
