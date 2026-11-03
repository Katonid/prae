import Photos
import SwiftUI

/// Mediathek-Modus (seit 1.0.13): Aufnahmen der Fotos-Mediathek als Kachelraster wie in der
/// Fotos-App. Antippen öffnet den Betrachter — normale Fotos und Videos flach im Vollbild,
/// 360°-Aufnahmen rundum.
struct MediathekRaster: View {
    let quelle: MediathekQuelle
    @Environment(FotoBibliothek.self) private var bibliothek
    @Environment(\.horizontalSizeClass) private var groessenklasse
    /// Wie in der Fotos-App: neueste Aufnahmen unten (seit 1.0.14, umstellbar).
    @AppStorage("mediathekNeuesteUnten") private var neuesteUnten = true
    /// Kacheln je Zeile, mit zwei Fingern einstellbar (0 = Vorgabe je Gerät).
    @AppStorage("mediathekSpalten") private var spalten = 0
    @State private var spaltenBeimKneifen: Int?
    @State private var aufnahmen: [PHAsset] = []
    @State private var geladen = false
    @State private var geladeneReihenfolge: Bool?
    @State private var offen: BetrachterZiel?
    // Auswählen wie in der Fotos-App (seit 1.0.15)
    @State private var auswaehlen = false
    @State private var gewaehlt: Set<String> = []
    @State private var albumWahl = false
    @State private var paket: TeilenPaket?
    @State private var teiltGerade = false
    @State private var meldung: String?

    static let spaltenBereich = 1...15

    private var aktSpalten: Int {
        spalten > 0 ? spalten : (groessenklasse == .regular ? 7 : 4)
    }

    /// Pixel je Kachel — bei großen Kacheln schärfer, bei vielen kleinen sparsamer.
    private var kachelPixel: CGFloat {
        let breite = groessenklasse == .regular ? 1400.0 : 1200.0
        return min(1200, max(160, (breite / Double(aktSpalten)).rounded()))
    }

