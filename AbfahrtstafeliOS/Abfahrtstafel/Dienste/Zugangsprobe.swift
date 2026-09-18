import CoreLocation
import Foundation

/// Fragt einen Zugang mit dem eingetragenen Schlüssel ab und gibt die ROHE
/// Antwort zurück.
///
/// **Der rohe Text ist der Zweck, nicht ein Zugeständnis.** Dieselbe Regel wie
/// bei Schulalarms „Zustellung prüfen": Eine Meldung, die den Fehler bloß
/// aufhübscht, ist die Frage von vorhin noch einmal. Hier kommt dazu, dass
/// genau diese Antwort das Material ist, aus dem die Quelle gebaut wird —
/// jede Quelle dieser App ist an einer echten Antwort entstanden und keine an
/// einer Beschreibung.
enum Zugangsprobe {

    struct Befund: Sendable {
        let gelungen: Bool
        /// Die abgefragte Adresse, mit geschwärztem Schlüssel.
        let adresse: String
        let status: Int?
        /// Die Antwort, mit geschwärztem Schlüssel, vorne abgeschnitten.
        let rohtext: String
        /// Ein Satz darüber, was der Status bedeutet — ohne ihn steht eine
        /// Zahl da und sonst nichts.
        let deutung: String

        /// Was der Nutzer kopiert und weitergibt. **Ohne Schlüssel.**
        var kopiertext: String {
            """
            \(deutung)
            Adresse: \(adresse)
            Status: \(status.map(String.init) ?? "keine Antwort")

            \(rohtext)
            """
        }
    }

    /// Wie viel von der Antwort gezeigt wird.
    ///
    /// Eine Abfahrtstafel als JSON hat schnell hunderte Kilobyte; davon sagen
    /// die ersten Zeilen alles über den Aufbau. Der Rest wäre eine Wand, durch
    /// die niemand liest — und aus der Zwischenablage eines iPads bekäme man
    /// ihn ohnehin nicht heraus.
    private static let hoechstzahlZeichen = 4000

    static func pruefen(
        _ zugang: Zugang,
        schluessel: String,
        bei punkt: CLLocationCoordinate2D,
        sitzung: URLSession = .abfahrtstafel
    ) async -> Befund {
        let sauber = schluessel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty else {
            return Befund(
                gelungen: false,
                adresse: "-",
                status: nil,
                rohtext: "",
                deutung: "Es steht kein Schlüssel im Feld."
            )
        }

        guard var bausatz = zugang.probe(punkt) else {
            return Befund(
                gelungen: false,
                adresse: "-",
                status: nil,
                rohtext: "",
                deutung: "Die Adresse ließ sich nicht bauen."
            )
        }

        // Geheimnisse, die geschwärzt werden müssen — beim zweiteiligen
        // Zugang sind es zwei.
        var geheim: [String] = []
        var anfrage: URLRequest

        switch zugang.stelle {
        case .abfrageparameter(let name):
            bausatz.queryItems = (bausatz.queryItems ?? []) + [URLQueryItem(name: name, value: sauber)]
            geheim.append(sauber)
            guard let adresse = bausatz.url else { return unlesbareAdresse() }
            anfrage = URLRequest(url: adresse)

        case .basic:
            geheim.append(sauber)
            guard let adresse = bausatz.url else { return unlesbareAdresse() }
            anfrage = URLRequest(url: adresse)
            // Der Schlüssel steht als Benutzername, das Kennwort bleibt leer —
            // so nimmt Navitia ihn an (nachgemessen: über den
            // Abfrageparameter `key` sieht der Dienst gar keinen Schlüssel).
            let paar = Data("\(sauber):".utf8).base64EncodedString()
            anfrage.setValue("Basic \(paar)", forHTTPHeaderField: "Authorization")
            geheim.append(paar)

        case .kopfzeile(let name):
            geheim.append(sauber)
            guard let adresse = bausatz.url else { return unlesbareAdresse() }
            anfrage = URLRequest(url: adresse)
            anfrage.setValue(sauber, forHTTPHeaderField: name)

        case .zweiKopfzeilen(let kennungsfeld, let schluesselfeld):
            // Zwei Angaben in einem Feld, durch Doppelpunkt getrennt. Zwei
            // Eingabefelder wären ehrlicher und hätten den ganzen Bildschirm
            // für einen einzigen Sonderfall umgebaut.
            let teile = sauber.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard teile.count == 2 else {
                return Befund(
                    gelungen: false,
                    adresse: "-",
                    status: nil,
                    rohtext: "",
                    deutung: "Dieser Zugang braucht zwei Angaben: Kennung und Schlüssel, getrennt durch einen Doppelpunkt."
                )
            }
            let kennung = String(teile[0]).trimmingCharacters(in: .whitespaces)
            let wert = String(teile[1]).trimmingCharacters(in: .whitespaces)
            geheim.append(contentsOf: [sauber, kennung, wert])
            guard let adresse = bausatz.url else { return unlesbareAdresse() }
            anfrage = URLRequest(url: adresse)
            anfrage.setValue(kennung, forHTTPHeaderField: kennungsfeld)
            anfrage.setValue(wert, forHTTPHeaderField: schluesselfeld)
        }

        anfrage.setValue("application/json", forHTTPHeaderField: "Accept")

        let gezeigteAdresse = geschwaerzt(anfrage.url?.absoluteString ?? "-", geheim)

        do {
            let (daten, antwort) = try await sitzung.data(for: anfrage)
            let status = (antwort as? HTTPURLResponse)?.statusCode
            let text = String(data: daten, encoding: .utf8) ?? "\(daten.count) Bytes, nicht als Text lesbar"
            let gekuerzt = String(text.prefix(hoechstzahlZeichen))
            let gelungen = (200..<300).contains(status ?? 0)
            return Befund(
                gelungen: gelungen,
                adresse: gezeigteAdresse,
                status: status,
                rohtext: geschwaerzt(gekuerzt, geheim),
                deutung: deutung(status: status, gelungen: gelungen)
            )
        } catch let fehler as URLError {
            return Befund(
                gelungen: false,
                adresse: gezeigteAdresse,
                status: nil,
                rohtext: geschwaerzt(fehler.localizedDescription, geheim),
                deutung: "Der Dienst war nicht zu erreichen. Das sagt nichts über den Schlüssel."
            )
        } catch {
            return Befund(
                gelungen: false,
                adresse: gezeigteAdresse,
                status: nil,
                rohtext: geschwaerzt(error.localizedDescription, geheim),
                deutung: "Die Anfrage ist gescheitert."
            )
        }
    }

