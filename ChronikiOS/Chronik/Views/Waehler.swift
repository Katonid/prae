import PhotosUI
import SwiftUI
import UIKit

// Der Fotowähler — bewusst der von UIKit und nicht SwiftUIs `PhotosPicker`
// (Lehre aus dem Reisebuch): Nur `PHPickerConfiguration(photoLibrary:)`
// gibt den `assetIdentifier` heraus, über den sich das Datum am
// Mediathekseintrag nachschlagen lässt, wenn die Datei keines trägt.
//
// Der Wähler schließt sich NICHT selbst. Geschlossen wird über den Zustand
// in SwiftUI; schlösse UIKit das Blatt, bliebe der Zustand auf „offen", und
// der Knopf ginge beim zweiten Mal nicht mehr.
struct Fotowahl: UIViewControllerRepresentable {
    var hoechstzahl: Int = 0
    var fertig: ([PHPickerResult]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var aufbau = PHPickerConfiguration(photoLibrary: .shared())
        aufbau.filter = .images
        aufbau.selectionLimit = hoechstzahl
        aufbau.selection = .ordered
        // `current` gibt die Datei so heraus, wie sie auf dem Gerät liegt —
        // mit ihren Metadaten.
        aufbau.preferredAssetRepresentationMode = .current
        let waehler = PHPickerViewController(configuration: aufbau)
        waehler.delegate = context.coordinator
        return waehler
    }

    func updateUIViewController(_ waehler: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Bote { Bote(fertig: fertig) }

    final class Bote: NSObject, PHPickerViewControllerDelegate {
        let fertig: ([PHPickerResult]) -> Void
        init(fertig: @escaping ([PHPickerResult]) -> Void) { self.fertig = fertig }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            fertig(results)
        }
    }
}

// Das Teilen-Blatt, an SwiftUI vorbei — dieselbe Lehre wie in Tafelbild
// und Reisebuch: In ein SwiftUI-Sheet eingebettet flackert es oder bleibt
// schwarz.
enum Teilen {
    @MainActor
    static func zeigen(_ dinge: [Any]) {
        guard let szene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
            let fenster = szene.windows.first(where: { $0.isKeyWindow }) ?? szene.windows.first,
            var oben = fenster.rootViewController else { return }
        while let weiter = oben.presentedViewController { oben = weiter }
        let blatt = UIActivityViewController(activityItems: dinge, applicationActivities: nil)
        if let pop = blatt.popoverPresentationController {
            pop.sourceView = oben.view
            pop.sourceRect = CGRect(x: oben.view.bounds.midX, y: oben.view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        oben.present(blatt, animated: true)
    }
}

/// Ein Foto der Ablage als kleines Quadrat, im Hintergrund geladen.
struct Vorschaubild: View {
    let datei: String
    var kante: CGFloat = 56

    @State private var bild: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.secondary.opacity(0.15))
            if let bild {
                Image(uiImage: bild).resizable().scaledToFill()
            }
        }
        .frame(width: kante, height: kante)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task(id: datei) {
            let d = datei
            let px = Int(kante * 3)
            bild = await Task.detached(priority: .utility) { Medien.bild(d, maxPixel: px) }.value
        }
    }
}

/// Eine Buchseite, im Hintergrund mit dem Seitenzeichner gemalt.
struct Seitenbild: View {
    let seite: Seite
    let buch: Buch
    var breite: CGFloat = 480

    @State private var bild: UIImage?

    var body: some View {
        let g = buch.format.groesse
        ZStack {
            Color.white
            if let bild {
                Image(uiImage: bild).resizable().scaledToFit()
            } else {
                ProgressView()
            }
        }
        .aspectRatio(g.width / g.height, contentMode: .fit)
        .task(id: seite.signatur) {
            let s = seite
            let b = buch
            let w = breite
            let neu = await Task.detached(priority: .userInitiated) {
                Seitenzeichner.vorschau(s, buch: b, breite: w)
            }.value
            bild = neu
        }
    }
}
