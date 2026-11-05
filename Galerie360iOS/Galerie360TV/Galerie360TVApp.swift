import AVFoundation
import MediaPlayer
import Photos
import SwiftUI

/// Galerie 360 auf dem Apple TV: zeigt die Galerien aus der Fotos-Mediathek (iCloud Fotos)
/// rundum an. Bearbeitet wird auf iPhone/iPad — hier nur ansehen.
@main
struct Galerie360TVApp: App {
    @State private var bibliothek = FotoBibliothek()
    @State private var notizen = Notizen(wolke: ICloudNotizen())
    @Environment(\.scenePhase) private var phase

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // Prüfmodus für GitHub Actions (Job „Apple-TV-Betrachter starten"): öffnet den
            // Betrachter mit der ersten Aufnahme der Mediathek, ohne Bedienung.
            if let art = ProcessInfo.processInfo.environment["GALERIE360_PRUEFUNG"] {
                PruefBetrachterTV(art: art)
                    .environment(bibliothek)
                    .environment(notizen)
            } else {
                startseite
            }
            #else
            startseite
            #endif
        }
    }

    private var startseite: some View {
            StartTV()
                .environment(bibliothek)
                .environment(notizen)
                // Notizen (Titel, Startansicht, Albumbild) über iCloud abgleichen — beim Start,
                // nach erteiltem Fotozugriff, beim Zurückkommen und wenn Aufnahmen eintreffen.
                .task { notizen.abgleichen() }
                .onChange(of: bibliothek.zugriff) { notizen.abgleichen() }
                .onChange(of: bibliothek.stand) { notizen.abgleichen() }
                .onChange(of: phase) { if phase == .active { notizen.abgleichen() } }
    }
}

#if DEBUG
/// Öffnet den Betrachter mit der ersten Aufnahme (Foto oder Video) — nur für die Prüfung im
/// Simulator. Ohne Aufnahmen öffnet er leer, das prüft wenigstens Aufbau und Umgebung.
struct PruefBetrachterTV: View {
    let art: String
    @State private var aufnahmen: [PHAsset]?

    var body: some View {
        Color.black
            .task {
                let s = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                // foto = 360°-Foto, flach = normales Foto (nicht 2 : 1), video = erstes Video.
                let typ: PHAssetMediaType = art == "video" ? .video : .image
                let r = PHAsset.fetchAssets(with: typ, options: nil)
                let alle = r.count > 0 ? r.objects(at: IndexSet(integersIn: 0..<r.count)) : []
                let passend = alle.filter { art == "video" || (art == "flach") != $0.ist360 }
                print("PRUEFUNG: Zugriff \(s.rawValue), \(passend.count) Aufnahme(n) vom Typ \(art)")
                aufnahmen = passend.first.map { [$0] } ?? []
            }
            .fullScreenCover(isPresented: Binding(get: { aufnahmen != nil }, set: { _ in })) {
                BetrachterTV(albumTitel: "Prüfung", aufnahmen: aufnahmen ?? [], startIndex: 0)
                    .onAppear { print("PRUEFUNG: Betrachter offen") }
            }
    }
}
#endif

struct StartTV: View {
    @Environment(FotoBibliothek.self) private var bibliothek
    @AppStorage("tvQualitaetsAnzeige") private var qualitaetsAnzeige = false
    @State private var alben: [Knoten] = []
    @State private var sammlungen: [Sammlung] = []