    // MARK: - Schwärzen

    /// **Ein Schlüssel kann in der ANTWORT stehen** — das ist gemessen und
    /// nicht vorsichtshalber angenommen: Rejseplanen schickt bei einem
    /// falschen Schlüssel den Satz „access denied for <Schlüssel> on
    /// location.name" zurück, also das Geheimnis im Klartext. Ein Befund, den
    /// der Nutzer kopiert und weiterschickt, hätte ihn damit mitgenommen.
    ///
    /// Geschwärzt wird deshalb IMMER und an jeder Stelle: in der Adresse, im
    /// Rohtext und in jeder Fehlermeldung.
    private static func geschwaerzt(_ text: String, _ geheimnisse: [String]) -> String {
        var ergebnis = text
        // Die längsten zuerst — sonst zerlegt ein kurzes Teilstück das lange
        // und der Rest bliebe stehen.
        for geheim in geheimnisse.filter({ $0.count >= 4 }).sorted(by: { $0.count > $1.count }) {
            ergebnis = ergebnis.replacingOccurrences(of: geheim, with: "«Schlüssel»")
            // Auch die prozentkodierte Form: In einer Adresse steht der
            // Schlüssel maskiert, und dann greift der Vergleich oben nicht.
            if let kodiert = geheim.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
               kodiert != geheim {
                ergebnis = ergebnis.replacingOccurrences(of: kodiert, with: "«Schlüssel»")
            }
        }
        return ergebnis
    }

    private static func unlesbareAdresse() -> Befund {
        Befund(
            gelungen: false,
            adresse: "-",
            status: nil,
            rohtext: "",
            deutung: "Die Adresse ließ sich nicht bauen."
        )
    }

    private static func deutung(status: Int?, gelungen: Bool) -> String {
        guard let status else { return "Keine Antwort." }
        if gelungen { return "Der Schlüssel gilt — der Zugang hat geantwortet." }
        switch status {
        case 401, 403:
            return "Der Zugang hat geantwortet und den Schlüssel abgelehnt. Entweder stimmt er nicht, oder er ist für diese Abfrage nicht freigeschaltet."
        case 404:
            return "Der Zugang kennt diese Adresse nicht. Das sagt nichts über den Schlüssel."
        case 429:
            return "Zu viele Anfragen. Der Schlüssel gilt, das Kontingent ist aufgebraucht."
        case 500...599:
            return "Der Zugang hat einen Fehler bei sich selbst gemeldet. Das sagt nichts über den Schlüssel."
        default:
            return "Der Zugang hat mit Code \(status) geantwortet."
        }
    }
}
