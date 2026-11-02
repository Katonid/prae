import Foundation
import Observation
import Photos

/// Modus A: Fotos ohne Standort im gewählten Zeitraum finden und abarbeiten.
@MainActor
@Observable
final class ErgaenzenModell {
    enum Phase { case auswahl, suche, ergebnis }

    var phase: Phase = .auswahl
    private(set) var fortschritt: Double = 0
    /// `nil` = eigener Zeitraum.
    var schnellwahl: Schnellwahl? = .monat
    var von: Date
    var bis: Date
    private(set) var liste: Arbeitsliste?
    private(set) var laedt = false

    @ObservationIgnored private var aufgabe: Task<Void, Never>?

    init() {
        let z = Schnellwahl.monat.zeitraum() ?? Zeitraum(von: Date(), bis: Date())
        von = z.von
        bis = z.bis
    }

    var zeitraum: Zeitraum? {
        schnellwahl == .alles ? nil : Zeitraum(von: von, bis: bis)
    }

    func waehlen(_ wahl: Schnellwahl) {
        schnellwahl = wahl
        if let z = wahl.zeitraum() {
            von = z.von
            bis = z.bis
        }
    }

    /// Durchsucht den Zeitraum und beginnt damit eine neue Sitzung.
    func suchen(sitzung: Sitzungsspeicher) {
        aufgabe?.cancel()
        phase = .suche
        fortschritt = 0
        let zeitraum = self.zeitraum
        aufgabe = Task {
            let ergebnis = await FotoSuche.durchsuchen(
                zeitraum: zeitraum,
                filter: .ohneStandort,
                aufsteigend: true,
                nurAenderbare: true
            ) { [weak self] wert in
                Task { @MainActor in self?.fortschritt = wert }
            }
            guard !Task.isCancelled, !ergebnis.abgebrochen else { return }
            sitzung.sitzungBeginnen(ErgaenzenSitzung(
                zeitraum: zeitraum,
                ids: ergebnis.assets.map(\.localIdentifier),
                untersucht: ergebnis.untersucht,
                ohneStandort: ergebnis.ohneStandort,
                nichtAenderbar: ergebnis.nichtAenderbar
            ))
            liste = Arbeitsliste(art: .ergaenzen, assets: ergebnis.assets, abschnitte: ergebnis.abschnitte)
            phase = .ergebnis
        }
    }

    func abbrechen() {
        aufgabe?.cancel()
        aufgabe = nil
        phase = .auswahl
    }

    func neueAuswahl() {
        phase = .auswahl
    }

    /// Lädt eine gespeicherte Sitzung (nach einem Neustart) und liefert das
    /// Foto, bei dem es weitergeht.
    func fortsetzen(sitzung: Sitzungsspeicher) async -> Int? {
        guard let gespeichert = sitzung.laufend else { return nil }
        if liste == nil {
            laedt = true
            defer { laedt = false }
            let ergebnis = await FotoSuche.durchsuchen(
                zeitraum: nil,
                filter: .alle,
                aufsteigend: gespeichert.aufsteigend,
                ids: gespeichert.ids
            )
            let mitOrt = Set(ergebnis.assets.filter { $0.location != nil }.map(\.localIdentifier))
            sitzung.abgleichen(ids: ergebnis.assets.map(\.localIdentifier), mitOrt: mitOrt)
            liste = Arbeitsliste(art: .ergaenzen, assets: ergebnis.assets, abschnitte: ergebnis.abschnitte)
        }
        phase = .ergebnis
        return startIndex(sitzung: sitzung)
    }

    func startIndex(sitzung: Sitzungsspeicher) -> Int {
        guard let s = sitzung.laufend, let liste else { return 0 }
        return Fortschritt.startIndex(
            zuletzt: s.zuletzt.flatMap { liste.index(von: $0) },
            ids: liste.ids,
            erledigt: s.erledigt,
            uebersprungen: s.uebersprungen
        )
    }

    func sortierungUmkehren(sitzung: Sitzungsspeicher) {
        guard let alt = liste, let s = sitzung.laufend else { return }
        let neu = alt.umgekehrt()
        liste = neu
        sitzung.sortierung(aufsteigend: !s.aufsteigend, ids: neu.ids)
    }

    /// Verwirft die Sitzung (z. B. nach „Neue Suche“).
    func verwerfen(sitzung: Sitzungsspeicher) {
        aufgabe?.cancel()
        liste = nil
        phase = .auswahl
        sitzung.sitzungBeenden()
    }
}
