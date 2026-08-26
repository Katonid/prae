import Foundation
import UIKit

// Fertige Tafeln für die Bildschirmfotos im App Store.
//
// Apple verlangt Bilder in genauen Pixelmaßen, und die bekommt man nur aus
// einem Simulator der passenden Geräteklasse. Von Hand ist das mühsam: App
// starten, Tafel einrichten, Namen ziehen, fotografieren — und beim nächsten
// Mal sieht alles anders aus.
//
// Deshalb dieser Weg: Wird die App mit `-schaufenster 1` gestartet, ersetzt
// sie ihren Bestand durch eine **fertig eingerichtete Tafel** und schaltet
// den Abgleich ab. Die Zahl wählt die Szene. Der Arbeitsablauf
// `tafelbild-appstore-bilder.yml` startet die App damit mehrfach und
// fotografiert jedes Mal.
//
// Im normalen Betrieb ist das alles tot: Ohne den Startwert wird `aktiv` nie
// wahr, und niemand kann ihn versehentlich setzen — Startwerte lassen sich
// nur beim Start über Xcode oder `simctl` mitgeben.
//
// **Wichtig:** Die Szenen dürfen nichts zeigen, was die App nicht wirklich
// kann. Ein Bildschirmfoto im App Store ist ein Versprechen.

enum Schaufenster {
    /// Läuft die App gerade für ein Bildschirmfoto?
    static var aktiv: Bool { szeneNummer != nil }

    /// Welche Szene gewünscht ist (1 …). nil = normaler Betrieb.
    static var szeneNummer: Int? {
        let argumente = ProcessInfo.processInfo.arguments
        guard let stelle = argumente.firstIndex(of: "-schaufenster"),
              stelle + 1 < argumente.count,
              let nummer = Int(argumente[stelle + 1]), nummer > 0
        else { return nil }
        return nummer
    }

    static let listenID = "schaufenster-liste"

    /// Die Namensliste, aus der die Szenen ziehen.
    ///
    /// Bewusst EIN fester Wert und keine Funktion: Die Einträge bekommen beim
    /// Erzeugen zufällige Kennungen, und die Szenen verweisen auf sie. Würde
    /// bei jedem Aufruf eine neue Liste entstehen, zeigte das Element den
    /// gezogenen Namen nicht — er stünde in keiner Liste.
    static let liste: NameList = {
        var liste = NameList(
            name: "Klasse 3b",
            entries: NameList.parse("Adam, Betullah, Charlotte, Deniz, Erdem, Frida, "
                                    + "Giacomo, Hannah, Ilkay, Joel, Krystina, Liam, "
                                    + "Mia, Nesrin, Ophelia, Paul, Quentin, Ramazan, "
                                    + "Stine, Tallulah, Umut, Viktor, Weronika, Xenia, "
                                    + "Yesim, Zacharias"),
            owner: "")
        liste.id = listenID
        return liste
    }()

    /// Die Tafel zur gewünschten Szene.
    static func tafel(_ nummer: Int) -> Board {
        switch nummer {
        case 2:  return zufallsname()
        case 3:  return stillarbeit()
        default: return morgenkreis()
        }
    }

    // MARK: - Szenen

    /// Szene 1 — der ganze Morgen auf einer Tafel.
    private static func morgenkreis() -> Board {
        var board = grundgeruest(name: "Klasse 3b", emoji: "🍎")

        var text = element(x: 80, y: 40, w: 620, h: 170, z: 0,
                           inhalt: .text(TextContent(text: "Guten Morgen!", fontSize: 92)))
        text.karte = .nie

        var ziehung = NamePickerContent()
        ziehung.listID = listenID
        ziehung.title = "Wer liest vor?"
        ziehung.reveal = .instant
        ziehung.currentID = kennung("Charlotte")
        ziehung.drawnIDs = [kennung("Paul"), kennung("Nesrin"), kennung("Charlotte")]
        let name = element(x: 80, y: 240, w: 620, h: 430, z: 1, inhalt: .namePicker(ziehung))

        var ablauf = ChecklistContent()
        ablauf.title = "Unser Tag"
        ablauf.items = [
            ChecklistItem(text: "Ankommen und Morgenkreis", done: true, emoji: "☀️"),
            ChecklistItem(text: "Deutsch: Lesestunde", done: true, emoji: "📖"),
            ChecklistItem(text: "Frühstück und Pause", done: false, emoji: "🍎"),
            ChecklistItem(text: "Mathe: Einmaleins", done: false, emoji: "➗"),
            ChecklistItem(text: "Abschlussrunde", done: false, emoji: "👋")
        ]
        let liste = element(x: 80, y: 700, w: 620, h: 260, z: 2, inhalt: .checklist(ablauf))

        var uhr = ClockContent()
        uhr.showDate = true
        let zeit = element(x: 740, y: 40, w: 400, h: 420, z: 3, inhalt: .clock(uhr))

        var wecker = TimerContent()
        wecker.duration = 600
        let timer = element(x: 1180, y: 40, w: 340, h: 420, z: 4, inhalt: .timer(wecker))

        var ampel = TrafficLightContent()
        ampel.state = .green
        let licht = element(x: 1180, y: 500, w: 340, h: 460, z: 5, inhalt: .trafficLight(ampel))

        let pegel = element(x: 740, y: 500, w: 400, h: 250, z: 6, inhalt: .noise(NoiseContent()))

        var arbeit = SymbolContent()
        arbeit.symbol = .partner
        let symbol = element(x: 740, y: 790, w: 400, h: 170, z: 7, inhalt: .symbols(arbeit))

        board.widgets = [text, name, liste, zeit, timer, licht, pegel, symbol]
        return board
    }

