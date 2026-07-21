import Foundation
import UIKit

// Exporte des Verlaufs wie in der PWA: CSV (Semikolon, deutsche Zahlen,
// BOM), echtes Excel-XLSX (ZIP + SpreadsheetML, ohne Fremdbibliotheken)
// und ein PDF-Report (A4 quer) mit Kennzahlen, Jahreswerten und allen
// Tankvorgängen.

struct ExportRow {
    let number: Int
    let entry: FuelEntry
    let vehicleName: String
    let vehiclePlate: String
    let fuel: String
    let distance: Double?
    let consumption: Double?
    let costPer100: Double?
    let intervalConsumption: Double?
    let flags: [String]
}

struct ExportAnnual {
    let year: Int
    let count: Int
    let distance: Double
    let liters: Double
    let cost: Double
    let adBlueLiters: Double
    let consumptionDistance: Double
    let consumptionLiters: Double

    var consumption: Double? {
        consumptionDistance > 0 ? consumptionLiters / consumptionDistance * 100 : nil
    }
}

struct ExportReport {
    let title = "Tankbuch Export"
    let subtitle: String
    let rangeLabel: String
    let generatedAt: Date
    let rows: [ExportRow]
    let annual: [ExportAnnual]
    let metrics: [(label: String, value: String)]

    static func build(vehicles: [Vehicle], entries: [FuelEntry]) -> ExportReport {
        let computed = TripMath.computedByEntryId(vehicles: vehicles, entries: entries)
        let vehiclesById = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.externalId, $0) })

        let rows: [ExportRow] = entries
            .sorted { $0.date > $1.date }
            .enumerated()
            .map { index, entry in
                let item = computed[entry.externalId]
                let vehicle = vehiclesById[entry.vehicleId]
                var flags: [String] = [entry.fullTank ? "Vollgetankt" : "Teiltankung"]
                if entry.adBlue {
                    flags.append(entry.adBlueLiters.map { "AdBlue \(Format.number($0, digits: 2)) l" } ?? "AdBlue")
                }
                if entry.trailer { flags.append("Anhänger") }
                flags.append(TireSeason.from(entry.tireSeason).label)

                return ExportRow(
                    number: item?.number ?? index + 1,
                    entry: entry,
                    vehicleName: vehicle?.name ?? entry.vehicleName,
                    vehiclePlate: vehicle?.plate ?? "",
                    fuel: FuelType.label(for: entry.fuelType),
                    distance: item?.trip.distance,
                    consumption: item?.trip.consumption,
                    costPer100: item?.trip.costPer100,
                    intervalConsumption: item?.intervalConsumption,
                    flags: flags
                )
            }

        var annualByYear: [Int: ExportAnnual] = [:]
        for row in rows {
            let year = Calendar.current.component(.year, from: row.entry.date)
            let old = annualByYear[year]
            let distance = row.distance ?? 0
            let liters = row.entry.liters ?? 0
            let countsForConsumption = row.entry.fullTank && distance > 0 && liters > 0
            annualByYear[year] = ExportAnnual(
                year: year,
                count: (old?.count ?? 0) + 1,
                distance: (old?.distance ?? 0) + distance,
                liters: (old?.liters ?? 0) + liters,
                cost: (old?.cost ?? 0) + (row.entry.totalPrice ?? 0),
                adBlueLiters: (old?.adBlueLiters ?? 0) + (row.entry.adBlueLiters ?? 0),
                consumptionDistance: (old?.consumptionDistance ?? 0) + (countsForConsumption ? distance : 0),
                consumptionLiters: (old?.consumptionLiters ?? 0) + (countsForConsumption ? liters : 0)
            )
        }
        let annual = annualByYear.values.sorted { $0.year > $1.year }

        let totalCost = rows.reduce(0.0) { $0 + ($1.entry.totalPrice ?? 0) }
        let totalLiters = rows.reduce(0.0) { $0 + ($1.entry.liters ?? 0) }
        let adBlueLiters = rows.reduce(0.0) { $0 + ($1.entry.adBlueLiters ?? 0) }
        let consumptionBase = rows.filter { $0.entry.fullTank && ($0.distance ?? 0) > 0 && ($0.entry.liters ?? 0) > 0 }
        let consumptionDistance = consumptionBase.reduce(0.0) { $0 + ($1.distance ?? 0) }
        let consumptionLiters = consumptionBase.reduce(0.0) { $0 + ($1.entry.liters ?? 0) }

        let dates = rows.map(\.entry.date).sorted()
        let rangeLabel = dates.isEmpty
            ? "Keine Tankvorgänge"
            : "\(Format.date(dates.first)) bis \(Format.date(dates.last))"

        let subtitle: String
        if vehicles.count == 1, let single = vehicles.first {
            subtitle = single.displayName
        } else {
            subtitle = "Alle Fahrzeuge"
        }

        return ExportReport(
            subtitle: subtitle,
            rangeLabel: rangeLabel,
            generatedAt: Date(),
            rows: rows,
            annual: annual,
            metrics: [
                ("Einträge", String(rows.count)),
                ("Gesamtkosten", Format.currency(totalCost)),
                ("Gesamtliter", "\(Format.number(totalLiters, digits: 2)) l"),
                ("Ø Verbrauch", consumptionDistance > 0 ? "\(Format.number(consumptionLiters / consumptionDistance * 100, digits: 1)) l/100 km" : "-"),
                ("Ø Literpreis", totalLiters > 0 ? Format.currency(totalCost / totalLiters) : "-"),
                ("AdBlue", "\(Format.number(adBlueLiters, digits: 2)) l")
            ]
        )
    }
}

