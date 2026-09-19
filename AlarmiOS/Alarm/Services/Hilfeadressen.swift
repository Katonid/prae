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

    /// Eine echte Mailadresse, kein Formular: Wer melden will, sitzt am Gerät
    /// und soll nicht erst ein Konto anlegen müssen. Der Betreff ist
    /// vorbelegt, damit die Mail nicht im Übrigen untergeht.
    static let missbrauch = URL(
        string: "mailto:\(postfach)?subject=\(kodiert("Meldung aus der App Schulalarm"))")!

    /// Dieselbe Meldung, aber zu EINER bestimmten Nachricht.
    ///
    /// Mit Kürzel, Uhrzeit und Wortlaut im Entwurf — ohne die drei lässt sich
    /// eine Meldung nicht bearbeiten, und niemand tippt sie unter Druck von
    /// Hand ab. Abgeschickt wird sie vom Menschen: Eine Mail, die die App
    /// still hinausschickt, wäre keine Meldung, sondern eine Übermittlung.
    ///
    /// Kommt die Adresse nicht zustande — ein Wortlaut mit Zeichen, die sich
    /// nicht kodieren lassen —, gilt die allgemeine Meldeadresse. Ein Knopf,
    /// der dann gar nichts täte, wäre genau der Fehler, der diese App schon
    /// eine Einreichung gekostet hat.
    static func meldung(zu nachricht: Message) -> URL {
        let zeit = ISO8601DateFormatter().string(from: nachricht.createdAt)
        let text = """
        Ich melde diese Nachricht aus der App Schulalarm:

        Von: \(nachricht.senderName)
        Zeitpunkt: \(zeit)
        Kennung: \(nachricht.id)

        Wortlaut:
        \(nachricht.text)

        Grund der Meldung:
        """
        let adresse = "mailto:\(postfach)"
            + "?subject=\(kodiert("Meldung zu einer Nachricht in Schulalarm"))"
            + "&body=\(kodiert(text))"
        return URL(string: adresse) ?? missbrauch
    }

    private static let postfach = "schulalarm@apps.dblern.de"

    /// Prozentkodierung für Betreff und Rumpf einer `mailto:`-Adresse.
    ///
    /// `.urlQueryAllowed` lässt `&` und `+` stehen — das erste beendete den
    /// Rumpf mitten im Satz, das zweite käme als Leerzeichen an. Beide werden
    /// deshalb ausdrücklich ausgenommen.
    private static func kodiert(_ text: String) -> String {
        var erlaubt = CharacterSet.urlQueryAllowed
        erlaubt.remove(charactersIn: "&+?=#")
        return text.addingPercentEncoding(withAllowedCharacters: erlaubt) ?? ""
    }
}
