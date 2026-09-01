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
