import Foundation
import Security

/// Verwaltet das Pass-Type-ID-Zertifikat des Nutzers: Import der .p12,
/// Ablage der Identität im Schlüsselbund, Auslesen von Pass-Type-ID und
/// Team-ID sowie Nachladen des Apple-WWDR-Zwischenzertifikats.
@MainActor
final class CertStore: ObservableObject {

    struct Meta: Equatable {
        var passTypeIdentifier: String
        var teamIdentifier: String
        var organizationName: String
        var commonName: String
    }

    @Published private(set) var meta: Meta?
    @Published private(set) var wwdrAvailable: Bool = false

    private let identityLabel = "de.familie.kartenwallet.passidentity"
    private let fm = FileManager.default

    enum CertError: LocalizedError {
        case importFailed(OSStatus)
        case wrongPassword
        case noIdentity
        case notAPassCertificate
        case keychainFailed(OSStatus)
        case wwdrMissing

        var errorDescription: String? {
            switch self {
            case .importFailed(let status):
                return "Die Datei konnte nicht gelesen werden (Fehler \(status)). Ist es eine .p12-Datei?"
            case .wrongPassword:
                return "Das Passwort für die .p12-Datei ist falsch."
            case .noIdentity:
                return "In der Datei steckt keine Identität (Zertifikat + privater Schlüssel). Bitte in der Schlüsselbundverwaltung Zertifikat UND Schlüssel gemeinsam als .p12 exportieren."
            case .notAPassCertificate:
                return "Das Zertifikat ist kein Pass-Type-ID-Zertifikat (Pass-Type-ID fehlt im Zertifikat)."
            case .keychainFailed(let status):
                return "Das Zertifikat konnte nicht im Schlüsselbund gespeichert werden (Fehler \(status))."
            case .wwdrMissing:
                return "Das Apple-Zwischenzertifikat (WWDR) fehlt noch. Bitte einmal mit Internetverbindung die Einstellungen öffnen — es wird automatisch geladen."
            }
        }
    }

