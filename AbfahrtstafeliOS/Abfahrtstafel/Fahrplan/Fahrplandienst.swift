import CoreLocation
import Foundation

/// Alles Fahrplan-Nahe liegt hinter DIESEM Protokoll.
///
/// Das ist kein Stilwunsch. Öffentliche Fahrplanschnittstellen sind das
/// Wackeligste an einer solchen App: Sie werden abgeschaltet (die
/// HAFAS-Schnittstelle der Bahn), sie verlangen plötzlich einen Schlüssel,
/// oder sie decken eine Gegend nicht ab. Solange die Oberfläche nur dieses
/// Protokoll kennt, kostet ein Wechsel EINE Datei — und `Musterdienst` ist der
/// laufende Beweis, dass die Trennung hält: Steckte irgendwo ein JSON-Feld
/// von Transitous, ließe er sich nicht übersetzen.
///
/// Wer einen zweiten Dienst baut (etwa die MVG-Schnittstelle für München, weil
/// sie dort mehr weiß), baut ihn hierunter und nicht daneben.
protocol Fahrplandienst: Sendable {
    /// Der Name, der in den Einstellungen unter „Datenquelle" steht. Woher die
    /// Zahlen kommen, gehört dem Nutzer gesagt.
    var quellenname: String { get }
    /// Die Adresse der Quelle, zum Nachlesen. Eine App, die fremde Daten
    /// zeigt, nennt die Quelle.
    var quellenadresse: URL { get }

    /// Haltestellen um einen Punkt herum, nach Entfernung sortiert.
    func haltestellen(um punkt: CLLocationCoordinate2D, umkreis meter: Int) async throws -> [Haltestelle]

    /// Haltestellensuche über den Namen. Der Punkt ist optional und dient nur
    /// dazu, nahe Treffer nach vorn zu holen — „Hauptbahnhof" gibt es überall.
    func haltestellenSuchen(_ text: String, nahe punkt: CLLocationCoordinate2D?) async throws -> [Haltestelle]

    /// Die Abfahrten an einer Haltestelle — und, wenn `umkreis` größer als 0
    /// ist, gleich auch die der Haltestellen drumherum.
    ///
    /// Beides in EINER Abfrage, weil die Frage des Nutzers „was fährt hier
    /// gerade weg?" lautet und nicht „was fährt an Haltestelle X weg?". Eine
    /// Abfrage je Haltestelle wäre auch technisch schlechter: zehn Anfragen
    /// statt einer, und die Liste baute sich ruckweise auf.
    func abfahrten(
        ab haltestelle: Haltestelle,
        umkreis meter: Int,
        zeitpunkt: Date,
        anzahl: Int
    ) async throws -> [Abfahrt]

    /// Der ganze Lauf einer Fahrt samt Zwischenhalten und Streckengeometrie.
    func fahrt(_ fahrtId: String) async throws -> Fahrt

    /// Ortssuche für die Vorschlagsliste — Haltestellen UND Adressen.
    ///
    /// Getrennt von `haltestellenSuchen`, weil es eine andere Frage ist: Die
    /// Ortswahl der Tafel will einen Bezugspunkt, also eine Haltestelle; ein
    /// Ziel darf auch eine Adresse sein. Beides in eine Methode zu ziehen
    /// hieße, an einer der beiden Stellen zu filtern — und Filtern im
    /// Aufrufer ist genau die Art Wissen, die nicht in die Oberfläche gehört.
    func orteSuchen(_ text: String, nahe punkt: CLLocationCoordinate2D?) async throws -> [Ortstreffer]

    /// Ab wie vielen Zeichen die Ortssuche überhaupt etwas findet.
    ///
    /// Sie steht HIER und nicht in der Ansicht: Wie kurz eine Eingabe sein
    /// darf, weiß nur die Quelle — Transitous antwortet unter drei Zeichen mit
    /// einer leeren Liste. Die Oberfläche liest den Wert und schreibt hin, wie
    /// viele Zeichen noch fehlen; eine leere Liste sähe sonst aus wie „nichts
    /// gefunden". Eine Zahl, die in einer View steht, wäre beim nächsten
    /// Quellenwechsel still falsch.
    var kuerzesteSuche: Int { get }

    /// Verbindungen von A nach B.
    ///
    /// `ankunft == true` heißt: `zeitpunkt` ist die gewünschte ANKUNFT. Das
    /// ist keine Spielerei — „ich muss um neun da sein" ist die häufigere
    /// Frage als „ich gehe jetzt los", und sie lässt sich aus der anderen
    /// nicht ausrechnen.
    func verbindungen(
        von: CLLocationCoordinate2D,
        nach: CLLocationCoordinate2D,
        zeitpunkt: Date,
        ankunft: Bool,
        anzahl: Int,
        nurNahverkehr: Bool
    ) async throws -> [Verbindung]
}

extension Fahrplandienst {
    /// Drei Zeichen — der gemessene Wert von Transitous. Wer eine Quelle
    /// hinzufügt, die mehr oder weniger braucht, sagt es hier.
    var kuerzesteSuche: Int { 3 }
}

