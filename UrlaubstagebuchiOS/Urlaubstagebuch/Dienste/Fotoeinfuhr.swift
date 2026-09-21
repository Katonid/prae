import Foundation
import Photos
import SwiftUI

// Ein eingelesenes Bild, bevor es zu einem `Foto` wird.
struct Rohbild {
    var daten: Data
    var kennung: String?
    var endung: String = "jpg"
}

struct Einfuhrbericht {
    var aufgenommen: Int = 0
    var ohneDatum: Int = 0
    var ohneOrt: Int = 0
    var ortAusMediathek: Int = 0
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

    func fotosAufnehmen(_ bilder: [Rohbild]) async -> Einfuhrbericht {
        var bericht = Einfuhrbericht()
        let bekannteTage = Set(reise.tage.map(\.schluessel))
        var neueSchluessel = Set<String>()
        merken()

        for bild in bilder {
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
                    }
                }
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
                continue
            }
            if !bekannteTage.contains(schluessel) { neueSchluessel.insert(schluessel) }
            let stelle = reise.tagIndex(fuer: datum)
            reise.tage[stelle].fotos.append(foto.id)
        }

        bericht.neueTage = neueSchluessel.count

        // Die Fotos eines Tages stehen in ihrer Aufnahmereihenfolge — das
        // ist die Reihenfolge, in der der Tag erlebt wurde, und die einzige,
        // die sich nicht begründen muss.
        for stelle in reise.tage.indices {
            let index = reise.fotoIndex
            reise.tage[stelle].fotos.sort {
                (index[$0]?.aufnahme ?? .distantPast) < (index[$1]?.aufnahme ?? .distantPast)
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
