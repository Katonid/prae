//  Umgebung.swift
//  Development oder Production — die stille Voraussetzung hinter allem.
//
//  Über Xcode installiert läuft die App gegen die **Development**-Umgebung von
//  CloudKit, über TestFlight und aus dem Laden gegen **Production**. Die beiden
//  teilen NICHTS: nicht die Datensätze, nicht die Indizes, nicht die
//  Abonnements. Eine Schule, die in der einen eingerichtet wurde, gibt es in
//  der anderen nicht — und ihr Beitrittscode dort auch nicht.
//
//  Das ist keine Randnotiz, sondern der häufigste Grund für „das ging doch
//  gestern noch". Gemeldet 09/2026: Eine Schule war über TestFlight
//  eingerichtet, das Kollegium war beigetreten — und auf einem per Xcode
//  angeschlossenen iPad wurde derselbe Code abgewiesen. Die App sagte dazu
//  „Diesen Beitrittscode gibt es nicht", und das war für die
//  Development-Umgebung wörtlich richtig und als Auskunft trotzdem
//  irreführend.
//
//  Auslesen lässt sich die Umgebung nicht: `CKContainer` gibt sie nicht her.
//  Erschlossen wird sie am Kaufbeleg im Bündel — deshalb heißt es hier
//  „vermutlich" und nicht „ist".

import Foundation

enum Umgebung {

    /// Wie diese Fassung installiert wurde, im Klartext.
    static var beschreibung: String {
        #if DEBUG
        return "vermutlich Development (über Xcode installiert)"
        #else
        guard let beleg = Bundle.main.appStoreReceiptURL?.lastPathComponent else {
            return "unbekannt — vermutlich Development"
        }
        return beleg == "sandboxReceipt"
            ? "Production (über TestFlight installiert)"
            : "Production (aus dem Laden installiert)"
        #endif
    }

    /// Der Satz, der einen abgewiesenen Beitrittscode erklärt.
    ///
    /// Er steht bewusst bei JEDEM unbekannten Code und nicht nur im
    /// Debug-Bau: Der Riss geht in beide Richtungen. Ein Code aus einer über
    /// Xcode eingerichteten Schule wird in der TestFlight-Fassung genauso
    /// abgewiesen wie umgekehrt, und welche Richtung gerade vorliegt, weiß
    /// die App nicht — sie kennt nur ihre eigene Seite.
    static var codehinweis: String {
        "Über Xcode installiert läuft die App gegen die "
        + "Development-Umgebung, über TestFlight und aus dem Laden gegen "
        + "Production. Die beiden teilen KEINE Daten: Ein Code aus der "
        + "TestFlight-Fassung gilt in einer über Xcode installierten Fassung "
        + "nicht — und umgekehrt. Diese Fassung hier läuft \(beschreibung)."
    }
}
