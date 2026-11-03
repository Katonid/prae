import Photos
import SwiftUI

/// Mediathek-Modus (seit 1.0.13): Aufnahmen der Fotos-Mediathek als Kachelraster wie in der
/// Fotos-App. Antippen öffnet den Betrachter — normale Fotos und Videos flach im Vollbild,
/// 360°-Aufnahmen rundum.
struct MediathekRaster: View {
    let quelle: MediathekQuelle
    @Environment(FotoBibliothek.self) private var bibliothek
    @State private var aufnahmen: [PHAsset] = []
    @State private var geladen = false
    @State private var offen: BetrachterZiel?

    var body: some View {
        ScrollView {
            if geladen && aufnahmen.isEmpty {
                ContentUnavailableView(quelle == .nur360 ? "Keine 360°-Aufnahmen" : "Keine Aufnahmen",
                                       systemImage: quelle.symbol)
                    .padding(.top, 60)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 2)], spacing: 2) {
                ForEach(Array(aufnahmen.enumerated()), id: \.element.localIdentifier) { i, a in
                    Button { offen = BetrachterZiel(index: i) } label: {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay { AssetBild(asset: a, groesse: CGSize(width: 300, height: 300)) }
                            .clipped()
                            .overlay(alignment: .bottomLeading) { KachelMarke(asset: a).scaleEffect(0.85, anchor: .bottomLeading).padding(4) }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(quelle.titel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .status) {
                if geladen { Text(aufnahmen.count == 1 ? "1 Aufnahme" : "\(aufnahmen.count) Aufnahmen").font(.caption).foregroundStyle(.secondary) }
            }
        }
        .task(id: bibliothek.stand) {
            aufnahmen = bibliothek.aufnahmen(quelle)
            geladen = true
        }
        .fullScreenCover(item: $offen) { z in
            BetrachterAnsicht(albumTitel: quelle.titel, aufnahmen: aufnahmen, startIndex: z.index)
        }
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
