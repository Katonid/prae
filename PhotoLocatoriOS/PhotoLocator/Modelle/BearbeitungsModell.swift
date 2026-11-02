import CoreLocation
import Observation
import Photos

struct Fehlermeldung: Identifiable {
    let id = UUID()
    let titel: String
    let text: String

    init(_ fehler: Error, titel: String = "Speichern fehlgeschlagen") {
        self.titel = titel
        let beschreibung = (fehler as? LocalizedError)?.errorDescription ?? fehler.localizedDescription
        if let rat = (fehler as? LocalizedError)?.recoverySuggestion {
            text = beschreibung + "\n\n" + rat
        } else {
            text = beschreibung
        }
    }
}

/// Zustand und Abläufe der Bearbeitungsansicht: welches Foto, wo die
/// Nadel steht, Speichern, Überspringen, Blättern, Rückgängig.
///
/// Grundsatz: Ein Foto gilt erst als erledigt, wenn `StandortSpeicher`
/// die Änderung aus der Mediathek zurückgelesen und bestätigt hat.
@MainActor
@Observable
final class BearbeitungsModell {
    let liste: Arbeitsliste
    let sitzung: Sitzungsspeicher

    private(set) var index: Int
    /// Die Nadel — noch nicht gespeichert, solange sie vom Foto abweicht.
    var nadel: CLLocationCoordinate2D?
    private(set) var speichert = false
    var fehler: Fehlermeldung?
    var hinweis: String?
    private(set) var hinweisZaehler = 0
    private(set) var erfolgZaehler = 0
    /// Modus A: Es gibt kein offenes Foto mehr (außer evtl. dem aktuellen).
    var keinWeiteres = false

    @ObservationIgnored private var vorgewaermt: [PHAsset] = []

    init(liste: Arbeitsliste, sitzung: Sitzungsspeicher, index: Int) {
        self.liste = liste
        self.sitzung = sitzung
        self.index = min(max(index, 0), max(liste.anzahl - 1, 0))
        nadel = liste.asset(self.index)?.location?.coordinate
        merken()
    }

    // MARK: - Abgeleitete Angaben

    var art: Arbeitsliste.Art { liste.art }
    var asset: PHAsset? { liste.asset(index) }
    var gespeichert: CLLocationCoordinate2D? { asset?.location?.coordinate }
    var nadelGeaendert: Bool { !Koordinaten.gleich(nadel, gespeichert) }
    var aenderbar: Bool { asset?.canPerform(.properties) ?? false }
    var hatVorheriges: Bool { index > 0 }
    var hatNaechstes: Bool { index < liste.anzahl - 1 }

    var offen: Int? {
        art == .ergaenzen ? sitzung.laufend?.offen : nil
    }

    var titel: String {
        Fortschritt.titel(position: index + 1, gesamt: liste.anzahl)
    }

    var untertitel: String? {
        offen.map { Fortschritt.rest(offen: $0) }
    }

    /// Beschriftung der Hauptschaltfläche.
    var primaerTitel: String {
        switch art {
        case .ergaenzen:
            return (!nadelGeaendert && gespeichert != nil) ? "Weiter" : "Speichern & Weiter"
        case .bearbeiten:
            return "Speichern"
        }
    }

    var primaerMoeglich: Bool {
        guard !speichert, asset != nil else { return false }
        switch art {
        case .ergaenzen:
            return nadel != nil && (aenderbar || !nadelGeaendert)
        case .bearbeiten:
            return nadel != nil && nadelGeaendert && aenderbar
        }
    }

    var kannRueckgaengig: Bool { !sitzung.verlauf.isEmpty && !speichert }

    var rueckgaengigText: String {
        guard let letzte = sitzung.verlauf.last else { return "Nichts rückgängig zu machen" }
        let wann = letzte.fotoDatum.map { " (Foto vom \(Formate.datumZeit($0)))" } ?? ""
        return "Letzte Änderung rückgängig\(wann)"
    }

    /// Der Standort, den das Foto vor der ersten Änderung durch PhotoLocator hatte.
    var ursprung: Ursprung? {
        guard let id = asset?.localIdentifier else { return nil }
        return sitzung.ursprung[id]
    }

    var ursprungWiederherstellbar: Bool {
        guard let ursprung else { return false }
        return !Koordinaten.gleich(ursprung.ort?.koordinate, gespeichert)
    }

    // MARK: - Blättern

    func gehe(zu neu: Int) {
        guard liste.anzahl > 0 else { return }
        index = min(max(neu, 0), liste.anzahl - 1)
        nadel = asset?.location?.coordinate
        keinWeiteres = false
        merken()
    }

    func vor() { if hatNaechstes { gehe(zu: index + 1) } }
    func zurueck() { if hatVorheriges { gehe(zu: index - 1) } }

    func ueberspringen() {
        guard let id = asset?.localIdentifier else { return }
        sitzung.ueberspringen(id)
        naechstesOffenes()
    }

