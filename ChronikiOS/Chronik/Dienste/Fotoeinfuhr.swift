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
    var schonVorhanden: Int = 0
    // Durch eine bearbeitete Fassung ersetzt (ab 1.0.50).
    var ersetzt: Int = 0
    // KAPITELWEISE (ab 1.0.32): neue Fotos in Kapiteln mit Handarbeit.
    var eingeschoben: Int = 0
    var wartenAufNeuverteilen: Int = 0
    // Ab 1.0.43.
    var neuGesetzteSeiten: Int = 0
    var imGesperrten: Int = 0

    // Der Bericht ist keine Zierde. Beim Einlesen von zweihundert Fotos
    // fällt sonst niemandem auf, dass dreißig davon keinen Ort tragen — und
    // die Spur dieser Tage ist dann unerklärlich kurz.
    var text: String {
        var zeilen: [String] = ["\(aufgenommen) Fotos eingelesen."]
        if ersetzt > 0 {
            zeilen.append(ersetzt == 1
                          ? "1 Foto war schon im Buch, aber bearbeitet \u{2014} es ersetzt das alte an derselben Stelle, in derselben Größe."
                          : "\(ersetzt) Fotos waren schon im Buch, aber bearbeitet \u{2014} sie ersetzen die alten an derselben Stelle, in derselben Größe.")
        }
        if schonVorhanden > 0 {
            zeilen.append(schonVorhanden == 1
                          ? "1 Foto war unverändert schon im Buch und wurde übersprungen."
                          : "\(schonVorhanden) Fotos waren unverändert schon im Buch und wurden übersprungen.")
        }
        if aufgenommen + schonVorhanden + ersetzt > 0 {
            zeilen.append("Wo sie stehen: Plusmenü \u{2192} Fotos \u{2192} \u{201E}Zuletzt eingelesene Fotos\u{201C}.")
        }
        if neueTage > 0 { zeilen.append("\(neueTage) neue Kapitel angelegt.") }
        if eingeschoben > 0 {
            zeilen.append("\(eingeschoben) Fotos sind in gestalteten Kapiteln nach Datum eingeordnet; dafür wurden \(neuGesetzteSeiten) Seiten ohne eigene Gestaltung neu gesetzt. Seiten mit Text oder Handarbeit blieben, wie sie waren.")
        }
        if imGesperrten > 0 {
            zeilen.append("\(imGesperrten) Fotos gehören zu gesperrten Kapiteln und stehen noch auf keiner Seite (\u{201E}Zuletzt eingelesene Fotos\u{201C}).")
        }
        if wartenAufNeuverteilen > 0 {
            zeilen.append("\(wartenAufNeuverteilen) Fotos gehören zu Kapiteln mit Handarbeit und stehen noch auf keiner Seite \u{2014} dort \u{201E}Ab hier neu aufbauen\u{201C} ab der passenden Stelle.")
        }
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
        // KAPITELWEISE (ab 1.0.11, Ansage des Nutzers 11/2026: „regelmäßig in
        // ein bestehendes Projekt neue Fotos hineinladen … egal, ob ich auch
        // Fotos markiere, die bereits vorhanden sind … Vorhandene Fotos werden
        // automatisch nicht importiert."): Ein Foto gilt als vorhanden, wenn
        // es denselben Mediathekseintrag hat — oder, für Fotos von vor dieser
        // Fassung und aus Dateien, dieselbe Aufnahmesekunde und dieselben
        // Maße. Auch Fotos in der Ablage zählen: Wer eines aus dem Buch
        // genommen hat, will es nicht beim nächsten Einlesen zurück.
        var bekannteKennungen = Set(reise.fotos.compactMap(\.mediathek))
        var bekannteAufnahmen = Set(reise.fotos.filter { !$0.grafik }.compactMap { f in
            f.aufnahme.map { Self.fingerabdruck($0, breite: f.breite, hoehe: f.hoehe) }
        })
        // Welches vorhandene Foto ein übersprungenes ist (ab 1.0.40) — damit
        // „Zuletzt eingelesene Fotos" es zeigen kann. Gemeldet 11/2026:
        // „mir gesagt wird, dass diese bereits im Projekt enthalten seien.
        // Ich finde sie aber an keiner Stelle."
        var idNachKennung: [String: UUID] = [:]
        var idNachAufnahme: [String: UUID] = [:]
        for f in reise.fotos {
            if let k = f.mediathek { idNachKennung[k] = f.id }
            if !f.grafik, let wann = f.aufnahme {
                idNachAufnahme[Self.fingerabdruck(wann, breite: f.breite, hoehe: f.hoehe)] = f.id
            }
        }
        var vorhandene: [UUID] = []
        var ersetzteFotos: [UUID] = []
        merken()
        var neueFotos: [UUID] = []

        for stelle in 0 ..< anzahl {
            if anzahl > 1 { beschaeftigt = "Foto \(stelle + 1) von \(anzahl)" }
            // Absturzspur (ab 1.0.32, gemeldet: Absturz nach dem Wählen eines
            // einzelnen Fotos — Ursache aus dem Quelltext nicht zu finden).
            Absturzspur.beginnt("Fotos einlesen: Foto \(stelle + 1) von \(anzahl) holen und ablegen")
            guard let bild = await naechstes(stelle) else {
                bericht.abgewiesen += 1
                continue
            }
            var befund = Bildleser.befund(datei: bild.daten)

            // KAPITELWEISE (ab 1.0.30): DAS DATUM DER MEDIATHEK GEHT VOR.
            // Gemeldet 11/2026: Bildschirmfotos aus alten Videos, deren
            // Zeitstempel danach in der Mediathek geändert wurde (Fotos von
            // Apple zeigt sie richtig einsortiert), landeten im Kapitel des
            // Tages, an dem sie entstanden — die Datei trägt weiter ihr
            // Erstellungsdatum; geändert wird nur der Eintrag in der
            // Mediathek. Was dort steht, ist, was der Nutzer sieht und
            // gewollt hat.
            if let kennung = bild.kennung,
               Self.mediathekStand == .authorized || Self.mediathekStand == .limited,
               let wann = PHAsset.fetchAssets(withLocalIdentifiers: [kennung], options: nil).firstObject?.creationDate
            {
                // Erst ab anderthalb Tagen Abstand: Das EXIF-Datum ist
                // Ortszeit ohne Zone, die Mediathek ein echter Zeitpunkt —
                // ein paar Stunden Unterschied sind die Zeitzone, kein
                // geändertes Datum.
                if befund.aufnahme.map({ abs($0.timeIntervalSince(wann)) > 36 * 3600 }) ?? true {
                    befund.aufnahme = wann
                    befund.tagesschluessel = Tagesdatum(wann).schluessel
                    bericht.datumAusMediathek += 1
                }
            }

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

            // SCHON IM BUCH — UNVERÄNDERT ODER BEARBEITET? (ab 1.0.50)
            //
            // Ansage des Nutzers, 11/2026: „Wenn ein Bild den gleichen
            // Titel und Zeitstempel hat, dann soll geprüft werden, ob ein
            // Neuimport anders ist und dann das Original ersetzen … in
            // Größe und Position genau an derselben Stelle." Bis 1.0.49
            // hieß „gleicher Eintrag" oder „gleiche Sekunde und Maße"
            // immer: überspringen.
            if let alt = vorgaenger(kennung: bild.kennung, name: bild.name, befund: befund,
                                    idNachKennung: idNachKennung) {
                if await Self.gleichesBild(bild.daten, pfad: Bildarchiv.shared.pfad(reise.id, datei: alt.datei)) {
                    bericht.schonVorhanden += 1
                    vorhandene.append(alt.id)
                } else if fotoErsetzen(alt.id, durch: bild, befund: befund) {
                    bericht.ersetzt += 1
                    ersetzteFotos.append(alt.id)
                } else {
                    bericht.abgewiesen += 1
                }
                continue
            }
            if let kennung = bild.kennung, bekannteKennungen.contains(kennung) {
                bericht.schonVorhanden += 1
                if let id = idNachKennung[kennung] { vorhandene.append(id) }
                continue
            }
            if let wann = befund.aufnahme,
               bekannteAufnahmen.contains(Self.fingerabdruck(wann, breite: befund.breite, hoehe: befund.hoehe)) {
                bericht.schonVorhanden += 1
                if let id = idNachAufnahme[Self.fingerabdruck(wann, breite: befund.breite, hoehe: befund.hoehe)] {
                    vorhandene.append(id)
                }
                continue
            }

            let name: String
            do {
                name = try Bildarchiv.shared.ablegen(bild.daten, reise: reise.id, endung: bild.endung)
            } catch {
                bericht.abgewiesen += 1
                continue
            }

            var foto = Foto(
                datei: name,
                breite: befund.breite,
                hoehe: befund.hoehe,
                aufnahme: befund.aufnahme,
                tagesschluessel: befund.tagesschluessel,
                koordinate: befund.koordinate,
                ortsquelle: befund.koordinate == nil ? .keiner : befund.quelle
            )
            foto.mediathek = bild.kennung
            foto.name = bild.name.map(Self.namenskern)
            if let k = bild.kennung { bekannteKennungen.insert(k) }
            if let wann = foto.aufnahme {
                bekannteAufnahmen.insert(Self.fingerabdruck(wann, breite: foto.breite, hoehe: foto.hoehe))
            }
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
            neueFotos.append(foto.id)
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
        Absturzspur.beginnt("Fotos einlesen: \(neueFotos.count) neue Fotos \u{2014} unberührte Kapitel neu setzen")
        alleNeuAnordnen(nurUnberuehrte: true)
        Absturzspur.beginnt("Fotos einlesen: neue Fotos in gestaltete Kapitel einschieben")
        // KAPITELWEISE (ab 1.0.32, gemeldet 11/2026: „ein weiteres Foto …
        // Da es mir sehr unsicher ist, die Fotos aus der Mediathek jetzt …
        // neu einzulesen, weil ich befürchte, dass dann alles andere wieder
        // verschoben wird"). Kapitel mit Handarbeit setzt das Einlesen nicht
        // neu — ein neues Foto stand dort bisher auf KEINER Seite. Bis zu
        // sechs neue je Kapitel kommen jetzt neben ihren zeitlichen Nachbarn
        // (`fotoEinzelnEinsetzen`); bei mehr wäre das Zerteilen einzelner
        // Rahmen kein Satz mehr — dann sagt der Bericht, wo neu aufzubauen ist.
        //
        // Seit 1.0.43 (Ansage des Nutzers 11/2026: „wenn auf einer Seite
        // schon Text ist, habe ich sie bearbeitet. Wenn noch nicht, können
        // die Fotos ab da doch auch neu angeordnet werden"): Gestaltete
        // Kapitel ordnen ALLE neuen Fotos nach Datum ein — feste Seiten
        // (Handarbeit, Text, Geburtstag) bleiben, die freien Seiten
        // dazwischen werden samt neuer Fotos neu gesetzt
        // (`neueFotosEinordnen`). Gesperrte Kapitel fasst das Einlesen gar
        // nicht an; ihre neuen Fotos stehen in „Zuletzt eingelesene Fotos".
        var jeKapitel: [Int: [UUID]] = [:]
        for id in neueFotos {
            guard let t = reise.tage.firstIndex(where: { $0.fotos.contains(id) }) else { continue }
            let tag = reise.tage[t]
            guard tag.seiten.contains(where: { $0.vonHand }) || tag.gesperrt else { continue }
            guard !tag.seiten.contains(where: { $0.bloecke.contains { $0.fotoID == id } }) else { continue }
            jeKapitel[t, default: []].append(id)
        }
        for (t, ids) in jeKapitel {
            if reise.tage[t].gesperrt {
                bericht.imGesperrten += ids.count
                continue
            }
            let r = neueFotosEinordnen(kapitel: t, neu: ids)
            bericht.eingeschoben += r.fotos
            bericht.neuGesetzteSeiten += r.seiten
            bericht.wartenAufNeuverteilen += ids.count - r.fotos
        }
        // Zuletzt eingelesen (ab 1.0.40): neue zuerst, dann übersprungene.
        var liste: [UUID] = []
        for id in neueFotos + ersetzteFotos + vorhandene where !liste.contains(id) { liste.append(id) }
        if !liste.isEmpty { zuletztEingelesen = liste }
        // Das erste neue Foto, das auf einer Seite steht, wird gezeigt und
        // gewählt — sonst sucht man es (gemeldet 11/2026: „unter einem
        // bestehenden Bild platziert … zunächst nicht erkannt").
        if let erstes = (neueFotos + ersetzteFotos).first(where: { fundort($0).block != nil }) { fotoZeigen(erstes) }
        sofortSichern()
        Absturzspur.endet()
        return bericht
    }

    nonisolated static func fingerabdruck(_ wann: Date, breite: Double, hoehe: Double) -> String {
        "\(Int(wann.timeIntervalSinceReferenceDate.rounded()))|\(Int(breite.rounded()))x\(Int(hoehe.rounded()))"
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
        // KAPITELWEISE: Jeder Abschnitt wird ein TEXTEINTRAG mit dem Datum
        // seiner Datumszeile — und landet damit im Kapitel, in das das
        // Datum fällt. Im Reisebuch wurde er der Text EINES Tages; hier
        // trägt ein Kapitel viele Einträge, und eine Zuweisung würde den
        // vorigen Abschnitt desselben Kapitels überschreiben.
        merken()
        var neueKapitel = Set<Tagesdatum>()
        var ersetzt = 0
        let bekannt = Set(reise.tage.map(\.datum))
        for abschnitt in befund.abschnitte {
            if ersetzen {
                let vorher = reise.eintraege.count
                reise.eintraege.removeAll { $0.tagesdatum == abschnitt.datum }
                ersetzt += vorher - reise.eintraege.count
            }
            var rumpf = abschnitt.text
            if !abschnitt.unterueberschrift.isEmpty { rumpf = abschnitt.unterueberschrift + "\n" + rumpf }
            reise.eintraege.append(Texteintrag(titel: abschnitt.ueberschrift, text: rumpf, zeit: abschnitt.datum.mittag))
            let stelle = reise.tagIndex(fuer: abschnitt.datum)
            if !bekannt.contains(reise.tage[stelle].datum) { neueKapitel.insert(reise.tage[stelle].datum) }
        }
        for stelle in reise.tage.indices where !reise.kapiteleintraege(reise.tage[stelle].datum).isEmpty {
            reise.tage[stelle].text = reise.kapiteltext(reise.tage[stelle].datum)
        }

        if befund.hatVorspann, vorspannAlsUntertitel {
            reise.untertitel = befund.vorspann
        }

        alleNeuAnordnen(nurUnberuehrte: true)
        sofortSichern()
        // Eingelesene Texte gleich durch die automatische Textpflege.
        Task { @MainActor in await self.texteAutomatischPruefen(melden: false) }

        var zeilen = ["\(befund.abschnitte.count) Texte übernommen."]
        if !neueKapitel.isEmpty { zeilen.append("\(neueKapitel.count) neue Kapitel angelegt.") }
        if ersetzt > 0 { zeilen.append("\(ersetzt) ältere Texte mit demselben Datum ersetzt.") }
        if befund.hatVorspann, !vorspannAlsUntertitel {
            zeilen.append("Der Vorspann vor der ersten Datumszeile wurde NICHT übernommen.")
        }
        return zeilen.joined(separator: " ")
    }
}
