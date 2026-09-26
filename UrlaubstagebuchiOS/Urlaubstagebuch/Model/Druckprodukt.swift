import Foundation

// EIN PRODUKT DER DRUCKEREI — und alles, was daran hängt (ab 1.0.111).
//
// Ansage des Nutzers, 09/2026, mit der Seite „Profibereich" von Saal
// Digital vor Augen: „Verwende sie, so dass nach Auswahl des Formates
// ‚Saal Digital 21x28 hochkant' diese automatisch angewendet werden. …
// Übernimm alle Formate und alle Maße."
//
// Bis 1.0.110 gab es dafür drei Wege, die einzeln zu gehen waren: das
// Seitenformat, den Anschnitt in der Gestaltung und die Maße des Umschlags
// samt Rückentabelle. Ein Produkt setzt alle drei auf einmal — und nur
// diese; was man SELBST entscheidet (Ränder, Schrift, Stil), bleibt.
//
// **Die Zahlen sind gemessen, nicht abgeschrieben**: `scripts/saal-produkte.py`
// holt sie über dieselbe Schnittstelle, aus der Saals Seite ihre Tabelle
// lädt, in Millimetern und je Papiersorte (`Model/Saalprodukte.swift`).
struct Druckprodukt: Identifiable, Hashable {
    var id: String
    /// Wer druckt (ab 1.0.113: Saal Digital oder WhiteWall).
    var anbieter: String
    var reihe: String
    var name: String
    var papiere: String
    /// Das ENDFORMAT einer Innenseite — Saals Vorlage minus Beschnitt.
    var seiteBreite: Double
    var seiteHoehe: Double
    /// Der Beschnitt der Innenseiten, in Millimetern.
    var anschnitt: Double
    /// Liefert Saal die Innenseiten als DOPPELSEITEN? Dann gibt es am Bund
    /// keinen Beschnitt — Saals Vorlage misst genau zwei Seiten plus zwei
    /// Beschnitte (426 = 2 × 210 + 2 × 3).
    var doppelseiten: Bool
    /// Beschnitt am Bund? Bei Doppelseiten nie; bei WhiteWall auch bei
    /// Einzelseiten nicht (Vorlage: 3 | 3 | 3 | 0).
    var anschnittAmBund: Bool
    /// Der Sicherheitsabstand der Druckerei — `nil`: die Druckerei nennt
    /// keinen, die Einstellung des Buches bleibt.
    var sicherheitsabstand: Double?
    var sicherheitsabstandInnen: Double?
    /// Ist Seite 1 eine LINKE Seite (die Innenseite des Umschlags, U2)?
    /// Bei Saal ja, bei WhiteWall nicht: Dort klebt Vorsatzpapier.
    var seiteEinsLinks: Bool
    var seitenVon: Int
    var seitenBis: Int
    /// In welchen Schritten die Seitenzahl wachsen darf.
    var seitenSchritt: Int
    /// Woher die Zahlen stammen, als Satz.
    var quelle: String?
    var umschlag: Umschlagvorgabe?
    /// Ein Umschlag, der KEIN Bogen mit Rücken ist (Professional Line,
    /// Portfolio Album) — ein eigenes Teil für den Deckel.
    var einzelteil: Einzelteil?

    init(id: String, anbieter: String = "Saal Digital", reihe: String, name: String, papiere: String,
         seiteBreite: Double, seiteHoehe: Double, anschnitt: Double, doppelseiten: Bool,
         anschnittAmBund: Bool? = nil,
         sicherheitsabstand: Double? = nil, sicherheitsabstandInnen: Double? = nil,
         seiteEinsLinks: Bool? = nil,
         seitenVon: Int, seitenBis: Int, seitenSchritt: Int = 2, quelle: String? = nil,
         umschlag: Umschlagvorgabe? = nil, einzelteil: Einzelteil? = nil)
    {
        self.id = id
        self.anbieter = anbieter
        self.anschnittAmBund = anschnittAmBund ?? !doppelseiten
        self.sicherheitsabstand = sicherheitsabstand
        self.sicherheitsabstandInnen = sicherheitsabstandInnen
        self.seiteEinsLinks = seiteEinsLinks ?? doppelseiten
        self.seitenSchritt = seitenSchritt
        self.quelle = quelle
        self.reihe = reihe
        self.name = name
        self.papiere = papiere
        self.seiteBreite = seiteBreite
        self.seiteHoehe = seiteHoehe
        self.anschnitt = anschnitt
        self.doppelseiten = doppelseiten
        self.seitenVon = seitenVon
        self.seitenBis = seitenBis
        self.umschlag = umschlag
        self.einzelteil = einzelteil
    }

