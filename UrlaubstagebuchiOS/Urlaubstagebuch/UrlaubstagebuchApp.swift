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
                .task { await regal.starten() }
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

    private var beobachter: NSMetadataQuery?
    private var nachschlag: Task<Void, Never>?

    init() { neuLesen() }

    // Beim Start wird einmal nachgesehen, ob iCloud überhaupt zu haben ist.
    // Das blockiert und darf deshalb nicht im `init` stehen; bis die Antwort
    // da ist, arbeitet die App auf dem Gerät weiter.
    func starten() async {
        await Wolke.vorbereiten()
        neuLesen()
        beobachten()
    }

    func neuLesen() {
        let ergebnis = Ablage.alle()
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

    @discardableResult
    func anlegen(titel: String) -> Reise {
        var neu = Reise()
        neu.titel = titel.isEmpty ? "Meine Reise" : titel
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

    func loeschen(_ id: UUID) {
        Ablage.loeschen(id)
        neuLesen()
    }
}
