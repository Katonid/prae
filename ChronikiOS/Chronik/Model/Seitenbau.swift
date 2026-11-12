import UIKit

// DER SEITENBAU — WIE AUS INHALTEN SEITEN WERDEN.
//
// Reihenfolge des Buches:
//
//   Titelseite · freie Seiten am Buchanfang
//   je Kapitel: Kapitelseite · freie Seiten am Kapitelanfang · Inhaltsseiten
//   freie Seiten am Buchende (und jede, deren Anker verschwunden ist)
//
// Innerhalb eines Kapitels läuft die Zeit. Ein TEXT nimmt die Fotos mit,
// die unmittelbar nach ihm kommen (höchstens zwei, oben auf seiner ersten
// Seite); passt er nicht auf eine Seite, läuft er auf Folgeseiten weiter.
// Fotos ohne Text davor füllen eigene Seiten bis zur eingestellten Zahl.
//
// **Gemessen wird der Umbruch, nicht geschätzt** (`Textsatz.aufteilen`) —
// mit genau dem Satz, mit dem die Seite später gezeichnet wird. Ein Text,
// der beim Messen sechs Zeilen hat und beim Zeichnen sieben, liefe unten
// aus seinem Feld (Lehre aus dem Reisebuch).
//
// Eine freie Seite mit `nachInhalt(x)` steht hinter der Seite, auf der x
// ENDET. Bei einem Text, der über drei Seiten läuft, ist das die dritte —
// eine freie Seite mitten in einem Text wäre ein Fehler, kein Wunsch.

enum Inhalt: Identifiable {
    case text(Texteintrag)
    case foto(Fotoeintrag)

    var id: UUID {
        switch self {
        case .text(let t): return t.id
        case .foto(let f): return f.id
        }
    }

    var zeit: Date {
        switch self {
        case .text(let t): return t.zeit
        case .foto(let f): return f.zeit
        }
    }

    var istText: Bool {
        if case .text = self { return true }
        return false
    }

    /// Nach der Zeit; bei gleicher Zeit der Text vor dem Foto.
    static func frueher(_ a: Inhalt, _ b: Inhalt) -> Bool {
        if a.zeit != b.zeit { return a.zeit < b.zeit }
        if a.istText != b.istText { return a.istText }
        return a.id.uuidString < b.id.uuidString
    }
}

struct Kapitelgruppe: Identifiable {
    let kapitel: Kapitel
    let titel: String
    let inhalte: [Inhalt]
    var id: String { kapitel.id }
}

struct Textstueck {
    let eintrag: UUID
    let inhalt: NSAttributedString
    let teil: Int
    let teile: Int
}

struct Seite: Identifiable {
    /// Wie die Fotos einer Inhaltsseite liegen.
    enum Muster: String {
        /// Ein Foto, groß — im modernen Stil bis an den Seitenrand.
        case aufmacher
        /// Blocksatz nach Seitenverhältnis.
        case reihen
        /// Ein großes Foto, die übrigen in Reihen daneben.
        case grossUndKlein
    }

    enum Art {
        case titel(zeitraum: String, foto: Fotoeintrag?)
        case kapitel(titel: String, zeitraum: String, texte: Int, fotos: Int, foto: Fotoeintrag?)
        case inhalt(text: Textstueck?, fotos: [Fotoeintrag], muster: Muster)
        case frei(FreieSeite)
    }

    let id: String
    let art: Art
    var nummer = 0
    var kopfzeile: String?
    /// Wohin eine freie Seite gehört, die man HINTER dieser einfügt.
    let stelleDanach: Einfuegestelle
    /// Ändert sich, sobald sich am Bild der Seite etwas ändert — daran
    /// hängt das Neuzeichnen der Vorschau.
    var signatur = ""

    var freieSeite: FreieSeite? {
        if case .frei(let f) = art { return f }
        return nil
    }
}

enum Seitenbau {
    static func gruppen(_ buch: Buch) -> [Kapitelgruppe] {
        let r = buch.raster
        var nachIndex: [Int: [Inhalt]] = [:]
        for t in buch.texte { nachIndex[r.index(fuer: t.zeit), default: []].append(.text(t)) }
        for f in buch.fotos { nachIndex[r.index(fuer: f.zeit), default: []].append(.foto(f)) }
        var indizes = nachIndex.keys.sorted()
        if buch.leereKapitelZeigen, let a = indizes.first, let b = indizes.last, b - a < 1000 {
            indizes = Array(a...b)
        }
        return indizes.map { k in
            let kapitel = r.kapitel(k)
            let inhalte = (nachIndex[k] ?? []).sorted(by: Inhalt.frueher)
            return Kapitelgruppe(kapitel: kapitel, titel: buch.kapitelTitel(kapitel), inhalte: inhalte)
        }
    }