enum Exports {

    static var dateStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: CSV (wie exportCsv der PWA)

    static func csv(report: ExportReport) -> Data {
        let headers = [
            "Datum", "Fahrzeug", "Kennzeichen", "Tankstelle", "Ort", "Kraftstoff",
            "Vollgetankt", "AdBlue", "Anhaenger", "Bereifung",
            "AdBlue_Liter", "AdBlue_Euro_l", "AdBlue_Endpreis",
            "Literpreis", "Liter", "Endpreis", "Kilometerstand", "Distanz",
            "Verbrauch_seit_letztem_l_100km", "Verbrauch_l_100km", "Kosten_100km", "Notiz"
        ]

        func num(_ value: Double?, _ digits: Int) -> String {
            Format.inputNumber(value, digits: digits)
        }

        let rows: [[String]] = report.rows.map { row in
            [
                Format.date(row.entry.date),
                row.vehicleName,
                row.vehiclePlate,
                row.entry.stationName,
                row.entry.stationPlace,
                row.fuel,
                row.entry.fullTank ? "ja" : "nein",
                row.entry.adBlue ? "ja" : "nein",
                row.entry.trailer ? "ja" : "nein",
                TireSeason.from(row.entry.tireSeason).label,
                num(row.entry.adBlueLiters, 2),
                num(row.entry.adBluePricePerLiter, 3),
                num(row.entry.adBlueTotalPrice, 2),
                num(row.entry.pricePerLiter, 3),
                num(row.entry.liters, 2),
                num(row.entry.totalPrice, 2),
                num(row.entry.odometer, 0),
                num(row.distance, 0),
                num(row.intervalConsumption, 1),
                num(row.consumption, 1),
                num(row.costPer100, 2),
                row.entry.notes
            ]
        }

        func escape(_ value: String) -> String {
            "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }

        let csv = ([headers] + rows)
            .map { $0.map(escape).joined(separator: ";") }
            .joined(separator: "\r\n")
        return Data("\u{FEFF}\(csv)".utf8)
    }

    // MARK: Excel (echtes XLSX, wie buildExcelReportXlsx der PWA)

    private enum Cell {
        case text(String, style: Int)
        case number(Double, style: Int)
        case empty
    }

    static func xlsx(report: ExportReport) -> Data {
        var overview: [[Cell]] = [
            [.text(report.title, style: 1)],
            [.text("Fahrzeug", style: 3), .text(report.subtitle, style: 0)],
            [.text("Zeitraum", style: 3), .text(report.rangeLabel, style: 0)],
            [.text("Erstellt", style: 3), .text(Format.date(report.generatedAt), style: 0)],
            []
        ]
        overview.append(contentsOf: report.metrics.map { [.text($0.label, style: 3), .text($0.value, style: 0)] })

        var annual: [[Cell]] = [
            ["Jahr", "Einträge", "Kilometer", "Liter", "Kosten", "Verbrauch l/100 km"].map { .text($0, style: 2) }
        ]
        annual.append(contentsOf: report.annual.map { row in
            [
                .number(Double(row.year), style: 0),
                .number(Double(row.count), style: 0),
                .number(row.distance, style: 0),
                .number(row.liters, style: 0),
                .number(row.cost, style: 0),
                row.consumption.map { Cell.number($0, style: 0) } ?? Cell.empty
            ]
        })

        var entriesSheet: [[Cell]] = [
            ["Nr.", "Datum", "Fahrzeug", "Kennzeichen", "Tankstelle", "Ort", "Kraftstoff", "Tankart",
             "Liter", "Literpreis", "Endpreis", "Kilometerstand", "Distanz", "Seit letztem l/100 km",
             "Verbrauch l/100 km", "AdBlue Liter", "Anhänger", "Bereifung", "Notiz"].map { .text($0, style: 2) }
        ]
        entriesSheet.append(contentsOf: report.rows.map { row in
            [
                .number(Double(row.number), style: 0),
                .text(Format.date(row.entry.date), style: 0),
                .text(row.vehicleName, style: 0),
                .text(row.vehiclePlate, style: 0),
                .text(row.entry.stationName, style: 0),
                .text(row.entry.stationPlace, style: 0),
                .text(row.fuel, style: 0),
                .text(row.entry.fullTank ? "Vollgetankt" : "Teiltankung", style: 0),
                row.entry.liters.map { Cell.number($0, style: 0) } ?? Cell.empty,
                row.entry.pricePerLiter.map { Cell.number($0, style: 0) } ?? Cell.empty,
                row.entry.totalPrice.map { Cell.number($0, style: 0) } ?? Cell.empty,
                row.entry.odometer.map { Cell.number($0, style: 0) } ?? Cell.empty,
                row.distance.map { Cell.number($0, style: 0) } ?? Cell.empty,
                row.intervalConsumption.map { Cell.number($0, style: 0) } ?? Cell.empty,
                row.consumption.map { Cell.number($0, style: 0) } ?? Cell.empty,
                row.entry.adBlueLiters.map { Cell.number($0, style: 0) } ?? Cell.empty,
                .text(row.entry.trailer ? "ja" : "nein", style: 0),
                .text(TireSeason.from(row.entry.tireSeason).label, style: 0),
                .text(row.entry.notes, style: 0)
            ]
        })

        let entries: [(name: String, data: Data)] = [
            ("[Content_Types].xml", Data(contentTypesXml.utf8)),
            ("_rels/.rels", Data(rootRelsXml.utf8)),
            ("xl/workbook.xml", Data(workbookXml.utf8)),
            ("xl/_rels/workbook.xml.rels", Data(workbookRelsXml.utf8)),
            ("xl/styles.xml", Data(stylesXml.utf8)),
            ("xl/worksheets/sheet1.xml", Data(sheetXml(overview).utf8)),
            ("xl/worksheets/sheet2.xml", Data(sheetXml(annual).utf8)),
            ("xl/worksheets/sheet3.xml", Data(sheetXml(entriesSheet).utf8))
        ]
        return zipStored(entries)
    }

    private static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func columnName(_ index: Int) -> String {
        var name = ""
        var value = index
        repeat {
            name = String(UnicodeScalar(UInt8(65 + value % 26))) + name
            value = value / 26 - 1
        } while value >= 0
        return name
    }

    private static func sheetXml(_ rows: [[Cell]]) -> String {
        var body = ""
        for (rowIndex, row) in rows.enumerated() {
            body += "<row r=\"\(rowIndex + 1)\">"
            for (colIndex, cell) in row.enumerated() {
                let ref = "\(columnName(colIndex))\(rowIndex + 1)"
                switch cell {
                case .text(let value, let style):
                    body += "<c r=\"\(ref)\" s=\"\(style)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xmlEscape(value))</t></is></c>"
                case .number(let value, let style):
                    body += "<c r=\"\(ref)\" s=\"\(style)\"><v>\(value)</v></c>"
                case .empty:
                    break
                }
            }
            body += "</row>"
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>\(body)</sheetData></worksheet>
        """
    }

    private static let contentTypesXml = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>
    """

    private static let rootRelsXml = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
    """

    private static let workbookXml = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Übersicht" sheetId="1" r:id="rId1"/><sheet name="Jahreswerte" sheetId="2" r:id="rId2"/><sheet name="Tankvorgänge" sheetId="3" r:id="rId3"/></sheets></workbook>
    """

    private static let workbookRelsXml = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/><Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>
    """

    /// Stile: 0 normal, 1 Titel (fett, groß), 2 Tabellenkopf (fett, weiß auf
    /// Blau), 3 Beschriftung (fett).
    private static let stylesXml = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="4"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="16"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF0B4DB3"/><bgColor rgb="FF0B4DB3"/></patternFill></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="4"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="2" fillId="2" borderId="0" xfId="0" applyFill="1"/><xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0"/></cellXfs></styleSheet>
    """

    // MARK: ZIP (Stored, ohne Kompression)

    private static let crcTable: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) != 0 ? 0xEDB88320 ^ (value >> 1) : value >> 1
        }
        return value
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }

