import SwiftUI
import CoreData
import MapKit

// WANN WAR ICH HIER? (ab 1.0.24, Ansage des Nutzers 09/2026: „Ich suche
// jedoch nach einer Möglichkeit, mir die einzelnen Punkte der Reise anzeigen
// zu lassen, beziehungsweise durch Auswählen auf der Karte anzeigen zu
// lassen, um welche Uhrzeit ich an diesem Ort war.")
//
// Jede Linie auf den bedienbaren Karten (Vollbild der Reise, Vollbild eines
// Tages, einer Wanderung) trägt ihre Uhrzeiten mit. Ein TIPP auf die Karte
// sucht den nächsten Punkt einer Linie — innerhalb von gut 30 Bildpunkten,
// in Metern umgerechnet aus dem gerade gezeigten Maßstab — und zeigt dort
// eine Blase: Uhrzeit in ORTSZEIT, auf der ganzen Reise mit Tag, dazu, was
// für eine Linie das ist. Ein Tipp daneben schließt sie.
//
// „Punkte" blendet die Messpunkte als kleine Kreise ein, höchstens 400 —
// über eine ganze Reise sind es sonst Zehntausende, und die Karte stünde.
// Die Punkte sind Bilder (keine Knöpfe, Lehre aus der Abfahrtstafel 1.1.18);
// den Tipp nimmt die Karte und rechnet selbst.

/// Ein Punkt mit Uhrzeit auf einer Linie.
struct Zeitpunkt: Identifiable {
    let breite: Double
    let laenge: Double
    let zeit: TimeInterval
    let art: Spurart
    let name: String
    let zone: TimeZone
    /// Woher der Punkt stammt (ab 1.0.32, zum Entfernen): die `Spur` oder,
    /// bei einer Wanderung, der `Eintrag`. `nil` heißt: nicht bearbeitbar.
    var quelle: NSManagedObjectID? = nil
    var koordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: breite, longitude: laenge) }
    var id: String { "\(art.rawValue)|\(name)|\(zeit)|\(breite)|\(laenge)" }
}

enum Zeitsuche {
    /// Der nächste Punkt zum Ziel — oder keiner, wenn alle weiter als
    /// `toleranz` Meter weg sind.
    static func naechster(zu ziel: CLLocationCoordinate2D, in punkte: [Zeitpunkt], toleranz: Double) -> Zeitpunkt? {
        // Flach gerechnet (Grad → Meter mit dem Kosinus der Breite): Für
        // „welcher Punkt ist am nächsten" genügt das, und es ist schnell
        // genug für Zehntausende Punkte je Tipp.
        let kx = cos(ziel.latitude * .pi / 180) * 111_320
        let ky = 110_540.0
        var bester: Zeitpunkt?
        var beste = toleranz * toleranz
        for p in punkte {
            let dx = (p.laenge - ziel.longitude) * kx
            let dy = (p.breite - ziel.latitude) * ky
            let d = dx * dx + dy * dy
            if d < beste { beste = d; bester = p }
        }
        return bester
    }

    /// Wie viele Meter `bildpunkte` Bildpunkte an dieser Stelle der Karte sind.
    static func toleranz(_ proxy: MapProxy, bei ort: CGPoint, bildpunkte: CGFloat = 32) -> Double? {
        guard let a = proxy.convert(ort, from: .local),
              let b = proxy.convert(CGPoint(x: ort.x + bildpunkte, y: ort.y), from: .local) else { return nil }
        return CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// Höchstens `hoechstens` Punkte, gleichmäßig über die Reihe verteilt.
    static func auswahl(_ punkte: [Zeitpunkt], hoechstens: Int) -> [Zeitpunkt] {
        guard punkte.count > hoechstens, hoechstens > 0 else { return punkte }
        let schritt = Double(punkte.count) / Double(hoechstens)
        return (0 ..< hoechstens).map { punkte[min(punkte.count - 1, Int(Double($0) * schritt))] }
    }

    /// Punkte einer Linie mit Uhrzeiten.
    static func punkte(_ spur: [Spurpunkt], art: Spurart, name: String, zone: TimeZone,
                       quelle: NSManagedObjectID? = nil) -> [Zeitpunkt] {
        spur.map { Zeitpunkt(breite: $0.breite, laenge: $0.laenge, zeit: $0.zeit, art: art, name: name, zone: zone,
                             quelle: quelle) }
    }
}

/// Die Blase an einem gewählten Punkt.
struct Zeitblase: View {
    let punkt: Zeitpunkt
    let farbe: Color
    /// Auf der ganzen Reise gehört der Tag dazu.
    var mitTag = false
    /// Entfernen (ab 1.0.32): `nil` = kein Knopf. Die Blase nimmt dann
    /// Berührungen an — sonst bleibt sie ein Bild.
    var punktEntfernen: (() -> Void)? = nil
    /// Die ganze Linie entfernen, mit Beschriftung („Fahrt entfernen").
    var linieEntfernen: (text: String, aktion: () -> Void)? = nil
    /// Hinweis unter den Knöpfen (etwa: Spur eines anderen Geräts).
    var hinweis: String? = nil

