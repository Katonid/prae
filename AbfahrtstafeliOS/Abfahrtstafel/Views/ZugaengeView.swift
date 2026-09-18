import CoreLocation
import SwiftUI
import UIKit

/// Eigene Zugänge: Schlüssel eintragen, Schlüssel beweisen.
///
/// **Was dieser Bildschirm NICHT tut**, und das steht auch darauf: Ein
/// eingetragener Schlüssel schaltet noch keine Abfahrten frei. Er beweist,
/// dass der Zugang antwortet — und die Antwort ist das, woraus die Quelle
/// gebaut wird. Diese App hat jede ihrer Quellen an einer echten Antwort
/// gebaut und keine an einer Beschreibung; für einen Zugang, den es ohne
/// Konto nicht zu sehen gibt, ist das der einzige ehrliche Weg.
struct ZugaengeView: View {

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var standort: Standortdienst

    @State private var schluessel: [String: String] = [:]
    @State private var befunde: [String: Zugangsprobe.Befund] = [:]
    @State private var laufend: String?

    var body: some View {
        Form {
            Section {
                Text("Ein Schlüssel, den Sie selbst holen und der in Ihrem Schlüsselbund liegt, ist etwas anderes als einer, der in der App steckt: Der hier verlässt das Gerät nur in seine eigene Abfrage.")
                Text("Was hier noch nicht passiert: Ein Schlüssel schaltet keine Abfahrten frei. Er beweist, dass der Zugang antwortet — und genau diese Antwort ist das Material, aus dem die Quelle gebaut wird.")
                    .foregroundStyle(.secondary)
            } footer: {
                Text("Für die Niederlande, Tschechien, Dänemark und Frankreich zeigt die App schon heute Abfahrten und Verbindungen mit Echtzeit; das kommt aus der offenen Quelle und braucht keinen Schlüssel. Ein Zugang hier ist eine zweite Meinung, kein Lückenschluss.")
            }

            ForEach(Zugang.alle) { zugang in
                Section {
                    anleitung(zugang)
                    eingabe(zugang)
                    knopfzeile(zugang)
                    if let befund = befunde[zugang.id] {
                        befundflaeche(befund)
                    }
                } header: {
                    Text("\(zugang.name) · \(zugang.land)")
                } footer: {
                    fusszeile(zugang)
                }
            }
        }
        .navigationTitle("Eigene Zugänge")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: schluesselLaden)
    }

    // MARK: - Bausteine

    private func eingabe(_ zugang: Zugang) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SecureField(
                zugang.zweiteilig ? "Kennung:Schlüssel" : "Schlüssel",
                text: bindung(zugang.id)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.body.monospaced())

            if zugang.zweiteilig {
                Text("Zwei Angaben, getrennt durch einen Doppelpunkt.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// **Wo der Schlüssel herkommt, steht ÜBER dem Feld und nicht daneben.**
    /// Ein Eingabefeld ohne den Weg zum Schlüssel ist eine Frage ohne Antwort
    /// — und ein Link allein reicht nicht, wenn hinter ihm ein Portal mit
    /// zwanzig Produkten liegt. Deshalb die Schritte in der Reihenfolge, in
    /// der sie zu tun sind.
    private func anleitung(_ zugang: Zugang) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Link(destination: zugang.anmeldung) {
                Label("Schlüssel beantragen", systemImage: "arrow.up.right.square.fill")
                    .font(.body.weight(.medium))
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(zugang.schritte.enumerated()), id: \.offset) { stelle, schritt in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("\(stelle + 1).")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(schritt)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let unterlagen = zugang.unterlagen {
                Link(destination: unterlagen) {
                    Label("Beschreibung der Schnittstelle", systemImage: "book")
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func knopfzeile(_ zugang: Zugang) -> some View {
        Button {
            pruefen(zugang)
        } label: {
            if laufend == zugang.id {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Wird geprüft …")
                }
            } else {
                Label("Zugang prüfen", systemImage: "checkmark.seal")
            }
        }
        .disabled(laufend != nil || (schluessel[zugang.id] ?? "").isEmpty)
    }

    private func befundflaeche(_ befund: Zugangsprobe.Befund) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(befund.deutung, systemImage: befund.gelungen ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(befund.gelungen ? Color.green : Color.orange)

            if !befund.rohtext.isEmpty {
                Text(befund.rohtext)
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(14)
            }

            Button {
                UIPasteboard.general.string = befund.kopiertext
            } label: {
                Label("Befund kopieren", systemImage: "doc.on.doc")
            }
            .font(.footnote)
        }
        .padding(.vertical, 2)
    }

    private func fusszeile(_ zugang: Zugang) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(zugang.nutzen)
            if zugang.gemessen {
                Text("Der Schlüssel steht in der Anfrage als: \(zugang.stelle.beschreibung). Nachgemessen am 18.09.2026 mit einem Platzhalter — die Fehlermeldung wechselte von „kein Schlüssel\u{201C} zu „falscher Schlüssel\u{201C}, der Dienst liest dort also wirklich.")
            } else {
                Text("Der Schlüssel steht in der Anfrage als: \(zugang.stelle.beschreibung) — das ist NICHT nachgemessen. Dieser Dienst antwortete mit und ohne Platzhalter wortgleich; die Stelle stammt aus der Beschreibung, und eine Beschreibung ist keine Messung. Antwortet die Probe mit 401, kann es auch daran liegen.")
            }
            if !zugang.seiteGeprueft {
                Text("Die Anmeldeseite ließ sich beim Bauen der App nicht abrufen — sie liegt hinter einem Bot-Schutz. Sie steht so in der offiziellen Hilfe des Anbieters; nachgesehen hat sie hier aber niemand.")
            }
            Text("Der kopierte Befund enthält den Schlüssel nicht — er wird überall geschwärzt, auch in der Antwort des Dienstes. Rejseplanen schickt ihn bei einem Fehler nämlich im Klartext zurück.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Tun

    private func bindung(_ id: String) -> Binding<String> {
        Binding(
            get: { schluessel[id] ?? "" },
            set: { neu in
                schluessel[id] = neu
                // Sofort in den Schlüsselbund: Ein Feld, das erst beim
                // Verlassen sichert, verliert den Schlüssel genau dann, wenn
                // jemand die App zur Seite legt, um ihn nachzuschlagen.
                Schluesselbund.schreiben(neu, konto: id)
                befunde[id] = nil
            }
        )
    }

    private func schluesselLaden() {
        for zugang in Zugang.alle where schluessel[zugang.id] == nil {
            schluessel[zugang.id] = Schluesselbund.lesen(zugang.id)
        }
    }

    /// Geprüft wird um den Punkt, den die Tafel gerade zeigt — sonst prüfte
    /// man einen Zugang an einer Stelle, an der er gar nicht zuständig ist,
    /// und hielte die leere Antwort für einen falschen Schlüssel.
    private var punkt: CLLocationCoordinate2D {
        if let gewaehlt = model.punkt?.koordinate { return gewaehlt }
        if case .da(let hier) = standort.stand { return hier }
        // Letzte Rettung: ein Punkt, an dem etwas fährt. Eine Probe braucht
        // eine Koordinate, und 0/0 läge im Golf von Guinea.
        return CLLocationCoordinate2D(latitude: 48.1402, longitude: 11.5581)
    }

    private func pruefen(_ zugang: Zugang) {
        let wert = schluessel[zugang.id] ?? ""
        laufend = zugang.id
        Task {
            let befund = await Zugangsprobe.pruefen(zugang, schluessel: wert, bei: punkt)
            befunde[zugang.id] = befund
            laufend = nil
        }
    }
}

#Preview {
    NavigationStack { ZugaengeView() }
        .environmentObject(AppModel(dienst: Musterdienst()))
        .environmentObject(Standortdienst())
}