    /// Wie die Fotos-App: Mediathek, Sammlungen (Favoriten, Selfies …), eigene und geteilte Alben.
    private var mediathekQuellen: [MediathekQuelle] {
        [.alle, .nur360, .videos] + sammlungen.map(\.quelle) + alben.map { .album(id: $0.id, titel: $0.titel) }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch bibliothek.zugriff {
                case .erlaubt, .eingeschraenkt:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 40) {
                            Text("Galerien").font(.title3).foregroundStyle(.secondary)
                            if bibliothek.galerien.isEmpty {
                                Text("Galerien legst du in Galerie 360 auf dem iPhone oder iPad an. Sie erscheinen hier, sobald iCloud Fotos sie auf das Apple TV gebracht hat.")
                                    .foregroundStyle(.secondary)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 420), spacing: 48)], spacing: 60) {
                                    ForEach(bibliothek.galerien) { g in
                                        NavigationLink(value: g) {
                                            VStack(alignment: .leading, spacing: 0) {
                                                SammlungsBild(id: g.id, art: .galerie, groesse: CGSize(width: 840, height: 472))
                                                    .frame(width: 420, height: 236)
                                                    .clipped()
                                                Text(g.titel).font(.headline).lineLimit(1).padding(16)
                                            }
                                            .frame(width: 420)
                                        }
                                        .buttonStyle(.card)
                                    }
                                }
                            }
                            // Mediathek-Modus (seit 1.0.13): die ganze Fotos-Mediathek ansehen.
                            Text("Fotos-Mediathek").font(.title3).foregroundStyle(.secondary).padding(.top, 30)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 40)], spacing: 40) {
                                ForEach(mediathekQuellen, id: \.self) { q in
                                    NavigationLink(value: q) {
                                        VStack(spacing: 14) {
                                            Image(systemName: q.symbol).font(.system(size: 50))
                                            Text(q.titel).font(.headline).lineLimit(1)
                                        }
                                        .frame(width: 320, height: 180)
                                    }
                                    .buttonStyle(.card)
                                }
                            }
                            Text("Einstellungen").font(.title3).foregroundStyle(.secondary).padding(.top, 30)
                            Button {
                                qualitaetsAnzeige.toggle()
                            } label: {
                                Label(qualitaetsAnzeige ? "Ladeanzeige bei Videos: an — ausschalten" : "Ladeanzeige bei Videos: aus — einschalten",
                                      systemImage: qualitaetsAnzeige ? "eye" : "eye.slash")
                                    .font(.callout)
                            }
                            Text("Zeigt unten rechts im Video, wie weit die volle Qualität geladen ist. Auch wenn sie aus ist, steht der Stand in der Hilfe (beim Video die Mitte der Fernbedienung drücken).")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(60)
                    }
                    .task(id: bibliothek.stand) {
                        // Teuer (zählt je Sammlung) — erst nach drei Sekunden Ruhe, im Hintergrund.
                        if !alben.isEmpty || !sammlungen.isEmpty {
                            try? await Task.sleep(for: .seconds(3))
                            guard !Task.isCancelled else { return }
                        }
                        let (a, z) = await Task.detached(priority: .utility) {
                            (FotoBibliothek.mediathekAlbenLesen().filter { $0.art == .album },
                             FotoBibliothek.sammlungenLesen() + FotoBibliothek.geteilteAlbenLesen())
                        }.value
                        guard !Task.isCancelled else { return }
                        alben = a
                        sammlungen = z
                    }
                case .verweigert:
                    ContentUnavailableView("Kein Zugriff auf Fotos", systemImage: "lock",
                                           description: Text("Bitte in den Einstellungen des Apple TV unter Apps › Galerie 360 den Zugriff auf Fotos erlauben."))
                case .unbekannt:
                    VStack(spacing: 30) {
                        Image(systemName: "globe.europe.africa").font(.system(size: 100)).foregroundStyle(Color.accentColor)
                        Text("Deine 360°-Fotos und -Videos auf dem Fernseher").font(.title2)
                        Text("Galerie 360 zeigt die Galerien aus deiner Fotos-Mediathek. Dafür braucht die App Zugriff auf Fotos.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Zugriff auf Fotos erlauben") { Task { await bibliothek.zugriffAnfragen() } }
                    }
                    .padding(80)
                }
            }
            .navigationTitle("Galerie 360")
            .safeAreaInset(edge: .bottom) {
                // Fassung sichtbar, damit sich am Gerät prüfen lässt, was installiert ist.
                Text("Fassung \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .navigationDestination(for: GalerieInfo.self) { GalerieTV(galerie: $0) }
            .navigationDestination(for: Knoten.self) { AlbumTV(album: $0) }
            .navigationDestination(for: MediathekQuelle.self) { MediathekRasterTV(quelle: $0) }
        }
    }
}