    private static func zipStored(_ entries: [(name: String, data: Data)]) -> Data {
        var output = Data()
        var central = Data()

        func append16(_ value: UInt16, to data: inout Data) {
            data.append(UInt8(value & 0xFF))
            data.append(UInt8(value >> 8))
        }
        func append32(_ value: UInt32, to data: inout Data) {
            data.append(UInt8(value & 0xFF))
            data.append(UInt8((value >> 8) & 0xFF))
            data.append(UInt8((value >> 16) & 0xFF))
            data.append(UInt8(value >> 24))
        }

        for entry in entries {
            let nameBytes = Data(entry.name.utf8)
            let crc = crc32(entry.data)
            let size = UInt32(entry.data.count)
            let offset = UInt32(output.count)

            // Lokaler Header
            append32(0x04034B50, to: &output)
            append16(20, to: &output)          // Version
            append16(0x0800, to: &output)      // UTF-8-Namen
            append16(0, to: &output)           // Methode: Stored
            append16(0, to: &output)           // Zeit
            append16(0x21, to: &output)        // Datum (1.1.1980)
            append32(crc, to: &output)
            append32(size, to: &output)
            append32(size, to: &output)
            append16(UInt16(nameBytes.count), to: &output)
            append16(0, to: &output)
            output.append(nameBytes)
            output.append(entry.data)

            // Zentralverzeichnis
            append32(0x02014B50, to: &central)
            append16(20, to: &central)
            append16(20, to: &central)
            append16(0x0800, to: &central)
            append16(0, to: &central)
            append16(0, to: &central)
            append16(0x21, to: &central)
            append32(crc, to: &central)
            append32(size, to: &central)
            append32(size, to: &central)
            append16(UInt16(nameBytes.count), to: &central)
            append16(0, to: &central)
            append16(0, to: &central)
            append16(0, to: &central)
            append16(0, to: &central)
            append32(0, to: &central)
            append32(offset, to: &central)
            central.append(nameBytes)
        }

        let centralOffset = UInt32(output.count)
        output.append(central)

        // Ende des Zentralverzeichnisses
        append32(0x06054B50, to: &output)
        append16(0, to: &output)
        append16(0, to: &output)
        append16(UInt16(entries.count), to: &output)
        append16(UInt16(entries.count), to: &output)
        append32(UInt32(central.count), to: &output)
        append32(centralOffset, to: &output)
        append16(0, to: &output)

        return output
    }

