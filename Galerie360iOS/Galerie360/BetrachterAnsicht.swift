import AVFoundation
import ImageIO
import Photos
import SwiftUI

/// Vollbild-Betrachter: startet ohne Bedienung; einmal tippen zeigt „← Album", Titel,
/// Startansicht festlegen, Bewegungssteuerung, Blättern und — bei Videos — die Wiedergabe.
/// Fotos und Videos kommen direkt aus der Fotos-Mediathek (bei iCloud Fotos aus dem Netz).
struct BetrachterAnsicht: View {
    let albumTitel: String
    /// Veränderlich: nach Löschen fällt die Aufnahme heraus, nach Favorit/Datum/Ort steht die
    /// frisch gelesene drin (seit 1.0.15).
    @State private var aufnahmen: [PHAsset]
    @Environment(\.dismiss) private var schliessen
    @Environment(Notizen.self) private var notizen
    @State private var index: Int
    @State private var szene = PanoramaSzene()
    @State private var bedienung = false
    @State private var hinweis = true
    @State private var bewegung = false
    @State private var info = false
    @State private var player: AVPlayer?
    @State private var zeitBeobachter: Any?
    @State private var laeuft = false
    @State private var zeit: Double = 0
    @State private var dauer: Double = 0
    @State private var spulen = false
    @State private var laedt = false
    @State private var fortschritt: Double?
    @State private var meldung: String?
    @State private var gemerkt = false
    /// Normales (nicht 360°) Foto, flach gezeigt (seit 1.0.13).
    @State private var flachBild: CGImage?
    // Aktionen wie in der Fotos-App (seit 1.0.15)
    @State private var infoOffen = false
    @State private var albumWahl = false
    @State private var paket: TeilenPaket?
    @State private var teiltGerade: Double?

    init(albumTitel: String, aufnahmen: [PHAsset], startIndex: Int) {
        self.albumTitel = albumTitel
        _aufnahmen = State(initialValue: aufnahmen)
        _index = State(initialValue: startIndex)
    }

