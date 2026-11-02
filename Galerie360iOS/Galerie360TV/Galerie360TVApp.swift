import AVFoundation
import AVKit
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
}

struct StartTV: View {
    @Environment(FotoBibliothek.self) private var bibliothek

    var body: some View {
        NavigationStack {
            Group {
                switch bibliothek.zugriff {
                case .erlaubt, .eingeschraenkt:
                    if bibliothek.galerien.isEmpty {
                        ContentUnavailableView("Noch keine Galerie",
                                               systemImage: "photo.stack",
                                               description: Text("Galerien legst du in Galerie 360 auf dem iPhone oder iPad an. Sie erscheinen hier, sobald iCloud Fotos sie auf das Apple TV gebracht hat (Einstellungen › Benutzer und Accounts › iCloud › iCloud Fotos)."))
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 420), spacing: 48)], spacing: 60) {
                                ForEach(bibliothek.galerien) { g in
                                    NavigationLink(value: g) {
                                        VStack(spacing: 18) {
                                            Image(systemName: "photo.stack").font(.system(size: 80))
                                            Text(g.titel).font(.title3).lineLimit(2)
                                        }
                                        .frame(width: 420, height: 260)
                                    }
                                    .buttonStyle(.card)
                                }
                            }
                            .padding(60)
                        }
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
            .navigationDestination(for: GalerieInfo.self) { GalerieTV(galerie: $0) }
            .navigationDestination(for: Knoten.self) { AlbumTV(album: $0) }
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
    @Environment(FotoBibliothek.self) private var bibliothek
    @Environment(Notizen.self) private var notizen
    @State private var asset: PHAsset?

    var body: some View {
        AssetBild(asset: asset, groesse: CGSize(width: 800, height: 450))
            .task(id: "\(albumId)-\(bibliothek.stand)") {
                let alle = bibliothek.aufnahmen(albumId)
                asset = alle.first { $0.localIdentifier == notizen.albumbild(albumId) } ?? alle.first
            }
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
                                .overlay(alignment: .bottomLeading) {
                                    Label(a.mediaType == .video ? zeitText(a.duration) : "360°",
                                          systemImage: a.mediaType == .video ? "video" : "camera")
                                        .font(.caption)
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(.black.opacity(0.55), in: Capsule())
                                        .padding(10)
                                }
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
    @State private var fortschritt: Double?
    @State private var meldung: String?

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

            if laedt {
                VStack(spacing: 16) {
                    ProgressView()
                    if let f = fortschritt, f > 0, f < 1 { Text("Aus iCloud geladen: \(Int(f * 100)) %").font(.callout) }
                }
            }
            if let meldung {
                Text(meldung).padding(30).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
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
                    }
                    Text("Wischen: umsehen  ·  oben/unten klicken: Zoom  ·  links/rechts: blättern  ·  Play/Pause: Video  ·  Mitte: diese Hilfe aus")
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
        guard let a = asset else { return }
        szene.setzeBild(nil)
        szene.setzeBlick(notizen.blick(a.localIdentifier))
        laedt = true
        defer { laedt = false }
        do {
            if a.mediaType == .video {
                let item = try await Mediathek.video(a) { f in Task { @MainActor in fortschritt = f } }
                guard !Task.isCancelled else { return }
                item.externalMetadata = [metadaten(.commonIdentifierTitle, notizen.titel(a.localIdentifier) ?? datumText(a.creationDate)),
                                         metadaten(.iTunesMetadataTrackSubTitle, albumTitel)]
                let p = AVPlayer(playerItem: item)
                p.actionAtItemEnd = .pause
                player = p
                zeit = 0
                szene.setzeVideo(p)
                zeitBeobachter = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { t in
                    zeit = t.seconds
                }
                tonAn(p)
                p.play()
            } else {
                // Apple TV 4K: Texturen bis 16384 — 8192 ist scharf und schont den Speicher.
                let bild = try await Mediathek.foto(a, maxPixel: 8192) { f in Task { @MainActor in fortschritt = f } }
                guard !Task.isCancelled else { return }
                szene.setzeBild(bild)
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

    private func metadaten(_ kennung: AVMetadataIdentifier, _ wert: String) -> AVMetadataItem {
        let m = AVMutableMetadataItem()
        m.identifier = kennung
        m.value = wert as NSString
        m.extendedLanguageTag = "und"
        return m.copy() as! AVMetadataItem
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
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func stoppen() {
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
