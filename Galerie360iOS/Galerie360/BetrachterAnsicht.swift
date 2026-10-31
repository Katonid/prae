import AVFoundation
import ImageIO
import SwiftUI

/// Vollbild-Betrachter: startet ohne Bedienung (Wunsch des Nutzers aus der Web-App);
/// einmal tippen zeigt „← Album", Titel, Bewegungssteuerung, Blättern und — bei Videos — die Wiedergabe.
struct BetrachterAnsicht: View {
    let galerie: Galerie
    let albumId: String
    @Environment(\.dismiss) private var schliessen
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
    @State private var meldung: String?

    init(galerie: Galerie, albumId: String, startIndex: Int) {
        self.galerie = galerie
        self.albumId = albumId
        _index = State(initialValue: startIndex)
    }

    private var album: Album? { galerie.album(albumId) }
    private var medien: [Medium] { album?.medien ?? [] }
    private var medium: Medium? { medien.indices.contains(index) ? medien[index] : nil }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PanoramaAnsicht(szene: szene, bewegung: bewegung) {
                withAnimation(.easeInOut(duration: 0.2)) { bedienung.toggle() }
                hinweis = false
            }
            .ignoresSafeArea()

            if laedt { ProgressView().controlSize(.large).tint(.white) }
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
        .task(id: index) { await laden() }
        .task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { hinweis = false }
        }
        .onDisappear(perform: stoppen)
    }

    // MARK: Bedienung

    private var bedienelemente: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { schliessen() } label: {
                    Label(album?.anzeigeTitel ?? "Zurück", systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(.black.opacity(0.45), in: Capsule())
                }
                .accessibilityLabel("Zurück zu \(album?.anzeigeTitel ?? "Album")")
                VStack(alignment: .leading, spacing: 0) {
                    Text(medium?.anzeigeTitel ?? "").font(.headline).lineLimit(1)
                    Text("\(index + 1) / \(medien.count)").font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                .shadow(radius: 3)
                Spacer()
                if let m = medium, !m.beschreibung.isEmpty || m.datum != nil {
                    rundknopf(info ? "info.circle.fill" : "info.circle") { info.toggle() }
                }
                rundknopf(bewegung ? "gyroscope" : "hand.draw") { bewegung.toggle() }
                    .accessibilityLabel(bewegung ? "Umsehen mit dem Finger" : "Umsehen durch Bewegen des Geräts")
            }
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 24)
            .background(LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))

            if info, let m = medium {
                VStack(alignment: .leading, spacing: 4) {
                    if !m.beschreibung.isEmpty { Text(m.beschreibung) }
                    if let d = m.datum { Text(datumText(d)).font(.caption).foregroundStyle(.white.opacity(0.7)) }
                }
                .frame(maxWidth: 520, alignment: .leading)
                .padding()
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            HStack {
                if medien.count > 1 {
                    rundknopf("chevron.left") { blaettern(-1) }
                    Spacer()
                    rundknopf("chevron.right") { blaettern(1) }
                }
            }
            .padding(.horizontal)

            if medium?.art == .video {
                HStack(spacing: 12) {
                    Button { umschalten() } label: { Image(systemName: laeuft ? "pause.fill" : "play.fill").font(.title3).frame(width: 36) }
                    Text(zeitText(zeit)).font(.caption.monospacedDigit())
                    Slider(value: Binding(get: { zeit }, set: { zeit = $0 }), in: 0...max(1, dauer)) { anfang in
                        spulen = anfang
                        if !anfang { player?.seek(to: CMTime(seconds: zeit, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) }
                    }
                    Text(zeitText(dauer)).font(.caption.monospacedDigit())
                }
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(.black.opacity(0.5), in: Capsule())
                .padding()
            }
        }
        .foregroundStyle(.white)
    }

    private func rundknopf(_ symbol: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.4), in: Circle())
        }
    }

    private func blaettern(_ r: Int) {
        guard medien.count > 1 else { return }
        index = (index + r + medien.count) % medien.count
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

    // MARK: Laden

    private func laden() async {
        stoppen()
        meldung = nil
        guard let m = medium else { return }
        szene.setzeBild(nil)
        szene.setzeBlick(m.blick)
        laedt = true
        defer { laedt = false }
        do {
            switch m.art {
            case .foto:
                // Bis 8192 Pixel Breite: so scharf, wie die Grafik es sicher trägt (16384 wären 1 GB Speicher).
                guard let url = galerie.url(m.bildfassung(grenze: 8192)) else { throw CocoaError(.fileNoSuchFile) }
                let bild = try await Task.detached(priority: .userInitiated) { () -> CGImage in
                    let lokal = try Datei.bereitstellen(url)
                    guard let q = CGImageSourceCreateWithURL(lokal as CFURL, nil),
                          let b = Import.verkleinert(q, 8192)
                    else { throw ImportFehler.keinBild }
                    return b
                }.value
                guard !Task.isCancelled else { return }
                szene.setzeBild(bild)
            case .video:
                guard let q = m.videofassung(grenze: 5760), let url = galerie.url(q.src) else { throw ImportFehler.keinVideo }
                // Aus iCloud ggf. erst ganz herunterladen — AVPlayer liest sonst nur Platzhalter.
                let lokal = try await Task.detached(priority: .userInitiated) { try Datei.bereitstellen(url) }.value
                guard !Task.isCancelled else { return }
                let p = AVPlayer(url: lokal)
                p.actionAtItemEnd = .pause
                player = p
                dauer = m.dauer
                zeit = 0
                szene.setzeVideo(p)
                zeitBeobachter = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { t in
                    if !spulen { zeit = t.seconds }
                    laeuft = p.rate > 0
                    if let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 { dauer = d }
                }
                p.play()
            }
        } catch {
            if !Task.isCancelled { meldung = "Diese Aufnahme lässt sich nicht öffnen: \(error.localizedDescription)" }
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
