import Foundation
import SwiftUI

@main
struct UrlaubstagebuchApp: App {
    @StateObject private var regal = Regal()
    @Environment(\.scenePhase) private var lage

    var body: some Scene {
        WindowGroup {
            RegalView()
                .environmentObject(regal)
                .task {
                    // Wie dieses Gerät heißt, wird EINMAL gebildet und
                    // liegt danach in den Voreinstellungen: Gesichert wird
                    // ein Buch auch abseits des Hauptfadens, und UIKit
                    // gehört dorthin (ab 1.0.102).
                    Geraetename.vorbereiten()
                    // Selbst installierte Schriften gelten nur für DIESEN
                    // Prozess und müssen bei jedem Start wieder angemeldet
                    // werden (ab 1.0.41, `Model/Geraeteschriften.swift`).
                    // Ohne das stünde im Buch ein Schriftname, den die App
                    // nach einem Neustart nicht mehr auflöst — und gesetzt
                    // würde still die Systemschrift.
                    Geraeteschriften.beimStartAnmelden()
                    await regal.starten()
                }
                .onOpenURL { ort in
                    // Eine Buchdatei, die jemand in „Dateien" antippt oder
                    // per AirDrop schickt. Gefragt wird trotzdem: Ein
                    // Einlesen, das gleich losschreibt, könnte ein Buch
                    // überschreiben, das der Nutzer noch braucht.
                    regal.angeboteneDatei = ort
                }
                .onChange(of: lage) { _, neu in
                    // Zurück aus dem Hintergrund: Auf dem anderen Gerät kann
                    // inzwischen etwas passiert sein. Ein Regal, das den
                    // Stand von gestern zeigt, sieht aus wie ein Abgleich,
                    // der nicht läuft.
                    if neu == .active { regal.neuLesen() }
                }
        }
    }
}

// Die Liste der Reisen. Sie liegt über dem einzelnen Buch, weil ein
// Urlaubstagebuch nichts ist, wovon man eines hat.
@MainActor
final class Regal: ObservableObject {
    @Published var reisen: [Reise] = []
    @Published var unlesbar: Int = 0
    @Published var offen: Reisewerk?
    // Eine Buchdatei, die von außen hereingereicht wurde — aus „Dateien",
    // per AirDrop oder über den Wähler in den Einstellungen. Die Frage
    // danach steht an EINER Stelle (im Regal): Ein zweiter Kasten mit
    // derselben Frage liefe irgendwann auseinander.
    @Published var angeboteneDatei: URL?
    // WAS BEIM LETZTEN MAL LIEGEN GEBLIEBEN IST (ab 1.0.100).
    //
    // `Absturzspur` legt vor jedem Schritt eine winzige Datei an und räumt
    // sie weg, wenn er gut ausgegangen ist. Liegt sie beim Start noch da,
    // ist die App genau darin gestorben — und dann steht es im Regal,
    // kopierbar. Gelesen wird EINMAL, im `init`: Ein Befund, der bei jedem
    // Neulesen wiederkäme, sähe aus wie ein zweiter Absturz.
    @Published var absturzbefund: String?

    private var beobachter: NSMetadataQuery?
    private var nachschlag: Task<Void, Never>?

    init() {
        absturzbefund = Absturzspur.aufgelesen()
        neuLesen()
    }

    // Beim Start wird einmal nachgesehen, ob iCloud überhaupt zu haben ist.
    // Das blockiert und darf deshalb nicht im `init` stehen; bis die Antwort
    // da ist, arbeitet die App auf dem Gerät weiter.
    func starten() async {
        await Wolke.vorbereiten()
        neuLesen()
        beobachten()
    }

    func neuLesen() {
        // GEMESSEN, NICHT GERATEN (ab 1.0.103). Gemeldet vom Mac: „Das
        // Öffnen dauerte." Hier wird jedes Buch von der Platte gelesen und
        // entziffert — bei einem Buch mit sechzig Seiten sind das mehrere
        // Megabyte JSON, und über iCloud kommt der Weg dorthin dazu. Ob es
        // wirklich daran liegt, sagt die Zahl in den Einstellungen.
        let anfang = Date()
        let ergebnis = Ablage.alle()
        Tempomesser.melde("Regal lesen", dauer: Date().timeIntervalSince(anfang),
                          zusatz: "\(ergebnis.reisen.count) Bücher")
        reisen = ergebnis.reisen
        unlesbar = ergebnis.unlesbar
    }