/// Eine Galerie: ihre Alben als Karten; Alben in Ordnern (Unteralben) mit dem Ordner darüber.
struct GalerieTV: View {
    let galerie: GalerieInfo
    @Environment(FotoBibliothek.self) private var bibliothek
    @State private var baum: [Knoten] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                ForEach(gruppen, id: \.titel) { gruppe in
                    if !gruppe.titel.isEmpty { Text(gruppe.titel).font(.title3).foregroundStyle(.secondary) }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 400), spacing: 48)], spacing: 60) {
                        ForEach(gruppe.alben) { a in
                            NavigationLink(value: a) {
                                VStack(alignment: .leading, spacing: 0) {
                                    AlbumBildTV(albumId: a.id)
                                        .frame(width: 400, height: 225)
                                        .clipped()
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(a.titel).font(.headline).lineLimit(1)
                                        Text(a.anzahl == 1 ? "1 Aufnahme" : "\(a.anzahl) Aufnahmen").font(.caption).foregroundStyle(.secondary)
                                    }
                                    .padding(16)
                                }
                                .frame(width: 400)
                            }
                            .buttonStyle(.card)
                        }
                    }
                }
            }
            .padding(60)
        }
        .navigationTitle(galerie.titel)
        .task(id: bibliothek.stand) { baum = bibliothek.baum(galerie.id) }
    }

    /// Alben gruppiert nach dem Ordner, in dem sie liegen (oberste Ebene ohne Überschrift).
    private var gruppen: [(titel: String, alben: [Knoten])] {
        var aus: [(titel: String, alben: [Knoten])] = [("", [])]
        var pfad: [String] = []
        for k in baum {
            pfad = Array(pfad.prefix(k.tiefe))
            if k.art == .ordner {
                pfad.append(k.titel)
                aus.append((pfad.joined(separator: " › "), []))
            } else if k.tiefe == 0 {
                aus[0].alben.append(k)
            } else {
                aus[aus.count - 1].alben.append(k)
            }
        }
        return aus.filter { !$0.alben.isEmpty }
    }
}

struct AlbumBildTV: View {
    let albumId: String

    var body: some View {
        SammlungsBild(id: albumId, art: .album, groesse: CGSize(width: 800, height: 450))
    }
}

struct AlbumTV: View {
    let album: Knoten
    @Environment(FotoBibliothek.self) private var bibliothek
    @Environment(Notizen.self) private var notizen
    @State private var aufnahmen: [PHAsset] = []
    @State private var offen: BetrachterZielTV?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 400), spacing: 48)], spacing: 60) {
                ForEach(Array(aufnahmen.enumerated()), id: \.element.localIdentifier) { i, a in
                    Button { offen = BetrachterZielTV(index: i) } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            AssetBild(asset: a, groesse: CGSize(width: 800, height: 450))
                                .frame(width: 400, height: 225)
                                .overlay(alignment: .bottomLeading) { KachelMarke(asset: a).padding(10) }
                            Text(notizen.titel(a.localIdentifier) ?? datumText(a.creationDate))
                                .font(.callout).lineLimit(1)
                                .padding(14)
                        }
                        .frame(width: 400)
                    }
                    .buttonStyle(.card)
                }
            }
            .padding(60)
        }
        .navigationTitle(album.titel)
        .task(id: bibliothek.stand) { aufnahmen = bibliothek.aufnahmen(album.id) }
        .fullScreenCover(item: $offen) { z in
            BetrachterTV(albumTitel: album.titel, aufnahmen: aufnahmen, startIndex: z.index)
        }
    }
}

struct BetrachterZielTV: Identifiable {
    let index: Int
    var id: Int { index }
}

/// Vollbild auf dem Fernseher. Siri Remote: wischen = umsehen, oben/unten klicken = Zoom,
/// links/rechts = blättern, Mitte = Titel und Hilfe ein/aus, Play/Pause = Video,
/// Zurück = Album.
struct BetrachterTV: View {
    let albumTitel: String
    let aufnahmen: [PHAsset]
    @Environment(Notizen.self) private var notizen
    @State private var index: Int
    @State private var szene = PanoramaSzene()
    @State private var hinweis = true
    @State private var player: AVPlayer?
    @State private var zeitBeobachter: Any?
    /// Macht die App zur „Now Playing"-App von tvOS — ohne das gehen die Lautstärketasten
    /// der Siri Remote bei Ton über HomePod/AirPlay ins Leere (gemeldet 11/2026, 1.0.5).
    @State private var sitzung: MPNowPlayingSession?
    @Environment(\.scenePhase) private var phase
    @State private var zeit: Double = 0
    @State private var laedt = false
    /// Ladestand des Originals im Hintergrund (nil = nicht nötig/fertig) und ob es läuft.
    @State private var original: Double?
    @State private var volleQualitaet = false
    /// Ladeanzeige „Volle Qualität wird geladen“ dauerhaft im Bild (seit 1.0.23 abschaltbar und
    /// aus als Vorgabe — gemeldet 11/2026: „scheint nicht wegzugehen … stört"). In der Hilfe
    /// (Mitte drücken) steht der Stand immer.
    @AppStorage("tvQualitaetsAnzeige") private var qualitaetsAnzeige = false
    @State private var originalAufgabe: Task<Void, Never>?
    @State private var fortschritt: Double?
    @State private var meldung: String?
    /// Normales (nicht 360°) Foto, flach gezeigt (seit 1.0.13).
    @State private var flachBild: CGImage?