/// Was schiefgehen kann — im Klartext, weil der Nutzer es liest.
///
/// Jeder Fall sagt, was zu tun ist. „Ein Fehler ist aufgetreten" ist keine
/// Meldung, sondern das Eingeständnis, dass niemand nachgesehen hat.
enum Fahrplanfehler: LocalizedError, Equatable {
    case keinNetz
    case dienstAntwortetNicht(status: Int)
    case antwortUnlesbar(String)
    case nichtsGefunden
    /// Um diesen Punkt herum kennt der Dienst überhaupt keine Haltestelle.
    ///
    /// Ein eigener Fall und nicht `nichtsGefunden`, weil die ANTWORT eine
    /// andere ist: Hier hilft kein zweiter Versuch, sondern nur ein anderer
    /// Punkt. Ein Knopf „Noch einmal versuchen" über einem Waldstück wäre
    /// eine Sackgasse mit Bedienelement.
    case keineHaltestelleInDerNaehe
    /// Keine Quelle der Kette hat geantwortet. Die Gründe reisen mit — je
    /// Quelle einer. „Verbindung fehlgeschlagen" über einer Kette aus drei
    /// Quellen sagt nichts darüber, welche der drei gerissen ist.
    case keineQuelleAntwortet(gruende: [String])
    /// Die Auskunft hat geantwortet und NICHTS gefunden.
    ///
    /// Ein eigener Fall und nicht `nichtsGefunden`: Das ist kein Fehler,
    /// sondern eine Auskunft — zwischen diesen beiden Punkten fährt zu dieser
    /// Zeit nichts. Ein „Noch einmal versuchen" wäre hier eine Sackgasse mit
    /// Bedienelement; was hilft, ist eine andere Zeit oder ein anderes Ziel.
    case keineVerbindung
    /// Es gibt NUR noch einen alten Stand — und der reist mitsamt seinem
    /// Alter.
    ///
    /// Ein Fehler, der Daten trägt, sieht seltsam aus und ist hier richtig:
    /// Der Aufrufer soll die Zeiten zeigen DÜRFEN, aber nicht ohne die
    /// Altersangabe. Gäbe man sie als normales Ergebnis zurück, wäre die
    /// Kennzeichnung eine Zeile, die man vergessen kann.
    case veralteterStand(abfahrten: [Abfahrt], geholtUm: Date)
    case abgebrochen

    var errorDescription: String? {
        switch self {
        case .keinNetz:
            return "Keine Verbindung. Die Abfahrten kommen aus dem Netz — ohne Netz gibt es keine."
        case .dienstAntwortetNicht(let status):
            return "Der Fahrplandienst antwortet gerade nicht (Code \(status)). Das liegt nicht am Gerät; in ein paar Minuten noch einmal versuchen."
        case .antwortUnlesbar(let grund):
            return "Die Antwort des Fahrplandienstes war nicht zu lesen: \(grund)"
        case .nichtsGefunden:
            return "Dazu hat der Fahrplandienst nichts."
        case .keineHaltestelleInDerNaehe:
            return "Um diesen Punkt herum kennt der Fahrplandienst keine Haltestelle. Der Dienst sucht nur etwa einen Kilometer weit — mitten im Feld oder im Wald findet er nichts, und das ist kein Fehler. Mit einem Punkt näher an einer Ortschaft geht es."
        case .keineVerbindung:
            return "Zwischen diesen beiden Punkten findet die Auskunft um diese Zeit keine Verbindung. Das ist kein Fehler der App — nachts, auf dem Land und über weite Strecken kommt das vor. Mit einer anderen Zeit oder einem Ziel näher an einer Haltestelle geht es oft doch."
        case .keineQuelleAntwortet(let gruende):
            let liste = gruende.isEmpty ? "" : "\n\n" + gruende.map { "• \($0)" }.joined(separator: "\n")
            return "Keine der Fahrplanquellen hat geantwortet.\(liste)"
        case .veralteterStand(_, let geholtUm):
            let uhrzeit = geholtUm.formatted(date: .omitted, time: .shortened)
            return "Keine Verbindung — die Zeiten sind von \(uhrzeit) und zählen nicht weiter."
        case .abgebrochen:
            return "Abgebrochen."
        }
    }
}

extension Fahrplanfehler {
    /// Die knappe Fassung für die Aufzählung in `keineQuelleAntwortet`.
    ///
    /// Der lange Satz aus `errorDescription` erklärt EINEN Fehler jemandem,
    /// der sonst nichts sieht. In einer Liste von drei Quellen untereinander
    /// wären drei solche Sätze eine Wand, durch die niemand liest.
    var kurzfassung: String {
        switch self {
        case .keinNetz: return "keine Verbindung"
        case .dienstAntwortetNicht(let status): return "antwortet nicht (Code \(status))"
        case .antwortUnlesbar(let grund): return grund
        case .nichtsGefunden: return "nichts gefunden"
        case .keineHaltestelleInDerNaehe: return "keine Haltestelle in der Nähe"
        case .keineVerbindung: return "keine Verbindung gefunden"
        case .keineQuelleAntwortet: return "keine Quelle"
        case .veralteterStand: return "nur ein alter Stand"
        case .abgebrochen: return "abgebrochen"
        }
    }
}
