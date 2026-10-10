import SwiftUI
import UIKit

struct ExportOptions: Equatable {
    enum Format: String, CaseIterable, Identifiable {
        case pdf, jpeg
        var id: String { rawValue }
        var title: String { self == .pdf ? "PDF (eine Datei)" : "JPG (eine Datei je Seite)" }
    }

    var format: Format = .pdf
    var cropMarks = false
    /// Auflösung für JPG und für weichgezeichnete Effekte im PDF.
    var dpi: Double = 300
}

/// Erzeugt druckfertige Dateien: jede Seite in Endformat plus Beschnitt.
@MainActor
enum Exporter {
    /// Abstand der Schnittmarken vom Beschnitt und ihre Länge, in mm.
    private static let markOffsetMM = 2.0
    private static let markLengthMM = 6.0

    static func export(project: CalendarProject, options: ExportOptions,
                       progress: @escaping (Double, String) -> Void) async throws -> [URL] {
        try await waitForPhotos(project, progress: progress)
        let marks = CalendarMarks.build(for: project)
        PhotoInfo.register(project.photos)
        let pages = project.pages
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Export-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let baseName = safeName(project.name.isEmpty ? "Kalender" : project.name)
        defer { ImageStore.shared.clearPrintCache() }

        switch options.format {
        case .pdf:
            let url = folder.appendingPathComponent("\(baseName) \(project.yearText.replacingOccurrences(of: "/", with: "-")).pdf")
            try await writePDF(project: project, pages: pages, marks: marks, options: options, to: url, progress: progress)
            return [url]
        case .jpeg:
            var urls: [URL] = []
            for (n, page) in pages.enumerated() {
                progress(Double(n) / Double(pages.count), "Seite \(n + 1) von \(pages.count)")
                await Task.yield()
                let view = pageView(project: project, page: page, marks: marks)
                let renderer = ImageRenderer(content: view)
                renderer.scale = CGFloat(options.dpi / 72)
                renderer.isOpaque = true
                guard let image = renderer.uiImage, let data = image.jpegData(compressionQuality: 0.93) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                let name = String(format: "%@ %02d %@.jpg", baseName, n + 1, safeName(page.label))
                let url = folder.appendingPathComponent(name)
                try data.write(to: url)
                urls.append(url)
                if n % 6 == 5 { ImageStore.shared.clearPrintCache() }
            }
            progress(1, "Fertig")
            return urls
        }
    }

    /// Mit iCloud können Originale noch in der Wolke liegen. Gedruckt wird
    /// erst, wenn alle da sind — sonst landete stillschweigend die
    /// Vorschau-Auflösung im PDF.
    private static func waitForPhotos(_ project: CalendarProject,
                                      progress: @escaping (Double, String) -> Void) async throws {
        let store = ImageStore.shared
        store.forgetMisses()
        var waiting = project.photos.map(\.id).filter { !store.fullIsReady($0) }
        var rounds = 0
        while !waiting.isEmpty && rounds < 180 {
            let missing = waiting.filter { store.state($0) == .missing }
            if missing.count == waiting.count { break }
            progress(0, "Lade \(waiting.count) Foto(s) aus iCloud …")
            try await Task.sleep(nanoseconds: 500_000_000)
            waiting = waiting.filter { !store.fullIsReady($0) }
            rounds += 1
        }
        guard waiting.isEmpty else {
            let missing = waiting.filter { store.state($0) == .missing }.count
            throw ExportError(message: missing > 0
                ? "\(missing) Foto(s) fehlen auf diesem Gerät und in iCloud. Bitte auf dem Gerät öffnen, auf dem sie hinzugefügt wurden, und dort warten, bis iCloud sie hochgeladen hat."
                : "\(waiting.count) Foto(s) kommen noch aus iCloud. Bitte mit Netz einen Moment warten und erneut exportieren.")
        }
    }

    static func pageView(project: CalendarProject, page: PageSpec, marks: CalendarMarks) -> some View {
        PageView(project: project, page: page, marks: marks)
            .environment(\.renderMode, .print)
            .environment(\.colorScheme, .light)
    }

    private static func writePDF(project: CalendarProject, pages: [PageSpec], marks: CalendarMarks,
                                 options: ExportOptions, to url: URL,
                                 progress: @escaping (Double, String) -> Void) async throws {
        let g = PageGeometry(project.format)
        let margin: CGFloat = options.cropMarks ? Units.pt(markOffsetMM + markLengthMM + 1) : 0
        var media = CGRect(x: 0, y: 0, width: g.size.width + 2 * margin, height: g.size.height + 2 * margin)
        let bleedBox = CGRect(x: margin, y: margin, width: g.size.width, height: g.size.height)
        let trimBox = bleedBox.insetBy(dx: g.bleed, dy: g.bleed)

        let info: [CFString: Any] = [
            kCGPDFContextTitle: "\(project.displayTitle) \(project.yearText)",
            kCGPDFContextCreator: "Kalenderstudio",
        ]
        guard let ctx = CGContext(url as CFURL, mediaBox: &media, info as CFDictionary) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let pageInfo: [CFString: Any] = [
            kCGPDFContextMediaBox: boxData(media),
            kCGPDFContextBleedBox: boxData(bleedBox),
            kCGPDFContextTrimBox: boxData(trimBox),
            kCGPDFContextCropBox: boxData(media),
        ]

        for (n, page) in pages.enumerated() {
            progress(Double(n) / Double(pages.count), "Seite \(n + 1) von \(pages.count)")
            await Task.yield()
            let view = pageView(project: project, page: page, marks: marks)
            let renderer = ImageRenderer(content: view)
            renderer.scale = CGFloat(options.dpi / 72)
            renderer.proposedSize = ProposedViewSize(g.size)
            ctx.beginPDFPage(pageInfo as CFDictionary)
            // Schatten, Masken und Weichzeichner werden gerastert — ohne
            // diese Angabe mit 72 dpi, also sichtbar unscharf im Druck.
            renderer.render(rasterizationScale: CGFloat(options.dpi / 72)) { _, draw in
                ctx.saveGState()
                ctx.translateBy(x: margin, y: margin)
                draw(ctx)
                ctx.restoreGState()
            }
            if options.cropMarks {
                drawCropMarks(ctx, trim: trimBox, bleed: g.bleed)
            }
            ctx.endPDFPage()
            if n % 6 == 5 { ImageStore.shared.clearPrintCache() }
        }
        ctx.closePDF()
        progress(1, "Fertig")
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
        let xs = [trim.minX, trim.maxX]
        let ys = [trim.minY, trim.maxY]
        for x in xs {
            for y in ys {
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

struct ExportError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
