import CoreGraphics
import Foundation

/// Die Schriftzeichen der Grundschrift — jedes als Folge von Strichen in
/// der Reihenfolge und Richtung, in der ein Kind sie schreiben soll.
///
/// Koordinaten in Einheiten des Vierliniensystems (y wächst nach unten):
///
///     y = 0.0   Oberlinie   (Großbuchstaben, Oberlängen, Ziffern)
///     y = 0.45  Mittellinie (Höhe der kleinen Buchstaben)
///     y = 1.0   Grundlinie
///     y = 1.4   Unterlinie  (Unterlängen: f, g, j, p, q, y, ß und J)
///
/// Maße, Strichfolge, Ansatzpunkte und Schreibrichtung folgen dem
/// **Merkblatt Schreibrichtung aus „Flex und Flora 1“** (Westermann),
/// Vorgabe des Nutzers 09/2026 („GENAU so“). Dort bedeutet ein Pfeil mit
/// Punkt: hier ansetzen (lila = erster Strich, türkis = weiterer Strich);
/// ein Pfeil ohne Punkt: ohne Absetzen weiter in diese Richtung. Die
/// Linienabstände (Mittellinie 0,45, Unterlinie 1,4) sind aus dem Blatt
/// gemessen. Die kleinen Buchstaben a, d, h, i, l, m, n, t, u enden mit
/// dem Wendebogen nach rechts. Die Ziffern stehen nicht auf dem Blatt.
///
/// Die Breite ergibt sich aus den Punkten; jedes Zeichen wird später
/// waagerecht mittig gesetzt.
///
/// Wegsprache (absolute Koordinaten, durch Leerzeichen getrennt):
///
///     M x y                  Stift ansetzen (Anfang des Strichs)
///     L x y                  gerade Linie
///     A cx cy rx ry von bis  Ellipsenbogen um (cx, cy), Winkel in Grad;
///                            0° = rechts, 90° = unten. Steigender Winkel
///                            läuft im Uhrzeigersinn, fallender dagegen.
///     Q x1 y1 x y            quadratische Bézierkurve
///     C x1 y1 x2 y2 x y      kubische Bézierkurve
///     P x y                  Punkt (i-Punkt, Umlautpunkte) — nur antippen
///
/// `scripts/zeichen-vorschau.py` zeichnet alle Zeichen samt Richtungspfeilen
/// in ein Bild. Wer hier etwas ändert, schaut sich das Bild an — ein Bogen
/// mit vertauschtem Winkel läuft sonst unbemerkt andersherum.
enum Zeichensatz {

    static let mittellinie: CGFloat = 0.45

