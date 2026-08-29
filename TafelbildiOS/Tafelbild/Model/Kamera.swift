import AVFoundation
import SwiftUI
import UIKit

// Kamera für die Dokumentenkamera.
//
// Ein iPad, das über dem Tisch hängt oder auf einem Ständer steht, ersetzt
// den Dokumentenprojektor: Heft aufschlagen, hinlegen, alle sehen es. Genau
// dafür ist dieses Element da — Livebild auf der Tafel, ein Tipp friert es
// ein, und über dem eingefrorenen Bild liegt die Handschrift der Tafel.
//
// Aufgebaut wie der Lautstärkemesser: eine gemeinsame Sitzung, die sich
// meldende Elemente zählt. Läuft kein Element mehr, geht die Kamera aus —
// die Anzeige „Kamera aktiv" im Kontrollzentrum soll nicht stehen bleiben,
// wenn längst niemand mehr filmt.
//
// Anders als der Lautstärkemesser ist diese Klasse NICHT an den Hauptfaden
// gebunden: AVFoundation verlangt, dass eine Sitzung auf einer eigenen
// seriellen Schlange auf- und abgebaut wird (`startRunning` blockiert
// spürbar). Alles, was die Oberfläche sieht, wird deshalb ausdrücklich auf
// dem Hauptfaden gesetzt.

final class Kameraquelle: NSObject, ObservableObject {
    static let shared = Kameraquelle()

    enum Erlaubnis { case unbekannt, erlaubt, verweigert }

    @Published private(set) var erlaubnis: Erlaubnis = .unbekannt
    @Published private(set) var laeuft = false
    /// Welche Kamera gerade benutzt wird.
    @Published private(set) var vorne = false
    @Published private(set) var lichtAn = false
    /// Kann das Gerät überhaupt leuchten? (iPads oft nicht.)
    @Published private(set) var lichtMoeglich = false

    /// Eingestellte Vergrößerung, 1 = ganzes Bild.
    ///
    /// Das ist eine Einstellung des **Geräts**, nicht der Tafel: Sie wird
    /// nicht mitgespeichert und nicht geteilt. Ein Dokumentenprojektor wird
    /// im Unterricht ständig nachgestellt — eine Vergrößerung, die beim
    /// nächsten Öffnen der Tafel wieder dastünde, wäre im Weg.
    @Published private(set) var zoom: Double = 1
    /// Was dieses Gerät hergibt. Nach oben gedeckelt: Was darüber liegt, ist
    /// reine Rechnerei und auf einem Heft nur noch Matsch.
    @Published private(set) var zoomMax: Double = 1

    /// Weiter als das wird nicht vergrößert, auch wenn das Gerät mehr könnte.
    static let zoomDeckel: Double = 6

    let sitzung = AVCaptureSession()

    private let bilder = AVCapturePhotoOutput()
    private var eingang: AVCaptureDeviceInput?
    private var kunden = 0
    private let werkbank = DispatchQueue(label: "de.familie.tafelbild.kamera")
    private var abschluss: ((UIImage?) -> Void)?
    /// Seitenverhältnis, auf das das nächste Standbild zugeschnitten wird.
    private var zuschnitt: Double = 0

    private override init() {
        super.init()
        pruefeErlaubnis()
    }

    // MARK: - An und aus

    func anmelden() {
        kunden += 1
        if kunden == 1 { starte() }
    }

    func abmelden() {
        kunden = max(0, kunden - 1)
        if kunden == 0 { stoppe() }
    }

