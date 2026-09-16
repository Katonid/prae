//  Geraetename.swift
//  Wie das Gerät heißt, auf dem die App gerade läuft.
//
//  Gemeldet 09/2026: Auf einem iPhone stand „Dieses iPad ist nicht
//  einsatzbereit". Die App war für dreißig Dienst-iPads gebaut, und die Texte
//  sagten das wörtlich — nur hält eine Lehrkraft eben auch mal ein iPhone in
//  der Hand, und ein Warnband, das vom falschen Gerät redet, liest sich wie
//  ein Fehler in der App.
//
//  Die Regel dahinter, und sie gilt für jeden neuen Text:
//
//  * Geht es um **dieses** Gerät, steht hier der Name, den der Mensch davor
//    auch auf der Rückseite liest — `Geraetename.wort`.
//  * Geht es um **irgendein** Gerät (eine allgemeine Aussage über die Schule,
//    ein anderes Mitglied, zwei Geräte an einer Apple-ID), steht dort
//    schlicht „Gerät". Ein „iPad" wäre dort nicht nur unpassend, sondern
//    falsch: Was in dem Satz steht, gilt für jedes Gerät.
//
//  Grammatisch geht das auf, weil iPad, iPhone und Gerät alle sächlich sind:
//  „dieses iPad", „dieses iPhone", „dieses Gerät". Wer hier eine Sprache
//  hinzufügt, bei der das nicht gilt, kommt mit einer Wortliste nicht weiter.

import UIKit

enum Geraetename {

    /// „iPad", „iPhone" — und für alles andere „Gerät".
    ///
    /// Kein `default`-Zweig mit Rateversuch: Läuft die App eines Tages auf
    /// einem Mac oder in einer Vision, ist „Gerät" richtig und „iPad" gelogen.
    static var wort: String {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone: return "iPhone"
        case .pad: return "iPad"
        default: return "Gerät"
        }
    }

    /// Die Mehrzahl, für Sätze über mehrere Geräte DERSELBEN Art.
    static var mehrzahl: String {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone: return "iPhones"
        case .pad: return "iPads"
        default: return "Geräte"
        }
    }
}
