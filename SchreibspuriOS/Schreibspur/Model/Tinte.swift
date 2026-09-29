import CoreGraphics

/// Ein Punkt der Schrift des Kindes und wie nah er an der Grenze lag:
/// 0 = mitten in der Form, 1 = gerade noch erlaubt. Daraus wird beim
/// Zeichnen die Farbe — dunkelblau, bei Gefahr orange.
struct Tintenpunkt {
    var p: CGPoint
    var warnung: CGFloat
}