    var body: some View {
        ScrollViewReader { leser in
            ScrollView {
                if geladen && aufnahmen.isEmpty {
                    ContentUnavailableView(quelle == .nur360 ? "Keine 360°-Aufnahmen" : "Keine Aufnahmen",
                                           systemImage: quelle.symbol)
                        .padding(.top, 60)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: aktSpalten), spacing: 2) {
                    ForEach(Array(aufnahmen.enumerated()), id: \.element.localIdentifier) { i, a in
                        Button {
                            if auswaehlen {
                                if gewaehlt.contains(a.localIdentifier) { gewaehlt.remove(a.localIdentifier) } else { gewaehlt.insert(a.localIdentifier) }
                            } else {
                                offen = BetrachterZiel(index: i)
                            }
                        } label: {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay { AssetBild(asset: a, groesse: CGSize(width: kachelPixel, height: kachelPixel)) }
                                .clipped()
                                .overlay(alignment: .bottomLeading) {
                                    if aktSpalten <= 7 {
                                        KachelMarke(asset: a).scaleEffect(0.85, anchor: .bottomLeading).padding(4)
                                    }
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    if auswaehlen {
                                        Image(systemName: gewaehlt.contains(a.localIdentifier) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, gewaehlt.contains(a.localIdentifier) ? Color.accentColor : .black.opacity(0.3))
                                            .shadow(radius: 2)
                                            .padding(5)
                                    }
                                }
                                .overlay { if auswaehlen && gewaehlt.contains(a.localIdentifier) { Color.white.opacity(0.25) } }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(a.localIdentifier)
                    }
                }
            }
            .defaultScrollAnchor(quelle.istMediathek && neuesteUnten ? .bottom : .top)
            // Zwei Finger: auseinander = größere Kacheln (weniger je Zeile), zusammen = mehr —
            // wie in der Fotos-App (seit 1.0.14).
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { w in
                        let start = spaltenBeimKneifen ?? aktSpalten
                        if spaltenBeimKneifen == nil { spaltenBeimKneifen = start }
                        let neu = Self.spalten(start: start, faktor: w.magnification)
                        if neu != aktSpalten { withAnimation(.easeInOut(duration: 0.2)) { spalten = neu } }
                    }
                    .onEnded { _ in spaltenBeimKneifen = nil }
            )
            .navigationTitle(quelle.titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .status) {
                    if geladen { Text(aufnahmen.count == 1 ? "1 Aufnahme" : "\(aufnahmen.count) Aufnahmen").font(.caption).foregroundStyle(.secondary) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(auswaehlen ? "Fertig" : "Auswählen") {
                        withAnimation { auswaehlen.toggle() }
                        gewaehlt = []
                    }
                    .fontWeight(auswaehlen ? .semibold : .regular)
                }
                if auswaehlen {
                    ToolbarItemGroup(placement: .bottomBar) {
                        if teiltGerade {
                            ProgressView()
                        } else {
                            Button { teilen() } label: { Image(systemName: "square.and.arrow.up") }.disabled(gewaehlt.isEmpty)
                        }
                        Spacer()
                        Text(gewaehlt.isEmpty ? "Aufnahmen wählen" : (gewaehlt.count == 1 ? "1 ausgewählt" : "\(gewaehlt.count) ausgewählt"))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Menu {
                            Button { ausfuehren { try await favoriten() } } label: { Label("Zu Favoriten", systemImage: "heart") }
                            Button { albumWahl = true } label: { Label("Zu Album hinzufügen …", systemImage: "rectangle.stack.badge.plus") }
                            Button { ausfuehren { try await Aenderungen.ausblenden(auswahl); fertig() } } label: { Label("Ausblenden", systemImage: "eye.slash") }
                        } label: { Image(systemName: "ellipsis.circle") }
                        .disabled(gewaehlt.isEmpty)
                        Button(role: .destructive) { ausfuehren { try await Aenderungen.loeschen(auswahl); fertig() } } label: { Image(systemName: "trash") }
                            .disabled(gewaehlt.isEmpty)
                    }
                }
                if quelle.istMediathek && !auswaehlen {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Picker("Reihenfolge", selection: $neuesteUnten) {
                                Label("Neueste unten (wie Fotos)", systemImage: "arrow.down").tag(true)
                                Label("Neueste oben", systemImage: "arrow.up").tag(false)
                            }
                        } label: {
                            Label("Reihenfolge", systemImage: "arrow.up.arrow.down")
                        }
                    }
                }
            }
            .task(id: "\(bibliothek.stand)-\(neuesteUnten)") {
                aufnahmen = bibliothek.aufnahmen(quelle, neuesteZuerst: !neuesteUnten)
                geladen = true
                // Beim Öffnen und nach dem Umstellen dort beginnen, wo die neuesten stehen —
                // aber NICHT bei jeder Änderung der Mediathek (iCloud), sonst springt das Raster.
                guard quelle.istMediathek, geladeneReihenfolge != neuesteUnten else { return }
                geladeneReihenfolge = neuesteUnten
                try? await Task.sleep(for: .milliseconds(60))
                if let z = neuesteUnten ? aufnahmen.last : aufnahmen.first {
                    leser.scrollTo(z.localIdentifier, anchor: neuesteUnten ? .bottom : .top)
                }
            }
        }
        .fullScreenCover(item: $offen) { z in
            BetrachterAnsicht(albumTitel: quelle.titel, aufnahmen: aufnahmen, startIndex: z.index)
        }
        .sheet(item: $paket) { p in TeilenBlatt(paket: p) { paket = nil } }
        .sheet(isPresented: $albumWahl) {
            AlbumWahl { ziel in ausfuehren { try await Aenderungen.hinzufuegen(auswahl, zuAlbum: ziel); fertig() } }
        }
        .alert("Hinweis", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(meldung ?? "") }
    }

    /// Die gewählten Aufnahmen in der Reihenfolge des Rasters.
    private var auswahl: [PHAsset] { aufnahmen.filter { gewaehlt.contains($0.localIdentifier) } }

    private func fertig() {
        gewaehlt = []
        withAnimation { auswaehlen = false }
    }

    private func ausfuehren(_ f: @escaping () async throws -> Void) {
        Task {
            do { try await f() } catch {
                if !Aenderungen.abgebrochen(error) { meldung = error.localizedDescription }
            }
        }
    }

    private func favoriten() async throws {
        for a in auswahl where !a.isFavorite { _ = try await Aenderungen.favorit(a, true) }
        fertig()
    }

    private func teilen() {
        let liste = auswahl
        guard !liste.isEmpty else { return }
        teiltGerade = true
        ausfuehren {
            defer { teiltGerade = false }
            paket = try await Teilen.paket(liste) { _ in }
        }
    }

    /// Kacheln je Zeile nach einer Kneif-Geste: Faktor 2 halbiert die Zahl (größere Kacheln).
    static func spalten(start: Int, faktor: CGFloat) -> Int {
        guard faktor > 0 else { return start }
        let neu = Int((Double(start) / Double(faktor)).rounded())
        return min(spaltenBereich.upperBound, max(spaltenBereich.lowerBound, neu))
    }
}

