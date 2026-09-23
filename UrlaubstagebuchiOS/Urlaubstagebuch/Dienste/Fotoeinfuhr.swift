import Foundation
import Photos
import SwiftUI

// Ein eingelesenes Bild, bevor es zu einem `Foto` wird.
struct Rohbild {
    var daten: Data
    var kennung: String?
    var endung: String = "jpg"
    // Der Dateiname, wenn es einen gibt. Er ist seit 1.0.30 die DRITTE
    // Datumsquelle: Eine Datei, die durch einen Messenger oder eine
    // Bildbearbeitung gelaufen ist, hat kein EXIF mehr — der Name trägt
    // das Datum oft noch (siehe `Namensdatum`).
    var name: String?
}

// Wohin ein Foto geht, dessen Tag sich aus keiner der drei Quellen ergibt.
//
// Gemeldet 09/2026: „wenn das Datum fehlt, dann liegen sie in der Ablage.
// Das möchte ich nicht." Der Wunsch ist berechtigt, und die Antwort darauf
// muss ehrlich bleiben: Ein Foto ohne jede Datumsangabe trägt keine
// Auskunft darüber, wann es aufgenommen wurde — WELCHER Tag es wird, ist
// deshalb eine Entscheidung und keine Messung. Getroffen wird sie vor dem
// Einlesen und sichtbar, nicht im Stillen.
enum Fotoziel: Hashable {
    case ablage
    case tag(UUID)
}

struct Einfuhrbericht {
    var aufgenommen: Int = 0
    var ohneDatum: Int = 0
    var ohneOrt: Int = 0
    var ortAusMediathek: Int = 0
    var datumAusMediathek: Int = 0
    var datumAusName: Int = 0
    var einemTagZugeordnet: Int = 0
    var zieltag: String = ""
    var abgewiesen: Int = 0
    var neueTage: Int = 0

    // Der Bericht ist keine Zierde. Beim Einlesen von zweihundert Fotos
    // fällt sonst niemandem auf, dass dreißig davon keinen Ort tragen — und
    // die Spur dieser Tage ist dann unerklärlich kurz.
    var text: String {
        var zeilen: [String] = ["\(aufgenommen) Fotos eingelesen."]
        if neueTage > 0 { zeilen.append("\(neueTage) neue Tage angelegt.") }
        if ortAusMediathek > 0 {
            zeilen.append("Bei \(ortAusMediathek) Fotos kam der Ort aus der Fotomediathek.")
        }
        if ohneOrt > 0 {
            zeilen.append("\(ohneOrt) Fotos tragen keinen Ort — für sie entsteht kein Punkt auf der Karte. Du kannst ihn von Hand setzen.")
        }
        if datumAusMediathek > 0 {
            zeilen.append("Bei \(datumAusMediathek) Fotos kam das Datum aus der Fotomediathek.")
        }
        if datumAusName > 0 {
            zeilen.append("Bei \(datumAusName) Fotos stand das Datum nur im Dateinamen.")
        }
        if einemTagZugeordnet > 0 {
            zeilen.append("\(einemTagZugeordnet) Fotos tragen kein Datum und stehen jetzt bei \(zieltag).")
        }
        if ohneDatum > 0 {
            zeilen.append("\(ohneDatum) Fotos tragen kein Aufnahmedatum und liegen in der Ablage, bis du sie einem Tag zuordnest.")
        }
        if abgewiesen > 0 {
            zeilen.append("\(abgewiesen) Dateien ließen sich nicht lesen.")
        }
        return zeilen.joined(separator: " ")
    }
}

extension Reisewerk {
    // Ob iOS überhaupt bereit ist, Aufnahmeorte herauszugeben.
    //
    // Das ist die Falle, an der ein Reisetagebuch ohne Vorwarnung scheitert:
    // Der Fotowähler braucht KEINE Berechtigung, und genau deshalb hält man
    // ihn für den ganzen Weg. Ohne Zugriff auf die Mediathek entfernt iOS
    // aber die Standortdaten aus den herausgegebenen Bildern — die Fotos
    // kommen an, die Karte bleibt leer, und es sieht aus, als könne die App
    // kein EXIF lesen.
    nonisolated static var mediathekStand: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    nonisolated static func mediathekFragen() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    // Der gewöhnliche Weg: eine fertige Liste.
    func fotosAufnehmen(_ bilder: [Rohbild],
                        ohneDatum ziel: Fotoziel = .ablage) async -> Einfuhrbericht
    {
        await fotosAufnehmen(anzahl: bilder.count, ohneDatum: ziel) { stelle in
            bilder[stelle]
        }
    }

