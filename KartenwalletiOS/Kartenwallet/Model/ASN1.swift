import Foundation

/// Minimaler DER-Encoder/-Parser — genau so viel ASN.1, wie für die
/// PKCS#7-Signatur eines Wallet-Passes und das Auslesen des
/// Pass-Zertifikats nötig ist. Bewusst ohne externe Bibliothek.
enum ASN1 {

    // MARK: - Encoder

    static func encodeLength(_ length: Int) -> Data {
        if length < 0x80 {
            return Data([UInt8(length)])
        }
        var bytes: [UInt8] = []
        var value = length
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        return Data([0x80 | UInt8(bytes.count)] + bytes)
    }

    static func tlv(_ tag: UInt8, _ content: Data) -> Data {
        var out = Data([tag])
        out.append(encodeLength(content.count))
        out.append(content)
        return out
    }

    static func sequence(_ parts: [Data]) -> Data {
        tlv(0x30, parts.reduce(Data(), +))
    }

    /// DER-SET-OF: Elemente müssen nach ihrer Kodierung aufsteigend
    /// sortiert sein.
    static func setOf(_ parts: [Data]) -> Data {
        let sorted = parts.sorted { lhs, rhs in
            for (a, b) in zip(lhs, rhs) where a != b { return a < b }
            return lhs.count < rhs.count
        }
        return tlv(0x31, sorted.reduce(Data(), +))
    }

    static func integer(_ value: Int) -> Data {
        var bytes: [UInt8] = []
        var v = value
        repeat {
            bytes.insert(UInt8(v & 0xFF), at: 0)
            v >>= 8
        } while v > 0
        if bytes.isEmpty { bytes = [0] }
        if bytes[0] & 0x80 != 0 { bytes.insert(0, at: 0) }
        return tlv(0x02, Data(bytes))
    }

    static func octetString(_ data: Data) -> Data { tlv(0x04, data) }

    static var null: Data { Data([0x05, 0x00]) }

    static func objectIdentifier(_ oid: String) -> Data {
        let arcs = oid.split(separator: ".").compactMap { UInt64($0) }
        precondition(arcs.count >= 2)
        var content = Data()
        content.append(contentsOf: base128(arcs[0] * 40 + arcs[1]))
        for arc in arcs.dropFirst(2) {
            content.append(contentsOf: base128(arc))
        }
        return tlv(0x06, content)
    }

    private static func base128(_ value: UInt64) -> [UInt8] {
        var groups: [UInt8] = [UInt8(value & 0x7F)]
        var v = value >> 7
        while v > 0 {
            groups.insert(UInt8(v & 0x7F) | 0x80, at: 0)
            v >>= 7
        }
        return groups
    }

    static func utcTime(_ date: Date) -> Data {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return tlv(0x17, Data(formatter.string(from: date).utf8))
    }

    /// Kontextspezifischer Tag, konstruiert ([n] IMPLICIT bei Strukturen).
    static func contextTag(_ number: UInt8, _ content: Data) -> Data {
        tlv(0xA0 | number, content)
    }

    // MARK: - Parser

    struct Element {
        let tag: UInt8
        let content: Data
        /// Komplettes TLV inklusive Tag und Länge — für Stellen, an denen
        /// die Original-Bytes weiterverwendet werden (Issuer, Serial).
        let raw: Data
    }

    struct Reader {
        private let data: Data
        private var offset: Int

        init(_ data: Data) {
            self.data = data
            self.offset = data.startIndex
        }

        var hasMore: Bool { offset < data.endIndex }

        mutating func next() throws -> Element {
            guard offset + 2 <= data.endIndex else { throw ASN1Error.truncated }
            let tag = data[offset]
            var cursor = offset + 1
            var length = Int(data[cursor])
            cursor += 1
            if length & 0x80 != 0 {
                let count = length & 0x7F
                guard count > 0, count <= 4, cursor + count <= data.endIndex else {
                    throw ASN1Error.truncated
                }
                length = 0
                for _ in 0..<count {
                    length = (length << 8) | Int(data[cursor])
                    cursor += 1
                }
            }
            guard cursor + length <= data.endIndex else { throw ASN1Error.truncated }
            let content = data.subdata(in: cursor..<(cursor + length))
            let raw = data.subdata(in: offset..<(cursor + length))
            offset = cursor + length
            return Element(tag: tag, content: content, raw: raw)
        }
    }