    // DER UMSCHLAGBOGEN, wie Saal ihn je Seitenzahl nennt.
    //
    // **Die Hälfte ist FEST, der Rücken folgt der Gesamtbreite.** Saals
    // Spalte „Buchrücken" ist auf ganze Millimeter gerundet und springt in
    // anderen Schritten als die Bogenbreite — beide zugleich gehen mit einer
    // festen Hälfte nicht auf (gemessen: bis zu 3,4 mm auseinander). Genau
    // getroffen wird die BOGENBREITE, denn die prüft der Dienst an der Datei;
    // der Rücken liegt dafür bis zu gut 1,5 mm je Seite neben Saals Angabe.
    // Das deckt Saals eigener Falzbereich (9–17 mm) ab, in den ohnehin nichts
    // Wichtiges gehört.
    //
    // **Der Beschnitt links/rechts ist bei Saal oft größer als oben/unten**
    // (21 × 28: 9,3 gegen 7 mm). Diese App kennt EINEN Beschnitt je Bogen;
    // gesetzt wird der von oben/unten, und was seitlich darüber hinausgeht,
    // liegt als Teil der Hälfte da. Die Hälfte ist dadurch um diesen Betrag
    // breiter, als Saal den Deckel nennt — und genau so viel wird dort außen
    // noch abgeschnitten. Das steht in der Oberfläche.
    struct Umschlagvorgabe: Hashable {
        var haelfteBreite: Double
        var haelfteHoehe: Double
        var anschnitt: Double
        var anschnittSeitlich: Double
        var bogenhoehe: Double
        var stufen: [Stufe]

        struct Stufe: Hashable {
            var abSeiten: Int
            /// Die Rückenbreite, die diese App setzt — so, dass die
            /// Bogenbreite genau stimmt.
            var ruecken: Double
            /// Was Saal nennt, zum Vergleich.
            var bogenbreite: Double
            var rueckenSaal: Double
            var falz: Double

            init(_ abSeiten: Int, _ ruecken: Double, _ bogenbreite: Double,
                 _ rueckenSaal: Double, _ falz: Double)
            {
                self.abSeiten = abSeiten
                self.ruecken = ruecken
                self.bogenbreite = bogenbreite
                self.rueckenSaal = rueckenSaal
                self.falz = falz
            }
        }

        /// Was außen über den Beschnitt oben/unten hinaus noch abgeht.
        var seitlichMehr: Double { max(0, anschnittSeitlich - anschnitt) }

        func stufe(innenseiten: Int) -> Stufe? {
            stufen.filter { $0.abSeiten <= innenseiten }.max { $0.abSeiten < $1.abSeiten }
        }
    }

    struct Einzelteil: Hashable {
        var breite: Double
        var hoehe: Double
        var anschnitt: Double
    }

    // MARK: - Was die App daraus macht

    var istSaal: Bool { anbieter == "Saal Digital" }
    var titel: String { "\(reihe) \(name)" }
    var vollerName: String { "\(anbieter) \u{00B7} \(titel)" }

    var seitenformat: Seitenformat {
        Seitenformat(breite: seiteBreite, hoehe: seiteHoehe, vorlage: id)
    }

    /// Die Rückentabelle, wie `Umschlag` sie liest.
    var rueckentabelle: Rueckentabellen.Vorlage? {
        guard let u = umschlag, let erste = u.stufen.first else { return nil }
        return Rueckentabellen.Vorlage(
            id: id, anbieter: anbieter, produkt: titel,
            breite: seiteBreite, hoehe: seiteHoehe,
            bisSeiten: seitenBis,
            stufen: u.stufen.map { Umschlag.Rueckenstufe(abSeiten: $0.abSeiten, millimeter: $0.ruecken) },
            quelle: (quelle ?? "Von Saal Digital am \(Saalprodukte.stand) über die Schnittstelle der Seite \u{201E}Profibereich\u{201C} geholt")
                + " (ab \(erste.abSeiten) Seiten)."
        )
    }

