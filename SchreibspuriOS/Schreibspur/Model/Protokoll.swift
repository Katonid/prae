import CoreGraphics
import Foundation
import Observation

/// Eine bearbeitete Übung eines Kindes — für die Klassenübersicht der
/// Lehrkraft (seit 1.0.9, Ansage des Nutzers 09/2026).
///
/// Gezählt wird nur, was zur Pflicht gehört: Fehler bis die Seite geschafft
/// ist (was das Kind danach freiwillig weiterschreibt, zählt nicht), und
/// Übungen, deren Stufe das Kind schon mit drei Sternen gemeistert hatte,
/// sind `freiwillig`.
struct Bearbeitung: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Das Zeichen, dessen Seite geöffnet war („M“, „Mama“, „Gemischt“).
    var zeichen: String
    /// Was darauf stand, lesbar („M m“, „Gemischt: A m O l“).
    var titel: String
    var stufe: Int
    var beginn: Date
    var dauer: TimeInterval
    /// Die Pflicht ist erfüllt (Stufe 1–4: das Zeichen fertig geschrieben).
    var geschafft: Bool
    var sterne: Int
    /// Fehlversuche bis zur erfüllten Pflicht.
    var fehler: Int
    /// Stufe war vorher schon gemeistert — zählt nicht in der Übersicht.
    var freiwillig: Bool
    /// Angenommene Buchstaben (Heftseite), davon nach der Pflicht.
    var buchstaben: Int = 0
    var kuer: Int = 0
}

/// Die Spuren einer Bearbeitung als Vektoren — daraus wird die Seite
/// später auf ihrem Hintergrund neu gezeichnet.
struct Blattspuren: Codable {
    struct Linie: Codable {
        /// x, y abwechselnd in Tausendsteln einer Einheit der Lineatur.
        var xy: [Int32]
        /// Farbstufe je Punkt (0 Stift, 1 hellorange, 2 orange).
        var w: [UInt8]
        /// Von der Prüfung nicht angenommen.
        var verworfen: Bool
        /// Nach der Pflicht freiwillig geschrieben.
        var kuer: Bool
        /// Sekunden seit Beginn der Bearbeitung — für das Nachspielen in
        /// der Reihenfolge des Schreibens über alle Reihen.
        var t: Double

        init(_ punkte: [Tintenpunkt], verworfen: Bool, kuer: Bool = false, t: Double = 0) {
            self.t = (t * 10).rounded() / 10
            xy = punkte.flatMap { [Int32(($0.p.x * 1000).rounded()), Int32(($0.p.y * 1000).rounded())] }
            w = punkte.map { $0.warnung < 0.35 ? 0 : ($0.warnung < 0.8 ? 1 : 2) }
            self.verworfen = verworfen
            self.kuer = kuer
        }

        var punkte: [Tintenpunkt] {
            stride(from: 0, to: xy.count - 1, by: 2).map { i in
                let stufe = i / 2 < w.count ? w[i / 2] : 0
                return Tintenpunkt(p: CGPoint(x: CGFloat(xy[i]) / 1000, y: CGFloat(xy[i + 1]) / 1000),
                                   warnung: stufe == 0 ? 0 : (stufe == 1 ? 0.5 : 1))
            }
        }
    }

    /// Eine Reihe der Heftseite (Stufe 1–4: genau eine, das große Blatt).
    struct Reihe: Codable {
        /// Die Buchstaben am Anfang der Reihe und wie sie zusammengehören.
        var teile: [String]
        var art: Heftseite.Vorgabe.Art
        /// In der Reihenfolge, in der sie geschrieben wurden.
        var linien: [Linie]
    }

    var reihen: [Reihe]
}

/// Protokollstrich eines Prüfers: in der Reihenfolge des Schreibens,
/// angenommen oder verworfen.
struct Protokollstrich {
    var punkte: [Tintenpunkt]
    var verworfen: Bool
    var kuer = false
    var zeit = Date()
}