    func naechstesOffenes() {
        guard art == .ergaenzen, let s = sitzung.laufend else {
            vor()
            return
        }
        if let n = Fortschritt.naechsterOffener(
            nach: index, ids: liste.ids, erledigt: s.erledigt, uebersprungen: s.uebersprungen
        ) {
            gehe(zu: n)
        } else {
            keinWeiteres = true
        }
    }

    /// Zum ersten noch offenen Foto (z. B. den übersprungenen).
    func erstesOffenes() {
        guard let s = sitzung.laufend else { return }
        if let n = Fortschritt.naechsterOffener(
            nach: -1, ids: liste.ids, erledigt: s.erledigt, uebersprungen: s.uebersprungen
        ) {
            gehe(zu: n)
        }
    }

    private func merken() {
        liste.zuletzt = index
        if art == .ergaenzen, let id = asset?.localIdentifier {
            sitzung.aktuell(id)
        }
    }

    func vorwaermen() {
        let bereich = (index - 1)...(index + 3)
        let neu = bereich.filter { $0 != index }.compactMap { liste.asset($0) }
        let alt = vorgewaermt.filter { a in !neu.contains(where: { $0.localIdentifier == a.localIdentifier }) }
        Bildlader.shared.vorwaermenBeenden(alt)
        Bildlader.shared.vorwaermen(neu)
        vorgewaermt = neu
    }

    func aufraeumen() {
        Bildlader.shared.vorwaermenBeenden(vorgewaermt)
        vorgewaermt = []
    }

    // MARK: - Nadel

    func nadelZuruecksetzen() {
        nadel = gespeichert
    }

    func zeigeHinweis(_ text: String) {
        hinweis = text
        hinweisZaehler += 1
    }

    // MARK: - Speichern

    /// Hauptschaltfläche: speichern (und in Modus A weiter zum nächsten offenen Foto).
    func primaer() async {
        if art == .ergaenzen && !nadelGeaendert && gespeichert != nil {
            naechstesOffenes()
            return
        }
        await speichern()
    }

    func speichern() async {
        guard let asset, let nadel, !speichert else { return }
        let ort = GespeicherterOrt(koordinate: nadel, zeit: asset.creationDate ?? Date()).location
        let erfolg = await schreiben(ort, in: asset, hinweis: "Standort gespeichert")
        guard erfolg else { return }
        if art == .ergaenzen {
            naechstesOffenes()
        }
    }

    /// Entfernt den Standort vollständig (nach Bestätigung in der Oberfläche).
    func entfernen() async {
        guard let asset, asset.location != nil else { return }
        await schreiben(nil, in: asset, hinweis: "Standort entfernt")
    }

    /// Setzt das Foto auf den Standort zurück, den es vor der ersten
    /// Änderung durch PhotoLocator hatte (auch „keiner“).
    func ursprungWiederherstellen() async {
        guard let asset, let ursprung else { return }
        await schreiben(ursprung.ort?.location, in: asset, hinweis: "Ursprünglicher Standort wiederhergestellt")
    }

    /// Schreibt, bestätigt, hält fest — oder meldet den Fehler.
    @discardableResult
    private func schreiben(_ ort: CLLocation?, in asset: PHAsset, hinweis text: String) async -> Bool {
        guard !speichert else { return false }
        let id = asset.localIdentifier
        let vorher = asset.location
        speichert = true
        defer { speichert = false }
        do {
            let neu = try await StandortSpeicher.schreiben(ort, assetID: id)
            liste.ersetzen(neu)
            sitzung.erfassen(assetID: id, fotoDatum: asset.creationDate, vorher: vorher, nachher: neu.location)
            if neu.location != nil {
                sitzung.alsErledigt(id)
            } else {
                sitzung.alsOffen(id)
            }
            if asset.localIdentifier == self.asset?.localIdentifier {
                nadel = neu.location?.coordinate
            }
            erfolgZaehler += 1
            zeigeHinweis(text)
            return true
        } catch {
            fehler = Fehlermeldung(error)
            return false
        }
    }

    /// Macht die letzte gespeicherte Änderung rückgängig — auch wenn sie
    /// ein anderes Foto betraf; dann wird dieses Foto angezeigt.
    func rueckgaengig() async {
        guard let letzte = sitzung.verlauf.last, !speichert else { return }
        speichert = true
        defer { speichert = false }
        do {
            let neu = try await StandortSpeicher.schreiben(letzte.vorher?.location, assetID: letzte.assetID)
            sitzung.rueckgaengigErfasst(letzte)
            liste.ersetzen(neu)
            if neu.location == nil {
                sitzung.alsOffen(letzte.assetID)
            } else {
                sitzung.alsErledigt(letzte.assetID)
            }
            if let i = liste.index(von: letzte.assetID) {
                gehe(zu: i)
            }
            zeigeHinweis(neu.location == nil
                ? "Rückgängig – Foto hat wieder keinen Standort"
                : "Rückgängig – vorheriger Standort wiederhergestellt")
        } catch {
            fehler = Fehlermeldung(error, titel: "Rückgängig fehlgeschlagen")
        }
    }
}
