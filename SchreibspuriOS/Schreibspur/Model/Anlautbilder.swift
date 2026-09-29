import Foundation

/// Bilder zu jedem Buchstaben: Dinge, deren Name mit ihm beginnt.
///
/// Als Emoji, nicht als eigene Grafiken: Sie sind farbig und freundlich
/// gezeichnet statt piktogrammhaft, auf jedem Gerät vorhanden, frei von
/// Bildrechten (die Anlautbilder von „Flex und Flora“ dürfen wir nicht
/// übernehmen) und in einheitlichem Stil. Ausgewählt nach dem **Laut**,
/// nicht nur nach dem Buchstaben: kein „Eis“ beim E (Ei ist ein eigener
/// Laut), kein „Schaf“ beim S, kein „Pferd“ beim P. Für X, Y und die
/// Umlaute gibt es kaum Anlautwörter — dort steht der Buchstabe im Wort
/// (Taxi, Pony, Bär); die Bilderleiste färbt ihn dann an seiner Stelle.
enum Anlautbilder {
    struct Bild: Hashable {
        let emoji: String
        let wort: String
    }

    /// Bilder zu einem Buchstaben; Groß- und Kleinbuchstabe teilen sie.
    static func bilder(fuer zeichen: Zeichen) -> [Bild] {
        guard !zeichen.istSchwung else { return [] }
        let schluessel = zeichen.id == "ß" ? "ß" : zeichen.id.uppercased()
        return (liste[schluessel] ?? []).map { Bild(emoji: $0.0, wort: $0.1) }
    }

    private static let liste: [String: [(String, String)]] = [
        "A": [("🐒", "Affe"), ("🍍", "Ananas"), ("🍎", "Apfel"), ("⚓", "Anker")],
        "B": [("🍌", "Banane"), ("🐻", "Bär"), ("🌳", "Baum"), ("⚽", "Ball")],
        "C": [("🤡", "Clown"), ("💻", "Computer"), ("🦎", "Chamäleon")],
        "D": [("🦖", "Dino"), ("🐬", "Delfin"), ("🐉", "Drache"), ("🚿", "Dusche")],
        "E": [("🐘", "Elefant"), ("🦆", "Ente"), ("🫏", "Esel"), ("🍓", "Erdbeere")],
        "F": [("🐟", "Fisch"), ("🐸", "Frosch"), ("🦊", "Fuchs"), ("🪶", "Feder")],
        "G": [("🦒", "Giraffe"), ("🎸", "Gitarre"), ("🥒", "Gurke"), ("🎁", "Geschenk")],
        "H": [("🐶", "Hund"), ("🏠", "Haus"), ("🐇", "Hase"), ("🎩", "Hut")],
        "I": [("🦔", "Igel"), ("🏝️", "Insel")],
        "J": [("🧥", "Jacke"), ("🪀", "Jo-Jo"), ("🐆", "Jaguar")],
        "K": [("🐱", "Katze"), ("🐄", "Kuh"), ("🧀", "Käse"), ("👑", "Krone")],
        "L": [("🦁", "Löwe"), ("🦙", "Lama"), ("💡", "Lampe"), ("🍭", "Lolli")],
        "M": [("🐭", "Maus"), ("🌙", "Mond"), ("🍉", "Melone"), ("🥕", "Möhre")],
        "N": [("👃", "Nase"), ("🍜", "Nudeln"), ("🪺", "Nest"), ("🥜", "Nuss")],
        "O": [("🐙", "Oktopus"), ("👵", "Oma"), ("🍊", "Orange"), ("👂", "Ohr")],
        "P": [("🐧", "Pinguin"), ("🍕", "Pizza"), ("🐼", "Panda"), ("🍄", "Pilz")],
        "Q": [("🪼", "Qualle"), ("🟥", "Quadrat")],
        "R": [("🚀", "Rakete"), ("🌹", "Rose"), ("🤖", "Roboter"), ("🌈", "Regenbogen")],
        "S": [("🌞", "Sonne"), ("🧦", "Socke"), ("🥗", "Salat"), ("🦭", "Seehund")],
        "T": [("🐯", "Tiger"), ("🍅", "Tomate"), ("🌷", "Tulpe"), ("🚜", "Traktor")],
        "U": [("🦉", "Uhu"), ("⏰", "Uhr"), ("🛸", "Ufo")],
        "V": [("🐦", "Vogel"), ("🌋", "Vulkan"), ("🏺", "Vase")],
        "W": [("🐋", "Wal"), ("🐺", "Wolf"), ("☁️", "Wolke"), ("🍇", "Weintrauben")],
        "X": [("🚕", "Taxi"), ("🧙‍♀️", "Hexe"), ("🥊", "Boxer")],
        "Y": [("🧘", "Yoga"), ("🛥️", "Yacht"), ("🐴", "Pony")],
        "Z": [("🦓", "Zebra"), ("🍋", "Zitrone"), ("🦷", "Zahn"), ("⛺", "Zelt")],
        "Ä": [("🍎", "Äpfel"), ("🌾", "Ähre"), ("🐻", "Bär")],
        "Ö": [("🛢️", "Öl"), ("🦁", "Löwe"), ("🥕", "Möhre")],
        "Ü": [("🚪", "Tür"), ("🧢", "Mütze"), ("🐥", "Küken")],
        "ß": [("🦶", "Fuß"), ("⚽", "Fußball"), ("🛣️", "Straße")],
    ]
}