    init(albumTitel: String, aufnahmen: [PHAsset], startIndex: Int) {
        self.albumTitel = albumTitel
        self.aufnahmen = aufnahmen
        _index = State(initialValue: startIndex)
    }

    private var asset: PHAsset? { aufnahmen.indices.contains(index) ? aufnahmen[index] : nil }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PanoramaAnsicht(szene: szene, beiTippen: {
                withAnimation { hinweis.toggle() }
            }, beiTaste: { taste in
                switch taste {
                case .links: blaettern(-1)
                case .rechts: blaettern(1)
                case .playPause: umschalten()
                }
            })
            .ignoresSafeArea()

            // Normale Fotos und Videos flach darüber (seit 1.0.13). Die Kugel darunter bleibt
            // die fokussierte Fläche: Sie nimmt weiter Tasten an (blättern, Play/Pause, Hilfe).
            if let a = asset, !a.ist360 {
                Group {
                    if a.mediaType == .video, let p = player {
                        PlayerFlaeche(player: p)
                    } else if let b = flachBild {
                        Image(decorative: b, scale: 1).resizable().scaledToFit()
                    } else {
                        Color.black
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            if laedt {
                VStack(spacing: 16) {
                    ProgressView()
                    if let f = fortschritt, f > 0, f < 1 { Text("Aus iCloud geladen: \(Int(f * 100)) %").font(.callout) }
                }
            }
            if let meldung {
                Text(meldung).padding(30).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
            if qualitaetsAnzeige, !hinweis, asset?.mediaType == .video, original != nil || volleQualitaet {
                qualitaetsHinweis
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(.black.opacity(0.45), in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(50)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            if hinweis {
                VStack {
                    HStack(alignment: .firstTextBaseline) {
                        Text(asset.map { notizen.titel($0.localIdentifier) ?? datumText($0.creationDate) } ?? "").font(.title3)
                        Text("\(albumTitel) · \(index + 1) / \(aufnahmen.count)").font(.callout).foregroundStyle(.secondary)
                        Spacer()
                    }
                    Spacer()
                    if let a = asset, a.mediaType == .video, a.duration > 0 {
                        ProgressView(value: min(zeit, a.duration), total: a.duration)
                            .tint(.white)
                            .padding(.bottom, 12)
                        qualitaetsHinweis.padding(.bottom, 8)
                    }
                    Text(asset?.ist360 ?? true
                         ? "Wischen: umsehen  ·  oben/unten klicken: Zoom  ·  links/rechts: blättern  ·  Play/Pause: Video  ·  Mitte: diese Hilfe aus"
                         : "links/rechts: blättern  ·  Play/Pause: Video  ·  Mitte: diese Hilfe aus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(60)
                .background(LinearGradient(colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .task(id: index) { await laden() }
        .task {
            try? await Task.sleep(for: .seconds(5))
            withAnimation { hinweis = false }
        }
        .onDisappear(perform: stoppen)
        .onChange(of: phase) {
            if phase == .active {
                if let p = player, sitzung == nil { tonAn(p) }
            } else {
                player?.pause()
                tonAus()
            }
        }
    }

    private func blaettern(_ r: Int) {
        guard aufnahmen.count > 1 else { return }
        index = (index + r + aufnahmen.count) % aufnahmen.count
    }

    private func umschalten() {
        guard let p = player else { return }
        if p.rate > 0 {
            p.pause()
        } else {
            if let d = p.currentItem?.duration.seconds, d.isFinite, zeit >= d - 0.3 { p.seek(to: .zero) }
            p.play()
        }
    }

    private func laden() async {
        stoppen()
        meldung = nil
        fortschritt = nil
        flachBild = nil
        guard let a = asset else { return }
        szene.setzeBild(nil)
        szene.setzeBlick(notizen.blick(a.localIdentifier))
        laedt = true
        defer { laedt = false }
        do {
            if a.mediaType == .video {
                // .automatic wie die Fotos-App des Apple TV: Fotos liefert eine Fassung, die
                // die Leitung schafft. Mit .highQualityFormat kam das Original — es stockte,
                // lud nach, stockte wieder (gemeldet 11/2026), während dieselben Videos in der
                // Fotos-App des Apple TV flüssig liefen.
                let item = try await Mediathek.video(a, qualitaet: .automatic) { f in Task { @MainActor in fortschritt = f } }
                guard !Task.isCancelled else { return }
                // KEIN item.externalMetadata: Das PlayerItem von PhotoKit kennt es auf tvOS nicht —
                // „unrecognized selector", die App stürzte bei JEDEM Video ab (1.0.5 bis 1.0.9,
                // nachgestellt im Job „Apple-TV-Betrachter starten").
                let p = AVPlayer(playerItem: item)
                p.actionAtItemEnd = .pause
                player = p
                zeit = 0
                if a.ist360 { szene.setzeVideo(p) }
                zeitBeobachter = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { t in
                    zeit = t.seconds
                }
                tonAn(p)
                p.play()
                originalNachladen(a, in: p)
            } else {
                // Apple TV 4K: Texturen bis 16384 — 8192 ist scharf und schont den Speicher.
                let bild = try await Mediathek.foto(a, maxPixel: a.ist360 ? 8192 : 3840) { f in Task { @MainActor in fortschritt = f } }
                guard !Task.isCancelled else { return }
                if a.ist360 { szene.setzeBild(bild) } else { flachBild = bild }
            }
        } catch {
            if !Task.isCancelled { meldung = "Diese Aufnahme lässt sich nicht laden: \(error.localizedDescription)" }
        }
    }

    /// Audio-Sitzung aktivieren und als „Now Playing" bei tvOS anmelden: Dann steuert die
    /// Siri Remote die Lautstärke (HomePod, AirPlay, Lautsprecher am Apple TV) und das
    /// Kontrollzentrum zeigt das Video. Spielt der Ton über den Fernseher (HDMI-CEC/IR),
    /// regelt die Fernbedienung ohnehin direkt den Fernseher.
    private func tonAn(_ p: AVPlayer) {
        try? AVAudioSession.sharedInstance().setActive(true)
        let s = MPNowPlayingSession(players: [p])
        s.automaticallyPublishesNowPlayingInfo = true
        let befehle = s.remoteCommandCenter
        befehle.togglePlayPauseCommand.addTarget { _ in
            guard UIApplication.shared.applicationState == .active else { return .commandFailed }
            umschalten(); return .success
        }
        befehle.playCommand.addTarget { _ in
            guard UIApplication.shared.applicationState == .active else { return .commandFailed }
            p.play(); return .success
        }
        befehle.pauseCommand.addTarget { _ in p.pause(); return .success }
        s.becomeActiveIfPossible { _ in }
        sitzung = s
    }

    /// Abmelden als „Now Playing" — beim Verlassen des Videos UND sobald die App in den
    /// Hintergrund geht (Home-Taste, Ruhezustand). Bis 1.0.6 blieb die Anmeldung stehen,
    /// wenn man die App mit offenem Video verließ: Das Apple TV galt dann weiter als
    /// Wiedergabegerät, und ein Play-Befehl von iPhone (Sperrbildschirm, Kontrollzentrum),
    /// HomePod oder Siri konnte es samt Fernseher aus dem Ruhezustand holen
    /// (gemeldet 11/2026, „seit gestern geht es immer an" — einen Tag nach 1.0.5).
    private func tonAus() {
        guard let s = sitzung else { return }
        s.remoteCommandCenter.togglePlayPauseCommand.removeTarget(nil)
        s.remoteCommandCenter.playCommand.removeTarget(nil)
        s.remoteCommandCenter.pauseCommand.removeTarget(nil)
        s.automaticallyPublishesNowPlayingInfo = false
        s.nowPlayingInfoCenter.nowPlayingInfo = nil
        sitzung = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    @ViewBuilder
    private var qualitaetsHinweis: some View {
        if volleQualitaet {
            Label("Volle Qualität", systemImage: "checkmark.seal").font(.caption)
        } else if let o = original {
            Label("Volle Qualität wird geladen: \(Int(o * 100)) %", systemImage: "arrow.down.circle").font(.caption)
        }
    }

    /// Spielt zuerst die flüssige Fassung (`.automatic`) und lädt im Hintergrund das Original.
    /// Ist es ganz da, wechselt der Player an derselben Stelle darauf — volle Schärfe, und
    /// weil die Datei auf dem Gerät liegt, ohne Stocken (Nutzer 11/2026: „Bildqualität nicht
    /// mehr ausreichend" mit `.automatic`, mit dem gestreamten Original stockte es).
    private func originalNachladen(_ a: PHAsset, in p: AVPlayer) {
        original = 0
        volleQualitaet = false
        originalAufgabe = Task {
            do {
                let item = try await Mediathek.videoOriginal(a) { f in Task { @MainActor in if original != nil { original = f } } }
                guard !Task.isCancelled, player === p else { return }
                let stelle = p.currentTime()
                let lief = p.rate > 0
                p.replaceCurrentItem(with: item)
                await p.seek(to: stelle, toleranceBefore: .zero, toleranceAfter: .zero)
                if lief { p.play() }
                original = nil
                withAnimation { volleQualitaet = true }
                try? await Task.sleep(for: .seconds(4))
                withAnimation { volleQualitaet = false }
            } catch {
                original = nil // bleibt bei der flüssigen Fassung
            }
        }
    }

    private func stoppen() {
        originalAufgabe?.cancel()
        originalAufgabe = nil
        original = nil
        volleQualitaet = false
        tonAus()
        if let p = player {
            p.pause()
            if let b = zeitBeobachter { p.removeTimeObserver(b) }
            p.replaceCurrentItem(with: nil)
        }
        zeitBeobachter = nil
        player = nil
    }
}

/// Mediathek-Modus auf dem Apple TV (seit 1.0.13): Aufnahmen als Kacheln; der Betrachter
/// zeigt normale Fotos und Videos flach, 360°-Aufnahmen rundum.
struct MediathekRasterTV: View {
    let quelle: MediathekQuelle
    @Environment(FotoBibliothek.self) private var bibliothek
    /// Wie in der Fotos-App: neueste unten (seit 1.0.14, umstellbar mit dem Knopf oben).
    @AppStorage("mediathekNeuesteUnten") private var neuesteUnten = true
    @State private var aufnahmen: [PHAsset] = []
    @State private var geladen = false
    @State private var geladeneReihenfolge: Bool?
    @State private var ergebnis: PHFetchResult<PHAsset>?
    @State private var offen: BetrachterZielTV?

    var body: some View {
        ScrollView {
            if quelle.istMediathek {
                Button {
                    neuesteUnten.toggle()
                } label: {
                    Label(neuesteUnten ? "Neueste unten — umstellen auf: neueste oben" : "Neueste oben — umstellen auf: neueste unten",
                          systemImage: "arrow.up.arrow.down")
                        .font(.callout)
                }
                .padding(.top, 20)
            }
            if geladen && aufnahmen.isEmpty {
                ContentUnavailableView(quelle == .nur360 ? "Keine 360°-Aufnahmen" : "Keine Aufnahmen", systemImage: quelle.symbol)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 40)], spacing: 40) {
                ForEach(Array(aufnahmen.enumerated()), id: \.element.localIdentifier) { i, a in
                    Button { offen = BetrachterZielTV(index: i) } label: {
                        RasterBild(asset: a, pixel: 340)
                            .frame(width: 300, height: 169)
                            .overlay(alignment: .bottomLeading) { KachelMarke(asset: a).padding(8) }
                    }
                    .buttonStyle(.card)
                }
            }
            .padding(60)
        }
        .defaultScrollAnchor(quelle.istMediathek && neuesteUnten ? .bottom : .top)
        .navigationTitle(quelle.titel)
        .task(id: "\(bibliothek.stand)-\(neuesteUnten)") {
            if geladen, geladeneReihenfolge == neuesteUnten, let e = ergebnis, !bibliothek.betrifft(e) { return }
            geladeneReihenfolge = neuesteUnten
            ergebnis = bibliothek.ergebnis(quelle, neuesteZuerst: !neuesteUnten)
            aufnahmen = ergebnis.map { FotoBibliothek.aufnahmen(aus: $0, quelle: quelle) } ?? []
            geladen = true
        }
        .fullScreenCover(item: $offen) { z in
            BetrachterTV(albumTitel: quelle.titel, aufnahmen: aufnahmen, startIndex: z.index)
        }
    }
}
