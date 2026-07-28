import Foundation
import CryptoKit
import Security

/// Erzeugt die abgetrennte PKCS#7/CMS-Signatur (`signature`-Datei) über
/// manifest.json — das Format, das Apple Wallet verlangt. iOS bietet dafür
/// keine öffentliche API, deshalb wird die SignedData-Struktur hier direkt
/// in DER aufgebaut; nur die eigentliche RSA-Signatur macht Security.
enum CMSSigner {

    enum SignError: LocalizedError {
        case noCertificate
        case noPrivateKey
        case unsupportedKeyType
        case signingFailed(String)

        var errorDescription: String? {
            switch self {
            case .noCertificate:
                return "Aus der Identität ließ sich kein Zertifikat lesen."
            case .noPrivateKey:
                return "Aus der Identität ließ sich kein privater Schlüssel lesen."
            case .unsupportedKeyType:
                return "Das Zertifikat nutzt keinen RSA-Schlüssel. Bitte ein normales Pass-Type-ID-Zertifikat (RSA) verwenden."
            case .signingFailed(let reason):
                return "Signieren fehlgeschlagen: \(reason)"
            }
        }
    }

    private enum OID {
        static let signedData = "1.2.840.113549.1.7.2"
        static let data = "1.2.840.113549.1.7.1"
        static let sha256 = "2.16.840.1.101.3.4.2.1"
        static let rsaEncryption = "1.2.840.113549.1.1.1"
        static let contentType = "1.2.840.113549.1.9.3"
        static let messageDigest = "1.2.840.113549.1.9.4"
        static let signingTime = "1.2.840.113549.1.9.5"
    }

    /// Signiert `manifest` abgetrennt mit der Identität; `extraCertificates`
    /// (DER) — typischerweise das Apple-WWDR-Zwischenzertifikat — werden in
    /// die Signatur eingebettet, damit Wallet die Kette prüfen kann.
    static func sign(manifest: Data, identity: SecIdentity, extraCertificates: [Data], date: Date = Date()) throws -> Data {
        var certRef: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certRef) == errSecSuccess,
              let certificate = certRef else {
            throw SignError.noCertificate
        }
        var keyRef: SecKey?
        guard SecIdentityCopyPrivateKey(identity, &keyRef) == errSecSuccess,
              let privateKey = keyRef else {
            throw SignError.noPrivateKey
        }

        let leafDER = SecCertificateCopyData(certificate) as Data
        let certInfo = try CertificateInfo.parse(der: leafDER)

        let sha256AlgId = ASN1.sequence([ASN1.objectIdentifier(OID.sha256), ASN1.null])
        let manifestDigest = Data(SHA256.hash(data: manifest))

        // Signierte Attribute (contentType, signingTime, messageDigest)
        let attributes: [Data] = [
            ASN1.sequence([
                ASN1.objectIdentifier(OID.contentType),
                ASN1.setOf([ASN1.objectIdentifier(OID.data)]),
            ]),
            ASN1.sequence([
                ASN1.objectIdentifier(OID.signingTime),
                ASN1.setOf([ASN1.utcTime(date)]),
            ]),
            ASN1.sequence([
                ASN1.objectIdentifier(OID.messageDigest),
                ASN1.setOf([ASN1.octetString(manifestDigest)]),
            ]),
        ]
        // Signiert wird über die Attribute mit explizitem SET-Tag …
        let signedAttrsSet = ASN1.setOf(attributes)
        // … eingebettet werden sie als [0] IMPLICIT (gleicher Inhalt).
        var signedAttrsTagged = signedAttrsSet
        signedAttrsTagged[signedAttrsTagged.startIndex] = 0xA0

        let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
        guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
            throw SignError.unsupportedKeyType
        }
        var signError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey, algorithm, signedAttrsSet as CFData, &signError) as Data? else {
            let reason = (signError?.takeRetainedValue() as Error?)?.localizedDescription ?? "unbekannt"
            throw SignError.signingFailed(reason)
        }

        let signerInfo = ASN1.sequence([
            ASN1.integer(1),
            ASN1.sequence([certInfo.issuerDER, certInfo.serialDER]),
            sha256AlgId,
            signedAttrsTagged,
            ASN1.sequence([ASN1.objectIdentifier(OID.rsaEncryption), ASN1.null]),
            ASN1.octetString(signature),
        ])

        // Zertifikate: Leaf plus Kette (dedupliziert), als [0] IMPLICIT.
        var certDatas: [Data] = [leafDER]
        for extra in extraCertificates where !certDatas.contains(extra) {
            certDatas.append(extra)
        }
        let certificates = ASN1.contextTag(0, certDatas.reduce(Data(), +))

        let signedData = ASN1.sequence([
            ASN1.integer(1),
            ASN1.setOf([sha256AlgId]),
            ASN1.sequence([ASN1.objectIdentifier(OID.data)]),   // detached: kein eContent
            certificates,
            ASN1.tlv(0x31, signerInfo),                          // SET OF SignerInfo
        ])

        return ASN1.sequence([
            ASN1.objectIdentifier(OID.signedData),
            ASN1.contextTag(0, signedData),
        ])
    }
}