    // Nach einem Wechsel der Ablage: neu lesen UND zu horchen anfangen.
    // Ohne das Zweite liefe der Abgleich erst nach dem nächsten Start —
    // und für den Menschen davor sähe er aus, als liefe er gar nicht.
    func wolkeGewechselt() {
        neuLesen()
        beobachten()
    }

    // Das Regal horcht, statt zu fragen: `NSMetadataQuery` meldet, wenn in
    // iCloud etwas dazukommt oder sich ändert — und genau das ist der
    // Unterschied zwischen „abgeglichen" und „abgeglichen, sobald jemand
    // die App neu startet".
    //
    // Gemeldet wird oft und in Schüben, deshalb die zwei Sekunden Ruhe
    // dazwischen: Ein Regal, das sich während einer Übertragung zwanzigmal
    // neu aufbaut, flackert nur.
    private func beobachten() {
        guard Wolke.stand == .an, beobachter == nil else { return }
        let frage = NSMetadataQuery()
        frage.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        frage.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*.json")
        for name in [NSNotification.Name.NSMetadataQueryDidFinishGathering,
                     NSNotification.Name.NSMetadataQueryDidUpdate]
        {
            NotificationCenter.default.addObserver(forName: name, object: frage,
                                                   queue: .main) { [weak self] _ in
                // Die Meldung kommt auf dem Hauptfaden an, der Übersetzer
                // weiß das aber nicht — ohne den Sprung in den Actor wäre
                // es unter Swift 6 ein Fehler.
                guard let self else { return }
                Task { @MainActor in self.spaeterNachlesen() }
            }
        }
        frage.start()
        beobachter = frage
    }