    // Setzt alles, was der DRUCKEREI gehört — aber nicht das Format selbst:
    // Das ist der heikle Teil und geht über den Formatwechsel mit seiner
    // Rückfrage (mitrechnen / nur das Format), wie jede Formatänderung.
    func anwenden(auf reise: inout Reise) {
        reise.gestaltung.anschnitt = anschnitt
        reise.gestaltung.anschnittAmBund = anschnittAmBund
        // Die Schutzzone nur, wo die Druckerei eine nennt (WhiteWall: 5 mm
        // oben, unten, außen, am Bund keine — die Seiten liegen flach).
        if let s = sicherheitsabstand { reise.gestaltung.sicherheitsabstand = s }
        if let s = sicherheitsabstandInnen { reise.gestaltung.sicherheitsabstandInnen = s }
        if let u = umschlag {
            reise.umschlag.format = Seitenformat(breite: u.haelfteBreite, hoehe: u.haelfteHoehe)
            reise.umschlag.anschnitt = u.anschnitt
            reise.umschlag.tabellenvorlage = id
            reise.umschlag.ohneVorlage = false
            // Eine von Hand eingetragene Rückenstärke und eine eigene
            // Tabelle gingen der Tabelle des Produkts VOR — und stammen fast
            // immer von einer anderen Druckerei. Wer ein Produkt wählt, will
            // dessen Zahlen. Zurück geht es mit „Widerrufen".
            reise.umschlag.rueckenbreiteVonHand = nil
            reise.umschlag.rueckentabelle = []
            reise.umschlag.einband = reihe == "Softcover" ? .softcover : .hardcover
            // SEITE 1 IST BEI SAAL LINKS (ab 1.0.112). Saals Vorlage für 26
            // Seiten sind 13 volle Doppelseiten: Die erste Hälfte ist die
            // Innenseite des vorderen Deckels, wird bedruckt und verklebt,
            // die letzte ebenso hinten — und beide zählen mit. Die
            // Umschlagdatei trägt nur die Außenseite.
            if seiteEinsLinks {
                reise.umschlag.alsBogen = true
                reise.umschlag.innenseitenBogen = true
                reise.umschlag.innenseitenInhalt = true
                reise.umschlag.innenseitenImBlock = true
            } else if !istSaal {
                // SEITE 1 IST BEI WHITEWALL RECHTS (ab 1.0.113): Innen am
                // Deckel klebt Vorsatzpapier, das keiner bedruckt. Die
                // Umschlagvorlage ist EIN Bogen — Außenseite und Rücken.
                reise.umschlag.alsBogen = true
                reise.umschlag.innenseitenBogen = false
                reise.umschlag.innenseitenInhalt = false
                reise.umschlag.innenseitenImBlock = false
            }
        }
    }

    /// Wo Saal auf der LETZTEN Innenseite seinen Strichcode druckt — aus
    /// der Tabelle „Barcode" derselben Schnittstelle, gemessen 26.09.2026.
    /// Gilt für alle Produkte mit Umschlagbogen gleich.
    static let strichcodeText = "Auf die letzte Seite (U3, hinten verklebt) druckt Saal "
        + "unten rechts einen Strichcode: 7,8 \u{00D7} 5,6 mm, 8,9 mm vom rechten und "
        + "4,1 mm vom unteren Rand. Dort nichts Wichtiges hinlegen."