    /// Szene 2 — das Auslosen, groß.
    private static func zufallsname() -> Board {
        var board = grundgeruest(name: "Klasse 3b", emoji: "🎲")
        board.accent = "sonne"

        var ziehung = NamePickerContent()
        ziehung.listID = listenID
        ziehung.title = "Wer ist dran?"
        ziehung.reveal = .mosaik
        ziehung.currentID = kennung("Giacomo")
        ziehung.drawnIDs = [kennung("Adam"), kennung("Mia"), kennung("Stine"),
                            kennung("Umut"), kennung("Giacomo")]
        // Halb aufgedeckt: Genau der Moment, in dem die Klasse miträt.
        ziehung.revealParts = [0, 3, 4, 7, 8, 11, 12, 15]
        let name = element(x: 120, y: 80, w: 900, h: 700, z: 0, inhalt: .namePicker(ziehung))

        var klang = SoundsContent()
        klang.buttons = [
            SoundButton(label: "Applaus", emoji: "👏", colorHex: "#f59e0b"),
            SoundButton(label: "Gong", emoji: "🔔", colorHex: "#0f9b8e")
        ]
        let klaenge = element(x: 1080, y: 80, w: 420, h: 320, z: 1, inhalt: .sounds(klang))

        var arbeit = SymbolContent()
        arbeit.symbol = .melden
        let symbol = element(x: 1080, y: 440, w: 420, h: 340, z: 2, inhalt: .symbols(arbeit))

        var hinweis = TextContent(text: "Erst antippen, dann ziehen.", fontSize: 46)
        hinweis.bold = false
        var zettel = element(x: 120, y: 820, w: 900, h: 130, z: 3, inhalt: .text(hinweis))
        zettel.karte = .nie

        board.widgets = [name, klaenge, symbol, zettel]
        return board
    }

    /// Szene 3 — Stillarbeit: Zeit, Ruhe, Arbeitsform.
    private static func stillarbeit() -> Board {
        var board = grundgeruest(name: "Klasse 3b", emoji: "🤫")
        board.accent = "wald"

        var wecker = TimerContent()
        wecker.duration = 900
        let timer = element(x: 100, y: 120, w: 620, h: 620, z: 0, inhalt: .timer(wecker))

        var pegel = NoiseContent()
        pegel.title = "Ruhe im Raum"
        pegel.schwelleDb = 58
        let lautstaerke = element(x: 780, y: 120, w: 720, h: 300, z: 1, inhalt: .noise(pegel))

        var arbeit = SymbolContent()
        arbeit.symbol = .einzel
        let symbol = element(x: 780, y: 460, w: 350, h: 280, z: 2, inhalt: .symbols(arbeit))

        var ampel = TrafficLightContent()
        ampel.state = .yellow
        ampel.horizontal = true
        let licht = element(x: 1170, y: 460, w: 330, h: 280, z: 3, inhalt: .trafficLight(ampel))

        var auftrag = TextContent(text: "Stillarbeit: Seite 42, Nr. 1–4", fontSize: 54)
        auftrag.bold = true
        var zettel = element(x: 100, y: 790, w: 1400, h: 150, z: 4, inhalt: .text(auftrag))
        zettel.karte = .nie

        board.widgets = [timer, lautstaerke, symbol, licht, zettel]
        return board
    }

    // MARK: - Ausrichtung

    /// Dreht das iPad ins Querformat.
    ///
    /// Eine Tafel ist 16:10 — hochkant bliebe die Hälfte des Bildes leer.
    /// Der Simulator startet aber immer hochkant, und `simctl` kann nicht
    /// drehen. Also bittet die App selbst darum; erlaubt ist das, weil sie
    /// alle Ausrichtungen unterstützt. Nur im Schaufenster, versteht sich.
    @MainActor
    static func richteAus() {
        guard aktiv, UIDevice.current.userInterfaceIdiom == .pad else { return }
        let szenen = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for szene in szenen {
            szene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
        }
    }

    // MARK: - Bausteine

    private static func grundgeruest(name: String, emoji: String) -> Board {
        var board = Board()
        board.id = "schaufenster-\(name)-\(emoji)"
        board.name = name
        board.emoji = emoji
        board.background = .aurora("nordlicht")
        board.accent = "ozean"
        return board
    }

    private static func element(x: Double, y: Double, w: Double, h: Double, z: Int,
                                inhalt: WidgetContent) -> BoardWidget {
        var widget = BoardWidget(content: inhalt)
        widget.x = x
        widget.y = y
        widget.width = w
        widget.height = h
        widget.z = z
        return widget
    }

    /// Kennung eines Namens in der Schaufensterliste — die Einträge bekommen
    /// beim Erzeugen zufällige Kennungen, hier wird nach Text gesucht.
    private static func kennung(_ text: String) -> String {
        liste.entries.first { $0.text == text }?.id ?? ""
    }
}
