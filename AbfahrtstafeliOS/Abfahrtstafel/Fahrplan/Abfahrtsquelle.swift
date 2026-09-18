import Foundation

/// Eine Quelle, die NUR Abfahrten kann.
///
/// **Warum es das neben `Fahrplandienst` gibt:** Nicht jede Quelle kann alles.
/// Die EFA-Schnittstelle der Verkehrsverbünde liefert vorzügliche
/// Abfahrtstafeln, aber keine Streckengeometrie — und eine Fahrt ohne Strecke
/// hat in dieser App keinen Bildschirm. Sie als `Fahrplandienst` auszugeben
/// hieße, vier Methoden zu versprechen und zwei davon mit „geht nicht" zu
/// beantworten. Das ist keine Trennung, das ist eine Lüge mit Protokoll.
///
/// Also: `Fahrplandienst` bleibt das, was die Ansichten sehen (eine Quelle,
/// die alles kann). `Abfahrtsquelle` ist das, was sich VERKETTEN lässt.
/// `Kettendienst` fügt beides zusammen.
protocol Abfahrtsquelle: Sendable {
    /// Der Name, der an der einzelnen Abfahrt steht.
    var name: String { get }

    /// Ob diese Quelle für eine Haltestelle überhaupt zuständig ist.
    ///
    /// Sie wird VOR der Abfrage gefragt, damit die Kette nicht bei jeder
    /// Haltestelle in Hamburg eine Münchner Schnittstelle anruft. Wer sich
    /// nicht sicher ist, sagt `true` — eine Abfrage zu viel kostet eine
    /// Sekunde, eine Abfrage zu wenig kostet die Auskunft.
    func zustaendig(fuer haltestelle: Haltestelle) -> Bool

    func abfahrten(
        ab haltestelle: Haltestelle,
        umkreis meter: Int,
        zeitpunkt: Date,
        anzahl: Int
    ) async throws -> [Abfahrt]
}