    func pruefeErlaubnis() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:          erlaubnis = .erlaubt
        case .denied, .restricted: erlaubnis = .verweigert
        default:                   erlaubnis = .unbekannt
        }
    }

    func frageErlaubnis() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] gewaehrt in
            DispatchQueue.main.async {
                guard let self else { return }
                self.erlaubnis = gewaehrt ? .erlaubt : .verweigert
                if gewaehrt && self.kunden > 0 { self.starte() }
            }
        }
    }

    private func starte() {
        guard !laeuft else { return }
        guard erlaubnis == .erlaubt else {
            if erlaubnis == .unbekannt { frageErlaubnis() }
            return
        }
        werkbank.async { [weak self] in
            guard let self else { return }
            self.baueAuf()
            self.sitzung.startRunning()
            let laeuftJetzt = self.sitzung.isRunning
            DispatchQueue.main.async { self.laeuft = laeuftJetzt }
        }
    }

    /// Läuft auf der Werkbank.
    private func baueAuf() {
        sitzung.beginConfiguration()
        sitzung.sessionPreset = .photo
        if eingang == nil, let geraet = Self.geraet(vorne: false) {
            setzeEingang(geraet)
        }
        if !sitzung.outputs.contains(bilder), sitzung.canAddOutput(bilder) {
            sitzung.addOutput(bilder)
        }
        sitzung.commitConfiguration()
    }

    private func stoppe() {
        guard laeuft else { return }
        laeuft = false
        lichtAn = false
        werkbank.async { [weak self] in
            self?.sitzung.stopRunning()
        }
    }

    // MARK: - Kamera wählen

    /// Vorder- und Rückkamera tauschen.
    func wechsle() {
        let neuVorne = !vorne
        vorne = neuVorne
        werkbank.async { [weak self] in
            guard let self, let geraet = Self.geraet(vorne: neuVorne) else { return }
            self.sitzung.beginConfiguration()
            if let alt = self.eingang {
                self.sitzung.removeInput(alt)
                self.eingang = nil
            }
            self.setzeEingang(geraet)
            self.sitzung.commitConfiguration()
        }
    }

    /// Licht an oder aus — hilft bei einem Heft im Schatten.
    func licht(_ an: Bool) {
        werkbank.async { [weak self] in
            guard let self, let geraet = self.eingang?.device, geraet.hasTorch else { return }
            try? geraet.lockForConfiguration()
            geraet.torchMode = an ? .on : .off
            let steht = geraet.torchMode == .on
            geraet.unlockForConfiguration()
            DispatchQueue.main.async { self.lichtAn = steht }
        }
    }

    // MARK: - Vergrößern

    /// Stellt die Vergrößerung ein. Werte außerhalb des Möglichen werden
    /// eingefangen, nicht abgewiesen — die Geste soll am Anschlag stehen
    /// bleiben und nicht springen.
    ///
    /// Was hier eingestellt ist, gilt auch für das Standbild: Die
    /// Vergrößerung sitzt im Gerät, nicht in der Vorschau. Eingefroren wird
    /// deshalb genau das, was im Sucher steht.
    func setzeZoom(_ faktor: Double) {
        werkbank.async { [weak self] in
            guard let self, let geraet = self.eingang?.device else { return }
            let unten = Double(geraet.minAvailableVideoZoomFactor)
            let oben = min(Double(geraet.maxAvailableVideoZoomFactor), Self.zoomDeckel)
            let sauber = min(max(faktor, unten), max(oben, unten))
            guard (try? geraet.lockForConfiguration()) != nil else { return }
            geraet.videoZoomFactor = CGFloat(sauber)
            geraet.unlockForConfiguration()
            DispatchQueue.main.async { self.zoom = sauber }
        }
    }

    /// Zurück auf das ganze Bild.
    func zoomZurueck() { setzeZoom(1) }

    private static func geraet(vorne: Bool) -> AVCaptureDevice? {
        let suche = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: vorne ? .front : .back)
        return suche.devices.first ?? AVCaptureDevice.default(for: .video)
    }

    /// Eingang setzen und die Kamera auf Nahaufnahme einstellen. Läuft auf
    /// der Werkbank, innerhalb einer laufenden Konfiguration.
    ///
    /// Ein Dokumentenprojektor filmt aus 30 bis 50 Zentimetern. Ohne die
    /// eingeschränkte Fokussuche pumpt die Kamera zwischen Tisch und Raum
    /// hin und her, sobald jemand die Hand ins Bild hält.
    private func setzeEingang(_ geraet: AVCaptureDevice) {
        guard let neu = try? AVCaptureDeviceInput(device: geraet),
              sitzung.canAddInput(neu)
        else { return }
        sitzung.addInput(neu)
        eingang = neu

        try? geraet.lockForConfiguration()
        if geraet.isFocusModeSupported(.continuousAutoFocus) {
            geraet.focusMode = .continuousAutoFocus
        }
        if geraet.isAutoFocusRangeRestrictionSupported {
            geraet.autoFocusRangeRestriction = .near
        }
        if geraet.isExposureModeSupported(.continuousAutoExposure) {
            geraet.exposureMode = .continuousAutoExposure
        }
        geraet.unlockForConfiguration()

        // Jede Kamera bringt ihre eigenen Grenzen mit, und die vorige
        // Vergrößerung passt nicht dazu. Beim Wechsel also zurück auf das
        // ganze Bild — sonst stünde man plötzlich in einem Ausschnitt, den
        // man nicht eingestellt hat.
        geraet.videoZoomFactor = 1
        let hatLicht = geraet.hasTorch
        let obergrenze = min(Double(geraet.maxAvailableVideoZoomFactor), Self.zoomDeckel)
        DispatchQueue.main.async { [weak self] in
            self?.lichtMoeglich = hatLicht
            self?.zoomMax = obergrenze
            self?.zoom = 1
        }
    }

    // MARK: - Einfrieren

    /// Nimmt ein Standbild auf. Der Rückruf kommt auf dem Hauptfaden.
    ///
    /// - Parameters:
    ///   - verhaeltnis: Breite geteilt durch Höhe der Vorschau. Das Standbild
    ///     wird genau darauf zugeschnitten, damit es zeigt, was eben noch im
    ///     Sucher stand — die Vorschau füllt ihre Fläche, die Aufnahme kommt
    ///     aber im Seitenverhältnis des Sensors.
    ///   - winkel: Drehwinkel passend zur Lage des Geräts (`Videolage.jetzt`).
    func friereEin(verhaeltnis: Double, winkel: CGFloat,
                   fertig: @escaping (UIImage?) -> Void) {
        guard laeuft else { fertig(nil); return }
        zuschnitt = verhaeltnis
        abschluss = fertig
        werkbank.async { [weak self] in
            guard let self else { return }
            if let verbindung = self.bilder.connection(with: .video) {
                if verbindung.isVideoRotationAngleSupported(winkel) {
                    verbindung.videoRotationAngle = winkel
                }
                // Die Vorschau spiegelt die Frontkamera von selbst. Ohne
                // dieselbe Spiegelung stünde auf dem Standbild plötzlich
                // alles seitenverkehrt.
                let gespiegelt = self.eingang?.device.position == .front
                if verbindung.isVideoMirroringSupported {
                    verbindung.automaticallyAdjustsVideoMirroring = false
                    verbindung.isVideoMirrored = gespiegelt
                }
            }
            let einstellung = AVCapturePhotoSettings()
            einstellung.flashMode = .off
            self.bilder.capturePhoto(with: einstellung, delegate: self)
        }
    }
}

