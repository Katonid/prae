import Foundation
import Observation

/// Modus B: alle Fotos durchsehen und vorhandene Standorte bearbeiten.
@MainActor
@Observable
final class BearbeitenModell {
    var schnellwahl: Schnellwahl = .alles
    var eigenerZeitraum: Zeitraum?
    var filter: Standortfilter = .alle
    /// Neueste zuerst — so sind die letzten Aufnahmen sofort da.
    private(set) var aufsteigend = false
    private(set) var liste: Arbeitsliste?
    private(set) var laedt = false
    private(set) var fortschritt: Double = 0

    @ObservationIgnored private var geladen: String?

    var zeitraum: Zeitraum? { eigenerZeitraum ?? schnellwahl.zeitraum() }

    var zeitraumText: String { eigenerZeitraum?.text ?? schnellwahl.titel }

    func waehlen(_ wahl: Schnellwahl) {
        eigenerZeitraum = nil
        schnellwahl = wahl
    }

    /// Ändert sich dieser Schlüssel, muss neu geladen werden.
    func schluessel(_ sitzung: Sitzungsspeicher) -> String {
        let bearbeitet = filter == .bearbeitet ? sitzung.bearbeiteteIDs.joined(separator: ",").hashValue : 0
        return "\(filter.rawValue)|\(zeitraum?.schluessel ?? "alles")|\(bearbeitet)"
    }

    func laden(sitzung: Sitzungsspeicher, erzwingen: Bool = false) async {
        let schluessel = schluessel(sitzung)
        guard erzwingen || schluessel != geladen || liste == nil else { return }
        laedt = true
        fortschritt = 0
        let ergebnis = await FotoSuche.durchsuchen(
            zeitraum: zeitraum,
            filter: filter,
            aufsteigend: aufsteigend,
            ids: filter == .bearbeitet ? sitzung.bearbeiteteIDs : nil
        ) { [weak self] wert in
            Task { @MainActor in self?.fortschritt = wert }
        }
        guard !Task.isCancelled, !ergebnis.abgebrochen else { return }
        liste = Arbeitsliste(art: .bearbeiten, assets: ergebnis.assets, abschnitte: ergebnis.abschnitte)
        geladen = schluessel
        laedt = false
    }

    func sortierungUmkehren() {
        aufsteigend.toggle()
        if let alt = liste { liste = alt.umgekehrt() }
    }
}
