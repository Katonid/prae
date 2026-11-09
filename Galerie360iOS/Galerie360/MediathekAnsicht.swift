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
    @State private var datenStand = 0
    @State private var springen = false
    @State private var aufnahmen: [PHAsset] = []
    @State private var geladen = false
    @State private var geladeneReihenfolge: Bool?
    @State private var ergebnis: PHFetchResult<PHAsset>?
    @State private var offen: BetrachterZiel?
    // Auswählen wie in der Fotos-App (seit 1.0.15)
    @State private var auswaehlen = false
    @State private var gewaehlt: Set<String> = []
    @State private var albumWahl = false
    @State private var paket: TeilenPaket?
    @State private var teiltGerade = false
    @State private var meldung: String?
    @State private var ortWahl = false
    /// Zählt geschlossene Betrachter — „Ohne Ort“ lädt danach neu (seit 1.0.24).
    @State private var betrachterZu = 0
    @State private var geladenNachZu = 0

    static let spaltenBereich = 1...15

    private var aktSpalten: Int {
        spalten > 0 ? spalten : (groessenklasse == .regular ? 7 : 4)
    }

    var body: some View {
        ZStack {
            // UIKit-Raster wie die Fotos-App (seit 1.0.17, `RasterSammlung`).
            RasterSammlung(aufnahmen: aufnahmen, stand: datenStand, spalten: aktSpalten, marken: aktSpalten <= 7,
                           auswaehlen: auswaehlen, gewaehlt: gewaehlt,
                           positionsSchluessel: quelle.positionsSchluessel,
                           neuesteUnten: quelle.istMediathek && neuesteUnten, zuNeuesten: springen,
                           getippt: { i in
                               guard aufnahmen.indices.contains(i) else { return }
                               let id = aufnahmen[i].localIdentifier
                               if auswaehlen {
                                   if gewaehlt.contains(id) { gewaehlt.remove(id) } else { gewaehlt.insert(id) }
                               } else {
                                   offen = BetrachterZiel(index: i)
                               }
                           },
                           spaltenGeaendert: { spalten = $0 })
                .ignoresSafeArea(edges: .bottom)
            if geladen && aufnahmen.isEmpty {
                ContentUnavailableView(quelle == .nur360 ? "Keine 360°-Aufnahmen"
                                       : quelle == .ohneOrt ? "Alle Aufnahmen haben einen Ort" : "Keine Aufnahmen",
                                       systemImage: quelle.symbol)
            }
        }
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
                        Button { ortWahl = true } label: { Image(systemName: "mappin.and.ellipse") }
                            .disabled(gewaehlt.isEmpty)
                            .accessibilityLabel("Ort festlegen")
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
            .task(id: "\(bibliothek.stand)-\(neuesteUnten)-\(betrachterZu)") {
                // „Ohne Ort“: Solange der Betrachter offen ist, bleibt die Liste stehen — sonst
                // verschwände die Aufnahme, der man gerade einen Ort gibt, unter dem Finger, und
                // der Betrachter spränge auf die nächste. Nach dem Schließen neu laden.
                if quelle == .ohneOrt, offen != nil { return }
                let nachBetrachter = quelle == .ohneOrt && geladenNachZu != betrachterZu
                geladenNachZu = betrachterZu
                // Nur neu laden, wenn sich an DIESEN Aufnahmen etwas geändert hat oder die
                // Reihenfolge umgestellt wurde — nicht bei jeder Meldung von iCloud (seit 1.0.16).
                if !nachBetrachter, geladen, geladeneReihenfolge == neuesteUnten, let e = ergebnis, !bibliothek.betrifft(e) { return }
                guard let e = bibliothek.ergebnis(quelle, neuesteZuerst: !neuesteUnten) else {
                    aufnahmen = []
                    geladen = true
                    datenStand += 1
                    return
                }
                ergebnis = e
                aufnahmen = FotoBibliothek.aufnahmen(aus: e, quelle: quelle)
                geladen = true
                // Beim Öffnen und nach dem Umstellen dort beginnen, wo die neuesten stehen —
                // aber NICHT bei jeder Änderung der Mediathek (iCloud), sonst springt das Raster.
                // Erstes Öffnen: das Raster geht selbst zur gemerkten Stelle (sonst zu den
                // neuesten). Nach dem Umstellen der Reihenfolge: zu den neuesten.
                let umgestellt = geladeneReihenfolge != nil && geladeneReihenfolge != neuesteUnten
                geladeneReihenfolge = neuesteUnten
                springen = umgestellt
                datenStand += 1
            }
        .fullScreenCover(item: $offen, onDismiss: { betrachterZu += 1 }) { z in
            BetrachterAnsicht(albumTitel: quelle.titel, aufnahmen: aufnahmen, startIndex: z.index)
        }
        .sheet(isPresented: $ortWahl) {
            // Ein Ort für alle gewählten (seit 1.0.24) — Start auf dem Ort der ersten, falls sie einen hat.
            let liste = auswahl
            OrtWahlAnsicht(start: liste.lazy.compactMap { $0.location?.coordinate }.first) { k in
                ausfuehren {
                    let gesperrt = try await Aenderungen.ort(liste, k)
                    fertig()
                    if gesperrt > 0 {
                        meldung = gesperrt == 1 ? "1 Aufnahme lässt iOS nicht ändern (z. B. aus einem geteilten Album)."
                            : "\(gesperrt) Aufnahmen lässt iOS nicht ändern (z. B. aus geteilten Alben)."
                    }
                }
            }
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
            // Gezielt die Aufnahmen ohne Ort (seit 1.0.24, Wunsch 11/2026) — „Auswählen“ →
            // Stecknadel gibt vielen auf einmal einen Ort, ⓘ im Betrachter einer einzelnen.
            NavigationLink(value: MediathekQuelle.ohneOrt) {
                Label(MediathekQuelle.ohneOrt.titel, systemImage: MediathekQuelle.ohneOrt.symbol).foregroundStyle(.primary)
            }
        } header: {
            Label("Fotos-Mediathek", systemImage: "photo.on.rectangle.angled")
        } footer: {
            Text("Alle Fotos und Videos deiner Mediathek: normale Aufnahmen im Vollbild, 360°-Aufnahmen gleich rundum. „Ohne Ort“ zeigt, was noch keinen Ort hat.")
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
