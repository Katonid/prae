//  Hilfeadressen.swift
//  Die drei Adressen nach draußen — an EINER Stelle.
//
//  Sie stehen hier und nicht in der Ansicht, weil sie an mehreren Stellen
//  gebraucht werden (Einstellungen, später vielleicht der Beitrittsbildschirm)
//  und weil eine Adresse, die zweimal im Quelltext steht, irgendwann zweimal
//  verschieden lautet. Die Seiten liegen im selben Repo unter
//  `docs/schulalarm/` und werden vom Pages-Ablauf ausgeliefert.
//
//  Warum es die Meldeadresse überhaupt gibt: Im Alarm schreibt das Kollegium
//  einander Nachrichten, und Kürzel, Schulname und Standorte sind frei
//  getippt. Das ist von Nutzern eingestellter Inhalt, und dafür verlangt Apple
//  einen Weg, etwas zu melden, und einen, jemanden loszuwerden. Den zweiten
//  gibt es in der App (Verwaltung → Mitglieder → Entfernen, dazu den
//  Beitrittscode zurückziehen); der erste ist diese Adresse.

import Foundation

enum Hilfeadressen {

    static let support = URL(string: "https://katonid.github.io/prae/schulalarm/support.html")!

    static let datenschutz = URL(string: "https://katonid.github.io/prae/schulalarm/datenschutz.html")!

    /// Nutzungsbedingungen und Haftung.
    ///
    /// Sie stehen auf einer Seite und nicht in der App: Ein Text, der sich
    /// ändern muss — eine Anschrift, ein Satz nach einer Rückfrage —, darf
    /// nicht an einer Fassung hängen, die erst durch die Prüfung muss. Und die
    /// dreißig iPads, die schon eingerichtet sind, lesen dann die alte.
    static let nutzungsbedingungen = URL(
        string: "https://katonid.github.io/prae/schulalarm/nutzungsbedingungen.html")!

    /// Eine echte Mailadresse, kein Formular: Wer melden will, sitzt am iPad
    /// und soll nicht erst ein Konto anlegen müssen. Der Betreff ist
    /// vorbelegt, damit die Mail nicht im Übrigen untergeht.
    static let missbrauch = URL(
        string: "mailto:schulalarm@apps.dblern.de?subject=Meldung%20aus%20der%20App%20Schulalarm")!
}