    var body: some View {
        let datum = Date(timeIntervalSince1970: punkt.zeit)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: punkt.art.symbol).font(.caption2.weight(.bold))
                    Text(Tag.text(datum, "HH:mm", zone: punkt.zone) + " Uhr")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                if mitTag {
                    Text(Tag.text(datum, "EEEE, d. MMMM", zone: punkt.zone))
                        .font(.caption2)
                }
                if !punkt.name.isEmpty {
                    Text(punkt.name).font(.caption2).lineLimit(1)
                }
                if punkt.zone.identifier != TimeZone.current.identifier {
                    Text("Ortszeit \(punkt.zone.abbreviation(for: datum) ?? punkt.zone.identifier)")
                        .font(.caption2)
                        .opacity(0.85)
                }
                if punktEntfernen != nil || linieEntfernen != nil {
                    Divider().overlay(.white.opacity(0.6)).padding(.vertical, 3)
                    if let punktEntfernen {
                        Button(action: punktEntfernen) {
                            Label("Punkt entfernen", systemImage: "trash")
                        }
                    }
                    if let linieEntfernen {
                        Button(action: linieEntfernen.aktion) {
                            Label(linieEntfernen.text, systemImage: "trash.fill")
                        }
                    }
                    if let hinweis {
                        Text(hinweis).font(.caption2).opacity(0.85).frame(maxWidth: 200, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(farbe, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white, lineWidth: 1.5))
            Image(systemName: "triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(farbe)
                .rotationEffect(.degrees(180))
                .offset(y: -2)
            Circle()
                .fill(.white)
                .frame(width: 10, height: 10)
                .overlay(Circle().fill(farbe).padding(2))
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        .fixedSize()
        .allowsHitTesting(punktEntfernen != nil || linieEntfernen != nil)
    }
}

/// Die Knöpfe der Blase für einen Punkt — an EINER Stelle entschieden,
/// gefragt von der Karte der Reise und vom Vollbild eines Tages (ab 1.0.32).
enum Punktbearbeitung {
    /// Beschriftung für „ganze Linie entfernen" — `nil`, wo es das nicht
    /// gibt (Wanderung: die ist ein Eintrag und geht über sein Menü).
    @MainActor
    static func linientext(_ z: Zeitpunkt) -> String? {
        switch z.art {
        case .fahrt: return "Ganze Fahrt entfernen"
        case .reisespur: return "Ganze Spur des Tages entfernen"
        case .wanderung: return nil
        }
    }

    @MainActor
    static func hinweis(_ z: Zeitpunkt) -> String? {
        Spurbearbeitung.fremd(z)
            ? "Von einem anderen Gerät aufgezeichnet — dort kann die Spur beim nächsten Abgleich zurückkommen."
            : nil
    }
}

/// Ein Messpunkt als kleiner Kreis.
struct Messpunkt: View {
    let farbe: Color
    var body: some View {
        Circle()
            .fill(farbe)
            .frame(width: 7, height: 7)
            .overlay(Circle().stroke(.white, lineWidth: 1.2))
            .allowsHitTesting(false)
    }
}
