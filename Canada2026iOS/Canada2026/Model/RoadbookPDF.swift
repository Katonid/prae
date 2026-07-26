import UIKit

// STAN Roadbook – erzeugt das Reisebuch als PDF (Deckblatt, Route, Journal,
// Fotoalbum, Statistik), Gegenstück zum PDF-Export der PWA.

@MainActor
final class RoadbookPDF {
    private let store: AppStore
    private let pageSize = CGSize(width: 595, height: 842) // A4 in Punkten
    private let margin: CGFloat = 48
    private var cursorY: CGFloat = 0
    private var context: UIGraphicsPDFRendererContext?

    private var contentWidth: CGFloat { pageSize.width - 2 * margin }

    init(store: AppStore) {
        self.store = store
    }

    struct Options {
        var includeJournal = true
        var includePhotos = true
        var includeStats = true
        var includeAwards = true
    }

    func generate(options: Options) -> URL? {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Canada 2026 – STAN Roadbook",
            kCGPDFContextCreator as String: "Canada 2026 App"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("STAN-Roadbook.pdf")

        do {
            try renderer.writePDF(to: url) { context in
                self.context = context
                drawCover()
                drawRoute()
                if options.includeJournal { drawJournal() }
                if options.includePhotos { drawPhotos() }
                if options.includeAwards { drawAwards() }
                if options.includeStats { drawStats() }
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Zeichen-Hilfen

    private func newPage() {
        context?.beginPage()
        cursorY = margin
    }

    private func ensureSpace(_ height: CGFloat) {
        if cursorY + height > pageSize.height - margin {
            newPage()
        }
    }

    @discardableResult
    private func drawText(
        _ text: String,
        font: UIFont,
        color: UIColor = .black,
        spacingAfter: CGFloat = 6,
        indent: CGFloat = 0
    ) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let width = contentWidth - indent
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let bounds = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        ensureSpace(bounds.height + spacingAfter)
        attributed.draw(in: CGRect(x: margin + indent, y: cursorY, width: width, height: ceil(bounds.height)))
        cursorY += ceil(bounds.height) + spacingAfter
        return bounds.height
    }

    private func drawDivider(spacing: CGFloat = 10) {
        ensureSpace(spacing + 1)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: cursorY))
        path.addLine(to: CGPoint(x: pageSize.width - margin, y: cursorY))
        UIColor(red: 0.78, green: 0.15, blue: 0.22, alpha: 0.4).setStroke()
        path.lineWidth = 1
        path.stroke()
        cursorY += spacing
    }

    private func sectionTitle(_ title: String) {
        ensureSpace(60)
        cursorY += 8
        drawText(title, font: .boldSystemFont(ofSize: 20), color: UIColor(red: 0.78, green: 0.15, blue: 0.22, alpha: 1), spacingAfter: 4)
        drawDivider()
    }

    // MARK: - Abschnitte

    private func drawCover() {
        newPage()
        cursorY = 200
        drawText("🍁", font: .systemFont(ofSize: 64), spacingAfter: 20)
        drawText("STAN on Tour", font: .boldSystemFont(ofSize: 16), color: UIColor(red: 0.78, green: 0.15, blue: 0.22, alpha: 1), spacingAfter: 4)
        drawText("Canada 2026", font: .boldSystemFont(ofSize: 40), spacingAfter: 10)
        drawText("Das Roadbook der Reise", font: .systemFont(ofSize: 16), color: .darkGray, spacingAfter: 30)
        drawText("4. – 22. August 2026", font: .systemFont(ofSize: 14), color: .darkGray, spacingAfter: 6)
        drawText(TravelData.crewNames.joined(separator: " · "), font: .systemFont(ofSize: 14), color: .darkGray, spacingAfter: 6)
        let stationNames = TravelData.stations.map { $0.name }.joined(separator: " – ")
        drawText(stationNames, font: .systemFont(ofSize: 11), color: .gray, spacingAfter: 0)
    }

    private func drawRoute() {
        newPage()
        sectionTitle("Die Route")
        for (index, station) in TravelData.stations.enumerated() {
            ensureSpace(70)
            drawText("\(index + 1). \(station.name)", font: .boldSystemFont(ofSize: 14), spacingAfter: 2)
            drawText("ab \(HomeView.dayLabel(station.date)) · \(station.region)", font: .systemFont(ofSize: 11), color: .gray, spacingAfter: 2, indent: 14)
            drawText(station.notes, font: .systemFont(ofSize: 11), color: .darkGray, spacingAfter: 10, indent: 14)
        }
    }

    private func drawJournal() {
        let entries = store.journalEntries()
        guard !entries.isEmpty else { return }
        newPage()
        sectionTitle("Reisejournal")
        let grouped = Dictionary(grouping: entries, by: { $0.day })
        for day in grouped.keys.sorted() {
            drawText(HomeView.dayLabel(day), font: .boldSystemFont(ofSize: 14), spacingAfter: 4)
            for entry in (grouped[day] ?? []).sorted(by: { $0.createdAt < $1.createdAt }) {
                let mood = entry.mood > 0 ? " \(String(repeating: "★", count: entry.mood))" : ""
                drawText("\(entry.author)\(mood)\(entry.title.isEmpty ? "" : " – \(entry.title)")", font: .boldSystemFont(ofSize: 11), color: .darkGray, spacingAfter: 2, indent: 10)
                drawText(entry.text, font: .systemFont(ofSize: 11), spacingAfter: 8, indent: 10)
            }
            cursorY += 4
        }
    }