    // Derselbe Weg, aber Foto für Foto abgeholt (ab 1.0.30).
    //
    // Der Zeitraum-Import kann tausend Bilder umfassen, und tausend
    // Rohbilder sind mehrere Gigabyte — sie passen zusammen nicht in den
    // Arbeitsspeicher. Geholt wird deshalb eines nach dem anderen; sobald
    // es auf der Platte liegt, ist es wieder los. Es gibt trotzdem nur
    // EINE Stelle, an der ein Foto zu einem `Foto` wird: Zwei Fassungen
    // liefen mit Sicherheit auseinander.
    func fotosAufnehmen(anzahl: Int, ohneDatum ziel: Fotoziel,
                        naechstes: (Int) async -> Rohbild?) async -> Einfuhrbericht
    {
        var bericht = Einfuhrbericht()
        guard anzahl > 0 else { return bericht }
        let bekannteTage = Set(reise.tage.map(\.schluessel))
        var neueSchluessel = Set<String>()
        var heimatlose: [UUID] = []
        merken()

        for stelle in 0 ..< anzahl {
            if anzahl > 1 { beschaeftigt = "Foto \(stelle + 1) von \(anzahl)" }
            guard let bild = await naechstes(stelle) else {
                bericht.abgewiesen += 1
                continue
            }
            var befund = Bildleser.befund(datei: bild.daten)

            // Fehlt der Ort, wird er am Mediathekseintrag nachgeschlagen.
            // Das ist der einzige Weg, der auch bei Fotos greift, aus denen
            // iOS die Koordinaten herausgenommen hat.
            if befund.koordinate == nil, let kennung = bild.kennung,
               Self.mediathekStand == .authorized || Self.mediathekStand == .limited
            {
                if let treffer = Self.mediathekOrt(kennung) {
                    befund.koordinate = treffer.ort
                    befund.quelle = .mediathek
                    bericht.ortAusMediathek += 1
                    if befund.tagesschluessel == nil, let wann = treffer.wann {
                        // Auch das Datum kann fehlen. Hier ist eine Zeitzone
                        // unvermeidlich — die Mediathek gibt einen echten
                        // Zeitpunkt heraus, keine Ortszeit. Genommen wird die
                        // des Geräts, und das ist die einzige Stelle dieser
                        // App, an der ein Tag aus einer Umrechnung entsteht.
                        befund.tagesschluessel = Tagesdatum(wann).schluessel
                        befund.aufnahme = wann
                        bericht.datumAusMediathek += 1
                    }
                }
            }

            // Die dritte Quelle: der Dateiname. Sie kommt zuletzt, weil sie
            // die schwächste ist — ein Name lässt sich ändern, ein
            // EXIF-Feld nicht so leicht. Sie kommt aber überhaupt, und das
            // ist der Unterschied zwischen einem Foto im Buch und einem in
            // der Ablage.
            if befund.tagesschluessel == nil, let name = bild.name,
               let gelesen = Namensdatum.lesen(name)
            {
                befund.tagesschluessel = gelesen.schluessel
                befund.aufnahme = gelesen.zeitpunkt
                bericht.datumAusName += 1
            }

            guard befund.breite > 0, befund.hoehe > 0 else {
                bericht.abgewiesen += 1
                continue
            }

            let name: String
            do {
                name = try Bildarchiv.shared.ablegen(bild.daten, reise: reise.id, endung: bild.endung)
            } catch {
                bericht.abgewiesen += 1
                continue
            }

            let foto = Foto(
                datei: name,
                breite: befund.breite,
                hoehe: befund.hoehe,
                aufnahme: befund.aufnahme,
                tagesschluessel: befund.tagesschluessel,
                koordinate: befund.koordinate,
                ortsquelle: befund.koordinate == nil ? .keiner : befund.quelle
            )
            reise.fotos.append(foto)
            bericht.aufgenommen += 1
            if foto.koordinate == nil { bericht.ohneOrt += 1 }

            guard let schluessel = befund.tagesschluessel,
                  let datum = Tagesdatum(schluessel: schluessel)
            else {
                bericht.ohneDatum += 1
                heimatlose.append(foto.id)
                continue
            }
            if !bekannteTage.contains(schluessel) { neueSchluessel.insert(schluessel) }
            let tagstelle = reise.tagIndex(fuer: datum)
            reise.tage[tagstelle].fotos.append(foto.id)
        }

        // Was kein Datum hat, geht an den Tag, den der Nutzer vorher
        // gewählt hat — oder in die Ablage, wenn er das so wollte oder
        // wenn es noch gar keinen Tag gibt.
        if case let .tag(zieltag) = ziel, !heimatlose.isEmpty,
           let tagstelle = tagIndex(zieltag)
        {
            reise.tage[tagstelle].fotos.append(contentsOf: heimatlose)
            bericht.einemTagZugeordnet = heimatlose.count
            bericht.zieltag = reise.tage[tagstelle].datum.mittel
            bericht.ohneDatum -= heimatlose.count
        }

        bericht.neueTage = neueSchluessel.count
        beschaeftigt = nil

        // Die Fotos eines Tages stehen in ihrer Aufnahmereihenfolge — das
        // ist die Reihenfolge, in der der Tag erlebt wurde, und die einzige,
        // die sich nicht begründen muss.
        //
        // Was KEINE Aufnahmezeit hat, kommt ans Ende und nicht an den
        // Anfang (ab 1.0.30). Bis dahin stand dort `.distantPast`, und das
        // war folgenlos, solange ein Tag gar kein undatiertes Foto tragen
        // konnte. Seit ein Foto ohne Datum einem Tag zugeordnet werden
        // kann, wäre es die falsche Richtung: Es schöbe sich vor den
        // Morgen eines Tages, über den es nichts aussagt. Dieselbe Regel
        // wie beim Handpunkt ohne Uhrzeit in der Reisespur.
        for stelle in reise.tage.indices {
            let index = reise.fotoIndex
            reise.tage[stelle].fotos.sort {
                (index[$0]?.aufnahme ?? .distantFuture) < (index[$1]?.aufnahme ?? .distantFuture)
            }
            spurAktualisieren(reise.tage[stelle].id)
        }
        alleNeuAnordnen(nurUnberuehrte: true)
        sofortSichern()
        return bericht
    }

