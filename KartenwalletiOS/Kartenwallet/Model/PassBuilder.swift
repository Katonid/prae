import Foundation
import UIKit
import SwiftUI
import CryptoKit
import Security

/// Baut aus einer Karte eine fertige .pkpass-Datei: pass.json, Bilder,
/// manifest.json (SHA-1 je Datei), PKCS#7-Signatur, alles als ZIP.
enum PassBuilder {

    enum BuildError: LocalizedError {
        case noCertificate
        case photoMissing
        case imageRenderFailed

        var errorDescription: String? {
            switch self {
            case .noCertificate:
                return "Es ist noch kein Pass-Zertifikat eingerichtet. Bitte in den Einstellungen die .p12-Datei importieren."
            case .photoMissing:
                return "Für diese Foto-Karte wurde kein Foto gefunden."
            case .imageRenderFailed:
                return "Die Passbilder konnten nicht erzeugt werden."
            }
        }
    }

    @MainActor
    static func makePass(for card: Card, photo: UIImage?, certStore: CertStore) throws -> Data {
        guard let meta = certStore.meta, let identity = certStore.identity() else {
            throw BuildError.noCertificate
        }
        let chain = try certStore.requireChain()

        var files: [(name: String, data: Data)] = []

        // pass.json
        let passJSON = try JSONSerialization.data(
            withJSONObject: passDictionary(for: card, meta: meta),
            options: [.sortedKeys]
        )
        files.append(("pass.json", passJSON))

        // Icon (Pflicht) in 1x/2x/3x
        for (suffix, pixels) in [("", 29), ("@2x", 58), ("@3x", 87)] {
            guard let png = renderIcon(colorHex: card.colorHex, pixels: CGFloat(pixels)) else {
                throw BuildError.imageRenderFailed
            }
            files.append(("icon\(suffix).png", png))
        }

        // Foto-Karten: Kartenfoto als Streifenbild
        if card.kind == .photo {
            guard let photo else { throw BuildError.photoMissing }
            for (suffix, scale) in [("", 1.0), ("@2x", 2.0), ("@3x", 3.0)] {
                guard let png = renderStrip(photo: photo, colorHex: card.colorHex, scale: scale) else {
                    throw BuildError.imageRenderFailed
                }
                files.append(("strip\(suffix).png", png))
            }
        } else if card.hasBarcode,
                  card.barcodeFormat == .code128 || card.barcodeFormat == .pdf417 {
            // Wallet rendert 1D-Codes nur klein. Deshalb zusätzlich den Code
            // groß als Streifenbild über die Passmitte — der offizielle
            // Wallet-Barcode unten bleibt daneben bestehen.
            for (suffix, scale) in [("", 1.0), ("@2x", 2.0), ("@3x", 3.0)] {
                guard let png = renderBarcodeStrip(card: card, scale: scale) else { break }
                files.append(("strip\(suffix).png", png))
            }
        }

        // manifest.json: SHA-1 jeder Datei
        var manifest: [String: String] = [:]
        for file in files {
            manifest[file.name] = Insecure.SHA1.hash(data: file.data)
                .map { String(format: "%02x", $0) }.joined()
        }
        let manifestJSON = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])

        let signature = try CMSSigner.sign(
            manifest: manifestJSON,
            identity: identity,
            extraCertificates: chain
        )

        var entries: [(name: String, data: Data)] = [
            ("pass.json", passJSON),
            ("manifest.json", manifestJSON),
            ("signature", signature),
        ]
        entries.append(contentsOf: files.filter { $0.name != "pass.json" })

        return ZipWriter.archive(entries: entries)
    }

    // MARK: - pass.json

    private static func passDictionary(for card: Card, meta: CertStore.Meta) -> [String: Any] {
        let (r, g, b) = Color.rgb(fromHex: card.colorHex)
        let (textHex, _) = contrastingTextColor(forHex: card.colorHex)
        let (tr, tg, tb) = Color.rgb(fromHex: textHex)

        let title = card.title.isEmpty ? "Karte" : card.title
        var pass: [String: Any] = [
            "formatVersion": 1,
            "passTypeIdentifier": meta.passTypeIdentifier,
            "teamIdentifier": meta.teamIdentifier,
            "organizationName": meta.organizationName,
            "serialNumber": card.serialNumber,
            "description": title,
            "logoText": title,
            "backgroundColor": "rgb(\(r),\(g),\(b))",
            "foregroundColor": "rgb(\(tr),\(tg),\(tb))",
            "labelColor": "rgb(\(tr),\(tg),\(tb))",
        ]

        var headerFields: [[String: Any]] = []
        var secondaryFields: [[String: Any]] = []
        var backFields: [[String: Any]] = []

        if !card.subtitle.isEmpty {
            headerFields.append(["key": "untertitel", "label": "", "value": card.subtitle])
        }
        // Bei Foto-Karten bleibt die Vorderseite frei (das Foto liegt als
        // Streifen hinter den Feldern) — Angaben wandern auf die Rückseite.
        if card.kind == .photo {
            if !card.memberName.isEmpty {
                backFields.append(["key": "name", "label": "Name", "value": card.memberName])
            }
            if !card.memberNumber.isEmpty {
                backFields.append(["key": "nummer", "label": "Kartennummer", "value": card.memberNumber])
            }
        } else {
            if !card.memberName.isEmpty {
                secondaryFields.append(["key": "name", "label": "NAME", "value": card.memberName])
            }
            if !card.memberNumber.isEmpty {
                secondaryFields.append(["key": "nummer", "label": "KARTENNUMMER", "value": card.memberNumber])
            }
        }
        if !card.note.isEmpty {
            backFields.append(["key": "notiz", "label": "Notiz", "value": card.note])
        }
        backFields.append([
            "key": "info",
            "label": "Über diesen Pass",
            "value": "Erstellt mit Kartenwallet am \(card.createdAt.formatted(date: .abbreviated, time: .omitted)).",
        ])

        var fields: [String: Any] = [:]
        if !headerFields.isEmpty { fields["headerFields"] = headerFields }
        if !secondaryFields.isEmpty { fields["secondaryFields"] = secondaryFields }
        if !backFields.isEmpty { fields["backFields"] = backFields }

        // Wallet stapelt alle Pässe mit derselben Pass-Type-ID. Nur beim
        // Event-Ticket-Layout erlaubt Apple einen groupingIdentifier:
        // gleicher Wert = gemeinsamer Stapel, eigener Wert = einzeln.
        if let group = card.walletGroupName {
            pass["eventTicket"] = fields
            pass["groupingIdentifier"] = "stapel.\(group.lowercased())"
        } else if card.showsSeparatelyInWallet {
            pass["eventTicket"] = fields
            pass["groupingIdentifier"] = card.serialNumber
        } else {
            pass["storeCard"] = fields
        }

        if card.hasBarcode {
            let barcode: [String: Any] = [
                "format": card.barcodeFormat.rawValue,
                "message": card.barcodeMessage,
                "messageEncoding": "iso-8859-1",
                "altText": card.memberNumber.isEmpty ? card.barcodeMessage : card.memberNumber,
            ]
            pass["barcodes"] = [barcode]
        }

        return pass
    }

    // MARK: - Bilder

    /// Pass-Icon: abgerundete Kachel in Kartenfarbe mit Wallet-Symbol.
    private static func renderIcon(colorHex: String, pixels: CGFloat) -> Data? {
        let size = CGSize(width: pixels, height: pixels)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let background = UIColor(Color(hex: colorHex))
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: pixels * 0.22).addClip()
            background.setFill()
            ctx.fill(rect)

            let config = UIImage.SymbolConfiguration(pointSize: pixels * 0.5, weight: .medium)
            if let symbol = UIImage(systemName: "wallet.pass.fill", withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let symbolSize = symbol.size
                let origin = CGPoint(
                    x: (size.width - symbolSize.width) / 2,
                    y: (size.height - symbolSize.height) / 2
                )
                symbol.draw(at: origin)
            }
        }
        return image.pngData()
    }

    /// Streifenbild mit groß gerendertem Barcode (weißer Grund, scharfe
    /// Module durch ganzzahlige Skalierung ohne Interpolation).
    private static func renderBarcodeStrip(card: Card, scale: CGFloat) -> Data? {
        guard let code = Barcode.rawImage(message: card.barcodeMessage, format: card.barcodeFormat) else {
            return nil
        }
        let size = CGSize(width: 375 * scale, height: 123 * scale)
        let margin = 14 * scale
        let codeWidth = CGFloat(code.width)
        let codeHeight = CGFloat(code.height)
        guard codeWidth > 0, codeHeight > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.interpolationQuality = .none

            let maxWidth = size.width - 2 * margin
            let maxHeight = size.height - 2 * margin
            let horizontal = max(1, floor(maxWidth / codeWidth))
            let drawSize: CGSize
            if card.barcodeFormat == .code128 {
                // 1D-Code: Breite ganzzahlig skalieren, Höhe frei strecken.
                drawSize = CGSize(width: codeWidth * horizontal, height: maxHeight)
            } else {
                // PDF417 trägt Information in beiden Achsen — Seitenverhältnis halten.
                let uniform = max(1, min(horizontal, floor(maxHeight / codeHeight)))
                drawSize = CGSize(width: codeWidth * uniform, height: codeHeight * uniform)
            }
            let origin = CGPoint(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2
            )
            UIImage(cgImage: code).draw(in: CGRect(origin: origin, size: drawSize))
        }
        return image.pngData()
    }

    /// Streifenbild für Foto-Karten: das Foto eingepasst auf die
    /// Streifenfläche (375×123 pt), Ränder in der Kartenfarbe.
    private static func renderStrip(photo: UIImage, colorHex: String, scale: CGFloat) -> Data? {
        let size = CGSize(width: 375 * scale, height: 123 * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor(Color(hex: colorHex)).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let photoSize = photo.size
            guard photoSize.width > 0, photoSize.height > 0 else { return }
            let fit = min(size.width / photoSize.width, size.height / photoSize.height)
            let drawSize = CGSize(width: photoSize.width * fit, height: photoSize.height * fit)
            let origin = CGPoint(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2
            )
            photo.draw(in: CGRect(origin: origin, size: drawSize))
        }
        return image.pngData()
    }
}
