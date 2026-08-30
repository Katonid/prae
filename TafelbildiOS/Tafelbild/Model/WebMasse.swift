import CoreGraphics

// Maße, die aus der Web-App „Klassenraum" übernommen sind.
//
// Die beiden Apps sollen gleich aussehen. Damit das nicht bei jeder
// Änderung neu von Hand nachgezogen werden muss, stehen die Zahlen der
// Vorlage hier an einer Stelle beisammen — mit dem Namen, unter dem sie
// im Web zu finden sind.

extension WidgetKind {
    /// Vorgesehene Größe eines Elements in Tafelpunkten — im Web
    /// `defaultSize` in der jeweiligen Datei unter `js/widgets/`.
    ///
    /// Beide Tafeln sind 1600 Punkte breit, die Zahlen gelten also
    /// unverändert. Sie sind zugleich der Bezugspunkt für den Maßstab des
    /// Inhalts: Ein Element in dieser Größe zeichnet mit Maßstab 1.
    var webSize: CGSize {
        switch self {
        case .namePicker:   return CGSize(width: 600, height: 460)
        case .timer:        return CGSize(width: 320, height: 320)
        case .clock:        return CGSize(width: 400, height: 400)
        case .trafficLight: return CGSize(width: 220, height: 340)
        case .noise:        return CGSize(width: 460, height: 300)
        case .checklist:    return CGSize(width: 480, height: 380)
        case .text:         return CGSize(width: 520, height: 240)
        case .image:        return CGSize(width: 520, height: 380)
        case .sounds:       return CGSize(width: 340, height: 220)
        case .symbols:      return CGSize(width: 300, height: 320)
        case .video:        return CGSize(width: 640, height: 400)
        // Wie ein Dokumentenprojektor: groß genug, dass eine Heftseite von
        // hinten zu lesen ist. 4:3, weil Hefte und Blätter hochkant sind.
        case .kamera:       return CGSize(width: 640, height: 480)
        // Der Auftritt gehört auf die halbe Tafel: Ein Geburtstag ist
        // kein Nebenbei-Element, und die Animation braucht Platz.
        case .geburtstag:   return CGSize(width: 820, height: 560)
        // Ein Grundriss braucht Fläche: Bei dreißig Plätzen bleibt sonst je
        // Tisch weniger Platz, als ein Name breit ist.
        case .sitzplan:     return CGSize(width: 900, height: 620)
        }
    }
}
