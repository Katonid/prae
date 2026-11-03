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
                        Button { offen = BetrachterZiel(index: i) } label: {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay { AssetBild(asset: a, groesse: CGSize(width: kachelPixel, height: kachelPixel)) }
                                .clipped()
                                .overlay(alignment: .bottomLeading) {
                                    if aktSpalten <= 7 {
                                        KachelMarke(asset: a).scaleEffect(0.85, anchor: .bottomLeading).padding(4)
                                    }
                                }
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
                if quelle.istMediathek {
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

    var body: some View {
        Section {
            ForEach([MediathekQuelle.alle, .nur360, .videos], id: \.self) { q in
                NavigationLink(value: q) {
                    Label(q.titel, systemImage: q.symbol).foregroundStyle(.primary)
                }
            }
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
        } header: {
            Label("Fotos-Mediathek", systemImage: "photo.on.rectangle.angled")
        } footer: {
            Text("Alle Fotos und Videos deiner Mediathek: normale Aufnahmen im Vollbild, 360°-Aufnahmen gleich rundum.")
        }
    }
}