    private var asset: PHAsset? { aufnahmen.indices.contains(index) ? aufnahmen[index] : nil }
    private var titel: String {
        guard let a = asset else { return "" }
        return notizen.titel(a.localIdentifier) ?? datumText(a.creationDate)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if asset?.ist360 ?? true {
                PanoramaAnsicht(szene: szene, bewegung: bewegung) { tippen() }
                    .ignoresSafeArea()
            } else if let p = player {
                // Normales Video: flach, zoombar wie ein Foto (seit 1.0.14).
                ZoomFlaeche(inhalt: .video(p), beiTippen: tippen, beiWischen: blaettern)
                    .ignoresSafeArea()
            } else if let b = flachBild {
                // Normales Foto: flach, mit Zoom (seit 1.0.13).
                ZoomFlaeche(inhalt: .bild(b), beiTippen: tippen, beiWischen: blaettern)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea().onTapGesture { tippen() }
            }

            if laedt {
                VStack(spacing: 10) {
                    ProgressView().controlSize(.large).tint(.white)
                    if let f = fortschritt, f > 0, f < 1 {
                        Text("Aus iCloud geladen: \(Int(f * 100)) %").font(.footnote).foregroundStyle(.white)
                    }
                }
            }
            if let meldung {
                Text(meldung)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(40)
            }
            if bedienung { bedienelemente.transition(.opacity) }
            if hinweis && !bedienung {
                Text("Antippen zeigt die Bedienung")
                    .font(.footnote)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 40)
                    .allowsHitTesting(false)
            }
        }
        .statusBarHidden(!bedienung)
        .persistentSystemOverlays(bedienung ? .automatic : .hidden)
        .preferredColorScheme(.dark)
        .task(id: asset?.localIdentifier ?? "") { await laden() }
        .task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { hinweis = false }
        }
        .onDisappear(perform: stoppen)
        .sheet(isPresented: $infoOffen) {
            if let a = asset { InfoAnsicht(asset: a) { neu in ersetzen(neu) } }
        }
        .sheet(item: $paket) { p in
            TeilenBlatt(paket: p) { paket = nil }
        }
        .sheet(isPresented: $albumWahl) {
            AlbumWahl { ziel in
                guard let a = asset else { return }
                ausfuehren { try await Aenderungen.hinzufuegen([a], zuAlbum: ziel) }
            }
        }
    }

    // MARK: Bedienung

    private var bedienelemente: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { schliessen() } label: {
                    Label(albumTitel, systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(.black.opacity(0.45), in: Capsule())
                }
                .accessibilityLabel("Zurück zu \(albumTitel)")
                VStack(alignment: .leading, spacing: 0) {
                    Text(titel).font(.headline).lineLimit(1)
                    Text("\(index + 1) / \(aufnahmen.count)").font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                .shadow(radius: 3)
                Spacer()
                if let a = asset, !(notizen.notiz(a.localIdentifier).beschreibung ?? "").isEmpty {
                    rundknopf(info ? "text.bubble.fill" : "text.bubble") { info.toggle() }
                }
                if asset?.ist360 ?? true {
                    rundknopf(gemerkt ? "pin.fill" : "pin") { startansichtMerken() }
                        .accessibilityLabel("Diesen Blick als Startansicht merken")
                    rundknopf(bewegung ? "gyroscope" : "hand.draw") { bewegung.toggle() }
                        .accessibilityLabel(bewegung ? "Umsehen mit dem Finger" : "Umsehen durch Bewegen des Geräts")
                }
            }
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 24)
            .background(LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))

            if info, let a = asset, let b = notizen.notiz(a.localIdentifier).beschreibung, !b.isEmpty {
                Text(b)
                    .frame(maxWidth: 520, alignment: .leading)
                    .padding()
                    .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            HStack {
                if aufnahmen.count > 1 {
                    rundknopf("chevron.left") { blaettern(-1) }
                    Spacer()
                    rundknopf("chevron.right") { blaettern(1) }
                }
            }
            .padding(.horizontal)

            if asset?.mediaType == .video {
                HStack(spacing: 12) {
                    Button { umschalten() } label: { Image(systemName: laeuft ? "pause.fill" : "play.fill").font(.title3).frame(width: 36) }
                    Text(zeitText(zeit)).font(.caption.monospacedDigit())
                    Slider(value: Binding(get: { zeit }, set: { zeit = $0 }), in: 0...max(1, dauer), onEditingChanged: { anfang in
                        spulen = anfang
                        if !anfang { player?.seek(to: CMTime(seconds: zeit, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) }
                    })
                    Text(zeitText(dauer)).font(.caption.monospacedDigit())
                }
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(.black.opacity(0.5), in: Capsule())
                .padding(.horizontal).padding(.top, 8)
            }

            aktionsleiste
        }
        .foregroundStyle(.white)
    }

    /// Wie unten in der Fotos-App: Teilen, Favorit, Info, mehr, Löschen.
    private var aktionsleiste: some View {
        HStack {
            if let t = teiltGerade {
                ProgressView(value: t).frame(width: 44).tint(.white)
            } else {
                rundknopf("square.and.arrow.up") { teilen() }.accessibilityLabel("Teilen")
            }
            Spacer()
            rundknopf(asset?.isFavorite == true ? "heart.fill" : "heart") { favorit() }
                .accessibilityLabel(asset?.isFavorite == true ? "Aus Favoriten entfernen" : "Zu Favoriten")
            Spacer()
            rundknopf("info.circle") { infoOffen = true }.accessibilityLabel("Info: Datum und Ort")
            Spacer()
            Menu {
                Button { albumWahl = true } label: { Label("Zu Album hinzufügen …", systemImage: "rectangle.stack.badge.plus") }
                Button { ausblenden() } label: { Label("Ausblenden", systemImage: "eye.slash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .accessibilityLabel("Mehr")
            Spacer()
            rundknopf("trash") { loeschen() }.accessibilityLabel("Löschen")
        }
        .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 12)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
    }

    // MARK: Aktionen (seit 1.0.15)

    private func ersetzen(_ neu: PHAsset) {
        if let i = aufnahmen.firstIndex(where: { $0.localIdentifier == neu.localIdentifier }) { aufnahmen[i] = neu }
    }

    private func entfernen(_ id: String) {
        guard let i = aufnahmen.firstIndex(where: { $0.localIdentifier == id }) else { return }
        aufnahmen.remove(at: i)
        if aufnahmen.isEmpty { schliessen(); return }
        index = min(index, aufnahmen.count - 1)
    }

    private func ausfuehren(_ f: @escaping () async throws -> Void) {
        Task {
            do { try await f() } catch {
                if !Aenderungen.abgebrochen(error) { meldung = error.localizedDescription }
            }
        }
    }

    private func favorit() {
        guard let a = asset else { return }
        ausfuehren {
            let neu = try await Aenderungen.favorit(a, !a.isFavorite)
            ersetzen(neu)
        }
    }

    private func loeschen() {
        guard let a = asset else { return }
        ausfuehren {
            try await Aenderungen.loeschen([a])
            if Aenderungen.holen(a.localIdentifier) == nil { entfernen(a.localIdentifier) }
        }
    }

    private func ausblenden() {
        guard let a = asset else { return }
        ausfuehren {
            try await Aenderungen.ausblenden([a])
            entfernen(a.localIdentifier)
        }
    }

    private func teilen() {
        guard let a = asset, teiltGerade == nil else { return }
        teiltGerade = 0
        ausfuehren {
            defer { teiltGerade = nil }
            paket = try await Teilen.paket([a]) { f in Task { @MainActor in if teiltGerade != nil { teiltGerade = f } } }
        }
    }

    private func rundknopf(_ symbol: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.4), in: Circle())
        }
    }

    private func tippen() {
        withAnimation(.easeInOut(duration: 0.2)) { bedienung.toggle() }
        hinweis = false
    }

    private func blaettern(_ r: Int) {
        guard aufnahmen.count > 1 else { return }
        index = (index + r + aufnahmen.count) % aufnahmen.count
    }

    private func umschalten() {
        guard let p = player else { return }
        if laeuft {
            p.pause()
        } else {
            if dauer > 0 && zeit >= dauer - 0.3 { p.seek(to: .zero) }
            p.play()
        }
    }

    /// Der aktuelle Blick wird zur Startansicht dieser Aufnahme (nur in der App gespeichert).
    private func startansichtMerken() {
        guard let a = asset else { return }
        let f = szene.blickrichtung
        let yaw = Double(atan2(f.x, -f.z)) * 180 / .pi
        let pitch = Double(asin(max(-1, min(1, f.y)))) * 180 / .pi
        notizen.setzeBlick(a.localIdentifier, Blick(yaw: yaw, pitch: pitch, fov: szene.fov))
        gemerkt = true
    }

    // MARK: Laden

    private func laden() async {
        stoppen()
        meldung = nil
        gemerkt = false
        fortschritt = nil
        flachBild = nil
        guard let a = asset else { return }
        szene.setzeBild(nil)
        szene.setzeBlick(notizen.blick(a.localIdentifier))
        laedt = true
        defer { laedt = false }
        do {
            if a.mediaType == .video {
                let item = try await Mediathek.video(a) { f in Task { @MainActor in fortschritt = f } }
                guard !Task.isCancelled else { return }
                let p = AVPlayer(playerItem: item)
                // Kein AirPlay: Das Video ist nur die Textur der Kugel — auf dem Fernseher käme
                // das verzerrte Rundumbild an. Und „Automatisch AirPlay" in iOS hat damit das
                // Apple TV samt Fernseher aus dem Ruhezustand geholt (gemeldet 11/2026, 1.0.6).
                p.allowsExternalPlayback = false
                p.actionAtItemEnd = .pause
                player = p
                dauer = a.duration
                zeit = 0
                if a.ist360 { szene.setzeVideo(p) }
                zeitBeobachter = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { t in
                    if !spulen { zeit = t.seconds }
                    laeuft = p.rate > 0
                }
                p.play()
            } else {
                let bild = try await Mediathek.foto(a, maxPixel: a.ist360 ? 8192 : 4096) { f in Task { @MainActor in fortschritt = f } }
                guard !Task.isCancelled else { return }
                if a.ist360 { szene.setzeBild(bild) } else { flachBild = bild }
            }
        } catch {
            if !Task.isCancelled { meldung = "Diese Aufnahme lässt sich nicht laden: \(error.localizedDescription)" }
        }
    }

    private func stoppen() {
        if let p = player {
            p.pause()
            if let b = zeitBeobachter { p.removeTimeObserver(b) }
            p.replaceCurrentItem(with: nil)
        }
        zeitBeobachter = nil
        player = nil
        laeuft = false
    }
}