    static let grossbuchstaben: [(String, [String])] = [
        ("A", ["M 0.04 1 L 0.4 0 L 0.76 1", "M 0.184 0.6 L 0.616 0.6"]),
        ("B", ["M 0 0 L 0 1", "M 0 0 L 0.2 0 A 0.2 0.23 0.24 0.23 -90 90 L 0 0.46 L 0.24 0.46 A 0.24 0.73 0.28 0.27 -90 90 L 0 1"]),
        ("C", ["M 0.8 0.18 A 0.45 0.5 0.45 0.5 -40 -320"]),
        ("D", ["M 0 0 L 0 1", "M 0 0 L 0.15 0 A 0.15 0.5 0.5 0.5 -90 90 L 0 1"]),
        ("E", ["M 0 0 L 0 1", "M 0 0 L 0.55 0", "M 0 0.46 L 0.45 0.46", "M 0 1 L 0.55 1"]),
        ("F", ["M 0 0 L 0 1", "M 0 0 L 0.55 0", "M 0 0.46 L 0.45 0.46"]),
        ("G", ["M 0.8 0.18 A 0.45 0.5 0.45 0.5 -40 -360 L 0.55 0.5"]),
        ("H", ["M 0 0 L 0 1", "M 0.62 0 L 0.62 1", "M 0 0.5 L 0.62 0.5"]),
        ("I", ["M 0 0 L 0 1"]),
        ("J", ["M 0.3 0 L 0.3 1.2 C 0.3 1.33 0.22 1.4 0.12 1.4 C 0.06 1.4 0.02 1.38 -0.02 1.34"]),
        ("K", ["M 0 0 L 0 1", "M 0.55 0 L 0 0.55 L 0.6 1"]),
        ("L", ["M 0 0 L 0 1 L 0.5 1"]),
        ("M", ["M 0 1 L 0 0 L 0.44 1 L 0.88 0 L 0.88 1"]),
        ("N", ["M 0 1 L 0 0 L 0.65 1 L 0.65 0"]),
        ("O", ["M 0.48 0.067 A 0.32 0.5 0.32 0.5 -60 -420"]),
        ("P", ["M 0 0 L 0 1", "M 0 0 L 0.22 0 A 0.22 0.26 0.26 0.26 -90 90 L 0 0.52"]),
        ("Q", ["M 0.48 0.067 A 0.32 0.5 0.32 0.5 -60 -420", "M 0.4 0.68 L 0.68 1"]),
        ("R", ["M 0 0 L 0 1", "M 0 0 L 0.22 0 A 0.22 0.26 0.26 0.26 -90 90 L 0 0.52 L 0.55 1"]),
        ("S", ["M 0.56 0.14 C 0.46 -0.02 0.03 -0.05 0.03 0.25 C 0.03 0.52 0.6 0.44 0.6 0.74 C 0.6 1.06 0.1 1.06 0 0.86"]),
        ("T", ["M 0.35 0 L 0.35 1", "M 0 0 L 0.7 0"]),
        ("U", ["M 0 0 L 0 0.66 A 0.3 0.66 0.3 0.34 180 0 L 0.6 0"]),
        ("V", ["M 0 0 L 0.35 1 L 0.7 0"]),
        ("W", ["M 0 0 L 0.25 1 L 0.5 0 L 0.75 1 L 1 0"]),
        ("X", ["M 0 0 L 0.65 1", "M 0.65 0 L 0 1"]),
        ("Y", ["M 0 0 L 0.35 0.5", "M 0.7 0 L 0.35 0.5 L 0.35 1"]),
        ("Z", ["M 0 0 L 0.65 0 L 0 1 L 0.65 1"]),
        ("Ä", ["M 0.04 1 L 0.4 0 L 0.76 1", "M 0.184 0.6 L 0.616 0.6", "P 0.26 -0.14", "P 0.54 -0.14"]),
        ("Ö", ["M 0.48 0.067 A 0.32 0.5 0.32 0.5 -60 -420", "P 0.18 -0.14", "P 0.46 -0.14"]),
        ("Ü", ["M 0 0 L 0 0.66 A 0.3 0.66 0.3 0.34 180 0 L 0.6 0", "P 0.16 -0.14", "P 0.44 -0.14"]),
    ]

