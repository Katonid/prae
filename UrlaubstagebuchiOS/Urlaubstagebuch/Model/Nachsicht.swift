import Foundation

// Ein Leser, der eine fehlende Angabe überliest.
//
// Swift baut den Leser einer `Codable`-Struktur selbst — und der verlangt
// JEDEN Schlüssel, auch wenn die Eigenschaft einen Vorgabewert hat. Ein
// neues Feld in einer neuen Fassung macht damit jede vorher gesicherte
// Datei unlesbar: Das Buch öffnet sich nicht mehr, weil eine Einstellung
// hinzugekommen ist, die es noch gar nicht geben konnte.
//
// Bei einem Reisetagebuch ist das der teuerste denkbare Fehler — es gibt
// keine zweite Ausfertigung. Deshalb schreiben die Typen, die wachsen,
// ihren Leser von Hand und holen jede Angabe hierüber.
//
// `try?` schluckt dabei auch einen Typfehler, und das ist Absicht: Eine
// Einstellung, deren Bedeutung sich geändert hat, fällt auf ihren
// Vorgabewert zurück. Eine verlorene Einstellung ist ein Ärgernis, ein
// verlorenes Buch ein Verlust.
extension KeyedDecodingContainer {
    func wert<T: Decodable>(_ schluessel: Key, _ vorgabe: T) -> T {
        (try? decodeIfPresent(T.self, forKey: schluessel)) ?? vorgabe
    }

    func wahlweise<T: Decodable>(_ schluessel: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: schluessel)) ?? nil
    }
}