extension Kameraquelle: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let roh = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        let verhaeltnis = zuschnitt
        let bild = verhaeltnis > 0 ? roh?.zugeschnitten(auf: verhaeltnis) : roh
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let rueckruf = self.abschluss
            self.abschluss = nil
            self.zuschnitt = 0
            rueckruf?(bild)
        }
    }
}

// MARK: - Livebild

/// Zeigt das laufende Kamerabild. `AVCaptureVideoPreviewLayer` gehört in eine
/// UIKit-Ebene; SwiftUI bekommt sie über diesen Umweg.
struct Kameravorschau: UIViewRepresentable {
    let sitzung: AVCaptureSession

    func makeUIView(context: Context) -> VorschauView {
        let view = VorschauView()
        view.backgroundColor = .black
        view.ebene.session = sitzung
        // Füllend: Ein Dokument soll die Fläche ausnutzen; schwarze Ränder
        // wären auf der Tafel verschenkter Platz.
        view.ebene.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: VorschauView, context: Context) {
        if view.ebene.session !== sitzung { view.ebene.session = sitzung }
    }

    final class VorschauView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var ebene: AVCaptureVideoPreviewLayer {
            // Sicher: layerClass oben legt genau diese Ebene fest.
            layer as! AVCaptureVideoPreviewLayer
        }

        private var beobachter: NSObjectProtocol?

        /// Nicht jede Drehung ändert die Größe dieser Ansicht — auf einer
        /// quadratischen Kachel bliebe sie gleich, und `layoutSubviews`
        /// liefe nie. Deshalb zusätzlich auf die Drehung selbst hören.
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard beobachter == nil else { return }
            beobachter = NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil, queue: .main) { [weak self] _ in
                self?.setNeedsLayout()
            }
        }

        deinit {
            if let beobachter { NotificationCenter.default.removeObserver(beobachter) }
        }

        /// Das Bild muss sich mitdrehen, wenn das Gerät sich dreht.
        ///
        /// Ohne diese Zeilen bleibt die Verbindung auf der Vorgabe stehen —
        /// Hochformat, egal wie das iPad liegt. Ein Heft im Querformat war
        /// dann hochkant und beschnitten. `layoutSubviews` ist die richtige
        /// Stelle: Es läuft bei jeder Drehung und bei jeder Größenänderung
        /// des Elements.
        /// Maßgeblich ist die Lage des iPads, nicht die des Fensters: Auf
        /// dem Beamer liegt dieselbe Vorschau noch einmal, und dessen Szene
        /// kennt gar keine Lage.
        override func layoutSubviews() {
            super.layoutSubviews()
            let winkel = Videolage.jetzt
            if let verbindung = ebene.connection,
               verbindung.isVideoRotationAngleSupported(winkel),
               verbindung.videoRotationAngle != winkel {
                verbindung.videoRotationAngle = winkel
            }
        }
    }
}