    // MARK: PDF-Report (A4 quer, mehrseitig)

    static func pdf(report: ExportReport) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 842, height: 595)
        let margin: CGFloat = 34
        let contentWidth = pageRect.width - margin * 2
        let brandBlue = UIColor(red: 0.043, green: 0.302, blue: 0.702, alpha: 1)
        let lightBlue = UIColor(red: 0.894, green: 0.937, blue: 1.0, alpha: 1)
        let textColor = UIColor(red: 0.063, green: 0.125, blue: 0.2, alpha: 1)
        let subColor = UIColor(red: 0.4, green: 0.45, blue: 0.53, alpha: 1)

        func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = alignment
            paragraph.lineBreakMode = .byTruncatingTail
            (text as NSString).draw(
                in: rect,
                withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
            )
        }

        // Spalten der Eintragstabelle: (Titel, Breite, rechtsbündig)
        let columns: [(String, CGFloat, Bool)] = [
            ("Nr.", 28, true),
            ("Datum", 82, false),
            ("Fahrzeug", 92, false),
            ("Tankstelle", 138, false),
            ("Kraftstoff", 64, false),
            ("Liter", 46, true),
            ("Preis", 72, true),
            ("Strecke", 70, true),
            ("Seit letztem", 56, true),
            ("Verbrauch", 56, true),
            ("Merkmale", contentWidth - 704, false)
        ]

        let headerFont = UIFont.systemFont(ofSize: 8, weight: .bold)
        let cellFont = UIFont.systemFont(ofSize: 8.5)
        let cellSubFont = UIFont.systemFont(ofSize: 7)
        let rowHeight: CGFloat = 24

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            var y: CGFloat = 0

            func drawTableHeader() {
                let headerRect = CGRect(x: margin, y: y, width: contentWidth, height: 16)
                brandBlue.setFill()
                UIBezierPath(roundedRect: headerRect, cornerRadius: 3).fill()
                var x = margin
                for column in columns {
                    draw(column.0, in: CGRect(x: x + 3, y: y + 3, width: column.1 - 6, height: 12),
                         font: headerFont, color: .white, alignment: column.2 ? .right : .left)
                    x += column.1
                }
                y += 18
            }

            func startPage(withReportHeader: Bool) {
                context.beginPage()
                y = margin

                if withReportHeader {
                    // Kopfbereich
                    let headRect = CGRect(x: margin, y: y, width: contentWidth, height: 64)
                    brandBlue.setFill()
                    UIBezierPath(roundedRect: headRect, cornerRadius: 10).fill()
                    draw(report.title, in: CGRect(x: margin + 16, y: y + 10, width: contentWidth - 260, height: 26),
                         font: .systemFont(ofSize: 20, weight: .heavy), color: .white)
                    draw(report.subtitle, in: CGRect(x: margin + 16, y: y + 38, width: contentWidth - 260, height: 16),
                         font: .systemFont(ofSize: 11, weight: .semibold), color: .white)
                    draw("Zeitraum: \(report.rangeLabel)", in: CGRect(x: margin + 16, y: y + 10, width: contentWidth - 32, height: 14),
                         font: .systemFont(ofSize: 9, weight: .semibold), color: .white, alignment: .right)
                    draw("Erstellt: \(Format.date(report.generatedAt))", in: CGRect(x: margin + 16, y: y + 26, width: contentWidth - 32, height: 14),
                         font: .systemFont(ofSize: 9, weight: .semibold), color: .white, alignment: .right)
                    y += 74

                    // Kennzahlen
                    let metricWidth = (contentWidth - CGFloat(report.metrics.count - 1) * 8) / CGFloat(report.metrics.count)
                    var x = margin
                    for metric in report.metrics {
                        let box = CGRect(x: x, y: y, width: metricWidth, height: 40)
                        lightBlue.setFill()
                        UIBezierPath(roundedRect: box, cornerRadius: 8).fill()
                        draw(metric.label.uppercased(), in: CGRect(x: x + 8, y: y + 6, width: metricWidth - 16, height: 10),
                             font: .systemFont(ofSize: 7, weight: .heavy), color: subColor)
                        draw(metric.value, in: CGRect(x: x + 8, y: y + 18, width: metricWidth - 16, height: 16),
                             font: .systemFont(ofSize: 11, weight: .bold), color: brandBlue)
                        x += metricWidth + 8
                    }
                    y += 50

                    // Jahreswerte
                    if !report.annual.isEmpty {
                        draw("Jahreswerte", in: CGRect(x: margin, y: y, width: 200, height: 14),
                             font: .systemFont(ofSize: 11, weight: .bold), color: brandBlue)
                        y += 16
                        let annualColumns: [(String, CGFloat, Bool)] = [
                            ("Jahr", 60, false), ("Einträge", 70, true), ("Kilometer", 90, true),
                            ("Liter", 90, true), ("Kosten", 100, true), ("Ø Verbrauch", 100, true)
                        ]
                        var ax = margin
                        for column in annualColumns {
                            draw(column.0, in: CGRect(x: ax + 3, y: y, width: column.1 - 6, height: 11),
                                 font: headerFont, color: subColor, alignment: column.2 ? .right : .left)
                            ax += column.1
                        }
                        y += 13
                        for row in report.annual.prefix(8) {
                            let values = [
                                String(row.year),
                                Format.number(Double(row.count), digits: 0),
                                "\(Format.number(row.distance, digits: 0)) km",
                                "\(Format.number(row.liters, digits: 2)) l",
                                Format.currency(row.cost),
                                row.consumption.map { "\(Format.number($0, digits: 1)) l/100 km" } ?? "-"
                            ]
                            ax = margin
                            for (index, column) in annualColumns.enumerated() {
                                draw(values[index], in: CGRect(x: ax + 3, y: y, width: column.1 - 6, height: 11),
                                     font: cellFont, color: textColor, alignment: column.2 ? .right : .left)
                                ax += column.1
                            }
                            y += 12
                        }
                        y += 10
                    }

                    draw("Tankvorgänge", in: CGRect(x: margin, y: y, width: 200, height: 14),
                         font: .systemFont(ofSize: 11, weight: .bold), color: brandBlue)
                    y += 16
                }

                drawTableHeader()
            }

            startPage(withReportHeader: true)

            for (rowIndex, row) in report.rows.enumerated() {
                if y + rowHeight > pageRect.height - margin {
                    startPage(withReportHeader: false)
                }

                if rowIndex % 2 == 1 {
                    UIColor(red: 0.961, green: 0.976, blue: 1.0, alpha: 1).setFill()
                    UIBezierPath(rect: CGRect(x: margin, y: y, width: contentWidth, height: rowHeight)).fill()
                }

                let mains = [
                    String(row.number),
                    Format.date(row.entry.date),
                    row.vehicleName,
                    row.entry.stationName,
                    row.fuel,
                    Format.number(row.entry.liters, digits: 2),
                    Format.currency(row.entry.totalPrice),
                    row.distance.map { "\(Format.number($0, digits: 0)) km" } ?? "-",
                    row.intervalConsumption.map { Format.number($0, digits: 1) } ?? "-",
                    row.consumption.map { Format.number($0, digits: 1) } ?? "-",
                    row.flags.joined(separator: " · ")
                ]
                let subs: [String?] = [
                    nil, nil,
                    row.vehiclePlate.isEmpty ? nil : row.vehiclePlate,
                    row.entry.stationPlace.isEmpty ? nil : row.entry.stationPlace,
                    nil, nil,
                    "\(Format.number(row.entry.pricePerLiter, digits: 3)) €/l",
                    "\(Format.number(row.entry.odometer, digits: 0)) km",
                    nil, nil, nil
                ]

                var x = margin
                for (index, column) in columns.enumerated() {
                    let alignment: NSTextAlignment = column.2 ? .right : .left
                    draw(mains[index], in: CGRect(x: x + 3, y: y + 2, width: column.1 - 6, height: 11),
                         font: cellFont, color: textColor, alignment: alignment)
                    if let sub = subs[index] {
                        draw(sub, in: CGRect(x: x + 3, y: y + 13, width: column.1 - 6, height: 9),
                             font: cellSubFont, color: subColor, alignment: alignment)
                    }
                    x += column.1
                }
                y += rowHeight
            }

            if report.rows.isEmpty {
                draw("Keine Tankvorgänge vorhanden.", in: CGRect(x: margin, y: y + 8, width: contentWidth, height: 16),
                     font: cellFont, color: subColor)
            }
        }
    }
}
