import Foundation

/// Schreibt ein unkomprimiertes ZIP-Archiv (Methode „store").
/// Ein .pkpass ist ein gewöhnliches ZIP; Kompression ist optional und
/// die Pass-Dateien sind klein — so braucht es keine externe Bibliothek.
enum ZipWriter {

    static func archive(entries: [(name: String, data: Data)], date: Date = Date()) -> Data {
        var out = Data()
        var centralDirectory = Data()
        let (dosTime, dosDate) = dosDateTime(date)

        for entry in entries {
            let nameBytes = Data(entry.name.utf8)
            let crc = crc32(entry.data)
            let offset = UInt32(out.count)

            // Local File Header
            out.appendLE(UInt32(0x04034b50))
            out.appendLE(UInt16(20))            // version needed
            out.appendLE(UInt16(0x0800))        // flags: UTF-8-Namen
            out.appendLE(UInt16(0))             // method: store
            out.appendLE(dosTime)
            out.appendLE(dosDate)
            out.appendLE(crc)
            out.appendLE(UInt32(entry.data.count))
            out.appendLE(UInt32(entry.data.count))
            out.appendLE(UInt16(nameBytes.count))
            out.appendLE(UInt16(0))             // extra length
            out.append(nameBytes)
            out.append(entry.data)

            // Central Directory Header
            centralDirectory.appendLE(UInt32(0x02014b50))
            centralDirectory.appendLE(UInt16(20))   // version made by
            centralDirectory.appendLE(UInt16(20))   // version needed
            centralDirectory.appendLE(UInt16(0x0800))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(dosTime)
            centralDirectory.appendLE(dosDate)
            centralDirectory.appendLE(crc)
            centralDirectory.appendLE(UInt32(entry.data.count))
            centralDirectory.appendLE(UInt32(entry.data.count))
            centralDirectory.appendLE(UInt16(nameBytes.count))
            centralDirectory.appendLE(UInt16(0))    // extra
            centralDirectory.appendLE(UInt16(0))    // comment
            centralDirectory.appendLE(UInt16(0))    // disk number
            centralDirectory.appendLE(UInt16(0))    // internal attrs
            centralDirectory.appendLE(UInt32(0))    // external attrs
            centralDirectory.appendLE(offset)
            centralDirectory.append(nameBytes)
        }

        let cdOffset = UInt32(out.count)
        out.append(centralDirectory)

        // End of Central Directory
        out.appendLE(UInt32(0x06054b50))
        out.appendLE(UInt16(0))
        out.appendLE(UInt16(0))
        out.appendLE(UInt16(entries.count))
        out.appendLE(UInt16(entries.count))
        out.appendLE(UInt32(centralDirectory.count))
        out.appendLE(cdOffset)
        out.appendLE(UInt16(0))

        return out
    }

    private static func dosDateTime(_ date: Date) -> (UInt16, UInt16) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max(1980, c.year ?? 1980)
        let time = UInt16((c.hour ?? 0) << 11 | (c.minute ?? 0) << 5 | (c.second ?? 0) / 2)
        let day = UInt16((year - 1980) << 9 | (c.month ?? 1) << 5 | (c.day ?? 1))
        return (time, day)
    }

    private static let crcTable: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
        }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8(value >> 8))
    }

    mutating func appendLE(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8(value >> 24))
    }
}
