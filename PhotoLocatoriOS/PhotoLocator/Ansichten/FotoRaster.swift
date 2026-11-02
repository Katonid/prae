import Photos
import SwiftUI

/// Kennzeichen auf einer Miniatur.
struct Kennzeichen: OptionSet {
    let rawValue: Int
    static let ohneStandort = Kennzeichen(rawValue: 1 << 0)
    static let erledigt = Kennzeichen(rawValue: 1 << 1)
    static let uebersprungen = Kennzeichen(rawValue: 1 << 2)
    static let bearbeitet = Kennzeichen(rawValue: 1 << 3)
    static let live = Kennzeichen(rawValue: 1 << 4)
}

/// Raster mit Miniaturen, nach Aufnahmetag gegliedert.
///
/// `LazyVGrid` legt nur sichtbare Zellen an; jede Zelle lädt ihre
/// Miniatur erst, wenn sie erscheint, und bricht die Anfrage ab, wenn sie
/// wieder verschwindet. So bleibt das Raster auch bei Zehntausenden
/// Fotos flüssig.
struct FotoRaster: View {
    let liste: Arbeitsliste
    let kennzeichen: (PHAsset) -> Kennzeichen
    let tippen: (Int) -> Void

    private let spalten = [GridItem(.adaptive(minimum: 88, maximum: 150), spacing: 2)]

    var body: some View {
        ScrollViewReader { leser in
            ScrollView {
                LazyVGrid(columns: spalten, spacing: 2, pinnedViews: [.sectionHeaders]) {
                    ForEach(liste.abschnitte) { abschnitt in
                        Section {
                            ForEach(abschnitt.bereich, id: \.self) { i in
                                if let asset = liste.asset(i) {
                                    RasterZelle(asset: asset, kennzeichen: kennzeichen(asset)) {
                                        tippen(i)
                                    }
                                    .id(i)
                                }
                            }
                        } header: {
                            AbschnittKopf(abschnitt: abschnitt)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .onAppear {
                if let zuletzt = liste.zuletzt {
                    leser.scrollTo(zuletzt, anchor: .center)
                }
            }
        }
    }
}

private struct AbschnittKopf: View {
    let abschnitt: Tagesabschnitt

    var body: some View {
        HStack {
            Text(abschnitt.tag == Calendar.current.startOfDay(for: .distantPast)
                 ? "Ohne Aufnahmedatum"
                 : Formate.tag(abschnitt.tag))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(abschnitt.bereich.count == 1 ? "1 Foto" : "\(Formate.zahl(abschnitt.bereich.count)) Fotos")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }
}

private struct RasterZelle: View {
    let asset: PHAsset
    let kennzeichen: Kennzeichen
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { MiniaturAnsicht(asset: asset) }
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    if let datum = asset.creationDate {
                        Text(Formate.uhrzeit(datum))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 2)
                            .padding(4)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    symbole.padding(4)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(beschreibung)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var symbole: some View {
        HStack(spacing: 3) {
            if kennzeichen.contains(.erledigt) {
                abzeichen("checkmark", farbe: .green)
            } else if kennzeichen.contains(.uebersprungen) {
                abzeichen("forward.fill", farbe: .orange)
            } else if kennzeichen.contains(.ohneStandort) {
                abzeichen("mappin.slash", farbe: .red)
            }
            if kennzeichen.contains(.bearbeitet) && !kennzeichen.contains(.erledigt) {
                abzeichen("pencil", farbe: .blue)
            }
        }
    }

    private func abzeichen(_ symbol: String, farbe: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(farbe, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1))
    }

    private var beschreibung: String {
        var teile = [Formate.aufnahme(asset.creationDate)]
        if kennzeichen.contains(.erledigt) { teile.append("Standort ergänzt") }
        else if kennzeichen.contains(.uebersprungen) { teile.append("übersprungen") }
        else if kennzeichen.contains(.ohneStandort) { teile.append("ohne Standort") }
        else { teile.append("mit Standort") }
        if kennzeichen.contains(.bearbeitet) { teile.append("bearbeitet") }
        return teile.joined(separator: ", ")
    }
}

/// Miniatur eines Fotos — aus dem Zwischenspeicher oder asynchron geladen.
struct MiniaturAnsicht: View {
    let asset: PHAsset
    @State private var bild: UIImage? = nil
    @State private var anfrage: PHImageRequestID? = nil

    var body: some View {
        ZStack {
            Color(.secondarySystemFill)
            if let bild {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFill()
            }
        }
        .onAppear(perform: laden)
        .onDisappear(perform: abbrechen)
        .onChange(of: asset.localIdentifier) { _, _ in
            abbrechen()
            bild = nil
            laden()
        }
    }

    private func laden() {
        if let vorhanden = Bildlader.shared.miniaturImSpeicher(asset.localIdentifier) {
            bild = vorhanden
            return
        }
        anfrage = Bildlader.shared.miniatur(fuer: asset) { neu in
            bild = neu
        }
    }

    private func abbrechen() {
        if let anfrage { Bildlader.shared.abbrechen(anfrage) }
        anfrage = nil
    }
}
