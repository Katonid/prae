import SwiftUI
import UIKit

// DAS SYMBOL EINER REISE (ab 1.0.5, Ansage des Nutzers 09/2026: „Hier ist
// mir die Auswahl zu gering … Zugriff auf alle Symbole, die Apple zur
// Verfügung stellt“ — und dann „beides“: Emojis UND Apples Symbole).
//
// Gespeichert wird weiter im Attribut `emoji` — ein neues Attribut hieße ein
// Schema-Deploy für eine Zeichenkette. Ein Apple-Symbol steht dort als
// `sf:<Name>`, alles andere ist ein Emoji. Die Unterscheidung trifft NUR
// `Reisesymbol`; wer irgendwo sonst `emoji` in einen `Text` steckt, zeigt
// „sf:airplane“ im Klartext.

enum Reisesymbol {
    static let vorsatz = "sf:"

    static func sfName(_ wert: String?) -> String? {
        guard let wert, wert.hasPrefix(vorsatz) else { return nil }
        let name = String(wert.dropFirst(vorsatz.count))
        return UIImage(systemName: name) == nil ? nil : name
    }

    /// Als `Text` — damit es in einer Zeile vor dem Titel stehen kann und
    /// dieselbe Schrift bekommt.
    static func text(_ wert: String?, ersatz: String = "") -> Text {
        if let name = sfName(wert) { return Text(Image(systemName: name)) }
        let w = wert ?? ""
        if w.hasPrefix(vorsatz) { return Text(ersatz) }
        return Text(w.isEmpty ? ersatz : w)
    }

    /// „Symbol Titel“ in einer Zeile.
    static func mitTitel(_ wert: String?, _ titel: String) -> Text {
        let symbol = text(wert)
        let leer = (wert ?? "").isEmpty
        return leer ? Text(titel) : symbol + Text(" " + titel)
    }
}

/// Das große Symbol auf einem Titelbild ohne Foto.
struct ReisesymbolBild: View {
    let wert: String?
    var groesse: CGFloat = 90

    var body: some View {
        if let name = Reisesymbol.sfName(wert) {
            Image(systemName: name)
                .font(.system(size: groesse * 0.85, weight: .semibold))
                .foregroundStyle(.white)
        } else {
            Text((wert ?? "").isEmpty || (wert ?? "").hasPrefix(Reisesymbol.vorsatz) ? "✈️" : (wert ?? ""))
                .font(.system(size: groesse))
        }
    }
}

// MARK: - Auswahl

/// Beides in einem Blatt: Emojis über die Tastatur des Systems (dort gibt es
/// ALLE, ohne dass die App eine Liste führen muss) und Apples Symbole aus
/// einer mitgelieferten Liste.
///
/// **Apple gibt keine Liste seiner Symbole heraus** — es gibt keine
/// Schnittstelle, die sie aufzählt. Die Liste steht deshalb hier, rund
/// dreihundert Namen in Gruppen, und jeder wird beim Anzeigen mit
/// `UIImage(systemName:)` nachgeschlagen: Was es auf diesem Gerät nicht gibt,
/// erscheint nicht, statt ein leeres Feld zu zeigen.
struct SymbolWahl: View {
    @Binding var wert: String
    let palette: Palette
    @Environment(\.dismiss) private var schliessen

    enum Art: String, CaseIterable, Identifiable {
        case symbole = "Symbole", emoji = "Emoji"
        var id: String { rawValue }
    }