/// Abschnitt „Fotos-Mediathek" auf der Startseite: alle Aufnahmen, nur 360°, Videos und die
/// eigenen Alben der Mediathek.
struct MediathekAbschnitt: View {
    let alben: [Knoten]
    var sammlungen: [Sammlung] = []
    var geteilte: [Sammlung] = []

    var body: some View {
        Section {
            ForEach([MediathekQuelle.alle, .nur360, .videos], id: \.self) { q in
                NavigationLink(value: q) {
                    Label(q.titel, systemImage: q.symbol).foregroundStyle(.primary)
                }
            }
            NavigationLink { OrteKarte() } label: {
                Label("Orte", systemImage: "map").foregroundStyle(.primary)
            }
        } header: {
            Label("Fotos-Mediathek", systemImage: "photo.on.rectangle.angled")
        } footer: {
            Text("Alle Fotos und Videos deiner Mediathek: normale Aufnahmen im Vollbild, 360°-Aufnahmen gleich rundum.")
        }
        if !sammlungen.isEmpty {
            // Wie „Medientypen" und „Sammlungen" in der Fotos-App (seit 1.0.15).
            Section("Sammlungen") {
                ForEach(sammlungen) { z in
                    NavigationLink(value: z.quelle) {
                        HStack {
                            Label(z.titel, systemImage: z.symbol).foregroundStyle(.primary)
                            Spacer()
                            Text("\(z.anzahl)").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        Section {
            if !alben.isEmpty {
                DisclosureGroup {
                    ForEach(alben) { k in
                        if k.art == .album {
                            NavigationLink(value: MediathekQuelle.album(id: k.id, titel: k.titel)) {
                                HStack {
                                    Text(k.titel).foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(k.anzahl)").foregroundStyle(.secondary)
                                }
                                .padding(.leading, CGFloat(k.tiefe) * 16)
                            }
                        } else {
                            Label(k.titel, systemImage: "folder")
                                .foregroundStyle(.secondary)
                                .padding(.leading, CGFloat(k.tiefe) * 16)
                        }
                    }
                } label: {
                    Label("Meine Alben", systemImage: "rectangle.stack").foregroundStyle(.primary)
                }
            }
            if !geteilte.isEmpty {
                DisclosureGroup {
                    ForEach(geteilte) { z in
                        NavigationLink(value: z.quelle) {
                            HStack {
                                Text(z.titel).foregroundStyle(.primary)
                                Spacer()
                                Text("\(z.anzahl)").foregroundStyle(.secondary)
                            }
                        }
                    }
                } label: {
                    Label("Geteilte Alben", systemImage: "person.2").foregroundStyle(.primary)
                }
            }
        } header: {
            Text("Alben")
        } footer: {
            Text("„Personen\u{201C}, „Erinnerungen\u{201C}, „Ausgeblendet\u{201C} und „Zuletzt gelöscht\u{201C} gibt iOS nur der Fotos-App selbst heraus.")
        }
    }
}
