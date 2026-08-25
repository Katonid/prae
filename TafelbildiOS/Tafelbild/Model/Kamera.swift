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

    let sitzung = AVCaptureSession()

    private let bilder = AVCapturePhotoOutput()
    private var eingang: AVCaptureDeviceInput?
    private var kunden = 0
    private let werkbank = DispatchQueue(label: "de.familie.tafelbild.kamera")
    private var abschluss: ((UIImage?) -> Void)?

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

        let hatLicht = geraet.hasTorch
        DispatchQueue.main.async { [weak self] in self?.lichtMoeglich = hatLicht }
    }

    // MARK: - Einfrieren

    /// Nimmt ein Standbild auf. Der Rückruf kommt auf dem Hauptfaden.
    func friereEin(_ fertig: @escaping (UIImage?) -> Void) {
        guard laeuft else { fertig(nil); return }
        abschluss = fertig
        werkbank.async { [weak self] in
            guard let self else { return }
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
        let bild = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let rueckruf = self.abschluss
            self.abschluss = nil
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
    }
}