    @State private var art: Art = .symbole
    @State private var suche = ""
    @State private var emojiEingabe = ""
    @FocusState private var emojiFokus: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Art", selection: $art) {
                    ForEach(Art.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                switch art {
                case .symbole: symbolListe
                case .emoji: emojiFeld
                }
            }
            .navigationTitle("Symbol der Reise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
            }
            .onAppear {
                if !wert.isEmpty && !wert.hasPrefix(Reisesymbol.vorsatz) { art = .emoji }
            }
        }
    }

    private var gefilterteGruppen: [(String, [String])] {
        let s = suche.trimmingCharacters(in: .whitespaces).lowercased()
        return Symbolkatalog.gruppen.compactMap { gruppe, namen in
            let passend = namen.filter { name in
                guard UIImage(systemName: name) != nil else { return false }
                if s.isEmpty { return true }
                return gruppe.lowercased().contains(s) || name.contains(s)
                    || (Symbolkatalog.stichworte[name] ?? "").contains(s)
            }
            return passend.isEmpty ? nil : (gruppe, passend)
        }
    }

    /// Ziffern und # gelten Unicode als „Emoji“ — deshalb die Prüfung auf
    /// Darstellung ODER zusammengesetzte Zeichen (Hautton, Flagge, ✈️ mit
    /// Variantenwahl).
    static func istEmoji(_ z: Character) -> Bool {
        guard let erstes = z.unicodeScalars.first else { return false }
        return erstes.properties.isEmojiPresentation
            || (erstes.properties.isEmoji && z.unicodeScalars.count > 1)
    }

    private var symbolListe: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18, pinnedViews: []) {
                ForEach(gefilterteGruppen, id: \.0) { gruppe, namen in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(gruppe).font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
                            ForEach(namen, id: \.self) { name in
                                let an = wert == Reisesymbol.vorsatz + name
                                Button {
                                    wert = Reisesymbol.vorsatz + name
                                } label: {
                                    Image(systemName: name)
                                        .font(.title2)
                                        .frame(width: 52, height: 52)
                                        .foregroundStyle(an ? Color.white : palette.haupt)
                                        .background(an ? AnyShapeStyle(palette.verlauf) : AnyShapeStyle(palette.hell.opacity(0.15)),
                                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(name)
                            }
                        }
                    }
                }
                if gefilterteGruppen.isEmpty {
                    Text("Nichts gefunden. Gesucht wird in den Gruppennamen, in deutschen Stichworten und in Apples englischen Symbolnamen (z. B. „airplane“, „mountain“).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .searchable(text: $suche, placement: .navigationBarDrawer(displayMode: .always), prompt: "Suchen, z. B. Berg, Zug, Strand")
    }

    private var emojiFeld: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Text(wert.isEmpty || wert.hasPrefix(Reisesymbol.vorsatz) ? "–" : wert)
                        .font(.system(size: 72))
                    Spacer()
                }
                TextField("Emoji eingeben", text: $emojiEingabe)
                    .focused($emojiFokus)
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .onChange(of: emojiEingabe) { _, neu in
                        // Das zuletzt getippte Zeichen gilt — aber nur, wenn
                        // es wirklich ein Emoji ist; Buchstaben sind kein Symbol.
                        if let letztes = neu.last, Self.istEmoji(letztes) {
                            wert = String(letztes)
                        }
                        if neu.count > 1 { emojiEingabe = neu.last.map(String.init) ?? "" }
                    }
            } footer: {
                Text("Tippe ins Feld und wechsle mit der Weltkugel oder dem Smiley unten auf der Tastatur zu den Emojis — dort stehen alle, die dein Gerät kennt.")
            }
            Section("Schnell gewählt") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                    ForEach(Symbolkatalog.emojis, id: \.self) { e in
                        Text(e)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(wert == e ? palette.hell.opacity(0.35) : Color.clear, in: Circle())
                            .onTapGesture { wert = e }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear { emojiFokus = true }
    }
}

/// Die mitgelieferte Auswahl aus Apples Symbolen. Alles, was eine Reise
/// ausmachen kann — und nicht die Büroklammern und Pfeile.
enum Symbolkatalog {
    static let emojis = ["✈️", "🏖️", "🏔️", "🚗", "🚆", "⛺️", "🛳️", "🚲", "🌋", "🏝️", "🗺️", "🌸",
                         "🏕️", "⛷️", "🏄", "🚐", "🏰", "🎡", "🌅", "🗽", "🍝", "🍷", "🐘", "❤️"]

