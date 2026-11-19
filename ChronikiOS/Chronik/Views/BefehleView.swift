import SwiftUI

// DIE FUNKTIONSSUCHE (KAPITELWEISE, ab 1.0.28).
//
// Ansage des Nutzers 11/2026: „Ich finde, dass die Bedienung der App immer
// unübersichtlicher wird und Funktionen, von denen ich weiß, dass sie
// vorhanden sind, mir nicht auf den ersten Blick entgegenspringen … Dann
// frage ich dich und bin überrascht, in welchem Menü sie gelandet sind."
//
// Eine Lupe oben, ein Suchfeld, alle Funktionen in der Sprache, in der man
// sie sucht („fett", „aufrücken", „sperren", „Lücke", „zurückholen"). Jede
// Zeile sagt, WO die Funktion sonst steht — man lernt die Menüs nebenbei —
// und führt sie, wo es geht, gleich aus. Was eine Geste ist (Doppeltipp,
// Markieren), lässt sich nicht ausführen; dann erklärt die Zeile den Weg.
//
// **Wer eine Funktion baut, trägt sie hier ein.** Eine Funktion, die nur in
// einem Menü steht, ist genau die, nach der dann gefragt wird.
struct BefehleView: View {
    @ObservedObject var werk: Reisewerk
    /// Führt eine Handlung aus, nachdem dieses Blatt geschlossen ist.
    var ausfuehren: (@escaping () -> Void) -> Void
    /// Öffnet ein anderes Blatt.
    var oeffnen: (ReiseView.Blatt) -> Void

    @State private var suche = ""
    @Environment(\.dismiss) private var schliessen

    enum Tat {
        case blatt(ReiseView.Blatt)
        case tun(() -> Void)
        case hinweis
    }

    struct Befehl: Identifiable {
        let id = UUID()
        let gruppe: String
        let titel: String
        let wo: String
        let worte: String
        let symbol: String
        let tat: Tat
    }

    private var gewaehltesFoto: UUID? {
        guard let id = werk.gewaehlterBlock, let b = werk.blockWert(id), let f = b.fotoID,
              werk.reise.foto(f)?.grafik == false else { return nil }
        return f
    }