    /// Von wann bis wann das Buch reicht, in Jahren.
    static func gesamtzeitraum(_ buch: Buch) -> String {
        let zeiten = buch.texte.map(\.zeit) + buch.fotos.map(\.zeit)
        guard let a = zeiten.min(), let e = zeiten.max() else { return "" }
        let kal = Zeitraster.kalender
        let ja = kal.component(.year, from: a)
        let je = kal.component(.year, from: e)
        return ja == je ? "\(ja)" : "\(ja) – \(je)"
    }

    static func freiSeite(_ f: FreieSeite) -> Seite {
        Seite(id: "frei-\(f.id.uuidString)", art: .frei(f), stelleDanach: f.stelle)
    }

    /// Das Bild für eine große Fläche: das erste Querformat, sonst das erste.
    static func aufmacherfoto(_ fotos: [Fotoeintrag], ausser: UUID? = nil) -> Fotoeintrag? {
        let liste = fotos.filter { $0.id != ausser }
        return liste.first { $0.seitenverhaeltnis >= 1.2 } ?? liste.first
    }

    /// Wie viele Fotos nacheinander auf eine Seite kommen. Der Wechsel
    /// macht den Rhythmus: eine volle Seite, ein Aufmacher, wieder eine
    /// volle. Der klassische Stil bleibt gleichmäßig.
    private static func seitengroessen(_ stil: Buchstil, jeSeite: Int) -> [Int] {
        if stil == .klassisch { return [jeSeite] }
        return [3, 1, 4, 2, 5, 3, 1, 4].map { min($0, jeSeite) }
    }

    static func seiten(_ buch: Buch) -> [Seite] {
        let stil = buch.stil
        let geo = Seitengeometrie(groesse: buch.format.groesse, stil: stil)
        var liste: [Seite] = []
        var platziert = Set<UUID>()

        func freie(_ passt: (Einfuegestelle) -> Bool) {
            for f in buch.freieSeiten where !platziert.contains(f.id) && passt(f.stelle) {
                platziert.insert(f.id)
                liste.append(freiSeite(f))
            }
        }

        let titelfoto = titelbild(buch) ?? aufmacherfoto(buch.fotos.sorted { $0.zeit < $1.zeit })
        liste.append(Seite(id: "titel", art: .titel(zeitraum: gesamtzeitraum(buch), foto: titelfoto),
                           stelleDanach: .buchAnfang))
        freie { $0 == .buchAnfang }

        let jeSeite = min(6, max(1, buch.fotosJeSeite))
        let beimText = min(stil.fotosBeimText, jeSeite)
        let groessen = seitengroessen(stil, jeSeite: jeSeite)
        var fotoseite = 0

        for g in gruppen(buch) {
            let texte = g.inhalte.filter(\.istText).count
            let schluessel = g.kapitel.schluessel
            let kapitelfotos = g.inhalte.compactMap { inhalt -> Fotoeintrag? in
                if case .foto(let f) = inhalt { return f }
                return nil
            }
            // Das Kapitelbild steht groß auf der Kapitelseite und deshalb
            // nicht noch einmal auf einer Inhaltsseite.
            let kapitelfoto = aufmacherfoto(kapitelfotos, ausser: titelfoto?.id)
            liste.append(Seite(id: "kapitel-\(schluessel)",
                               art: .kapitel(titel: g.titel, zeitraum: g.kapitel.zeitraum,
                                             texte: texte, fotos: g.inhalte.count - texte, foto: kapitelfoto),
                               stelleDanach: .kapitelAnfang(schluessel)))
            freie { $0 == .kapitelAnfang(schluessel) }

            let inhalte = g.inhalte.filter { $0.id != kapitelfoto?.id }
            var i = 0
            while i < inhalte.count {
                switch inhalte[i] {
                case .text(let t):
                    var fotos: [Fotoeintrag] = []
                    var j = i + 1
                    while j < inhalte.count, fotos.count < beimText, case .foto(let f) = inhalte[j] {
                        fotos.append(f)
                        j += 1
                    }
                    let ids = [t.id] + fotos.map(\.id)
                    let anker = Einfuegestelle.nachInhalt(ids[ids.count - 1])
                    let erste = fotos.isEmpty ? geo.innen.size : geo.textMitFotos().text.size
                    let stuecke = Textsatz.aufteilen(Textsatz.eintrag(t, stil: stil), erste: erste, folge: geo.innen.size)
                    for (n, s) in stuecke.enumerated() {
                        let stueck = Textstueck(eintrag: t.id, inhalt: s, teil: n, teile: stuecke.count)
                        liste.append(Seite(id: "t-\(t.id.uuidString)-\(n)",
                                           art: .inhalt(text: stueck, fotos: n == 0 ? fotos : [], muster: .reihen),
                                           kopfzeile: g.titel,
                                           stelleDanach: anker))
                    }
                    freie { stelle in
                        if case .nachInhalt(let x) = stelle { return ids.contains(x) }
                        return false
                    }
                    i = j
                case .foto:
                    var lauf: [Fotoeintrag] = []
                    var j = i
                    while j < inhalte.count, case .foto(let f) = inhalte[j] {
                        lauf.append(f)
                        j += 1
                    }
                    for gruppe in tagesgruppen(lauf, getrennt: stil != .klassisch) {
                        var rest = gruppe[...]
                        while !rest.isEmpty {
                            var zahl = min(groessen[fotoseite % groessen.count], rest.count)
                            // Kein einzelnes Foto als Rest hinter einer vollen Seite.
                            if rest.count - zahl == 1, zahl > 1, zahl < jeSeite { zahl += 1 }
                            let fotos = Array(rest.prefix(zahl))
                            rest = rest.dropFirst(zahl)
                            let muster: Seite.Muster = fotos.count == 1
                                ? .aufmacher
                                : (fotos.count >= 3 && stil != .klassisch && fotoseite % 2 == 0 ? .grossUndKlein : .reihen)
                            fotoseite += 1
                            let ids = fotos.map(\.id)
                            liste.append(Seite(id: "f-\(ids[0].uuidString)",
                                               art: .inhalt(text: nil, fotos: fotos, muster: muster),
                                               kopfzeile: g.titel,
                                               stelleDanach: .nachInhalt(ids[ids.count - 1])))
                            freie { stelle in
                                if case .nachInhalt(let x) = stelle { return ids.contains(x) }
                                return false
                            }
                        }
                    }
                    i = j
                }
            }
        }
        // Buchende — und jede freie Seite, deren Inhalt oder Kapitel es
        // nicht mehr gibt. Sie verschwindet nicht still, sie rückt ans Ende.
        freie { _ in true }

        for n in liste.indices {
            liste[n].nummer = n + 1
            liste[n].signatur = signatur(liste[n], buch: buch)
        }
        return liste
    }

