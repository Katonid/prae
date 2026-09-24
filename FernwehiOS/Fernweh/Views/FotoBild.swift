import SwiftUI
import Photos

/// Ein Foto aus dem Tagebuch — aus der eigenen Mediathek, wenn es dort
/// liegt (dann immer in der aktuellen, bearbeiteten Fassung), sonst aus der
/// mitgereisten Kopie.
struct FotoBild: View {
    @ObservedObject var foto: Foto
    var kante: CGFloat = Bildwerk.vorschauKante
    var fuellen = true

    @State private var bild: UIImage?

    var body: some View {
        // Das Bild liegt als Überlagerung auf einer Fläche: So bestimmt die
        // Fläche die Größe, und ein füllendes Bild sprengt den Rahmen nicht.
        Rectangle()
            .fill(Color(uiColor: .secondarySystemFill))
            .overlay {
                if let bild {
                    Image(uiImage: bild)
                        .resizable()
                        .aspectRatio(contentMode: fuellen ? .fill : .fit)
                        .transition(.opacity)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .clipped()
        .task(id: schluessel) {
            let geladen = await Bildvorrat.shared.bild(foto, kante: kante)
            withAnimation(.easeOut(duration: 0.25)) { bild = geladen }
        }
    }

    private var schluessel: String {
        "\(foto.objectID.uriRepresentation().absoluteString)|\(foto.geaendert?.timeIntervalSince1970 ?? 0)|\(Int(kante))"
    }
}

/// Ein Foto aus der Mediathek, das noch nicht im Tagebuch steht.
struct AssetBild: View {
    let asset: PHAsset
    var kante: CGFloat = 300
    @State private var bild: UIImage?

    var body: some View {
        Rectangle()
            .fill(Color(uiColor: .secondarySystemFill))
            .overlay {
                if let bild { Image(uiImage: bild).resizable().scaledToFill() }
            }
            .clipped()
        .task(id: asset.localIdentifier + "\(asset.modificationDate?.timeIntervalSince1970 ?? 0)") {
            bild = await Fotodienst.shared.bild(asset, kante: kante, schnell: true)
        }
    }
}

/// Die Fotos eines Eintrags als Collage: eines groß, zwei nebeneinander,
/// drei und mehr als großes Bild mit zweien daneben.
struct Collage: View {
    let fotos: [Foto]
    var hoehe: CGFloat = 230

    var body: some View {
        let abstand: CGFloat = 3
        Group {
            switch fotos.count {
            case 0:
                EmptyView()
            case 1:
                FotoBild(foto: fotos[0], kante: 900)
                    .frame(height: hoehe)
            case 2:
                HStack(spacing: abstand) {
                    FotoBild(foto: fotos[0], kante: 600)
                    FotoBild(foto: fotos[1], kante: 600)
                }
                .frame(height: hoehe * 0.8)
            default:
                HStack(spacing: abstand) {
                    FotoBild(foto: fotos[0], kante: 700)
                    VStack(spacing: abstand) {
                        FotoBild(foto: fotos[1], kante: 400)
                        ZStack {
                            FotoBild(foto: fotos[2], kante: 400)
                            if fotos.count > 3 {
                                Color.black.opacity(0.45)
                                Text("+\(fotos.count - 3)")
                                    .font(Stil.titel(24))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: hoehe)
            }
        }
    }
}