    static let kleinbuchstaben: [(String, [String])] = [
        ("a", ["M 0.378 0.514 A 0.23 0.725 0.23 0.275 -50 -360 L 0.46 0.45 L 0.46 0.84 C 0.46 0.95 0.51 1 0.61 0.98"]),
        ("b", ["M 0 0 L 0 1 L 0 0.725 A 0.23 0.725 0.23 0.275 180 540"]),
        ("c", ["M 0.4 0.55 A 0.23 0.725 0.23 0.275 -40 -320"]),
        ("d", ["M 0.378 0.514 A 0.23 0.725 0.23 0.275 -50 -360 L 0.46 0 L 0.46 0.84 C 0.46 0.95 0.51 1 0.61 0.98"]),
        ("e", ["M 0 0.73 L 0.46 0.73 A 0.23 0.725 0.23 0.275 0 -315"]),
        ("f", ["M 0.42 0.08 C 0.36 0.01 0.28 0 0.22 0 C 0.13 0 0.08 0.07 0.08 0.18 L 0.08 1.4", "M -0.06 0.45 L 0.28 0.45"]),
        ("g", ["M 0.378 0.514 A 0.23 0.725 0.23 0.275 -50 -360 L 0.46 0.45 L 0.46 1.2 C 0.46 1.34 0.38 1.4 0.24 1.4 C 0.12 1.4 0.04 1.36 0 1.3"]),
        ("h", ["M 0 0 L 0 1 L 0 0.7 C 0 0.54 0.1 0.45 0.22 0.45 C 0.36 0.45 0.44 0.54 0.44 0.7 L 0.44 0.84 C 0.44 0.95 0.49 1 0.59 0.98"]),
        ("i", ["M 0 0.45 L 0 0.84 C 0 0.95 0.05 1 0.15 0.98", "P 0 0.22"]),
        ("j", ["M 0.26 0.45 L 0.26 1.22 C 0.26 1.35 0.19 1.4 0.1 1.4 C 0.04 1.4 0 1.38 -0.04 1.34", "P 0.26 0.22"]),
        ("k", ["M 0 0 L 0 1", "M 0.38 0.45 L 0 0.74 L 0.4 1"]),
        ("l", ["M 0 0 L 0 0.84 C 0 0.95 0.05 1 0.15 0.98"]),
        ("m", ["M 0 0.45 L 0 1 L 0 0.68 C 0 0.52 0.08 0.45 0.18 0.45 C 0.29 0.45 0.36 0.52 0.36 0.68 L 0.36 1 L 0.36 0.68 C 0.36 0.52 0.44 0.45 0.54 0.45 C 0.65 0.45 0.72 0.52 0.72 0.68 L 0.72 0.84 C 0.72 0.95 0.77 1 0.87 0.98"]),
        ("n", ["M 0 0.45 L 0 1 L 0 0.7 C 0 0.54 0.1 0.45 0.22 0.45 C 0.36 0.45 0.44 0.54 0.44 0.7 L 0.44 0.84 C 0.44 0.95 0.49 1 0.59 0.98"]),
        ("o", ["M 0.352 0.492 A 0.23 0.725 0.23 0.275 -58 -418"]),
        ("p", ["M 0 0.45 L 0 1.4 L 0 0.725 A 0.23 0.725 0.23 0.275 180 540"]),
        ("q", ["M 0.378 0.514 A 0.23 0.725 0.23 0.275 -50 -360 L 0.46 0.45 L 0.46 1.4"]),
        ("r", ["M 0 0.45 L 0 1 L 0 0.7 C 0 0.54 0.1 0.45 0.22 0.45 C 0.28 0.45 0.33 0.47 0.36 0.5"]),
        ("s", ["M 0.36 0.52 C 0.3 0.46 0.02 0.44 0.02 0.59 C 0.02 0.74 0.38 0.7 0.38 0.86 C 0.38 1.03 0.08 1.03 0 0.93"]),
        ("t", ["M 0.1 0.05 L 0.1 0.84 C 0.1 0.95 0.15 1 0.25 0.98", "M -0.04 0.45 L 0.28 0.45"]),
        ("u", ["M 0 0.45 L 0 0.75 C 0 0.9 0.1 1 0.22 1 C 0.34 1 0.44 0.9 0.44 0.75 L 0.44 0.45 L 0.44 0.84 C 0.44 0.95 0.49 1 0.59 0.98"]),
        ("v", ["M 0 0.45 L 0.24 1 L 0.48 0.45"]),
        ("w", ["M 0 0.45 L 0.18 1 L 0.36 0.45 L 0.54 1 L 0.72 0.45"]),
        ("x", ["M 0 0.45 L 0.44 1", "M 0.44 0.45 L 0 1"]),
        ("y", ["M 0 0.45 L 0.24 1", "M 0.48 0.45 L 0.066 1.4"]),
        ("z", ["M 0 0.45 L 0.42 0.45 L 0 1 L 0.42 1"]),
        ("ä", ["M 0.378 0.514 A 0.23 0.725 0.23 0.275 -50 -360 L 0.46 0.45 L 0.46 0.84 C 0.46 0.95 0.51 1 0.61 0.98", "P 0.1 0.22", "P 0.36 0.22"]),
        ("ö", ["M 0.352 0.492 A 0.23 0.725 0.23 0.275 -58 -418", "P 0.1 0.22", "P 0.36 0.22"]),
        ("ü", ["M 0 0.45 L 0 0.75 C 0 0.9 0.1 1 0.22 1 C 0.34 1 0.44 0.9 0.44 0.75 L 0.44 0.45 L 0.44 0.84 C 0.44 0.95 0.49 1 0.59 0.98", "P 0.08 0.22", "P 0.36 0.22"]),
        ("ß", ["M 0 1.4 L 0 0.25 C 0 0.08 0.1 0 0.23 0 C 0.37 0 0.46 0.1 0.46 0.22 C 0.46 0.36 0.36 0.44 0.22 0.45 C 0.4 0.47 0.52 0.58 0.52 0.72 C 0.52 0.9 0.4 1 0.22 1 L 0.12 1"]),
    ]

