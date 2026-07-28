import Foundation
import UIKit
import CoreImage
import Vision

/// Barcode-Vorschau in der App und Barcode-Erkennung aus Fotos.
enum Barcode {

    /// Erzeugt eine Vorschau des Barcodes (scharf skaliert).
    static func previewImage(message: String, format: BarcodeFormat) -> UIImage? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let data = trimmed.data(using: .isoLatin1) ?? trimmed.data(using: .utf8) else { return nil }

        let filterName: String
        switch format {
        case .qr: filterName = "CIQRCodeGenerator"
        case .aztec: filterName = "CIAztecCodeGenerator"
        case .code128: filterName = "CICode128BarcodeGenerator"
        case .pdf417: filterName = "CIPDF417BarcodeGenerator"
        }
        guard let filter = CIFilter(name: filterName) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        if format == .qr {
            filter.setValue("M", forKey: "inputCorrectionLevel")
        }
        guard let output = filter.outputImage else { return nil }

        let scale = max(4, 320 / max(output.extent.width, 1))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    struct DetectionResult {
        let message: String
        let format: BarcodeFormat
        /// Gesetzt, wenn das Originalformat (z. B. EAN-13) in Wallet nicht
        /// existiert und als Code 128 übernommen wurde.
        let convertedFrom: String?
    }

    /// Sucht in einem Foto nach einem Barcode (Vision).
    static func detect(in image: UIImage) async -> DetectionResult? {
        guard let cgImage = image.cgImage else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> DetectionResult? in
            let request = VNDetectBarcodesRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
            let observations = request.results ?? []
            return observations.compactMap { obs -> DetectionResult? in
                guard let payload = obs.payloadStringValue, !payload.isEmpty else { return nil }
                return map(symbology: obs.symbology, payload: payload)
            }.first
        }.value
    }

    /// Übersetzt Vision-Symbologien in Wallet-Formate. Wallet kennt nur
    /// QR, Aztec, Code 128 und PDF417 — Handelsformate wie EAN-13 werden
    /// als Code 128 übernommen (der Zahlencode bleibt identisch und ist
    /// an Scannerkassen in aller Regel lesbar).
    static func map(symbology: VNBarcodeSymbology, payload: String) -> DetectionResult? {
        switch symbology {
        case .qr, .microQR:
            return DetectionResult(message: payload, format: .qr, convertedFrom: nil)
        case .aztec:
            return DetectionResult(message: payload, format: .aztec, convertedFrom: nil)
        case .code128:
            return DetectionResult(message: payload, format: .code128, convertedFrom: nil)
        case .pdf417, .microPDF417:
            return DetectionResult(message: payload, format: .pdf417, convertedFrom: nil)
        case .ean13:
            return DetectionResult(message: payload, format: .code128, convertedFrom: "EAN-13")
        case .ean8:
            return DetectionResult(message: payload, format: .code128, convertedFrom: "EAN-8")
        case .upce:
            return DetectionResult(message: payload, format: .code128, convertedFrom: "UPC-E")
        case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum:
            return DetectionResult(message: payload, format: .code128, convertedFrom: "Code 39")
        case .code93, .code93i:
            return DetectionResult(message: payload, format: .code128, convertedFrom: "Code 93")
        case .itf14, .i2of5, .i2of5Checksum:
            return DetectionResult(message: payload, format: .code128, convertedFrom: "ITF")
        case .codabar:
            return DetectionResult(message: payload, format: .code128, convertedFrom: "Codabar")
        default:
            return DetectionResult(message: payload, format: .qr, convertedFrom: symbology.rawValue)
        }
    }
}
