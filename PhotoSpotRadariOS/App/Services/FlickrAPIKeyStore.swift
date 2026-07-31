import Foundation
import Security

enum FlickrAPIKeyStore {
    private static let service = "PhotoSpotRadar.Flickr"
    private static let account = "APIKey"

    static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword, kSecAttrService: service,
            kSecAttrAccount: account, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String) throws {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                     kSecAttrService: service, kSecAttrAccount: account]
        SecItemDelete(query as CFDictionary)
        guard !key.isEmpty else { return }
        let attributes = query.merging([kSecValueData: Data(key.utf8)]) { _, new in new }
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw FlickrConfigurationError.keychain(status) }
    }
}

enum FlickrConfigurationError: LocalizedError {
    case keychain(OSStatus)
    var errorDescription: String? { "Der Flickr-API-Schlüssel konnte nicht sicher gespeichert werden." }
}
