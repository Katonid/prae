import SwiftUI
import UIKit

/// Bild zuschneiden — vergrößern, verschieben, Rahmen ziehen.
///
/// Gedacht für die Dokumentenkamera: Ein Heft liegt unter dem iPad, aber
/// gebraucht wird nur die eine Aufgabe. Statt das Element auf der Tafel
/// kleiner zu ziehen, wird hier aus dem Bild selbst der Ausschnitt genommen —
/// danach steht er formatfüllend an der Tafel und ist aus der letzten Reihe
/// zu lesen.
///
/// **Der Zuschnitt ist endgültig.** Kein zweites Bild wird aufbewahrt: Das
/// verdoppelte den Platz auf dem Gerät und in iCloud, und die Kamera steht
/// ja daneben. Wer sich verschnitten hat, tippt „Weiter" und friert neu ein.
struct Zuschnittblatt: View {
    let bild: UIImage
    /// Der fertige Ausschnitt — nil heißt abgebrochen.
    let fertig: (UIImage?) -> Void

    /// Der Ausschnitt in **Einheitskoordinaten des Bildes** (0 … 1, Ursprung
    /// links oben).
    ///
    /// Bewusst nicht in Bildpunkten des Bildschirms: So bleibt der Rahmen
    /// beim Vergrößern, Verschieben und Drehen des Geräts an derselben
    /// Stelle des Bildes stehen.
    @State private var ausschnitt = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)

    @State private var zoom: CGFloat = 1
    @State private var zoomBeginn: CGFloat = 1
    @State private var schub: CGSize = .zero
    @State private var schubBeginn: CGSize = .zero
    /// Der Ausschnitt, wie er beim Ansetzen der Geste stand.
    ///
    /// `DragGesture` liefert den Weg **seit dem Ansetzen**, nicht seit dem
    /// letzten Aufruf. Wer ihn bei jedem Aufruf aufaddiert, sieht den Rahmen
    /// davonlaufen — er bewegt sich dann quadratisch statt mit dem Finger.
    @State private var ausschnittBeginn = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// Was die laufende Zieh-Geste gerade tut. Wird beim Ansetzen einmal
    /// bestimmt und bleibt bis zum Loslassen — sonst wechselte der Griff
    /// mitten in der Bewegung.
    @State private var griff: Griff?

    private enum Griff: Equatable {
        case ecke(oben: Bool, links: Bool)
        case rahmen
        case bild
    }

    /// Kleiner darf der Rahmen nicht werden — sonst ist er nicht mehr zu
    /// fassen, und der Ausschnitt wäre ohnehin nur noch Matsch.
    private static let kleinster: CGFloat = 0.08
    /// Wie nah an einer Ecke ein Finger als „Ecke" zählt.
    private static let fangradius: CGFloat = 44
    private static let zoomMax: CGFloat = 6

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                kopfleiste
                GeometryReader { geo in
                    flaeche(in: geo.size)
                }
                fussleiste
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    // MARK: - Leisten

    private var kopfleiste: some View {
        HStack {
            Button("Abbrechen") { fertig(nil) }
            Spacer()
            Text("Zuschneiden")
                .font(Theme.font(17, weight: .bold))
            Spacer()
            Button("Übernehmen") { uebernehmen() }
                .font(Theme.font(17, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var fussleiste: some View {
        HStack(spacing: 14) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    ausschnitt = CGRect(x: 0, y: 0, width: 1, height: 1)
                    zoom = 1
                    schub = .zero
                }
            } label: {
                Label("Ganzes Bild", systemImage: "arrow.up.left.and.arrow.down.right")
            }

            Spacer()

            Text(zoom > 1.02 ? String(format: "%.1f×", zoom) : "")
                .font(Theme.font(15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    zoom = 1
                    schub = .zero
                }
            } label: {
                Label("Zoom zurück", systemImage: "minus.magnifyingglass")
            }
            .disabled(zoom <= 1.02)
        }
        .font(Theme.font(15, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Bildfläche

    @ViewBuilder
    private func flaeche(in groesse: CGSize) -> some View {
        let anzeige = bildrahmen(in: groesse)
        let rahmen = rahmenAufSchirm(anzeige)

        ZStack {
            Image(uiImage: bild)
                .resizable()
                .interpolation(.high)
                .frame(width: anzeige.width, height: anzeige.height)
                .position(x: anzeige.midX, y: anzeige.midY)

            // Alles außerhalb des Rahmens abdunkeln. Zwei Rechtecke mit
            // „gerade/ungerade" ergeben ein Loch — vier einzelne Balken
            // ließen an den Kanten Fugen stehen.
            Path { pfad in
                pfad.addRect(CGRect(origin: .zero, size: groesse))
                pfad.addRect(rahmen)
            }
            .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            gitter(rahmen)
                .allowsHitTesting(false)
        }
        .frame(width: groesse.width, height: groesse.height)
        .contentShape(Rectangle())
        .clipped()
        .gesture(zieh(anzeige: anzeige, rahmen: rahmen))
        .simultaneousGesture(vergroessern())
    }

    /// Rahmen, Drittellinien und Ecken.
    private func gitter(_ rahmen: CGRect) -> some View {
        ZStack {
            Path(rahmen)
                .stroke(Color.white, lineWidth: 1.5)

            // Drittellinien — die alte Regel für einen guten Ausschnitt,
            // und zugleich eine Hilfe, ein Heft gerade auszurichten.
            Path { pfad in
                for teil in 1...2 {
                    let anteil = CGFloat(teil) / 3
                    let x = rahmen.minX + rahmen.width * anteil
                    let y = rahmen.minY + rahmen.height * anteil
                    pfad.move(to: CGPoint(x: x, y: rahmen.minY))
                    pfad.addLine(to: CGPoint(x: x, y: rahmen.maxY))
                    pfad.move(to: CGPoint(x: rahmen.minX, y: y))
                    pfad.addLine(to: CGPoint(x: rahmen.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 0.75)

            ForEach(Array(ecken(rahmen).enumerated()), id: \.offset) { _, ecke in
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.5), radius: 3)
                    .position(ecke.punkt)
            }
        }
    }

    private struct Ecke {
        let punkt: CGPoint
        let oben: Bool
        let links: Bool
    }

    private func ecken(_ rahmen: CGRect) -> [Ecke] {
        [Ecke(punkt: CGPoint(x: rahmen.minX, y: rahmen.minY), oben: true, links: true),
         Ecke(punkt: CGPoint(x: rahmen.maxX, y: rahmen.minY), oben: true, links: false),
         Ecke(punkt: CGPoint(x: rahmen.minX, y: rahmen.maxY), oben: false, links: true),
         Ecke(punkt: CGPoint(x: rahmen.maxX, y: rahmen.maxY), oben: false, links: false)]
    }

    // MARK: - Umrechnung

    /// Wo das Bild auf dem Schirm liegt: eingepasst, dann vergrößert und
    /// verschoben.
    private func bildrahmen(in groesse: CGSize) -> CGRect {
        let seiten = bild.size
        guard seiten.width > 0, seiten.height > 0,
              groesse.width > 0, groesse.height > 0 else {
            return CGRect(origin: .zero, size: groesse)
        }
        let masstab = min(groesse.width / seiten.width, groesse.height / seiten.height)
        let breite = seiten.width * masstab * zoom
        let hoehe = seiten.height * masstab * zoom
        return CGRect(x: (groesse.width - breite) / 2 + schub.width,
                      y: (groesse.height - hoehe) / 2 + schub.height,
                      width: breite, height: hoehe)
    }

    private func rahmenAufSchirm(_ anzeige: CGRect) -> CGRect {
        CGRect(x: anzeige.minX + ausschnitt.minX * anzeige.width,
               y: anzeige.minY + ausschnitt.minY * anzeige.height,
               width: ausschnitt.width * anzeige.width,
               height: ausschnitt.height * anzeige.height)
    }

    // MARK: - Gesten

    private func vergroessern() -> some Gesture {
        MagnifyGesture()
            .onChanged { wert in
                if griff != nil { return }
                let neu = zoomBeginn * wert.magnification
                zoom = min(max(neu, 1), Self.zoomMax)
            }
            .onEnded { _ in
                zoomBeginn = zoom
                if zoom <= 1.001 { schub = .zero }
            }
    }

    /// Eine einzige Zieh-Geste für drei Aufgaben. Was gemeint ist, entscheidet
    /// sich beim Ansetzen: an einer Ecke wird die Ecke gezogen, im Rahmen
    /// verschiebt sich der Rahmen, außerhalb das Bild.
    private func zieh(anzeige: CGRect, rahmen: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { wert in
                let laufend: Griff
                if let griff {
                    laufend = griff
                } else {
                    laufend = bestimme(start: wert.startLocation, rahmen: rahmen)
                    griff = laufend
                    schubBeginn = schub
                    ausschnittBeginn = ausschnitt
                }

                switch laufend {
                case .bild:
                    schub = CGSize(width: schubBeginn.width + wert.translation.width,
                                   height: schubBeginn.height + wert.translation.height)
                case .rahmen:
                    verschiebeRahmen(um: wert.translation, in: anzeige)
                case .ecke(let oben, let links):
                    zieheEcke(oben: oben, links: links,
                              zu: wert.location, in: anzeige)
                }
            }
            .onEnded { _ in
                griff = nil
                zoomBeginn = zoom
                schubBeginn = schub
            }
    }

    private func bestimme(start: CGPoint, rahmen: CGRect) -> Griff {
        for ecke in ecken(rahmen) {
            let abstand = hypot(start.x - ecke.punkt.x, start.y - ecke.punkt.y)
            if abstand <= Self.fangradius {
                return .ecke(oben: ecke.oben, links: ecke.links)
            }
        }
        return rahmen.contains(start) ? .rahmen : .bild
    }

    /// Verschieben, ohne aus dem Bild zu laufen. Gerechnet wird gegen den
    /// Stand beim Ansetzen, nicht gegen den letzten Aufruf.
    private func verschiebeRahmen(um weg: CGSize, in anzeige: CGRect) {
        guard anzeige.width > 0, anzeige.height > 0 else { return }
        let neuX = ausschnittBeginn.minX + weg.width / anzeige.width
        let neuY = ausschnittBeginn.minY + weg.height / anzeige.height
        var naechster = ausschnittBeginn
        naechster.origin.x = min(max(neuX, 0), 1 - ausschnittBeginn.width)
        naechster.origin.y = min(max(neuY, 0), 1 - ausschnittBeginn.height)
        ausschnitt = naechster
    }

    private func zieheEcke(oben: Bool, links: Bool, zu punkt: CGPoint, in anzeige: CGRect) {
        guard anzeige.width > 0, anzeige.height > 0 else { return }
        let x = min(max((punkt.x - anzeige.minX) / anzeige.width, 0), 1)
        let y = min(max((punkt.y - anzeige.minY) / anzeige.height, 0), 1)

        var links_ = ausschnitt.minX
        var rechts = ausschnitt.maxX
        var oben_ = ausschnitt.minY
        var unten = ausschnitt.maxY

        if links { links_ = min(x, rechts - Self.kleinster) }
        else     { rechts = max(x, links_ + Self.kleinster) }
        if oben  { oben_ = min(y, unten - Self.kleinster) }
        else     { unten = max(y, oben_ + Self.kleinster) }

        ausschnitt = CGRect(x: links_, y: oben_,
                            width: rechts - links_, height: unten - oben_)
    }

    // MARK: - Fertig

    private func uebernehmen() {
        // Nichts verändert? Dann auch nichts neu berechnen — ein Zuschnitt
        // auf das ganze Bild kostet nur Schärfe.
        let ganz = ausschnitt.minX < 0.001 && ausschnitt.minY < 0.001
                && ausschnitt.width > 0.998 && ausschnitt.height > 0.998
        if ganz {
            fertig(nil)
            return
        }
        fertig(bild.zugeschnitten(auf: ausschnitt) ?? bild)
    }
}

// MARK: - Zeigen

/// Zeigt das Zuschnittblatt — **an SwiftUI vorbei**, wie der Dateiwähler.
///
/// Dieselbe Regel wie bei `Dateiwahl` und `Freigabewahl`: Eine Präsentation,
/// die an einem Ansichtswert hängt, räumt SwiftUI beim Neuzeichnen ab — und
/// die Tafel zeichnet sich bei jedem Abgleich neu. Hier kommt sie von UIKit,
/// und das Ziel reist im Rückruf mit.
///
/// Bewusst nicht an den Hauptfaden gebunden: Der Wert liegt in einer
/// Eigenschaft der Ansicht, und das ist kein Ort mit zugesichertem
/// Hauptfaden. Gerufen wird ohnehin nur von dort.
final class Zuschnittwahl {
    private weak var blatt: UIViewController?

    func oeffne(bild: UIImage, fertig: @escaping (UIImage?) -> Void) {
        guard blatt?.presentingViewController == nil,
              let halter = Oberflaeche.obersterHalter() else { return }

        // Über den schwachen Zeiger geschlossen, nicht über eine örtliche
        // Veränderliche: Die hielte das Blatt über seinen eigenen Rückruf
        // fest und gäbe es nie wieder frei.
        let ansicht = Zuschnittblatt(bild: bild) { [weak self] ergebnis in
            self?.blatt?.dismiss(animated: true)
            fertig(ergebnis)
        }
        let traeger = UIHostingController(rootView: ansicht)
        traeger.modalPresentationStyle = .fullScreen
        traeger.view.backgroundColor = .black
        blatt = traeger
        halter.present(traeger, animated: true)
    }
}