// MARK: - Lage

/// Rechnet die Lage der Bedienoberfläche in einen Drehwinkel für Video um.
///
/// AVFoundation zählt den Winkel im Uhrzeigersinn, gemessen von der Lage
/// „Gerät quer, Ladebuchse rechts": 0° ist quer, 90° hochkant. Genau diese
/// Zuordnung braucht sowohl die Vorschau als auch die Aufnahme — sonst
/// zeigen beide etwas Verschiedenes.
enum Videolage {
    static func winkel(fuer lage: UIInterfaceOrientation) -> CGFloat {
        switch lage {
        case .portrait:           return 90
        case .portraitUpsideDown: return 270
        case .landscapeLeft:      return 180
        case .landscapeRight:     return 0
        default:                  return 90
        }
    }

    /// Der Winkel, der gerade gilt. Nur vom Hauptfaden aufzurufen.
    @MainActor
    static var jetzt: CGFloat {
        let szenen = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let szene = szenen.first { $0.activationState == .foregroundActive } ?? szenen.first
        return winkel(fuer: szene?.interfaceOrientation ?? .portrait)
    }
}

// MARK: - Zuschnitt

extension UIImage {
    /// Zeichnet das Bild in seiner sichtbaren Lage neu.
    ///
    /// Eine Aufnahme trägt ihre Drehung in `imageOrientation` — sichtbar
    /// richtig, in den Bilddaten aber gedreht. Ein Zuschnitt auf der
    /// CGImage-Ebene übersähe das und schnitte an der falschen Kante.
    func aufrecht() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Schneidet auf einen Ausschnitt in **Einheitskoordinaten** zu
    /// (0 … 1, Ursprung links oben) — so, wie ihn das Zuschnittblatt führt.
    ///
    /// Gerechnet wird auf dem aufrecht gezeichneten Bild: Eine Aufnahme
    /// trägt ihre Drehung in `imageOrientation`, und ein Zuschnitt auf der
    /// CGImage-Ebene schnitte sonst an der falschen Kante.
    func zugeschnitten(auf ausschnitt: CGRect) -> UIImage? {
        let gerade = aufrecht()
        guard let cg = gerade.cgImage else { return nil }
        let breite = CGFloat(cg.width), hoehe = CGFloat(cg.height)
        guard breite > 0, hoehe > 0 else { return nil }

        let bereich = CGRect(x: ausschnitt.minX * breite,
                             y: ausschnitt.minY * hoehe,
                             width: ausschnitt.width * breite,
                             height: ausschnitt.height * hoehe)
            .intersection(CGRect(x: 0, y: 0, width: breite, height: hoehe))
            .integral
        guard bereich.width >= 1, bereich.height >= 1,
              let teil = cg.cropping(to: bereich) else { return nil }
        return UIImage(cgImage: teil, scale: gerade.scale, orientation: .up)
    }

    /// Schneidet mittig auf ein Seitenverhältnis zu — dasselbe, was die
    /// Vorschau mit `resizeAspectFill` zeigt.
    func zugeschnitten(auf verhaeltnis: Double) -> UIImage {
        let gerade = aufrecht()
        guard verhaeltnis > 0, let cg = gerade.cgImage else { return gerade }
        let breite = Double(cg.width), hoehe = Double(cg.height)
        guard breite > 0, hoehe > 0 else { return gerade }
        let ist = breite / hoehe
        var ausschnitt = CGRect(x: 0, y: 0, width: breite, height: hoehe)
        if ist > verhaeltnis + 0.001 {
            let neueBreite = hoehe * verhaeltnis
            ausschnitt = CGRect(x: (breite - neueBreite) / 2, y: 0,
                                width: neueBreite, height: hoehe)
        } else if ist < verhaeltnis - 0.001 {
            let neueHoehe = breite / verhaeltnis
            ausschnitt = CGRect(x: 0, y: (hoehe - neueHoehe) / 2,
                                width: breite, height: neueHoehe)
        }
        guard let teil = cg.cropping(to: ausschnitt.integral) else { return gerade }
        return UIImage(cgImage: teil, scale: gerade.scale, orientation: .up)
    }
}