    static let gruppen: [(String, [String])] = [
        ("Unterwegs", [
            "airplane", "airplane.departure", "airplane.arrival", "car.fill", "car.side.fill", "bus.fill",
            "bus.doubledecker.fill", "tram.fill", "train.side.front.car", "cablecar.fill", "ferry.fill",
            "sailboat.fill", "bicycle", "scooter", "motorcycle", "figure.walk", "figure.hiking",
            "suitcase.fill", "suitcase.rolling.fill", "backpack.fill", "map.fill", "globe.europe.africa.fill",
            "globe.americas.fill", "globe.asia.australia.fill", "location.fill", "signpost.right.fill",
            "fuelpump.fill", "road.lanes", "ticket.fill", "passport",
        ]),
        ("Natur", [
            "mountain.2.fill", "sun.max.fill", "sunrise.fill", "sunset.fill", "moon.stars.fill", "snowflake",
            "cloud.sun.fill", "water.waves", "drop.fill", "leaf.fill", "tree.fill", "camera.macro",
            "flame.fill", "tornado", "rainbow", "sparkles", "star.fill", "wind", "beach.umbrella.fill",
            "tent.fill", "tent.2.fill", "fish.fill", "bird.fill", "pawprint.fill", "tortoise.fill",
            "hare.fill", "ladybug.fill", "ant.fill", "lizard.fill", "dog.fill", "cat.fill",
        ]),
        ("Orte", [
            "house.fill", "house.lodge.fill", "building.2.fill", "building.columns.fill", "tent.circle.fill",
            "bed.double.fill", "fork.knife", "cup.and.saucer.fill", "mug.fill", "wineglass.fill",
            "birthday.cake.fill", "cart.fill", "bag.fill", "theatermasks.fill", "music.note",
            "books.vertical.fill", "paintpalette.fill", "camera.fill", "photo.fill", "binoculars.fill",
            "ferriswheel", "party.popper.fill", "balloon.2.fill", "gift.fill", "heart.fill",
        ]),
        ("Sport", [
            "figure.skiing.downhill", "figure.snowboarding", "figure.surfing", "figure.pool.swim",
            "figure.open.water.swim", "figure.climbing", "figure.outdoor.cycle", "figure.run",
            "figure.sailing", "figure.fishing", "figure.golf", "figure.tennis", "figure.skating",
            "figure.roll", "figure.yoga", "figure.equestrian.sports", "soccerball", "basketball.fill",
            "tennisball.fill", "skis.fill", "snowboard.fill", "surfboard.fill", "sailboat",
            "kayak", "oar.2.crossed", "dumbbell.fill",
        ]),
        ("Menschen", [
            "person.fill", "person.2.fill", "person.3.fill", "figure.2.and.child.holdinghands",
            "figure.and.child.holdinghands", "figure.child", "heart.circle.fill", "hands.clap.fill",
            "graduationcap.fill", "briefcase.fill", "stethoscope", "crown.fill", "star.circle.fill",
        ]),
    ]

    /// Deutsche Stichworte, damit die Suche nicht nur Englisch kann.
    static let stichworte: [String: String] = [
        "airplane": "flugzeug flug", "airplane.departure": "abflug flughafen", "airplane.arrival": "ankunft landung",
        "car.fill": "auto", "car.side.fill": "auto wagen", "bus.fill": "bus", "tram.fill": "straßenbahn tram",
        "train.side.front.car": "zug bahn eisenbahn", "cablecar.fill": "seilbahn gondel", "ferry.fill": "fähre schiff",
        "sailboat.fill": "segeln boot", "bicycle": "fahrrad rad", "motorcycle": "motorrad", "figure.walk": "gehen wandern",
        "figure.hiking": "wandern berg", "suitcase.fill": "koffer", "backpack.fill": "rucksack", "map.fill": "karte",
        "mountain.2.fill": "berg berge gebirge alpen", "sun.max.fill": "sonne sommer", "snowflake": "schnee winter",
        "water.waves": "meer see wasser wellen", "tree.fill": "baum wald", "leaf.fill": "blatt natur",
        "beach.umbrella.fill": "strand sonnenschirm", "tent.fill": "zelt camping", "house.lodge.fill": "hütte ferienhaus",
        "building.columns.fill": "museum tempel", "fork.knife": "essen restaurant", "wineglass.fill": "wein",
        "cup.and.saucer.fill": "kaffee café", "camera.fill": "kamera foto", "figure.skiing.downhill": "ski skifahren",
        "figure.surfing": "surfen", "figure.pool.swim": "schwimmen", "figure.climbing": "klettern",
        "figure.outdoor.cycle": "radfahren", "kayak": "kajak paddeln", "heart.fill": "herz liebe",
        "person.2.fill": "paar zwei", "figure.2.and.child.holdinghands": "familie kinder",
        "party.popper.fill": "feier fest party", "birthday.cake.fill": "geburtstag torte", "gift.fill": "geschenk",
        "ferriswheel": "riesenrad kirmes", "moon.stars.fill": "nacht mond", "sunset.fill": "sonnenuntergang abend",
        "globe.europe.africa.fill": "welt europa erde", "passport": "pass reisepass", "ticket.fill": "ticket karte eintritt",
        "dog.fill": "hund", "cat.fill": "katze", "fish.fill": "fisch", "bird.fill": "vogel",
    ]
}
