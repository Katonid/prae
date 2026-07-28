import Foundation
import PassKit

/// Nimmt .pkpass-Dateien entgegen — per „Öffnen mit Kartenwallet" aus
/// anderen Apps oder über den Import-Knopf in der App — und reicht sie
/// an den Wallet-Dialog weiter.
@MainActor
final class PassImporter: ObservableObject {
    @Published var pendingPass: PKPass?
    @Published var errorMessage: String?

    func importPass(from url: URL) {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            pendingPass = try PKPass(data: data)
        } catch {
            errorMessage = "Die Pass-Datei konnte nicht gelesen werden. Ist es eine gültige, signierte .pkpass-Datei? (\(error.localizedDescription))"
        }
    }
}