    private func drawPhotos() {
        let photos = store.visiblePhotos.reversed().filter {
            FileManager.default.fileExists(atPath: store.photoFileURL($0).path)
        }
        guard !photos.isEmpty else { return }
        newPage()
        sectionTitle("Fotoalbum")

        let cellWidth = (contentWidth - 12) / 2
        let cellHeight: CGFloat = cellWidth * 0.75
        var column = 0

        for photo in photos {
            guard let image = UIImage(contentsOfFile: store.photoFileURL(photo).path) else { continue }
            if column == 0 { ensureSpace(cellHeight + 34) }
            let x = margin + CGFloat(column) * (cellWidth + 12)
            let rect = CGRect(x: x, y: cursorY, width: cellWidth, height: cellHeight)
            drawImageAspectFill(image, in: rect)

            let caption = [photo.author, photo.caption, HomeView.dayLabel(photo.day)]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            let captionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.gray
            ]
            NSAttributedString(string: caption, attributes: captionAttributes)
                .draw(in: CGRect(x: x, y: cursorY + cellHeight + 3, width: cellWidth, height: 24))

            if column == 1 {
                cursorY += cellHeight + 34
                column = 0
            } else {
                column = 1
            }
        }
        if column == 1 { cursorY += cellHeight + 34 }
    }

    private func drawImageAspectFill(_ image: UIImage, in rect: CGRect) {
        guard let cgContext = UIGraphicsGetCurrentContext() else { return }
        cgContext.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: 6).addClip()
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2
        )
        image.draw(in: CGRect(origin: origin, size: drawSize))
        cgContext.restoreGState()
    }

    private func drawAwards() {
        let allVotes = store.data.awardVotes ?? []
        let days = Set(allVotes.filter { !$0.votedFor.isEmpty }.map { $0.day }).sorted()
        guard !days.isEmpty else { return }
        newPage()
        sectionTitle("Canada Awards")
        for day in days {
            drawText(HomeView.dayLabel(day), font: .boldSystemFont(ofSize: 13), spacingAfter: 3)
            for category in TravelData.awardTemplates {
                let winners = store.awardWinners(day: day, category: category)
                guard !winners.isEmpty else { continue }
                drawText("🏆 \(category): \(winners.joined(separator: " & "))", font: .systemFont(ofSize: 11), spacingAfter: 2, indent: 10)
            }
            cursorY += 6
        }
    }

    private func drawStats() {
        newPage()
        sectionTitle("Roadtrip in Zahlen")

        drawText("Roadtrip Score", font: .boldSystemFont(ofSize: 14), spacingAfter: 4)
        for entry in store.leaderboard {
            let achievements = store.earnedAchievements(member: entry.member)
            drawText("\(entry.member): \(entry.score) Punkte\(achievements.isEmpty ? "" : " · " + achievements.map { $0.title }.joined(separator: ", "))", font: .systemFont(ofSize: 11), spacingAfter: 3, indent: 10)
        }
        cursorY += 8

        let expenses = store.visibleExpenses
        if !expenses.isEmpty {
            let total = expenses.reduce(0) { $0 + $1.amountCad }
            drawText("Kosten", font: .boldSystemFont(ofSize: 14), spacingAfter: 4)
            drawText(String(format: "Gesamt: %.2f CAD (≈ %.2f €)", total, total * TravelData.exchangeRateCadToEur), font: .systemFont(ofSize: 11), spacingAfter: 3, indent: 10)
            for category in TravelData.expenseCategories {
                let sum = expenses.filter { $0.category == category }.reduce(0) { $0 + $1.amountCad }
                if sum > 0 {
                    drawText(String(format: "%@: %.2f CAD", category, sum), font: .systemFont(ofSize: 11), color: .darkGray, spacingAfter: 2, indent: 10)
                }
            }
            cursorY += 8
        }

        let doneBucket = store.visibleBucketList.filter { $0.done }
        if !doneBucket.isEmpty {
            drawText("Erlebte Bucket-List-Wünsche", font: .boldSystemFont(ofSize: 14), spacingAfter: 4)
            for item in doneBucket {
                drawText("✓ \(item.text)\(item.doneBy.isEmpty ? "" : " (\(item.doneBy))")", font: .systemFont(ofSize: 11), spacingAfter: 2, indent: 10)
            }
            cursorY += 8
        }

        let messageCount = store.data.messages.filter { !$0.deleted }.count
        let photoCount = store.visiblePhotos.count
        let journalCount = store.journalEntries().count
        drawText("Gesammelt unterwegs", font: .boldSystemFont(ofSize: 14), spacingAfter: 4)
        drawText("\(photoCount) Fotos · \(journalCount) Journal-Einträge · \(messageCount) Nachrichten", font: .systemFont(ofSize: 11), spacingAfter: 2, indent: 10)
    }
}