    static let ziffern: [(String, [String])] = [
        ("0", ["M 0.3 0 A 0.3 0.5 0.3 0.5 -90 -450"]),
        ("1", ["M 0.05 0.28 L 0.4 0 L 0.4 1"]),
        ("2", ["M 0.03 0.24 C 0.06 -0.06 0.6 -0.08 0.58 0.27 C 0.56 0.5 0.22 0.7 0 1 L 0.6 1"]),
        ("3", ["M 0.05 0.12 C 0.2 -0.05 0.57 -0.03 0.55 0.23 C 0.53 0.42 0.36 0.47 0.22 0.47 C 0.46 0.47 0.62 0.58 0.6 0.75 C 0.58 1.03 0.14 1.05 0 0.87"]),
        ("4", ["M 0.35 0 L 0 0.65 L 0.62 0.65", "M 0.46 0.35 L 0.46 1"]),
        ("5", ["M 0.1 0 L 0.05 0.44 C 0.25 0.33 0.6 0.37 0.6 0.68 C 0.6 1.03 0.14 1.05 0 0.88", "M 0.1 0 L 0.55 0"]),
        ("6", ["M 0.5 0.03 C 0.22 0.1 0.02 0.38 0.02 0.7 A 0.3 0.7 0.28 0.3 180 -180"]),
        ("7", ["M 0 0 L 0.6 0 L 0.18 1"]),
        ("8", ["M 0.3 0 C 0.02 0 0.02 0.25 0.06 0.3 C 0.12 0.4 0.58 0.5 0.58 0.75 C 0.58 1.0 0.02 1.0 0.02 0.75 C 0.02 0.5 0.48 0.4 0.54 0.3 C 0.58 0.25 0.58 0 0.3 0"]),
        ("9", ["M 0.55 0.3 A 0.3 0.3 0.25 0.3 0 -360 L 0.55 0.62 C 0.55 0.9 0.4 1 0.1 1"]),
    ]