    enum ASN1Error: Error {
        case truncated
        case unexpectedStructure
    }
}

/// Die Angaben aus einem X.509-Zertifikat, die die App braucht.
struct CertificateInfo {
    /// Issuer-Name als Original-DER (für SignerInfo).
    let issuerDER: Data
    /// Seriennummer als Original-DER-INTEGER (für SignerInfo).
    let serialDER: Data
    /// Subject-Attribute: OID-String → Wert.
    let subjectAttributes: [String: String]

    /// Pass-Type-Identifier steht beim Pass-Zertifikat im UID-Attribut.
    var passTypeIdentifier: String? { subjectAttributes["0.9.2342.19200300.100.1.1"] }
    /// Team-ID steht in der Organizational Unit.
    var teamIdentifier: String? { subjectAttributes["2.5.4.11"] }
    var organizationName: String? { subjectAttributes["2.5.4.10"] }
    var commonName: String? { subjectAttributes["2.5.4.3"] }

    /// Zerlegt ein DER-kodiertes Zertifikat.
    /// TBSCertificate: [0] version?, serialNumber, signature, issuer,
    /// validity, subject, ...
    static func parse(der: Data) throws -> CertificateInfo {
        var certReader = ASN1.Reader(der)
        let certificate = try certReader.next()
        guard certificate.tag == 0x30 else { throw ASN1.ASN1Error.unexpectedStructure }

        var tbsOuter = ASN1.Reader(certificate.content)
        let tbs = try tbsOuter.next()
        guard tbs.tag == 0x30 else { throw ASN1.ASN1Error.unexpectedStructure }

        var fields = ASN1.Reader(tbs.content)
        var element = try fields.next()
        if element.tag == 0xA0 {   // optionale Versionsangabe überspringen
            element = try fields.next()
        }
        let serial = element                     // INTEGER serialNumber
        _ = try fields.next()                    // AlgorithmIdentifier
        let issuer = try fields.next()           // Name
        _ = try fields.next()                    // Validity
        let subject = try fields.next()          // Name

        return CertificateInfo(
            issuerDER: issuer.raw,
            serialDER: serial.raw,
            subjectAttributes: try parseName(subject)
        )
    }

    /// Attribute eines rohen DER-Namens (z. B. `issuerDER`) auslesen.
    static func attributes(ofRawName rawName: Data) throws -> [String: String] {
        var reader = ASN1.Reader(rawName)
        return try parseName(reader.next())
    }

    /// Name ::= RDNSequence; RDN ::= SET OF AttributeTypeAndValue.
    private static func parseName(_ name: ASN1.Element) throws -> [String: String] {
        var attributes: [String: String] = [:]
        var rdnReader = ASN1.Reader(name.content)
        while rdnReader.hasMore {
            let rdnSet = try rdnReader.next()
            var atvReader = ASN1.Reader(rdnSet.content)
            while atvReader.hasMore {
                let atv = try atvReader.next()
                var pair = ASN1.Reader(atv.content)
                let oid = try pair.next()
                guard pair.hasMore else { continue }
                let value = try pair.next()
                if let string = String(data: value.content, encoding: .utf8)
                    ?? String(data: value.content, encoding: .ascii) {
                    attributes[decodeOID(oid.content)] = string
                }
            }
        }
        return attributes
    }

    private static func decodeOID(_ content: Data) -> String {
        guard let first = content.first else { return "" }
        var arcs: [UInt64] = [UInt64(first / 40), UInt64(first % 40)]
        // Sonderfall Arcs >= 2.48 (z. B. UID 0.9.2342…) korrekt behandeln:
        if first >= 80 { arcs = [2, UInt64(first) - 80] }
        var value: UInt64 = 0
        for byte in content.dropFirst() {
            value = (value << 7) | UInt64(byte & 0x7F)
            if byte & 0x80 == 0 {
                arcs.append(value)
                value = 0
            }
        }
        return arcs.map(String.init).joined(separator: ".")
    }
}