    private var befehle: [Befehl] {
        var l: [Befehl] = []
        func dazu(_ gruppe: String, _ titel: String, _ wo: String, _ worte: String,
                  _ symbol: String, _ tat: Tat) {
            l.append(Befehl(gruppe: gruppe, titel: titel, wo: wo, worte: worte, symbol: symbol, tat: tat))
        }
        let tag = werk.tag
        let foto = gewaehltesFoto
        let block = werk.gewaehlterBlock

        // Texte
        let t = "Texte"
        dazu(t, "Neuer Text", "Plusmenü \u{2192} Neuer Text", "schreiben diktieren kommentar eintrag einsprechen",
             "square.and.pencil", .blatt(.neuerText))
        dazu(t, "Text vor einem Foto (für einen ganzen Abschnitt)",
             foto == nil ? "Erst ein Foto antippen, dann unten \u{201E}Text davor\u{201C}" : "Foto gewählt \u{2192} unten \u{201E}Text davor\u{201C}",
             "abschnitt mehrere bilder einleitung gruppe überschrift", "text.insert",
             foto.map { .blatt(.textVor($0)) } ?? .hinweis)
        dazu(t, "Erinnerung zu einem Foto einsprechen",
             foto == nil ? "Erst ein Foto antippen, dann unten \u{201E}Erinnerung einsprechen\u{201C}" : "Foto gewählt \u{2192} unten \u{201E}Erinnerung\u{201C}",
             "kommentar diktat mikrofon bild foto text", "mic.fill",
             foto.map { .blatt(.erinnerung($0)) } ?? .hinweis)
        dazu(t, "Alle Texte ansehen und bearbeiten", "Plusmenü \u{2192} Alle Texte",
             "bearbeiten ändern liste gespeichert speicher erinnerungen löschen", "list.bullet.rectangle", .blatt(.texte))
        dazu(t, "Einen Text auf der Seite bearbeiten",
             "Textkasten antippen \u{2192} unten \u{201E}Text bearbeiten\u{201C} \u{2014} oder zweimal in den Text tippen",
             "ändern korrigieren tippen doppeltipp", "character.cursor.ibeam", .hinweis)
        dazu(t, "Wörter fett, kursiv, unterstrichen, größer oder in anderer Schrift",
             "Text bearbeiten, Wörter markieren \u{2192} Leiste über der Tastatur (B, I, U, A, Aa, Normal)",
             "fett kursiv unterstrichen formatieren schriftgröße schriftart markieren", "bold.italic.underline", .hinweis)
        dazu(t, "Texte automatisch korrigieren", "Alle Texte \u{2192} \u{201E}Alle Texte prüfen\u{201C}",
             "ki korrektur rechtschreibung tippfehler leerzeichen", "text.badge.checkmark", .blatt(.texte))
        dazu(t, "Einen Text als fertig markieren", "Alle Texte \u{2192} Text nach rechts wischen",
             "fertig abgeschlossen schützen", "checkmark.seal", .blatt(.texte))
        dazu(t, "Texte aus einer Datei einlesen", "Plusmenü \u{2192} Texte aus einer Datei",
             "word pdf import datei", "doc.text", .blatt(.textimport))

        // Fotos
        let f = "Fotos"
        dazu(f, "Fotos aus der Mediathek oder einem Album", "Plusmenü \u{2192} Fotos aus der Mediathek",
             "importieren laden album galerie nachladen neue fotos", "photo.on.rectangle", .blatt(.fotos))
        dazu(f, "Bilder oder PDF aus Dateien", "Plusmenü \u{2192} Bilder aus Dateien",
             "pdf datei scan dokument", "folder", .blatt(.dateien))
        dazu(f, "Fotoablage: gelöschte Fotos zurückholen", "Plusmenü \u{2192} Fotoablage",
             "gelöscht zurückholen ohne kapitel ablage wiederherstellen", "tray", .blatt(.ablage))
        dazu(f, "Doppelte Fotos suchen", "Mehr \u{2192} Doppelte Fotos suchen",
             "doppelt dubletten zweimal", "square.on.square", .blatt(.duplikate))
        dazu(f, "Bildunterschrift", "Foto antippen \u{2192} unten \u{201E}Bildunterschrift\u{201C}",
             "beschriftung unterschrift", "text.bubble", .hinweis)
        dazu(f, "Foto löschen", "Foto antippen \u{2192} Knopf mit drei Punkten am Foto \u{2192} Entfernen (es kommt in die Fotoablage)",
             "entfernen wegnehmen löschen", "trash", .hinweis)
        dazu(f, "Foto auf eine andere Seite verschieben", "Foto antippen \u{2192} Knopf mit drei Punkten \u{2192} Verschieben, oder Ausschneiden und Einfügen",
             "verschieben seite zurück vor ausschneiden einfügen", "arrow.up.doc", .hinweis)

        // Kapitel und Neu verteilen
        let k = "Kapitel und Neu verteilen"
        if let id = block, werk.automat.istLebensbuch {
            dazu(k, "Ab hier neu aufbauen (Fotos rücken auf)", "Foto oder Text antippen \u{2192} unten \u{201E}Ab hier neu aufbauen\u{201C}",
                 "aufrücken hochziehen lücke gelöscht nachrücken ab hier", "arrow.down.to.line.compact",
                 .tun { werk.abHierNeuAufbauen(block: id) })
        } else {
            dazu(k, "Ab hier neu aufbauen (Fotos rücken auf)", "Erst ein Foto oder einen Text antippen \u{2192} unten \u{201E}Ab hier neu aufbauen\u{201C}",
                 "aufrücken hochziehen lücke gelöscht nachrücken ab hier", "arrow.down.to.line.compact", .hinweis)
        }
        dazu(k, "Ein Kapitel automatisch neu verteilen (Handarbeit verwerfen)",
             "Kapitel-Menü unten rechts \u{2192} \u{201E}Automatisch neu verteilen\u{201C} (fragt vorher nach)",
             "zurücksetzen handarbeit neu anordnen kapitel", "wand.and.stars", .hinweis)
        if let tag {
            dazu(k, tag.gesperrt ? "Sperre dieses Kapitels aufheben" : "Dieses Kapitel sperren (fertig)",
                 "Kapitel-Menü unten rechts \u{2192} \u{201E}Kapitel sperren\u{201C}",
                 "sperren schützen fertig sperre entsperren versehentlich", tag.gesperrt ? "lock.open" : "lock",
                 .tun { werk.sperreUmschalten(tag.id) })
            dazu(k, "Text und Fotos dieses Kapitels", "Kapitel-Menü \u{2192} Text und Fotos",
                 "reihenfolge fotos kapitel inhalt überschrift", "square.and.pencil", .blatt(.tagInhalt(tag.id)))
            if !tag.vorwort {
                dazu(k, "Zeitung und Meldungen", "Kapitel-Menü \u{2192} Zeitung und Meldungen",
                     "zeitung titelseite geburtstag meldungen weltgeschichte", "newspaper", .blatt(.kapitelseiten(tag.id)))
            }
            dazu(k, "Seiten des Kapitels (einfügen, löschen, Reihenfolge)", "Kapitel-Menü \u{2192} Seiten",
                 "seite einfügen löschen reihenfolge leere seite", "rectangle.stack", .blatt(.seiten(tag.id)))
        }
        dazu(k, "Das ganze Buch neu verteilen", "Ganzes Buch \u{2192} Alles neu verteilen",
             "alles neu verteilen gesamt buch", "arrow.triangle.2.circlepath", .blatt(.neuverteilen))
        dazu(k, "Kapitel und Zeitraster (Jahre, Lebensjahre)", "Ganzes Buch \u{2192} Kapitel und Zeitraster",
             "jahr lebensjahr geburtstag einteilen zeitraum raster", "rectangle.split.3x1", .blatt(.kapitelraster))

        // Vorwort
        let v = "Vorwort"
        dazu(v, "Vorwort bearbeiten (Text, Fotos, Schrift, Abstand)", "Ganzes Buch \u{2192} Vorwort",
             "einleitung vorwort schrift abstand zweispaltig", "text.book.closed.fill", .blatt(.vorwort))
        if let i = werk.reise.vorwortIndex {
            dazu(v, "Vorwort: Text neu umfließen lassen", "Vorwort wählen \u{2192} Kapitel-Menü \u{2192} Text neu umfließen lassen",
                 "umfließen umbruch fotos text", "text.justify", .tun { werk.merken(); werk.vorwortNachfuehren(i) })
        }

        // Aussehen
        let a = "Aussehen"
        dazu(a, "Stil des Buches", "Ganzes Buch \u{2192} Stil wählen", "stil farben design aussehen",
             "paintpalette", .blatt(.stil))
        dazu(a, "Schrift, Größe, Zeilenabstand (ganzes Buch)", "Ganzes Buch \u{2192} Schrift und Ausrichtung",
             "schriftart zeilenabstand schriftgröße ausrichtung fett", "textformat", .blatt(.typografie))
        dazu(a, "Schrift nur für einen Textkasten", "Kasten antippen \u{2192} Pinsel oben rechts \u{2192} Schrift an dieser Stelle",
             "inspektor pinsel schrift einzeln", "paintbrush.pointed", .hinweis)
        dazu(a, "Überschriften", "Ganzes Buch \u{2192} Überschriften", "überschrift titel jahreszahl",
             "textformat.size.larger", .blatt(.ueberschriften))
        dazu(a, "Fotos: Rand, Schatten, Drehung", "Ganzes Buch \u{2192} Fotos", "rand schatten drehung rahmen",
             "photo.stack", .blatt(.fotostil))
        dazu(a, "Seitenhintergrund", "Ganzes Buch \u{2192} Seitenhintergrund", "hintergrund papier farbe",
             "square.fill.on.square.fill", .blatt(.hintergrund))
        dazu(a, "Titel, Umschlag und Rücken", "Ganzes Buch \u{2192} Titel, Umschlag und Rücken",
             "titel umschlag cover rücken titelseite", "book.closed.fill", .blatt(.umschlag))

        // Druck und Sichern
        let d = "Druck und Sichern"
        dazu(d, "Als PDF sichern", "Mehr \u{2192} Als PDF sichern", "pdf ausgeben export drucken",
             "square.and.arrow.up", .blatt(.ausgabe))
        dazu(d, "Vor dem Druck prüfen", "Mehr \u{2192} Druckprüfung", "prüfen fehler druckprüfung",
             "checkmark.seal", .blatt(.druckpruefung))
        dazu(d, "Fotobuch der Druckerei, Seitenformat", "Ganzes Buch \u{2192} Fotobuch der Druckerei wählen",
             "druckerei format saal whitewall größe", "printer", .blatt(.seitenformat))
        dazu(d, "Buch als Datei sichern", "Mehr \u{2192} Buch als Datei sichern (alle Bücher: im Regal)",
             "sicherung backup datei sichern", "shippingbox", .hinweis)
        dazu(d, "Rückgängig", "Pfeil oben links (\u{201E}Zurück\u{201C})", "rückgängig zurück widerrufen undo",
             "arrow.uturn.backward", .hinweis)
        dazu(d, "Handbuch", "Fragezeichen unten", "hilfe anleitung handbuch gesten", "book", .blatt(.handbuch))
        return l
    }