    private static func mediathekOrt(_ kennung: String) -> (ort: Koordinate, wann: Date?)? {
        let treffer = PHAsset.fetchAssets(withLocalIdentifiers: [kennung], options: nil)
        guard let eintrag = treffer.firstObject else { return nil }
        guard let ort = eintrag.location else { return nil }
        let koordinate = Koordinate(ort.coordinate)
        guard koordinate.gueltig else { return nil }
        return (koordinate, eintrag.creationDate)
    }

    // MARK: - Text

    // Verteilt einen eingelesenen Text auf die Tage.
    //
    // `ersetzen` ist die eine Frage, die vorher gestellt werden muss: Wer
    // zum zweiten Mal einliest, will meistens ergänzen und nicht den
    // eigenen, schon überarbeiteten Text überschreiben.
    func textVerteilen(_ befund: Textimport.Importbefund, ersetzen: Bool,
                       vorspannAlsUntertitel: Bool) -> String
    {
        merken()
        var neue = 0
        var ergaenzt = 0
        let bekannt = Set(reise.tage.map(\.schluessel))

        for abschnitt in befund.abschnitte {
            if !bekannt.contains(abschnitt.datum.schluessel) { neue += 1 }
            let stelle = reise.tagIndex(fuer: abschnitt.datum)
            if reise.tage[stelle].ueberschrift.isEmpty || ersetzen {
                reise.tage[stelle].ueberschrift = abschnitt.ueberschrift
            }
            // Dieselbe Regel wie für die Überschrift — und ein LEERER Fund
            // überschreibt auch beim Ersetzen nichts: Hat jemand die zweite
            // Überschrift von Hand eingetippt und liest denselben Text noch
            // einmal ein, wäre sie sonst weg.
            if !abschnitt.unterueberschrift.isEmpty,
               reise.tage[stelle].unterueberschrift.isEmpty || ersetzen
            {
                reise.tage[stelle].unterueberschrift = abschnitt.unterueberschrift
            }
            if ersetzen || reise.tage[stelle].text.isEmpty {
                reise.tage[stelle].text = abschnitt.text
            } else {
                reise.tage[stelle].text += "\n\n" + abschnitt.text
                ergaenzt += 1
            }
        }

        if befund.hatVorspann, vorspannAlsUntertitel {
            reise.untertitel = befund.vorspann
        }

        alleNeuAnordnen(nurUnberuehrte: true)
        sofortSichern()

        var zeilen = ["\(befund.abschnitte.count) Abschnitte verteilt."]
        if neue > 0 { zeilen.append("\(neue) neue Tage angelegt.") }
        if ergaenzt > 0 { zeilen.append("Bei \(ergaenzt) Tagen wurde der vorhandene Text ergänzt.") }
        if befund.hatVorspann, !vorspannAlsUntertitel {
            zeilen.append("Der Vorspann vor der ersten Datumszeile wurde NICHT übernommen.")
        }
        return zeilen.joined(separator: " ")
    }
}