    /// Fotos eines Tages bleiben auf ihren Seiten unter sich — so erzählt
    /// das Buch Tag für Tag. Ein Tag mit nur einem Foto wird mit dem
    /// nächsten zusammengelegt, sonst bestünde ein Urlaub aus Aufmachern.
    private static func tagesgruppen(_ fotos: [Fotoeintrag], getrennt: Bool) -> [[Fotoeintrag]] {
        guard getrennt else { return fotos.isEmpty ? [] : [fotos] }
        let kal = Zeitraster.kalender
        var gruppen: [[Fotoeintrag]] = []
        for f in fotos {
            if let letzte = gruppen.last?.last, kal.isDate(letzte.zeit, inSameDayAs: f.zeit) {
                gruppen[gruppen.count - 1].append(f)
            } else {
                gruppen.append([f])
            }
        }
        var zusammen: [[Fotoeintrag]] = []
        for g in gruppen {
            if let letzte = zusammen.last, letzte.count < 2 {
                zusammen[zusammen.count - 1].append(contentsOf: g)
            } else {
                zusammen.append(g)
            }
        }
        if zusammen.count > 1, let letzte = zusammen.last, letzte.count < 2 {
            zusammen.removeLast()
            zusammen[zusammen.count - 1].append(contentsOf: letzte)
        }
        return zusammen
    }

    private static func signatur(_ s: Seite, buch: Buch) -> String {
        let kopf = "\(buch.format.rawValue)|\(buch.stil.rawValue)|\(s.nummer)|\(s.kopfzeile ?? "")|"
        func bild(_ f: Fotoeintrag?) -> String { f.map { "\($0.datei)~\($0.unterschrift)" } ?? "" }
        switch s.art {
        case .titel(let zeitraum, let foto):
            return kopf + "T|\(buch.titel)|\(buch.untertitel)|\(zeitraum)|\(bild(foto))"
        case .kapitel(let titel, let zeitraum, let texte, let fotos, let foto):
            return kopf + "K|\(titel)|\(zeitraum)|\(texte)|\(fotos)|\(bild(foto))"
        case .inhalt(let text, let fotos, let muster):
            let bilder = fotos.map { bild($0) }.joined(separator: ",")
            return kopf + "I|\(muster.rawValue)|\(text?.inhalt.string.hashValue ?? 0)|\(text?.teil ?? -1)|\(bilder)"
        case .frei(let f):
            return kopf + "F|\(f.vorlage.rawValue)|\(String(describing: f.felder))"
        }
    }

    static func titelbild(_ buch: Buch) -> Fotoeintrag? {
        guard let id = buch.titelfoto else { return nil }
        return buch.fotos.first { $0.id == id }
    }
}

// MARK: - Geometrie der Seite