    /// Schwungübungen: die Grundformen, aus denen die Buchstaben bestehen —
    /// Striche, Zacken, Wendebogen, Brücken (n, m, h, r), Girlanden (u),
    /// Bögen (c, e), Kreise gegen den Uhrzeigersinn (o, a, d, g) und Wellen
    /// (s). Richtungen wie in den Buchstaben des Merkblatts.
    static let schwuenge: [(String, [String])] = [
        ("Lange Striche", ["M 0 0 L 0 1", "M 0.32 0 L 0.32 1", "M 0.64 0 L 0.64 1", "M 0.96 0 L 0.96 1", "M 1.28 0 L 1.28 1"]),
        ("Kurze Striche", ["M 0 0.45 L 0 1", "M 0.28 0.45 L 0.28 1", "M 0.56 0.45 L 0.56 1", "M 0.84 0.45 L 0.84 1", "M 1.12 0.45 L 1.12 1", "M 1.4 0.45 L 1.4 1"]),
        ("Querstriche", ["M 0 0.6 L 1.3 0.6", "M 0 0.86 L 1.3 0.86"]),
        ("Zacken", ["M 0 1 L 0.2 0.45 L 0.4 1 L 0.6 0.45 L 0.8 1 L 1 0.45 L 1.2 1 L 1.4 0.45 L 1.6 1"]),
        ("Wendebögen", ["M 0 0.45 L 0 0.84 C 0 0.95 0.05 1 0.15 0.98", "M 0.36 0.45 L 0.36 0.84 C 0.36 0.95 0.41 1 0.51 0.98", "M 0.72 0.45 L 0.72 0.84 C 0.72 0.95 0.77 1 0.87 0.98", "M 1.08 0.45 L 1.08 0.84 C 1.08 0.95 1.13 1 1.23 0.98"]),
        ("Brücken", ["M 0 1 L 0 0.7 C 0 0.54 0.1 0.45 0.22 0.45 C 0.34 0.45 0.44 0.54 0.44 0.7 L 0.44 1 L 0.44 0.7 C 0.44 0.54 0.54 0.45 0.66 0.45 C 0.78 0.45 0.88 0.54 0.88 0.7 L 0.88 1 L 0.88 0.7 C 0.88 0.54 0.98 0.45 1.1 0.45 C 1.22 0.45 1.32 0.54 1.32 0.7 L 1.32 1"]),
        ("Girlanden", ["M 0 0.45 L 0 0.75 C 0 0.9 0.1 1 0.22 1 C 0.34 1 0.44 0.9 0.44 0.75 L 0.44 0.45 L 0.44 0.75 C 0.44 0.9 0.54 1 0.66 1 C 0.78 1 0.88 0.9 0.88 0.75 L 0.88 0.45 L 0.88 0.75 C 0.88 0.9 0.98 1 1.1 1 C 1.22 1 1.32 0.9 1.32 0.75 L 1.32 0.45"]),
        ("Bögen", ["M 0.4 0.55 A 0.23 0.725 0.23 0.275 -40 -320", "M 0.95 0.55 A 0.78 0.725 0.23 0.275 -40 -320", "M 1.5 0.55 A 1.33 0.725 0.23 0.275 -40 -320"]),
        ("Kreise", ["M 0.352 0.492 A 0.23 0.725 0.23 0.275 -58 -418", "M 0.922 0.492 A 0.8 0.725 0.23 0.275 -58 -418", "M 1.492 0.492 A 1.37 0.725 0.23 0.275 -58 -418"]),
        ("Wellen", ["M 0 0.725 C 0.10 0.5 0.20 0.5 0.30 0.725 C 0.40 0.95 0.50 0.95 0.60 0.725 C 0.70 0.5 0.80 0.5 0.90 0.725 C 1.00 0.95 1.10 0.95 1.20 0.725 C 1.30 0.5 1.40 0.5 1.50 0.725"]),
    ]

    /// Lehrgangsreihenfolge von „Flex und Flora 1“ — genau die Reihenfolge
    /// des Merkblatts: Vorderseite beginnend mit A, daneben M, dann O und
    /// weiter zeilenweise, danach die Rückseite (Ansage des Nutzers
    /// 09/2026). Jeder Schritt ist ein Buchstabe (Groß und klein) oder eine
    /// Buchstabenverbindung, die als eigener Laut gelernt wird (Au, Sch …).
    /// Die Verbindungen haben keine eigene Schreibübung, entscheiden aber,
    /// ab wann ein Wort mit ihnen geschrieben werden darf.
    static let lehrgangSchritte: [String] = [
        "A a", "M m", "O o", "I i", "L l", "U u", "E e", "S s",
        "F f", "N n", "W w", "R r", "T t", "Au au", "P p", "Ei ei",
        "D d", "Sch sch", "K k", "H h", "B b", "G g", "Z z", "Eu eu",
        "ch", "ie", "Sp sp", "St st", "J j", "V v", "Ö ö", "Ü ü",
        "Ä ä", "äu", "Pf pf", "Qu qu", "ß", "C c", "Y y", "X x",
        "ng", "tz", "ck", "nk",
    ]