    /// Was `anwenden` ändert, in Worten — für das Blatt davor.
    func aenderungen(_ reise: Reise) -> [String] {
        var zeilen: [String] = []
        let f = seitenformat
        zeilen.append("Seitenformat: \(f.masstext) (Endformat einer Innenseite)")
        // Stück für Stück: `+`, `?:` und Interpolation in einem Ausdruck
        // sprengen den Typprüfer (die Lehre aus 1.0.38).
        var beschnitt = "Beschnitt der Innenseiten: " + Druckvorgabe.zahl(anschnitt) + " mm"
        if doppelseiten {
            beschnitt += ", am Bund keiner (\(anbieter) will Doppelseiten)"
        } else if !anschnittAmBund {
            beschnitt += " oben, unten und außen, am Bund keiner (Einzelseiten)"
        } else {
            beschnitt += " an allen vier Kanten"
        }
        zeilen.append(beschnitt)
        if let s = sicherheitsabstand {
            var satz = "Sicherheitsabstand: " + Druckvorgabe.zahl(s) + " mm"
            if let i = sicherheitsabstandInnen, abs(i - s) > 0.01 {
                satz += ", am Bund " + Druckvorgabe.zahl(i) + " mm"
            }
            satz += " \u{2014} die blaue Linie; was hineinragt, wird rot umrandet"
            zeilen.append(satz)
        }
        var umfang = "Seitenzahl bei \(anbieter): \(seitenVon) bis \(seitenBis)"
        if seitenSchritt > 2 {
            umfang += ", in Schritten von \(seitenSchritt)"
        }
        zeilen.append(umfang)
        if let u = umschlag {
            let halb = Seitenformat(breite: u.haelfteBreite, hoehe: u.haelfteHoehe)
            zeilen.append("Umschlag: je Hälfte \(halb.masstext), Beschnitt \(Druckvorgabe.zahl(u.anschnitt)) mm")
            zeilen.append("Rückenbreite nach Seitenzahl aus der Tabelle von \(anbieter)")
            if seiteEinsLinks {
                var satz = "Seite 1 liegt LINKS: Die erste und die letzte Tagebuchseite werden "
                satz += "die Innenseiten des Umschlags (U2, U3), stehen in der Innenteil-Datei "
                satz += "und zählen bei Saal mit. Die Umschlagdatei trägt nur die Außenseite."
                zeilen.append(satz)
                if istSaal { zeilen.append(Druckprodukt.strichcodeText) }
            } else if !istSaal {
                var satz = "Seite 1 liegt RECHTS: Innen am Deckel klebt Vorsatzpapier, "
                satz += "U2 und U3 werden nicht bedruckt. Die Umschlagdatei ist ein Bogen "
                satz += "mit Außenseite und Rücken."
                zeilen.append(satz)
            }
            if reise.umschlag.rueckenbreiteVonHand != nil || !reise.umschlag.rueckentabelle.isEmpty {
                zeilen.append("Die bisher eingetragene Rückenstärke bzw. eigene Tabelle wird entfernt")
            }
        } else if let e = einzelteil {
            zeilen.append("Der Umschlag ist bei diesem Produkt KEIN Bogen mit Rücken, sondern ein eigenes Teil (\(Druckvorgabe.zahl(e.breite)) \u{00D7} \(Druckvorgabe.zahl(e.hoehe)) mm mit \(Druckvorgabe.zahl(e.anschnitt)) mm Beschnitt). Das kann diese App nicht als Umschlag ausgeben \u{2014} die Umschlag-Einstellungen bleiben, wie sie sind.")
        }
        if !istSaal {
            var satz = "WhiteWalls Exportvorgabe verlangt ein PDF ohne Transparenz. "
            satz += "Das stellt sich NICHT von selbst um: \u{201E}Ohne Transparenz\u{201C} "
            satz += "beim Ausgeben nimmt die Wasserzeichen ganz heraus \u{2014} ob das "
            satz += "gewollt ist, entscheidest du dort."
            zeilen.append(satz)
        }
        return zeilen
    }

    // MARK: - Nachschlagen

    static let alle: [Druckprodukt] = Saalprodukte.alle + Whitewallprodukte.alle

    /// Die Anbieter in der Reihenfolge, in der sie im Blatt stehen.
    static var anbieterliste: [String] {
        var gesehen: [String] = []
        for p in alle where !gesehen.contains(p.anbieter) { gesehen.append(p.anbieter) }
        return gesehen
    }

    static func produkt(_ id: String?) -> Druckprodukt? {
        guard let id else { return nil }
        return alle.first { $0.id == id }
    }

    /// Die Reihen eines Anbieters in der Reihenfolge, in der er sie zeigt.
    static func reihen(von anbieter: String) -> [String] {
        var gesehen: [String] = []
        for p in alle where p.anbieter == anbieter && !gesehen.contains(p.reihe) {
            gesehen.append(p.reihe)
        }
        return gesehen
    }
}