struct Seitengeometrie {
    let groesse: CGSize
    var stil: Buchstil = .klassisch

    var rand: CGFloat { (min(groesse.width, groesse.height) * 0.08).rounded() }
    var abstand: CGFloat { stil.fuge }
    var seite: CGRect { CGRect(origin: .zero, size: groesse) }
    var innen: CGRect { seite.insetBy(dx: rand, dy: rand) }
    var istQuer: Bool { groesse.width > groesse.height * 1.05 }

    /// Wo die Fotos einer reinen Fotoseite liegen. Modern: schmaler Rand,
    /// damit die Bilder die Seite tragen.
    var fotoflaeche: CGRect {
        stil == .modern ? seite.insetBy(dx: (rand * 0.55).rounded(), dy: (rand * 0.55).rounded()) : innen
    }

    /// Erste Seite eines Textes mit Fotos. Modern: die Fotos als Band bis
    /// an drei Seitenkanten, der Text darunter (im Querformat: links die
    /// Fotos bis an den Rand, rechts der Text). Sonst: Fotos oben im
    /// Satzspiegel.
    func textMitFotos() -> (fotos: CGRect, text: CGRect) {
        if stil == .modern {
            if istQuer {
                let b = (groesse.width * 0.5).rounded()
                return (CGRect(x: 0, y: 0, width: b, height: groesse.height),
                        CGRect(x: b + rand * 0.8, y: innen.minY, width: groesse.width - b - rand * 1.8, height: innen.height))
            }
            let h = (groesse.height * 0.46).rounded()
            let oben = h + (rand * 0.7).rounded()
            return (CGRect(x: 0, y: 0, width: groesse.width, height: h),
                    CGRect(x: innen.minX, y: oben, width: innen.width, height: innen.maxY - oben))
        }
        let teile = istQuer
            ? Self.nebeneinander(innen, abstand: rand * 0.5, anteil: 0.5)
            : Self.untereinander(innen, abstand: rand * 0.4, anteil: 0.46)
        return (teile[0], teile[1])
    }

    static func untereinander(_ r: CGRect, abstand a: CGFloat, anteil: CGFloat) -> [CGRect] {
        let h1 = ((r.height - a) * anteil).rounded()
        return [CGRect(x: r.minX, y: r.minY, width: r.width, height: h1),
                CGRect(x: r.minX, y: r.minY + h1 + a, width: r.width, height: r.height - h1 - a)]
    }

    static func nebeneinander(_ r: CGRect, abstand a: CGFloat, anteil: CGFloat) -> [CGRect] {
        let b1 = ((r.width - a) * anteil).rounded()
        return [CGRect(x: r.minX, y: r.minY, width: b1, height: r.height),
                CGRect(x: r.minX + b1 + a, y: r.minY, width: r.width - b1 - a, height: r.height)]
    }
}

// MARK: - Freie Seiten einfügen und verschieben

extension Buch {
    /// Fügt freie Seiten unmittelbar HINTER `seite` ein.
    mutating func freieSeitenEinfuegen(_ neue: [FreieSeite], nach seite: Seite) {
        var neue = neue
        let stelle = seite.stelleDanach
        for i in neue.indices { neue[i].stelle = stelle }
        let ort: Int
        if let f = seite.freieSeite, let i = freieSeiten.firstIndex(where: { $0.id == f.id }) {
            ort = i + 1
        } else {
            // Freie Seiten an derselben Stelle stehen in der Reihenfolge der
            // Liste; die neue kommt direkt hinter die Seite, also vor sie.
            ort = freieSeiten.firstIndex(where: { $0.stelle == stelle }) ?? freieSeiten.count
        }
        freieSeiten.insert(contentsOf: neue, at: ort)
    }

    /// Rückt eine freie Seite um eine Seite nach vorn oder hinten. Gibt
    /// `false` zurück, wenn es nicht weitergeht.
    @discardableResult
    mutating func verschieben(_ id: UUID, frueher: Bool) -> Bool {
        let vorher = Seitenbau.seiten(self)
        guard let i = vorher.firstIndex(where: { $0.freieSeite?.id == id }),
              let seite = freieSeiten.first(where: { $0.id == id }) else { return false }
        var ohne = self
        ohne.freieSeiten.removeAll { $0.id == id }
        let nachher = Seitenbau.seiten(ohne)
        // Ohne die Seite steht ihr Vorgänger bei i - 1 und ihr Nachfolger
        // bei i. Nach vorn heißt: hinter den Vorvorgänger; nach hinten:
        // hinter den Nachfolger. Vor die Titelseite geht es nicht.
        let ziel = frueher ? i - 2 : i
        guard ziel >= 0, ziel < nachher.count else { return false }
        ohne.freieSeitenEinfuegen([seite], nach: nachher[ziel])
        self = ohne
        return true
    }
}
