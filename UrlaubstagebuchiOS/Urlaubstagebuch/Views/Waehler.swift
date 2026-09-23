import PhotosUI
import SwiftUI
import UIKit
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

// DEN SYSTEM-DRUCKDIALOG ZEIGEN (ab 1.0.37).
//
// Ansage des Nutzers, 09/2026: „das Reisetagebuch auf dem heimischen
// Drucker doppelseitig als Broschüre drucken zu können". Die Datei dafür
// baut die App seit 1.0.27 — was fehlte, war der Weg zum Drucker. Sie erst
// zu sichern, dann in „Dateien" zu suchen und von dort zu drucken, ist ein
// Umweg um genau den Knopf herum, um den gebeten wurde.
//
// **An SwiftUI vorbei.** `UIPrintInteractionController` ist kein
// View-Controller, den man in ein `.sheet` hängen kann — er zeigt sich
// selbst. Eingebettet bliebe das Blatt schwarz; dieselbe Lehre wie beim
// Teilen-Blatt und beim Dateiwähler in Tafelbild.
//
// **`duplex` ist ein WUNSCH, keine Einstellung.** Was der Drucker wirklich
// tut und über welche Kante er wendet, entscheidet der Mensch im Dialog;
// die App kann das weder setzen noch auslesen. Deshalb steht daneben der
// Schalter „Rückseiten um 180° drehen" mit einem Satz dazu — und keine
// Automatik, die bei der Hälfte aller Geräte jede zweite Seite auf den Kopf
// stellt.
enum Druckauftrag {
    @MainActor
    static func zeigen(_ adresse: URL, titel: String, beidseitig: Bool) {
        guard UIPrintInteractionController.isPrintingAvailable else { return }
        let auftrag = UIPrintInteractionController.shared
        let angaben = UIPrintInfo(dictionary: nil)
        angaben.outputType = .general
        angaben.jobName = titel.isEmpty ? "Reisebuch" : titel
        // Die lange Kante ist die gewöhnliche Wendung und die, für die der
        // Schalter in der Ausgabe aus bleibt. Wer seinen Drucker anders
        // eingestellt hat, sieht es im Dialog und ändert es dort.
        angaben.duplex = beidseitig ? .longEdge : .none
        auftrag.printInfo = angaben
        auftrag.printingItem = adresse
        // Auf dem iPad braucht der Dialog einen Anker. Ohne ihn wirft UIKit;
        // genommen wird die Ansicht der SZENE DIESER App und nie
        // `connectedScenes.first` — das ist eine ungeordnete Menge, und mit
        // einem Beamer am Gerät griffe es mal die eine und mal die andere
        // (dieselbe Falle wie bei Tafelbilds Dokumentenkamera).
        guard let fenster = aktivesFenster() else { return }
        // AUF DEM MAC GILT DASSELBE wie auf dem iPad (ab 1.0.62): Der
        // Dialog ist dort kein Vollbild, sondern hängt an einer Stelle im
        // Fenster. Unter Mac Catalyst meldet `userInterfaceIdiom` seit der
        // Mac-Fassung `.mac` und nicht mehr `.pad` — ohne diese Zeile fiele
        // der Druck in den Zweig ohne Anker, und der ist für eine Ansicht
        // gedacht, die den ganzen Bildschirm füllt.
        let brauchtAnker = UIDevice.current.userInterfaceIdiom == .pad
            || UIDevice.current.userInterfaceIdiom == .mac
        if brauchtAnker {
            let flaeche = fenster.bounds
            let anker = CGRect(x: flaeche.midX - 1, y: flaeche.midY - 1, width: 2, height: 2)
            auftrag.present(from: anker, in: fenster, animated: true, completionHandler: nil)
        } else {
            auftrag.present(animated: true, completionHandler: nil)
        }
    }

    @MainActor
    private static func aktivesFenster() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role == .windowApplication && $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}

// DER SYSTEM-SCHRIFTWÄHLER (ab 1.0.41).
//
// Der einzige Weg an Schriften, die der Nutzer selbst auf das Gerät gelegt
// hat: `UIFont.familyNames` zählt sie nicht mit (siehe
// `Model/Geraeteschriften.swift`). Es ist derselbe Wähler, den Pages zeigt.
//
// `includeFaces = true`, weil in dieser App der SCHNITT die halbe Miete ist
// — „zu dick gedruckt" war der Befund, mit dem die Schriftwahl in 1.0.29
// überhaupt entstand.
struct Schriftwahl: UIViewControllerRepresentable {
    var fertig: (UIFontDescriptor?) -> Void

    func makeUIViewController(context: Context) -> UIFontPickerViewController {
        let aufbau = UIFontPickerViewController.Configuration()
        aufbau.includeFaces = true
        // Die Systemschrift steht in dieser App schon oben in der Liste;
        // hier geht es um die Schriften des Geräts.
        aufbau.displayUsingSystemFont = false
        let waehler = UIFontPickerViewController(configuration: aufbau)
        waehler.delegate = context.coordinator
        return waehler
    }

    func updateUIViewController(_ waehler: UIFontPickerViewController, context: Context) {}

    func makeCoordinator() -> Bote { Bote(fertig: fertig) }

    final class Bote: NSObject, UIFontPickerViewControllerDelegate {
        let fertig: (UIFontDescriptor?) -> Void
        init(fertig: @escaping (UIFontDescriptor?) -> Void) { self.fertig = fertig }

        func fontPickerViewControllerDidPickFont(_ waehler: UIFontPickerViewController) {
            let deskriptor = waehler.selectedFontDescriptor
            waehler.dismiss(animated: true)
            fertig(deskriptor)
        }

        func fontPickerViewControllerDidCancel(_ waehler: UIFontPickerViewController) {
            waehler.dismiss(animated: true)
            fertig(nil)
        }
    }
}
