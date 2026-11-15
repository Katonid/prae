import Foundation
import CoreGraphics

struct ExportOptions: Equatable {
    /// Eine PDF mit allen Postern oder eine Datei je Poster.
    var oneFile = true
    /// Schnittmarken außerhalb des Beschnitts — nur, wenn die Druckerei sie will.
    var cropMarks = false
}

struct ExportError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Schreibt die Druckdatei direkt mit CoreGraphics: Jede Seite ist das
/// Datenformat (Endformat + Beschnitt), das Bild wird in voller Auflösung
/// gezeichnet. Ein JPEG-Original landet dabei unverändert im PDF (kein
/// erneutes Komprimieren), weil es nur beschnitten, verschoben und
/// gedreht, aber nie neu gerechnet wird.
///
/// MediaBox, BleedBox und TrimBox sind gesetzt — die Druckerei liest
/// daraus Endformat und Beschnitt.
enum PDFExporter {
    private static let markOffsetMM = 2.0
    private static let markLengthMM = 6.0

    /// Läuft abseits des Hauptfadens; `progress` wird dort aufgerufen.
    static func export(project: PosterProject, options: ExportOptions,
                       progress: @escaping @Sendable (Double, String) -> Void) throws -> [URL] {
        guard !project.items.isEmpty else {
            throw ExportError(message: "Der Auftrag enthält noch keine Bilder.")
        }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Export-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let base = safeName(project.name.isEmpty ? "Poster" : project.name)
        let items = project.items
        let total = Double(items.count)

        if options.oneFile {
            let g = PageGeometry(format: project.format, item: items.first)
            let url = folder.appendingPathComponent("\(base) – \(sizeText(g)).pdf")
            try write(items: items, format: project.format, title: project.name, options: options, to: url) { n in
                progress(Double(n) / total, "Poster \(n + 1) von \(items.count)")
            }
            progress(1, "Fertig")
            return [url]
        }

        var urls: [URL] = []
        for (n, item) in items.enumerated() {
            progress(Double(n) / total, "Poster \(n + 1) von \(items.count)")
            let g = PageGeometry(format: project.format, item: item)
            let name = String(format: "%@ %02d – %@.pdf", base, n + 1, sizeText(g))
            let url = folder.appendingPathComponent(name)
            try write(items: [item], format: project.format, title: "\(project.name) \(n + 1)", options: options, to: url) { _ in }
            urls.append(url)
        }
        progress(1, "Fertig")
        return urls
    }

    private static func sizeText(_ g: PageGeometry) -> String {
        let d = g.dataMM
        return "\(d.w.mmText)×\(d.h.mmText) mm"
    }

