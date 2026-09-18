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
    private static let dienst: Fahrplandienst = Kettendienst()

    @StateObject private var model = AppModel(dienst: AbfahrtstafelApp.dienst)
    @StateObject private var planer = Verbindungsmodell(dienst: AbfahrtstafelApp.dienst)
    @StateObject private var standort = Standortdienst()
    @StateObject private var uhr = Uhrwerk()
    @StateObject private var merkliste = Merkliste()
    @StateObject private var netz = Liniennetz()
    @StateObject private var meldungen = Meldungsdienst()

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
        }
    }
}