    private func spaeterNachlesen() {
        nachschlag?.cancel()
        nachschlag = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.neuLesen()
        }
    }

    func oeffnen(_ reise: Reise) {
        let werk = Reisewerk(reise: reise)
        werk.fehlendeSeitenNachholen()
        offen = werk
    }

    // EIN NEUES BUCH DARF MIT EINER VORLAGE ANFANGEN (ab 1.0.95).
    //
    // Das FORMAT wird hier schlicht gesetzt und läuft NICHT durch
    // `Formatwechsel`: Ein frisches Buch hat keine Seite und keinen Block,
    // den eine Umrechnung treffen könnte. Bei einem Buch mit Inhalt ist
    // das anders — dort fragt `Reisewerk.vorlageAnwenden` nach.
    @discardableResult
    func anlegen(titel: String,
                 aussehen: Vorlage? = nil,
                 druckerei: Vorlage? = nil) -> Reise
    {
        var neu = Reise()
        neu.titel = titel.isEmpty ? "Meine Reise" : titel
        if let aussehen { aussehen.werte.anwenden(.aussehen, auf: &neu) }
        if let druckerei {
            neu.format = druckerei.werte.format
            druckerei.werte.anwenden(.druckerei, auf: &neu)
        }
        try? Ablage.sichern(neu)
        neuLesen()
        return neu
    }

    func schliessen() {
        offen?.sofortSichern()
        offen = nil
        Bildarchiv.shared.aufraeumen()
        Task { await Kartenwerk.shared.vergessen() }
        neuLesen()
    }

    // EIN BUCH DUPLIZIEREN (ab 1.0.33, Ansage des Nutzers 09/2026:
    // „Ich möchte ein Projekt duplizieren können.").
    //
    // Ein Buch ist zweierlei: eine JSON-Datei und ein Ordner voller Bilder.
    // Kopiert werden müssen BEIDE — ein Buch mit fremdem Bilderordner wäre
    // eine Zeitbombe (siehe `Bildarchiv.ordnerKopieren`).
    //
    // Die INNEREN Kennungen bleiben, wie sie sind: Tage, Seiten, Blöcke und
    // Fotos gelten innerhalb eines Buches, und zwei Bücher sehen einander
    // nie. Mehr noch — sie MÜSSEN bleiben: Das Papierkorn rechnet aus
    // `UUID.saat` und der Drehwinkel eines Albumfotos aus der Kennung des
    // Fotos; mit neuen Kennungen sähe die Kopie anders
    // aus als das Urbuch. (Tafelbild hat 1.4.5 das Gegenteil gelernt; dort
    // lagen die Kopien in DERSELBEN Tafel, und dann ist eine doppelte
    // Kennung wirklich eine.) Neu ist genau eine Zahl: die der Reise, denn
    // die ist der Dateiname.
    //
    // Die Bilder werden ABSEITS des Hauptfadens kopiert. Ein Buch mit
    // zweihundert Fotos wiegt ein Gigabyte; auf dem Hauptfaden stünde die
    // App währenddessen still, und für den Menschen davor wäre sie
    // abgestürzt.
    //
    // `@MainActor`, weil `neuLesen()` am Ende `@Published` schreibt: Eine
    // nicht isolierte `async`-Funktion läuft im Nebenläufigkeits-Pool und
    // nicht beim Aufrufer (dieselbe Wurzel wie bei Schulalarms
    // Hintergrundereignissen, nur eine Ebene harmloser). Die eigentliche
    // Arbeit steht trotzdem abseits — dafür ist das `Task.detached` da.
    @MainActor
    @discardableResult
    func duplizieren(_ reise: Reise) async -> String {
        var kopie = reise
        kopie.id = UUID()
        // BENANNT WIRD DIE KOPIE, NICHT DAS BUCH (ab 1.0.84). Bis 1.0.83
        // stand „ (Kopie)" im gedruckten TITEL — wer ein Buch für einen
        // zweiten Druckdienst duplizierte und es nicht von Hand
        // umbenannte, hatte das Wort auf der Titelseite. Geändert wird
        // deshalb der Name in der Übersicht; die Titelseite bleibt, wie
        // sie war.
        kopie.regalname = Regal.kopietitel(reise.anzeigename,
                                           vorhandene: reisen.map(\.anzeigename))
        kopie.geaendert = Date()
        let alt = reise.id
        let neu = kopie.id

        let fehler: String? = await Task.detached(priority: .userInitiated) {
            do {
                try Bildarchiv.shared.ordnerKopieren(von: alt, nach: neu)
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value

        // Halb kopiert ist schlimmer als gar nicht kopiert: Ein Buch ohne
        // seine Bilder sieht aus wie eines, dem die Fotos abhandengekommen
        // sind. Was angefangen wurde, wird deshalb wieder weggeräumt.
        if let fehler {
            Ablage.loeschen(neu)
            return "Die Bilder ließen sich nicht kopieren: \(fehler)"
        }
        do {
            try Ablage.sichern(kopie)
        } catch {
            Ablage.loeschen(neu)
            return "Die Kopie ließ sich nicht sichern: \(error.localizedDescription)"
        }
        neuLesen()
        return "\u{201E}\(kopie.anzeigename)\u{201C} steht im Regal."
    }

    // „Reise (Kopie)", dann „Reise (Kopie 2)". Ein zweites Buch mit
    // demselben Namen wäre im Regal nicht auseinanderzuhalten — die
    // Kennung sieht man dort nicht.
    static func kopietitel(_ titel: String, vorhandene: [String]) -> String {
        let genommen = Set(vorhandene)
        let erster = titel + " (Kopie)"
        guard genommen.contains(erster) else { return erster }
        var zahl = 2
        while genommen.contains("\(titel) (Kopie \(zahl))"), zahl < 100 { zahl += 1 }
        return "\(titel) (Kopie \(zahl))"
    }

    // UMBENENNEN HEISST: DEN NAMEN IN DER ÜBERSICHT SETZEN (ab 1.0.84).
    // Der gedruckte Titel wird hier nie angefasst — wer vor dem Regal
    // steht, meint die Liste und nicht die Titelseite. Leer nimmt die
    // Abweichung zurück, dann folgt der Name wieder dem Titel.
    //
    // Ein offenes Buch wird über sein Werk geändert und nicht an ihm
    // vorbei auf die Platte geschrieben: Sonst überschriebe der nächste
    // Sicherungslauf des Werks den neuen Namen gleich wieder.
    func umbenennen(_ reise: Reise, auf name: String) {
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let neu: String? = sauber.isEmpty ? nil : sauber
        if let werk = offen, werk.reise.id == reise.id {
            werk.merken()
            werk.reise.regalname = neu
            werk.sofortSichern()
            neuLesen()
            return
        }
        var geaendert = reise
        geaendert.regalname = neu
        geaendert.geaendert = Date()
        try? Ablage.sichern(geaendert)
        neuLesen()
    }

    func loeschen(_ id: UUID) {
        Ablage.loeschen(id)
        neuLesen()
    }
}
