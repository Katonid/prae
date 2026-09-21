import SwiftUI

@main
struct UrlaubstagebuchApp: App {
    @StateObject private var regal = Regal()

    var body: some Scene {
        WindowGroup {
            RegalView()
                .environmentObject(regal)
        }
    }
}

// Die Liste der Reisen. Sie liegt über dem einzelnen Buch, weil ein
// Urlaubstagebuch nichts ist, wovon man eines hat.
@MainActor
final class Regal: ObservableObject {
    @Published var reisen: [Reise] = []
    @Published var unlesbar: Int = 0
    @Published var offen: Reisewerk?

    init() { neuLesen() }

    func neuLesen() {
        let ergebnis = Ablage.alle()
        reisen = ergebnis.reisen
        unlesbar = ergebnis.unlesbar
    }

    func oeffnen(_ reise: Reise) {
        let werk = Reisewerk(reise: reise)
        werk.fehlendeSeitenNachholen()
        offen = werk
    }

    @discardableResult
    func anlegen(titel: String) -> Reise {
        var neu = Reise()
        neu.titel = titel.isEmpty ? "Meine Reise" : titel
        try? Ablage.sichern(neu)
        neuLesen()
        return neu
    }

    func schliessen() {
        offen?.sofortSichern()
        offen = nil
        Bildarchiv.shared.aufraeumen()
        Task { await Kartenwerk.shared.vergessen() }
        neuLesen()
    }

    func loeschen(_ id: UUID) {
        Ablage.loeschen(id)
        neuLesen()
    }
}
