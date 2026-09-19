import SwiftUI

/// Die Ziele, die JEDER Navigationsstapel dieser App kennen muss.
///
/// **Warum es das als eine Stelle gibt** (ab 1.1.25, gemeldet 09/2026: „Ein
/// Tipp auf eine Linie bewirkt leider gar nichts"). Ein
/// `NavigationLink(value:)`, dessen Wertetyp im umgebenden Stapel kein Ziel
/// hat, tut **nichts** — kein Absturz, keine Meldung, keine Bewegung. Für den
/// Menschen davor ist das ein kaputter Knopf.
///
/// Getroffen hat es die **Vollbildkarte**: Sie macht seit 1.1.11 einen eigenen
/// Stapel auf und trug darin `Haltestelle` ein, aber nicht `Fahrtwunsch`. Wer
/// dort einen Halt antippte, kam in die Abfahrtstafel dieser Haltestelle — und
/// von da an ging es nicht weiter, obwohl jede Zeile ihren Pfeil trug.
///
/// **Die Lehre stand schon da und war trotzdem nicht gezogen.** Über genau
/// dieser Zeile stand seit 1.1.11 der Kommentar „Ein eigener Stapel braucht
/// sein eigenes Ziel. Dieselbe Falle wie in 1.1.7" — und darunter wurde EINES
/// der zwei Ziele eingetragen. Dasselbe Muster wie bei Schulalarms
/// `requestAuthorization`, wo die Falle im Kommentar beschrieben stand und die
/// Prüfung fehlte: **Ein Kommentar ersetzt keine Prüfung.**
///
/// Deshalb ist es jetzt kein Merksatz mehr, sondern ein Modifikator. Wer einen
/// neuen Stapel baut, hängt `.fahrplanziele()` daran und kann keines der
/// beiden Ziele mehr vergessen; wer ein drittes Ziel braucht, trägt es HIER
/// ein und erreicht damit alle Stapel auf einmal.
///
/// `Verbindung` steht bewusst NICHT hier: Die gibt es nur in der
/// Verbindungsauskunft, und ein Ziel in einem Stapel anzumelden, in den nie
/// ein solcher Wert gelegt wird, verspräche einen Weg, den es dort nicht gibt.
extension View {
    func fahrplanziele() -> some View {
        self
            .navigationDestination(for: Haltestelle.self) { halt in
                HaltestelleView(haltestelle: halt)
            }
            .navigationDestination(for: Fahrtwunsch.self) { wunsch in
                FahrtView(fahrtId: wunsch.fahrtId, einstiegsHaltestelle: wunsch.einstieg)
            }
    }
}