    private var gefiltert: [Befehl] {
        let worte = suche.lowercased().split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !worte.isEmpty else { return befehle }
        return befehle.filter { b in
            let heu = (b.titel + " " + b.wo + " " + b.worte + " " + b.gruppe).lowercased()
            return worte.allSatisfy { heu.contains($0) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                let liste = gefiltert
                if liste.isEmpty {
                    Text("Nichts gefunden. Ein anderes Wort versuchen \u{2014} z. B. \u{201E}Foto\u{201C}, \u{201E}Text\u{201C}, \u{201E}Seite\u{201C}.")
                        .foregroundStyle(.secondary)
                }
                ForEach(gruppen(liste), id: \.self) { gruppe in
                    Section(gruppe) {
                        ForEach(liste.filter { $0.gruppe == gruppe }) { b in
                            zeile(b)
                        }
                    }
                }
            }
            .searchable(text: $suche, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Was möchtest du tun? (z. B. fett, sperren, Vorwort)")
            .navigationTitle("Funktion suchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }

    private func gruppen(_ liste: [Befehl]) -> [String] {
        var gesehen: [String] = []
        for b in liste where !gesehen.contains(b.gruppe) { gesehen.append(b.gruppe) }
        return gesehen
    }

    @ViewBuilder
    private func zeile(_ b: Befehl) -> some View {
        let inhalt = HStack(alignment: .top, spacing: 12) {
            Image(systemName: b.symbol)
                .frame(width: 26)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(b.titel).foregroundStyle(.primary)
                Text(b.wo).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if case .hinweis = b.tat {
                EmptyView()
            } else {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        switch b.tat {
        case .blatt(let ziel):
            Button { oeffnen(ziel) } label: { inhalt }
        case .tun(let handlung):
            Button { ausfuehren(handlung) } label: { inhalt }
        case .hinweis:
            inhalt
        }
    }
}