    private static func write(items: [PosterItem], format: PosterFormat, title: String,
                              options: ExportOptions, to url: URL,
                              pageStarted: (Int) -> Void) throws {
        let info: [CFString: Any] = [
            kCGPDFContextTitle: title,
            kCGPDFContextCreator: "Posterdruck",
        ]
        let first = PageGeometry(format: format, item: items.first)
        let margin: CGFloat = options.cropMarks ? Units.pt(markOffsetMM + markLengthMM + 1) : 0
        var firstMedia = CGRect(x: 0, y: 0, width: first.size.width + 2 * margin, height: first.size.height + 2 * margin)
        guard let ctx = CGContext(url as CFURL, mediaBox: &firstMedia, info as CFDictionary) else {
            throw ExportError(message: "Die PDF-Datei ließ sich nicht anlegen.")
        }

        for (n, item) in items.enumerated() {
            pageStarted(n)
            try autoreleasepool {
                let g = PageGeometry(format: format, item: item)
                let media = CGRect(x: 0, y: 0, width: g.size.width + 2 * margin, height: g.size.height + 2 * margin)
                let bleedBox = CGRect(x: margin, y: margin, width: g.size.width, height: g.size.height)
                let trimBox = bleedBox.insetBy(dx: g.bleed, dy: g.bleed)
                let pageInfo: [CFString: Any] = [
                    kCGPDFContextMediaBox: boxData(media),
                    kCGPDFContextBleedBox: boxData(bleedBox),
                    kCGPDFContextTrimBox: boxData(trimBox),
                    kCGPDFContextCropBox: boxData(media),
                ]
                guard let original = PhotoStore.shared.original(item.photoID) else {
                    throw ExportError(message: "Das Bild „\(item.originalName.isEmpty ? "Poster \(n + 1)" : item.originalName)“ fehlt auf diesem Gerät.")
                }
                ctx.beginPDFPage(pageInfo as CFDictionary)
                ctx.saveGState()
                // Seite im Koordinatensystem der PDF (Ursprung unten links).
                ctx.translateBy(x: margin, y: margin)
                ctx.clip(to: CGRect(origin: .zero, size: g.size))
                ctx.setFillColor(item.background.cgColor)
                ctx.fill(CGRect(origin: .zero, size: g.size))
                let r = PosterLayout.imageRect(item: item, geometry: g)
                // Layout rechnet von oben, die PDF von unten.
                let dest = CGRect(x: r.minX, y: g.size.height - r.maxY, width: r.width, height: r.height)
                draw(original.image, orientation: original.orientation, quarterTurns: item.quarterTurns, in: dest, ctx: ctx)
                ctx.restoreGState()
                if options.cropMarks {
                    drawCropMarks(ctx, trim: trimBox, bleed: g.bleed)
                }
                ctx.endPDFPage()
            }
        }
        ctx.closePDF()
    }

    /// Zeichnet ein Bild aufrecht (EXIF-Drehung) und zusätzlich um
    /// `quarterTurns` Vierteldrehungen im Uhrzeigersinn gedreht so, dass es
    /// genau `dest` ausfüllt.
    static func draw(_ image: CGImage, orientation: Int, quarterTurns: Int, in dest: CGRect, ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: dest.midX, y: dest.midY)
        let turns = ((quarterTurns % 4) + 4) % 4
        // Im PDF zeigt y nach oben: eine negative Drehung läuft im Uhrzeigersinn.
        ctx.rotate(by: -CGFloat(turns) * .pi / 2)
        var size = dest.size
        if turns % 2 == 1 { size = CGSize(width: size.height, height: size.width) }
        switch orientation {
        case 3:
            ctx.rotate(by: .pi)
        case 6:
            ctx.rotate(by: -.pi / 2)
            size = CGSize(width: size.height, height: size.width)
        case 8:
            ctx.rotate(by: .pi / 2)
            size = CGSize(width: size.height, height: size.width)
        default:
            break
        }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        ctx.restoreGState()
    }

    private static func boxData(_ rect: CGRect) -> CFData {
        var r = rect
        return Data(bytes: &r, count: MemoryLayout<CGRect>.size) as CFData
    }

    /// Schnittmarken an den vier Ecken des Endformats, außerhalb des Beschnitts.
    private static func drawCropMarks(_ ctx: CGContext, trim: CGRect, bleed: CGFloat) {
        let offset = bleed + Units.pt(markOffsetMM)
        let length = Units.pt(markLengthMM)
        ctx.saveGState()
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
        ctx.setLineWidth(0.25)
        for x in [trim.minX, trim.maxX] {
            for y in [trim.minY, trim.maxY] {
                let dx: CGFloat = x == trim.minX ? -1 : 1
                let dy: CGFloat = y == trim.minY ? -1 : 1
                ctx.move(to: CGPoint(x: x + dx * offset, y: y))
                ctx.addLine(to: CGPoint(x: x + dx * (offset + length), y: y))
                ctx.move(to: CGPoint(x: x, y: y + dy * offset))
                ctx.addLine(to: CGPoint(x: x, y: y + dy * (offset + length)))
            }
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func safeName(_ s: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        return s.components(separatedBy: bad).joined(separator: "-").trimmingCharacters(in: .whitespaces)
    }
}