    /// Wörter für die Heftzeile. Welches Wort wann dran ist, ergibt sich aus
    /// `Zeichenvorrat.wortSchritt`: erst wenn alle Buchstaben **und** alle
    /// Verbindungen darin (ei, au, sch, ch, ie, st/sp am Anfang, pf, ng …)
    /// gelernt sind. Bewusst nicht aufgenommen: Wörter, in denen Buchstaben
    /// anders klingen, als das Kind sie kennt (Mais, Ferien, Clown,
    /// Computer).
    static let woerter: [String] = [
        "Mama", "Oma", "Omi", "Mimi", "Mia", "Lama", "Limo", "Lola", "Lili", "Lolli",
        "Milo", "Ali", "alle", "Ulli", "Ulla", "Uli", "Emil", "Emma", "Ella", "Lea",
        "Leo", "Allee", "Ulme", "Emu", "Esel", "Salami", "Lisa", "Susi", "Suse",
        "Saal", "Moos", "Mus", "Oase", "Sessel", "alles", "Sofa", "Fee", "Fell", "Film",
        "Fass", "Nase", "Nina", "Name", "Nil", "Mann", "Sonne", "Linse", "Nuss", "Nonne",
        "Mine", "Ofen", "Nudel", "Wal", "Wolle", "Welle", "Wanne", "Wolf", "Waffel", "Rose",
        "Rasen", "Rolle", "Roller", "Wasser", "Rosine", "Ruine", "Tomate", "Tante", "Tor", "Turm",
        "Tasse", "Tunnel", "Tanne", "Ente", "Tee", "Tafel", "Taste", "Wurst", "Mantel", "Nest",
        "Auto", "Maus", "Laus", "Traum", "Frau", "Pause", "Papa", "Post", "Puppe", "Pirat",
        "Pilot", "Pinsel", "Lampe", "Tulpe", "Ei", "Eis", "Eimer", "Seil", "Seife", "Reis",
        "Wein", "Dose", "Dino", "Dame", "Radio", "Wand", "Dorf", "Mond", "Ende", "Leder",
        "Fisch", "Tisch", "Schule", "Schaf", "Schal", "Dusche", "Tasche", "Flasche", "Kamel", "Kanu",
        "Kino", "Kakao", "Kiste", "Paket", "Kette", "Rakete", "Kerze", "Kater", "Hut", "Haus",
        "Hose", "Hand", "Honig", "Huhn", "Uhu", "Uhr", "Kuh", "Hemd", "Himmel", "Baum",
        "Ball", "Bus", "Banane", "Bett", "Birne", "Brot", "Rabe", "Hobel", "Gans", "Gabel",
        "Igel", "Gurke", "Garten", "Regen", "Nagel", "Geld", "Gold", "Wagen", "Tiger", "Berg",
        "Glas", "Zebra", "Zahn", "Zelt", "Zug", "Zaun", "Zitrone", "Pilz", "Salz", "Herz",
        "Zimmer", "Eule", "Heu", "Feuer", "Euro", "Buch", "Dach", "Milch", "Kuchen", "Bach",
        "Biene", "Wiese", "Tier", "Spiel", "Spinne", "Stern", "Stein", "Stift", "Stuhl", "Jojo",
        "Jana", "Juli", "Jonas", "Jaguar", "Vogel", "Vase", "Vulkan", "Vater", "Klavier", "Olive",
        "Öl", "Löwe", "Möhre", "Vögel", "Flöte", "König", "Kröte", "Löffel", "Tür", "Mütze",
        "Küken", "Rübe", "Tüte", "Hütte", "Bügel", "Bär", "Käse", "Träne", "Säge", "Käfer",
        "Zähne", "Hände", "Mäuse", "Häuser", "Bäume", "Apfel", "Äpfel", "Kopf", "Pferd", "Pfanne",
        "Qualle", "Quark", "Quelle", "Fuß", "Straße", "Füße", "Fußball", "Soße", "Pony", "Baby",
        "Teddy", "Taxi", "Hexe", "Axt", "Box", "Nixe", "Ring", "Engel", "Finger", "Hunger",
        "Zange", "Katze", "Platz", "Sack", "Rock", "Socke", "Jacke", "Brücke", "Zucker", "Bank",
        "Onkel", "Anker", "Schrank",
    ]
}
