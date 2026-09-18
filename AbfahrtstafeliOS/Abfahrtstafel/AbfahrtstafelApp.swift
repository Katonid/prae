import SwiftUI

/// Abfahrtstafel — Abfahrten der öffentlichen Verkehrsmittel um einen Punkt
/// herum, mit Verspätungen, Minutenziffer, allen Zwischenhalten und der
/// Strecke auf der Karte.
///
/// Die vier Bausteine werden HIER angelegt und über die Umgebung
/// weitergereicht. Jede Ansicht, die sich ihren eigenen `Standortdienst`
/// erzeugte, hätte eine zweite Ortung laufen — und zwei Uhrwerke ließen die
/// Minutenziffern zweier Listen auseinanderlaufen.
@main
struct AbfahrtstafelApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var standort = Standortdienst()
    @StateObject private var uhr = Uhrwerk()
    @StateObject private var merkliste = Merkliste()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(standort)
                .environmentObject(uhr)
                .environmentObject(merkliste)
        }
    }
}
