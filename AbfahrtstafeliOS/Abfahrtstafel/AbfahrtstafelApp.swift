import SwiftUI

/// Abfahrtstafel — Abfahrten der öffentlichen Verkehrsmittel um einen Punkt
/// herum, mit Verspätungen, Minutenziffer, allen Zwischenhalten und der
/// Strecke auf der Karte.
///
/// Die Bausteine werden HIER angelegt und über die Umgebung
/// weitergereicht. Jede Ansicht, die sich ihren eigenen `Standortdienst`
/// erzeugte, hätte eine zweite Ortung laufen — und zwei Uhrwerke ließen die
/// Minutenziffern zweier Listen auseinanderlaufen.
@main
struct AbfahrtstafelApp: App {
    /// **Eine Kette für beide Bildschirme.** Tafel und Verbindungsauskunft
    /// fragen dieselbe Quelle; zwei Ketten nebeneinander hieße zwei
    /// Zwischenspeicher und zwei Meinungen darüber, welcher Verbund gerade
    /// antwortet.
    /// **Die Kette steht in ihrem eigenen Typ da und nicht hinter
    /// `Fahrplandienst`.** Sie kann mehr als das Protokoll — seit 1.1.26 auch
    /// den Fußweg (`Fusswegquelle`) —, und wer sie hier auf das eine
    /// Protokoll einengt, kann das andere nicht mehr weiterreichen, ohne zur
    /// Laufzeit zurückzufragen.
    private static let kette = Kettendienst()
    private static var dienst: Fahrplandienst { kette }

    @StateObject private var model = AppModel(dienst: AbfahrtstafelApp.dienst)
    @StateObject private var planer = Verbindungsmodell(dienst: AbfahrtstafelApp.dienst)
    @StateObject private var standort = Standortdienst()
    @StateObject private var uhr = Uhrwerk()
    @StateObject private var merkliste = Merkliste()
    @StateObject private var netz = Liniennetz()
    @StateObject private var meldungen = Meldungsdienst()
    /// **In der Umgebung und nicht in der Karte.** Die Netzkarte gibt es
    /// zweimal — eingebettet und im Vollbild —, und das sind zwei Ansichten
    /// mit eigenem `@State`. Eine gerade gemessene Strecke, die beim
    /// Aufziehen der Karte verschwindet, sähe wie ein Fehler aus.
    @StateObject private var fusswege = Fusswegmesser(quelle: AbfahrtstafelApp.kette)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(planer)
                .environmentObject(standort)
                .environmentObject(uhr)
                .environmentObject(merkliste)
                .environmentObject(netz)
                .environmentObject(meldungen)
                .environmentObject(fusswege)
        }
    }
}