/// Alle Bearbeitungen aller Kinder, als Dateien im Ordner „Protokoll“ der
/// App: je Kind ein Verzeichnis (JSON, klein) und je Bearbeitung eine
/// Datei mit den Spuren (nur geladen, wenn die Seite angesehen wird).
@Observable
final class Protokoll {
    /// Zählt bei jeder Änderung hoch — die Ansichten beobachten das, der
    /// Zwischenspeicher selbst wird nicht beobachtet.
    private(set) var stand = 0
    @ObservationIgnored private var geladen: [UUID: [Bearbeitung]] = [:]

    private static var ordner: URL {
        let basis = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return basis.appendingPathComponent("Protokoll", isDirectory: true)
    }

    private func ordner(_ kind: UUID) -> URL {
        Self.ordner.appendingPathComponent(kind.uuidString, isDirectory: true)
    }

    private func verzeichnis(_ kind: UUID) -> URL {
        ordner(kind).appendingPathComponent("verzeichnis.json")
    }

    private func spurenDatei(_ id: UUID, _ kind: UUID) -> URL {
        ordner(kind).appendingPathComponent("\(id.uuidString).json")
    }

    /// Die Bearbeitungen eines Kindes, die neuesten zuletzt.
    func bearbeitungen(von kind: UUID) -> [Bearbeitung] {
        _ = stand
        if let liste = geladen[kind] { return liste }
        let liste = (try? Data(contentsOf: verzeichnis(kind)))
            .flatMap { try? JSONDecoder().decode([Bearbeitung].self, from: $0) } ?? []
        geladen[kind] = liste
        return liste
    }

    /// Neu anlegen oder ersetzen (dieselbe `id`): Eine Heftseite wird beim
    /// Erfüllen der Pflicht gespeichert und beim Verlassen noch einmal —
    /// mit dem, was das Kind freiwillig weitergeschrieben hat.
    func speichern(_ b: Bearbeitung, spuren: Blattspuren, kind: UUID) {
        var liste = bearbeitungen(von: kind)
        if let i = liste.firstIndex(where: { $0.id == b.id }) { liste[i] = b } else { liste.append(b) }
        geladen[kind] = liste
        do {
            try FileManager.default.createDirectory(at: ordner(kind), withIntermediateDirectories: true)
            try JSONEncoder().encode(spuren).write(to: spurenDatei(b.id, kind), options: .atomic)
            try JSONEncoder().encode(liste).write(to: verzeichnis(kind), options: .atomic)
        } catch {
            // Kein Platz o. Ä.: Üben geht trotzdem weiter.
        }
        stand += 1
    }

    func spuren(_ b: Bearbeitung, kind: UUID) -> Blattspuren? {
        (try? Data(contentsOf: spurenDatei(b.id, kind)))
            .flatMap { try? JSONDecoder().decode(Blattspuren.self, from: $0) }
    }

    func loeschen(kind: UUID) {
        try? FileManager.default.removeItem(at: ordner(kind))
        geladen[kind] = []
        stand += 1
    }
}

/// Was die Übersicht je Zeichen und Stufe zeigt — ohne freiwillige
/// Wiederholungen schon gemeisterter Stufen.
struct Auswertung {
    var anlaeufe = 0
    var geschafft = 0
    var fehler = 0
    /// Alle Bearbeitungen, auch freiwillige.
    var alle = 0
    var letzte: Date?

    /// Je „Zeichen#Stufe“ eines Kindes. Eine Heftseite zählt für den
    /// Groß- und den Kleinbuchstaben (beide zeigen dieselben Reihen).
    static func je(_ liste: [Bearbeitung]) -> [String: Auswertung] {
        var je: [String: Auswertung] = [:]
        for b in liste {
            let ids = b.stufe == Stufe.heft.rawValue ? Zeichenvorrat.seitenpartner(b.zeichen) : [b.zeichen]
            for id in ids {
                var a = je["\(id)#\(b.stufe)", default: Auswertung()]
                a.alle += 1
                a.letzte = max(a.letzte ?? b.beginn, b.beginn)
                if !b.freiwillig {
                    a.anlaeufe += 1
                    a.fehler += b.fehler
                    if b.geschafft { a.geschafft += 1 }
                }
                je["\(id)#\(b.stufe)"] = a
            }
        }
        return je
    }
}
