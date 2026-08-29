import UIKit

/// Wo UIKit etwas zeigen kann, wenn SwiftUI dafür der falsche Weg ist.
///
/// **Zwei Bildschirme von iOS wollen präsentiert werden, nicht eingebettet:**
/// der Dateiwähler (`UIDocumentPickerViewController`) und Apples Teilen-Blatt
/// (`UICloudSharingController`). Beide sind Fenster fremder Dienste. In ein
/// SwiftUI-Blatt gesteckt bleiben sie schwarz oder flackern; von hier aus
/// gezeigt tun sie, was sie sollen.
///
/// Beide Male teuer gelernt: der Dateiwähler in 1.0.57, das Teilen-Blatt in
/// 1.0.60 — dort war es ein schwarzes Rechteck mitten auf der Tafel.
///
/// **Aus demselben Grund auch eigene Vollbilder** (`Zuschnittwahl`): Eine
/// Präsentation, die an einem Ansichtswert hängt, räumt SwiftUI beim
/// Neuzeichnen ab — und die Tafel zeichnet sich bei jedem Abgleich neu. Der
/// Zuschnitt eines Bildes dauert länger als ein Abgleich.
enum Oberflaeche {
    /// Das oberste gerade gezeigte Blatt.
    static func obersterHalter() -> UIViewController? {
        let szenen = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let szene = szenen.first { $0.activationState == .foregroundActive } ?? szenen.first
        guard var halter = szene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? szene?.windows.first?.rootViewController else { return nil }
        while let naechster = halter.presentedViewController { halter = naechster }
        return halter
    }

    /// Setzt den Ursprung für ein Blatt, das auf dem iPad als Sprechblase
    /// erscheinen möchte. Ohne das stürzt iPadOS beim Zeigen ab.
    static func ausMitte(_ blatt: UIViewController, in halter: UIViewController) {
        guard let sprechblase = blatt.popoverPresentationController else { return }
        sprechblase.sourceView = halter.view
        sprechblase.sourceRect = CGRect(x: halter.view.bounds.midX,
                                        y: halter.view.bounds.midY,
                                        width: 0, height: 0)
        sprechblase.permittedArrowDirections = []
    }
}
