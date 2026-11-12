import SwiftUI
import Foundation

// WAS LANGE DAUERT, SAGT WIE WEIT ES IST (ab 1.0.103).
//
// Gemeldet 09/2026 vom Mac: „Nun habe ich mehrfach versucht, das Buch als
// Datei zu sichern und die App reagiert nicht mehr. Es läuft nur der sich
// drehende farbige Ball."
//
// Zwei Dinge daran, und beide gehören hierher. Erstens lief die Arbeit auf
// dem Hauptfaden — der Ball IST das, und das ist in `Buchdatei` behoben.
// Zweitens: Es stand nichts da. Wer nichts sieht, tippt noch einmal, und
// genau das hat er getan. Ein Vorgang, der eine Minute dauert, muss sagen,
// dass er läuft, wie weit er ist und wie man ihn abbricht.
//
// Die Fläche darunter nimmt keine Tipps an — nicht als Gängelung, sondern
// weil ein zweiter Start dieselbe Gigabyte-Arbeit noch einmal anstieße.
// EIN BRIEFKASTEN ZWISCHEN ZWEI FÄDEN.
//
// Die Arbeit läuft abseits des Hauptfadens und meldet, wie weit sie ist;
// die Anzeige liest das. Sie tut es im eigenen Takt und nicht bei jeder
// Meldung: Ein `Task { @MainActor in … }` je Meldung wären bei einem
// Gigabyte hundert Sprünge auf den Hauptfaden für eine Anzeige, die
// ohnehin nicht feiner ist als ein Fünftel einer Sekunde.
//
// Dieselbe Bauweise wie `Zeichenmesser` und `Inhaltslage`: eine schlichte
// Klasse OHNE `@Published`. Wäre sie beobachtbar, löste jede Meldung ein
// Neuzeichnen aus.
final class Arbeitsmelder: @unchecked Sendable {
    private let sperre = NSLock()
    private var letzter: Buchdatei.Fortschritt?

    func melde(_ stand: Buchdatei.Fortschritt) {
        sperre.withLock { letzter = stand }
    }

    var stand: Buchdatei.Fortschritt? {
        sperre.withLock { letzter }
    }
}

// EIN ERGEBNIS ÜBER DIE FADENGRENZE TRAGEN.
//
// Geschrieben wird genau einmal, in der Aufgabe; gelesen erst, nachdem sie
// fertig ist. Dazwischen liegt das `await`, und das ist die Sperre — ein
// zweiter Faden sieht die Kiste nie. Deshalb `@unchecked`: Der Übersetzer
// kann das nicht nachrechnen, die Reihenfolge schon.
//
// Der Umweg steht hier, damit eine Arbeit abseits des Hauptfadens nicht
// verlangt, dass der halbe Datenbestand des Buches `Sendable` ist.
final class Kiste<Wert>: @unchecked Sendable {
    var ergebnis: Result<Wert, Error>?
}

struct Arbeitsanzeige: View {
    let titel: String
    let stand: Buchdatei.Fortschritt
    var abbrechen: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Text(titel)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                ProgressView(value: stand.anteil)
                    .progressViewStyle(.linear)
                VStack(spacing: 2) {
                    Text(stand.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !stand.zahlen.isEmpty {
                        Text(stand.zahlen)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                if let abbrechen {
                    Button("Abbrechen", role: .cancel, action: abbrechen)
                        .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .frame(maxWidth: 380)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .shadow(radius: 20)
            .padding(24)
        }
        .transition(.opacity)
    }
}

extension View {
    // Über ALLES gelegt, auch über ein offenes Blatt: Die Arbeit gehört dem
    // Fenster und nicht der Seite darunter.
    @ViewBuilder
    func arbeitsanzeige(_ stand: Buchdatei.Fortschritt?, titel: String,
                        abbrechen: (() -> Void)? = nil) -> some View {
        overlay {
            if let stand {
                Arbeitsanzeige(titel: titel, stand: stand, abbrechen: abbrechen)
            }
        }
    }
}
