import Foundation
import SwiftUI

// DIE BÜCHER AUF DEM GERÄT.
//
// Alle Bücher in EINER Datei (`Buecher.json` unter Application Support),
// die Fotos und PDF-Dateien daneben in `Medien` (Dokumente). Gesichert
// wird kurz nach jeder Änderung und beim Verlassen der App.
//
// **Eine unlesbare Datei wird nie überschrieben.** Lässt sie sich nicht
// lesen, wird sie zuerst beiseitegelegt (`Buecher-unlesbar-….json`), und
// das Aufräumen der Ablage unterbleibt — sonst löschte die App nach einem
// Lesefehler sämtliche Fotos, weil kein Buch mehr auf sie zeigt.
final class Bibliothek: ObservableObject {
    @Published var buecher: [Buch] = [] {
        didSet { if geladen { sichernBald() } }
    }
    @Published private(set) var ladefehler: String?

    private var geladen = false
    private var auftrag: DispatchWorkItem?

    static let datei: URL = {
        let basis = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: basis, withIntermediateDirectories: true)
        return basis.appendingPathComponent("Buecher.json")
    }()

    init() {
        laden()
        geladen = true
        if ladefehler == nil {
            let behalten = Bibliothek.verweise(buecher)
            DispatchQueue.global(qos: .utility).async { Medien.aufraeumen(behalten: behalten) }
        }
    }

    private func laden() {
        let url = Self.datei
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let daten = try Data(contentsOf: url)
            buecher = try JSONDecoder().decode([Buch].self, from: daten)
        } catch {
            let stempel = Int(Date().timeIntervalSince1970)
            let beiseite = url.deletingLastPathComponent().appendingPathComponent("Buecher-unlesbar-\(stempel).json")
            try? FileManager.default.copyItem(at: url, to: beiseite)
            ladefehler = "Die gespeicherten Bücher ließen sich nicht lesen (\(error.localizedDescription)). Die Datei ist unverändert beiseitegelegt."
        }
    }

    static func verweise(_ buecher: [Buch]) -> Set<String> {
        buecher.reduce(into: Set<String>()) { $0.formUnion($1.dateien) }
    }

    private func sichernBald() {
        auftrag?.cancel()
        let neu = DispatchWorkItem { [weak self] in self?.sichernJetzt() }
        auftrag = neu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: neu)
    }

    func sichernJetzt() {
        auftrag?.cancel()
        auftrag = nil
        guard let daten = try? JSONEncoder().encode(buecher) else { return }
        try? daten.write(to: Self.datei, options: .atomic)
    }

    // MARK: - Bücher

    @discardableResult
    func neuesBuch() -> UUID {
        let b = Buch()
        buecher.insert(b, at: 0)
        return b.id
    }

    func loeschen(_ id: UUID) {
        buecher.removeAll { $0.id == id }
    }

    /// Eine Bindung an ein Buch über seine Kennung — nicht über die Stelle
    /// in der Liste, die sich beim Löschen verschiebt.
    func binding(_ id: UUID) -> Binding<Buch> {
        Binding(
            get: { [weak self] in self?.buecher.first { $0.id == id } ?? Buch(id: id) },
            set: { [weak self] neu in
                guard let self, let i = self.buecher.firstIndex(where: { $0.id == id }) else { return }
                if self.buecher[i] != neu { self.buecher[i] = neu }
            }
        )
    }
}

/// Bindungen an einzelne Einträge eines Buches, über ihre Kennung.
enum Bindungen {
    static func text(_ buch: Binding<Buch>, _ id: UUID) -> Binding<Texteintrag> {
        Binding(
            get: { buch.wrappedValue.texte.first { $0.id == id } ?? Texteintrag(id: id) },
            set: { neu in
                if let i = buch.wrappedValue.texte.firstIndex(where: { $0.id == id }) { buch.wrappedValue.texte[i] = neu }
            }
        )
    }

    static func foto(_ buch: Binding<Buch>, _ id: UUID) -> Binding<Fotoeintrag> {
        Binding(
            get: { buch.wrappedValue.fotos.first { $0.id == id } ?? Fotoeintrag(id: id, datei: "", zeit: Date()) },
            set: { neu in
                if let i = buch.wrappedValue.fotos.firstIndex(where: { $0.id == id }) { buch.wrappedValue.fotos[i] = neu }
            }
        )
    }

    static func frei(_ buch: Binding<Buch>, _ id: UUID) -> Binding<FreieSeite> {
        Binding(
            get: { buch.wrappedValue.freieSeiten.first { $0.id == id } ?? FreieSeite(id: id) },
            set: { neu in
                if let i = buch.wrappedValue.freieSeiten.firstIndex(where: { $0.id == id }) {
                    buch.wrappedValue.freieSeiten[i] = neu
                }
            }
        )
    }
}
