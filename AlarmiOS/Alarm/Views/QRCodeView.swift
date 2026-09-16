//  QRCodeView.swift
//  Drawing and reading the join code.
//
//  Generated with CoreImage, which every iOS device already has — no library,
//  no network, nothing to keep up to date. The code content is just the plain
//  six characters, not a URL: it has to be readable by a human standing next
//  to the screen who would rather type it, and a URL would bury the code in
//  scheme and host.

import AVFoundation
import CoreImage.CIFilterBuiltins
import SwiftUI

struct QRCodeView: View {

    let text: String
    var size: CGFloat = 220

    var body: some View {
        if let image = Self.image(for: text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .frame(width: size, height: size)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
        } else {
            Text(text).font(.system(.title, design: .monospaced))
        }
    }

    /// Correction level M: a projected or printed code gets fingerprints and
    /// glare, and M costs a few modules to survive both.
    static func image(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// The camera side.
///
/// Deliberately thin: it recognises a code, hands the string up, and stops.
/// Anything else — validating, joining, error handling — belongs to the view
/// model, where it can be tested without a camera.
struct QRScannerView: UIViewControllerRepresentable {

    var onFound: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.onFound = onFound
        return controller
    }

    func updateUIViewController(_ controller: ScannerController, context: Context) {
        controller.onFound = onFound
    }

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

        var onFound: ((String) -> Void)?

        private let session = AVCaptureSession()
        private var preview: AVCaptureVideoPreviewLayer?
        private var hasReported = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            configure()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            preview?.frame = view.bounds
            richteVorschauAus()
        }

        /// Die Vorschau muss der Lage des GERÄTS folgen, nicht der des Sensors.
        ///
        /// Gemeldet 09/2026: Auf einem quer gehaltenen iPad stand das Kamerabild
        /// hochkant, und ein fremder Beitrittscode ließ sich kaum treffen. Eine
        /// `AVCaptureVideoPreviewLayer` beginnt nämlich immer im Hochformat —
        /// die Verbindung übernimmt die Lage der Oberfläche NICHT von selbst.
        ///
        /// Erkannt hätte die Kamera den Code trotzdem: Gesucht wird im
        /// Sensorbild, und das ist von der Anzeige unabhängig. Genau das macht
        /// den Fehler so zäh — nichts ist kaputt, es lässt sich nur nicht
        /// zielen. Für den Menschen davor ist das dasselbe.
        ///
        /// Gefragt wird die Szene DIESER Ansicht (`view.window?.windowScene`)
        /// und nicht `connectedScenes`: Das ist eine ungeordnete Menge, und
        /// hängt ein Beamer am iPad, greift `first { … }` mal die eine und mal
        /// die andere — derselbe Fehler, der in Tafelbild die Dokumentenkamera
        /// auf den Kopf stellte. Ist die Lage unbekannt, bleibt es beim
        /// Hochformat: die Vorgabe von vorher, nie schlechter als geraten.
        private func richteVorschauAus() {
            guard let connection = preview?.connection else { return }
            let lage = view.window?.windowScene?.interfaceOrientation ?? .portrait

            if #available(iOS 17.0, *) {
                let winkel = Self.winkel(fuer: lage)
                guard connection.isVideoRotationAngleSupported(winkel) else { return }
                if connection.videoRotationAngle != winkel {
                    connection.videoRotationAngle = winkel
                }
            } else {
                Self.richteAltAus(connection, lage)
            }
        }

        /// Der Winkel, um den das Sensorbild zu drehen ist (ab iOS 17).
        ///
        /// Die Zahlen sind Apples eigene Entsprechungen aus der Abkündigung von
        /// `videoOrientation`: portrait 90, portraitUpsideDown 270,
        /// landscapeLeft 180, landscapeRight 0. Nicht selbst nachrechnen — die
        /// Bezugslage der Kamera ist Querformat, und wer hier um 180 Grad
        /// danebenliegt, merkt es nur auf einem echten Gerät.
        static func winkel(fuer lage: UIInterfaceOrientation) -> CGFloat {
            switch lage {
            case .portrait: return 90
            case .portraitUpsideDown: return 270
            case .landscapeLeft: return 180
            case .landscapeRight: return 0
            default: return 90
            }
        }

        /// Dasselbe für iOS 16, wo es die Winkel noch nicht gibt.
        ///
        /// Hier ist es eine reine Umbenennung: `AVCaptureVideoOrientation` hat
        /// dieselben vier Fälle wie `UIInterfaceOrientation` und meint sie
        /// gleich.
        ///
        /// Die Abkündigung steht mit Absicht AN DER FUNKTION: `videoOrientation`
        /// ist seit iOS 17 veraltet, und ein `#available` schaltet die Warnung
        /// nicht ab — sie hängt an der Übersetzung, nicht am Lauf. So steht sie
        /// einmal hier statt dreimal im Bau, und sie verschwindet von selbst,
        /// sobald das Mindest-iOS 17 ist: Dann lässt sich diese Funktion samt
        /// ihrem Zweig ersatzlos streichen.
        @available(iOS, deprecated: 17.0,
                   message: "Ab iOS 17 übernimmt videoRotationAngle; dieser Zweig kann dann weg.")
        static func richteAltAus(_ connection: AVCaptureConnection,
                                 _ lage: UIInterfaceOrientation) {
            let richtung: AVCaptureVideoOrientation
            switch lage {
            case .portrait: richtung = .portrait
            case .portraitUpsideDown: richtung = .portraitUpsideDown
            case .landscapeLeft: richtung = .landscapeLeft
            case .landscapeRight: richtung = .landscapeRight
            default: return
            }
            guard connection.isVideoOrientationSupported,
                  connection.videoOrientation != richtung else { return }
            connection.videoOrientation = richtung
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            hasReported = false
            guard !session.isRunning else { return }
            // Starting a capture session blocks; off the main thread it is,
            // otherwise the sheet appears frozen for a second.
            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.startRunning()
            }
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            session.stopRunning()
        }

        private func configure() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            preview = layer
            richteVorschauAus()
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            // One report per presentation. A QR code is recognised many times
            // a second, and joining a group thirty times is not better than
            // joining it once.
            guard !hasReported,
                  let object = objects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue else { return }
            hasReported = true
            onFound?(value)
        }
    }
}
