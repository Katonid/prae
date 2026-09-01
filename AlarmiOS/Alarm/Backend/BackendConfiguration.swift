//  BackendConfiguration.swift
//  Which backend the app runs on, and where it lives.

import Foundation

/// The choice of backend, as data.
///
/// `remote` is declared but not built. That is on purpose and not laziness:
/// the case documents the shape a second backend takes (a base URL and
/// nothing else), and it makes the compiler complain at every `switch` that
/// would need extending. A comment in a migration document does neither.
enum BackendConfiguration: Equatable {
    case cloudKit(containerIdentifier: String)
    case mock
    case remote(baseURL: URL)

    /// What this app ships with.
    static let standard = BackendConfiguration.cloudKit(
        containerIdentifier: "iCloud.de.dboschule.alarm")

    func makeBackend() throws -> any AlarmBackend {
        switch self {
        case .cloudKit(let container):
            return CloudKitBackend(containerIdentifier: container)
        case .mock:
            return MockBackend()
        case .remote:
            throw BackendError.notImplemented(
                "Ein eigener Server als Gegenstelle (siehe docs/BACKEND_MIGRATION.md)")
        }
    }

    var label: String {
        switch self {
        case .cloudKit(let container): return "CloudKit (\(container))"
        case .mock: return "Testdaten"
        case .remote(let url): return "Server (\(url.absoluteString))"
        }
    }
}
