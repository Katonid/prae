import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// Der Fotowähler — bewusst der von UIKit und nicht SwiftUIs `PhotosPicker`.
//
// Der Grund ist eine einzige Zeile: `PHPickerConfiguration(photoLibrary:)`.
// Nur ein Wähler, der mit der Mediathek verbunden ist, gibt zu jedem
// Treffer dessen `assetIdentifier` heraus — und nur über den kommt die App
// an den Aufnahmeort, wenn iOS ihn aus den Bilddaten entfernt hat. SwiftUIs
// `PhotosPicker` lässt sich nicht so bauen; sein `itemIdentifier` bleibt
// leer. Eine Reise-App, die keine Orte bekommt, hat keine Karte.
struct Fotowahl: UIViewControllerRepresentable {
    var hoechstzahl: Int = 0
    var fertig: ([PHPickerResult]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var aufbau = PHPickerConfiguration(photoLibrary: .shared())
        aufbau.filter = .images
        aufbau.selectionLimit = hoechstzahl
        aufbau.selection = .ordered
        // `current` gibt die Datei so heraus, wie sie auf dem Gerät liegt —
        // mit ihren Metadaten. `compatible` rechnete HEIC nach JPEG um und
        // kostete dabei Bildgüte, ohne dass jemand danach gefragt hätte.
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
            picker.dismiss(animated: true)
            fertig(results)
        }
    }
}

// Der Dateiwähler. `asCopy: true` spart den dauerhaften Zugriff auf fremde
// Ordner — die App kopiert ohnehin sofort in ihren eigenen.
struct Dateiwahl: UIViewControllerRepresentable {
    var typen: [UTType]
    var mehrere: Bool = false
    var fertig: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let waehler = UIDocumentPickerViewController(forOpeningContentTypes: typen, asCopy: true)
        waehler.allowsMultipleSelection = mehrere
        waehler.delegate = context.coordinator
        return waehler
    }

    func updateUIViewController(_ waehler: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Bote { Bote(fertig: fertig) }

    final class Bote: NSObject, UIDocumentPickerDelegate {
        let fertig: ([URL]) -> Void
        init(fertig: @escaping ([URL]) -> Void) { self.fertig = fertig }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            fertig(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            fertig([])
        }
    }
}

// Das Teilen-Blatt, an SwiftUI vorbei — dieselbe Lehre wie in Tafelbild:
// Ein fremder Dienst, der in ein SwiftUI-Sheet eingebettet wird, flackert
// oder bleibt schwarz.
struct Teilenblatt: UIViewControllerRepresentable {
    var gegenstaende: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: gegenstaende, applicationActivities: nil)
    }

    func updateUIViewController(_ blatt: UIActivityViewController, context: Context) {}
}