    private var baseURL: URL {
        let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kartenwallet", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var leafURL: URL { baseURL.appendingPathComponent("pass-zertifikat.cer") }
    private var chainDirURL: URL {
        let url = baseURL.appendingPathComponent("Zertifikatskette", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private var wwdrURL: URL { baseURL.appendingPathComponent("apple-wwdr-g4.cer") }

    init() {
        reloadMeta()
        wwdrAvailable = fm.fileExists(atPath: wwdrURL.path)
    }

    var isReady: Bool { meta != nil && identity() != nil }

    // MARK: - Import

    func importP12(data: Data, password: String) throws {
        var rawItems: CFArray?
        let options = [kSecImportExportPassphrase as String: password] as CFDictionary
        let status = SecPKCS12Import(data as CFData, options, &rawItems)
        if status == errSecAuthFailed || status == errSecPkcs12VerifyFailure {
            throw CertError.wrongPassword
        }
        guard status == errSecSuccess,
              let items = rawItems as? [[String: Any]],
              let first = items.first else {
            throw CertError.importFailed(status)
        }
        guard let identityAny = first[kSecImportItemIdentity as String] else {
            throw CertError.noIdentity
        }
        let identity = identityAny as! SecIdentity

        var certRef: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certRef) == errSecSuccess,
              let certificate = certRef else {
            throw CertError.noIdentity
        }
        let leafDER = SecCertificateCopyData(certificate) as Data
        let info = try CertificateInfo.parse(der: leafDER)
        guard info.passTypeIdentifier != nil, info.teamIdentifier != nil else {
            throw CertError.notAPassCertificate
        }

        // Alte Identität ersetzen
        SecItemDelete([
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: identityLabel,
        ] as CFDictionary)
        let addStatus = SecItemAdd([
            kSecValueRef as String: identity,
            kSecAttrLabel as String: identityLabel,
        ] as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
            throw CertError.keychainFailed(addStatus)
        }

        // Leaf und mitgelieferte Kette für die Signatur ablegen
        try? leafDER.write(to: leafURL, options: .atomic)
        try? fm.removeItem(at: chainDirURL)
        if let chain = first[kSecImportItemCertChain as String] as? [SecCertificate] {
            for (index, cert) in chain.enumerated() {
                let der = SecCertificateCopyData(cert) as Data
                guard der != leafDER else { continue }
                try? der.write(to: chainDirURL.appendingPathComponent("kette-\(index).cer"), options: .atomic)
            }
        }

        reloadMeta()
    }

    func removeCertificate() {
        SecItemDelete([
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: identityLabel,
        ] as CFDictionary)
        try? fm.removeItem(at: leafURL)
        try? fm.removeItem(at: chainDirURL)
        meta = nil
    }

    private func reloadMeta() {
        guard let leafDER = try? Data(contentsOf: leafURL),
              let info = try? CertificateInfo.parse(der: leafDER),
              let passTypeID = info.passTypeIdentifier,
              let teamID = info.teamIdentifier else {
            meta = nil
            return
        }
        meta = Meta(
            passTypeIdentifier: passTypeID,
            teamIdentifier: teamID,
            organizationName: info.organizationName ?? info.commonName ?? "Kartenwallet",
            commonName: info.commonName ?? passTypeID
        )
    }

    // MARK: - Zugriff für die Signatur

    func identity() -> SecIdentity? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: identityLabel,
            kSecReturnRef as String: true,
        ] as CFDictionary, &result)
        guard status == errSecSuccess, let ref = result else { return nil }
        return (ref as! SecIdentity)
    }

    /// Zwischenzertifikate, die mit in die Signatur eingebettet werden:
    /// bevorzugt passend zum Aussteller des eigenen Zertifikats.
    func chainCertificates() -> [Data] {
        var candidates: [Data] = []
        if let files = try? fm.contentsOfDirectory(at: chainDirURL, includingPropertiesForKeys: nil) {
            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if let der = try? Data(contentsOf: file) { candidates.append(der) }
            }
        }
        if let wwdr = try? Data(contentsOf: wwdrURL), !candidates.contains(wwdr) {
            candidates.append(wwdr)
        }

        // Wenn der Aussteller bekannt ist, nur die passenden Kettenglieder
        // einbetten — sonst alle Kandidaten.
        if let leafDER = try? Data(contentsOf: leafURL),
           let info = try? CertificateInfo.parse(der: leafDER),
           let issuerAttrs = try? CertificateInfo.attributes(ofRawName: info.issuerDER),
           let issuerCN = issuerAttrs["2.5.4.3"] {
            let matching = candidates.filter { der in
                guard let candidateInfo = try? CertificateInfo.parse(der: der) else { return false }
                return candidateInfo.commonName == issuerCN
            }
            if !matching.isEmpty { return matching }
        }
        return candidates
    }

    // MARK: - Apple-WWDR-Zwischenzertifikat

    /// Lädt das öffentliche Apple-WWDR-G4-Zertifikat (signiert alle
    /// Pass-Type-ID-Zertifikate) einmalig von Apple und legt es lokal ab.
    func ensureWWDR() async {
        guard !fm.fileExists(atPath: wwdrURL.path) else {
            wwdrAvailable = true
            return
        }
        guard let url = URL(string: "https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  (try? CertificateInfo.parse(der: data)) != nil else { return }
            try data.write(to: wwdrURL, options: .atomic)
            wwdrAvailable = true
        } catch {
            // Kein Netz — beim nächsten Öffnen der Einstellungen erneut versuchen.
        }
    }

    /// Prüft vor dem Signieren, dass eine Kette eingebettet werden kann.
    func requireChain() throws -> [Data] {
        let chain = chainCertificates()
        guard !chain.isEmpty else { throw CertError.wwdrMissing }
        return chain
    }
}
