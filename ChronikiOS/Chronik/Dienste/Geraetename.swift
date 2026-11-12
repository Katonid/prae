import Foundation
#if canImport(UIKit)
import UIKit
#endif

// WER DIESE FASSUNG GESCHRIEBEN HAT (ab 1.0.102).
//
// Gemeldet 09/2026: „Ich weiß nicht, von welchem Gerät und von wann diese
// unterschiedlichen Fassungen sind. Deshalb kann ich auch nicht
// beurteilen, welches die aktuelle ist, die ich behalten will."
//
// Das WANN stand immer schon in der Datei (`Reise.geaendert`) — es wurde
// nur nirgends gezeigt. Das GERÄT stand nirgends: Keine Fassung dieser App
// hat es je vermerkt. Es lässt sich deshalb auch nicht nachtragen; für
// jede Konfliktdatei, die heute auf der Platte liegt, bleibt es
// unbekannt, und die App SAGT das, statt zu raten — ein Gerätename, der
// nur plausibel ist, wäre bei dieser Entscheidung die teuerste Auskunft
// überhaupt.
//
// **Den echten Namen des Geräts gibt iOS nicht heraus.** Seit iOS 16
// liefert `UIDevice.current.name` nur noch die Modellbezeichnung („iPad"),
// nicht mehr den Namen, den der Mensch vergeben hat; dafür gibt es ein
// eigenes Recht, das Apple auf Antrag vergibt. Eines davon in die
// Entitlements-Datei zu schreiben, ohne dass die App-Id es trägt, hat
// dieses Projekt in 1.0.44 den ganzen Bau gekostet — **das wird nicht
// wiederholt.** Der Name hier ist deshalb ein SELBST vergebener: Er steht
// in den Einstellungen und lässt sich ändern.
//
// Vorbelegt wird er mit dem, was ohne jedes Recht zu haben ist (Modell)
// plus einem Kürzel, das dieses Gerät von einem gleich benannten trennt —
// sonst hießen zwei iPads beide „iPad", und die Auskunft wäre wieder
// keine.
enum Geraetename {
    private static let nameSchluessel = "geraetename"
    private static let kuerzelSchluessel = "geraetekuerzel"
    private static let modellSchluessel = "geraetemodell"

    /// Wie dieses Gerät in einem Buch vermerkt wird.
    ///
    /// Gelesen wird AUSSCHLIESSLICH aus den Voreinstellungen — nie aus
    /// UIKit: `Ablage.sichern` läuft nicht immer auf dem Hauptfaden, und
    /// `UIDevice` gehört dorthin. Den Vorschlag bildet deshalb einmal
    /// `vorbereiten()` beim Start.
    static var eigener: String {
        let eigen = (UserDefaults.standard.string(forKey: nameSchluessel) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return eigen.isEmpty ? vorschlag : eigen
    }

    /// Hat jemand einen eigenen Namen eingetippt?
    static var istSelbstVergeben: Bool {
        !(UserDefaults.standard.string(forKey: nameSchluessel) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Leer heißt: zurück auf den Vorschlag. „Nichts gesetzt" und
    /// „ausdrücklich so genannt" sind zwei Aussagen — dieselbe Trennung
    /// wie überall in diesem Papier.
    static func setzen(_ name: String) {
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if sauber.isEmpty {
            UserDefaults.standard.removeObject(forKey: nameSchluessel)
        } else {
            UserDefaults.standard.set(String(sauber.prefix(40)), forKey: nameSchluessel)
        }
    }

    /// Was die App vorschlägt, solange niemand etwas anderes eingetippt hat.
    static var vorschlag: String { modell + " " + kuerzel }

    /// Einmal beim Start: die Modellbezeichnung merken.
    ///
    /// Läuft auf dem Hauptfaden, weil UIKit dort hingehört. Danach kommt
    /// der Name ohne UIKit aus.
    @MainActor
    static func vorbereiten() {
        guard UserDefaults.standard.string(forKey: modellSchluessel) == nil else { return }
        UserDefaults.standard.set(gemessenesModell, forKey: modellSchluessel)
    }

    @MainActor
    private static var gemessenesModell: String {
        #if targetEnvironment(macCatalyst)
        return "Mac"
        #elseif canImport(UIKit)
        // Seit iOS 16 ist das die MODELLbezeichnung und nicht der Name, den
        // der Mensch vergeben hat: „iPad", „iPhone". Mehr gibt es ohne
        // eigenes Recht nicht, und mehr wird hier auch nicht behauptet.
        let wort = UIDevice.current.model.trimmingCharacters(in: .whitespacesAndNewlines)
        return wort.isEmpty ? "Gerät" : wort
        #else
        return "Gerät"
        #endif
    }

    private static var modell: String {
        UserDefaults.standard.string(forKey: modellSchluessel) ?? "Gerät"
    }

    /// Vier Zeichen, die dieses Gerät von einem gleich benannten trennen.
    ///
    /// Gewürfelt und EINMAL gemerkt — nicht aus `identifierForVendor`
    /// abgeleitet: Das ist eine Kennung des Geräts, und sie reist mit dem
    /// Buch in die Wolke und in jede weitergegebene Buchdatei. Ein selbst
    /// vergebenes Kürzel sagt genauso viel und ist keine.
    ///
    /// Ohne I, O, 0 und 1 — dieselbe Regel wie bei den Codes der anderen
    /// Apps dieses Repos: Diese vier verwechselt man beim Abschreiben.
    private static var kuerzel: String {
        if let da = UserDefaults.standard.string(forKey: kuerzelSchluessel), !da.isEmpty {
            return da
        }
        let zeichen = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let neu = String((0..<4).map { _ in zeichen.randomElement() ?? "X" })
        UserDefaults.standard.set(neu, forKey: kuerzelSchluessel)
        return neu
    }
}
