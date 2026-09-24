import SwiftUI

struct GestaltungView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen
    @State private var hintergrundOffen = false

    // WAS DER BUNDSTEG TUT UND WAS NICHT (ab 1.0.58).
    //
    // Gemeldet 09/2026: „Der Bund soll bei 0 mm liegen. Das habe ich jetzt
    // so eingestellt. Dennoch sieht es nicht so aus, als ob die App das
    // akzeptiert hätte." Sie hat es akzeptiert — 0 ist der Vorgabewert und
    // der Anfang des Reglers. Nur ändert der Bundsteg zwei Dinge NICHT,
    // und beide sind genau die, an denen man es sehen würde: Er rührt den
    // Hintergrund nicht an (der läuft immer bis in den Anschnitt), und er
    // rückt keine Seite um, die schon gesetzt ist — Blöcke stehen als
    // Rechtecke im Buch und bleiben, wo jemand sie hat.
    //
    // Der Satz steht hier, weil hier die Frage entsteht.
    private var zugabenhinweis: String {
        var text = "Anschnitt: 3 mm sind der Standard, manche Buchdienste verlangen 5 mm. "
        text += "Ohne ihn kann kein Bild bis an die Papierkante laufen. Er liegt AUSSERHALB "
        text += "des Endformats und wird weggeschnitten \u{2014} deshalb ist die PDF-Seite "
        text += "gr\u{00F6}\u{00DF}er als das bestellte Format.\n\n"
        text += "Sicherheitsabstand: die Gegenrichtung, INNERHALB des Endformats. Dort soll "
        text += "nichts stehen, was gelesen werden muss. Der Grund ist derselbe wie beim "
        text += "Anschnitt: Jede Schneidemaschine hat ein Spiel von einem knappen "
        text += "Millimeter, und ein Stapel B\u{00FC}cher wird nie auf den Punkt genau "
        text += "getroffen \u{2014} eine Seitenzahl dicht an der Kante steht dann im einen "
        text += "Buch mittig und im n\u{00E4}chsten halb angeschnitten. 3 bis 5 mm sind "
        text += "\u{00FC}blich. Die Pr\u{00FC}fung vor dem Ausgeben z\u{00E4}hlt, was "
        text += "hineinragt; randabfallende Bl\u{00F6}cke sind ausgenommen, die sollen "
        text += "ja \u{00FC}ber die Kante laufen.\n\n"
        text += "Am BUND l\u{00E4}sst sich der Anschnitt ganz abschalten. Manche Dienste "
        text += "verlangen genau das \u{2014} \u{201E}Beschnittzugabe oben | unten | "
        text += "au\u{00DF}en | innen = 3 | 3 | 3 | 0 mm\u{201C}: Sie legen die Seiten "
        text += "selbst zusammen, und dort wird nichts geschnitten. Dann ist die PDF-Seite "
        text += "waagerecht nur um EINE Zugabe breiter als das Endformat, und aus einem "
        text += "geforderten Bogen von 208 mm werden 205 mm Endformat und nicht 202. Welche "
        text += "Kante die Zugabe tr\u{00E4}gt, wechselt von Seite zu Seite \u{2014} das "
        text += "Blatt auf der B\u{00FC}hne zeigt es, dort h\u{00F6}rt die rote "
        text += "Schnittkante am Bund auf.\n\n"
        text += "Der SICHERHEITSABSTAND am Bund darf ebenfalls ein anderer sein \u{2014} viele Druckereien verlangen "
        text += "dort mehr, weil bei der Klebebindung ein Streifen im Falz verschwindet. "
        text += "Oben und unten gilt immer der \u{00E4}u\u{00DF}ere Wert: Dort wird "
        text += "geschnitten und nicht gebunden. Welche Seite innen liegt, wechselt von "
        text += "Seite zu Seite \u{2014} die blaue Linie auf dem Blatt wandert deshalb mit, "
        text += "und daran l\u{00E4}sst sich ablesen, dass die Zahl an der richtigen Kante "
        text += "ankommt.\n\n"
        text += "Bundsteg: zusätzlicher Rand zur Heftung, 0 mm ist erlaubt und die Vorgabe. "
        text += "Er wird auf beide Seitenränder gerechnet — welche Seite innen liegt, hängt "
        text += "an der laufenden Seitenzahl, und die verschiebt sich, sobald ein Tag eine "
        text += "Seite mehr braucht.\n\n"
        text += "Er verschiebt nur den SATZSPIEGEL, also den Platz, in den neue Seiten "
        text += "gesetzt werden. Schon gesetzte Seiten behalten ihre Blöcke dort, wo sie "
        text += "stehen; wer sie mitziehen will, ordnet sie neu an. Und ein Hintergrund "
        text += "richtet sich gar nicht nach ihm: Der läuft immer bis in den Anschnitt. "
        text += "Was in der Doppelseitenansicht am Bund als Streifen stehen bleibt, sind "
        text += "die beiden Anschnitte — die schneidet die Druckerei weg."
        return text
    }

    var body: some View {
        NavigationStack {
            Form {
                // DER TITEL IST UMGEZOGEN (ab 1.0.84).
                //
                // Ansage des Nutzers, 09/2026: „Dabei ist mir aufgefallen,
                // dass der Titel des Buches versteckt in den Einstellungen
                // zu den Rändern und der Druckausgabe steckt. Dort ist er
                // nicht leicht zu finden."
                //
                // Er hat recht, und es war hier historisch gewachsen: Dieser
                // Bildschirm hieß bis 1.0.77 „Ränder, Karte, Seitenzahlen“
                // und war der Ort für alles, was sonst nirgends hinpasste.
                // Ein Buchtitel gehört dorthin, wo er GEDRUCKT wird — auf
                // die Titelseite, und die liegt im Umschlag. Hier bleibt
                // eine Auskunft mit dem Weg, wie beim Seitenformat seit
                // 1.0.27: Ein Bildschirm, der einen Wert nicht mehr führt,
                // muss sagen, wo er jetzt steht.
                Section {
                    LabeledContent("Titel", value: werk.reise.titel)
                    if werk.reise.hatEigenenRegalnamen {
                        LabeledContent("In der Übersicht", value: werk.reise.anzeigename)
                    }
                } header: {
                    Text("Buch")
                } footer: {
                    Text("Titel, Untertitel und Titelbild stehen unter \u{201E}Ganzes Buch → Titel, Umschlag und Rücken\u{201C} — dort, wo sie gedruckt werden. Wie das Buch in der Übersicht der Reisetagebücher heißt, lässt sich seit 1.0.84 getrennt davon einstellen; es steht auf derselben Seite und im Regal unter \u{201E}Umbenennen\u{201C}.")
                }

                Section {
                    LabeledContent("Seitenformat",
                                   value: "\(werk.reise.format.name) · \(werk.reise.format.masstext)")
                    LabeledContent("Bogen mit Anschnitt", value: bogentext)
                } header: {
                    Text("Format")
                } footer: {
                    // Das Format steht seit 1.0.27 auf einem EIGENEN
                    // Bildschirm (Gestalten → Seitenformat): Es gibt dort
                    // Vorlagen, ein freies Maß und die Umrechnung des
                    // ganzen Buches. Hier bleibt es als Auskunft stehen —
                    // dieselbe Einstellung an zwei Stellen zu bedienen wäre
                    // genau das, was dieses Haus sonst verbietet.
                    Text("Geändert wird das Format unter \u{201E}Ganzes Buch → Seitenformat\u{201C} — dort stehen die Vorlagen, das freie Maß und die Umrechnung des ganzen Buches.\n\nDas Endformat ist die Seite, wie sie nach dem Schneiden in der Hand liegt. Der Bogen ist das, was im PDF steht — Endformat plus Anschnitt. Beide Maße stehen als TrimBox und BleedBox in der Datei, daran erkennt der Druckdienst, wo geschnitten wird.")
                }

                Section {
                    mmRegler("Anschnitt", $werk.reise.gestaltung.anschnitt, 0...8, schritt: 1)
                    // AM BUND BRAUCHT NICHT JEDE DRUCKEREI EINEN (ab
                    // 1.0.85). Steht der Schalter aus, ist die PDF-Seite
                    // waagerecht nur um EINE Zugabe breiter als das
                    // Endformat, und welche Kante sie trägt, wechselt von
                    // Seite zu Seite. Vorgabe bleibt an: Jedes vorhandene
                    // Buch gibt danach dieselbe Datei aus wie vorher.
                    Toggle("Anschnitt auch am Bund",
                           isOn: $werk.reise.gestaltung.anschnittAmBund)
                    // DIE GEGENRICHTUNG (ab 1.0.73). Sie steht unmittelbar
                    // unter dem Anschnitt, weil die beiden dauernd
                    // verwechselt werden — und nebeneinander lässt sich der
                    // Unterschied in einem Satz sagen.
                    mmRegler("Sicherheitsabstand außen",
                             $werk.reise.gestaltung.sicherheitsabstand, 0...12, schritt: 1)
                    // AM BUND GILT OFT ETWAS ANDERES (ab 1.0.76). `nil`
                    // heißt „wie außen" — eine Abweichung und keine Kopie:
                    // Wer den äußeren Wert später ändert, ändert damit auch
                    // den inneren, solange er nichts anderes gesagt hat.
                    Toggle("Am Bund ein eigener Wert", isOn: bundeigen)
                    if werk.reise.gestaltung.sicherheitsabstandInnen != nil {
                        mmRegler("Sicherheitsabstand am Bund",
                                 bundwert, 0...20, schritt: 1)
                    }
                    Schutzzonenskizze(gestaltung: werk.reise.gestaltung,
                                      format: werk.reise.format)
                    mmRegler("Bundsteg", $werk.reise.gestaltung.bundsteg, 0...15, schritt: 1)
                } header: {
                    Text("Druckzugaben")
                } footer: {
                    Text(zugabenhinweis)
                }

                Section {
                    Button {
                        hintergrundOffen = true
                    } label: {
                        LabeledContent("Hintergrund",
                                       value: werk.reise.gestaltung.hintergrund.art.name)
                    }
                    Picker("Datumszeile", selection: $werk.reise.gestaltung.datumsstil) {
                        ForEach(Datumsstil.allCases) { stil in
                            Text(stil.name).tag(stil)
                        }
                    }
                } header: {
                    Text("Aussehen")
                } footer: {
                    Text("Beides gilt für das ganze Buch. Eine einzelne Seite darf einen anderen Hintergrund haben, und ein einzelner Tag eine andere Datumszeile — beides über den Inspektor rechts.")
                }

                // Die Felder dafür stehen jetzt in `Fotostil` und sind
                // über Gestalten → Fotos zu erreichen. Hier bleibt der Weg
                // dorthin, weil man sie eine Fassung lang an dieser Stelle
                // gesucht hat.
                Section {
                    NavigationLink {
                        Form { Fotostilfelder(werk: werk) }
                            .navigationTitle("Fotos")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("Fotos: Schatten, Rand, Linie", systemImage: "photo.stack")
                    }
                } footer: {
                    Text("Steht auch unter Ganzes Buch \u{2192} Fotos.")
                }

                Section {
                    // BIS AN DEN SICHERHEITSABSTAND HERAN (ab 1.0.82).
                    //
                    // Gefragt 09/2026: „Warum ist denn der so weit vom Rand
                    // entfernt? Der Satzspiegel könnte doch tatsächlich
                    // innerhalb des Sicherheitsabstandes ausgeführt werden."
                    //
                    // Er kann es — nur ging der Regler bis 1.0.81 nur bis
                    // 5 mm hinunter, und der Sicherheitsabstand liegt bei 3.
                    // Die Untergrenze war eine gewählte Zahl ohne Grund; die
                    // technische Grenze ist der Sicherheitsabstand, und die
                    // steht als eigene Linie daneben.
                    mmRegler("Rand außen", $werk.reise.gestaltung.randAussen, 0...45)
                    mmRegler("Rand oben", $werk.reise.gestaltung.randOben, 0...45)
                    mmRegler("Rand unten", $werk.reise.gestaltung.randUnten, 0...45)
                    Button("Ränder auf den Sicherheitsabstand setzen") {
                        werk.merken()
                        let g = werk.reise.gestaltung
                        werk.reise.gestaltung.randAussen = max(g.sicherheitsabstand,
                                                               g.innensicherheit)
                        werk.reise.gestaltung.randOben = g.sicherheitsabstand
                        werk.reise.gestaltung.randUnten = g.sicherheitsabstand
                    }
                    .disabled(!werk.reise.gestaltung.hatSicherheitsabstand)
                    mmRegler("Fuge zwischen Bildern", $werk.reise.gestaltung.fuge, 0...15,
                             schritt: 0.5)
                    mmRegler("Eckenradius", $werk.reise.gestaltung.eckenradius, 0...10,
                             schritt: 0.5)
                    Toggle("Seitenzahlen", isOn: $werk.reise.gestaltung.seitenzahlen)
                    Toggle("Kopfzeile mit Datum", isOn: $werk.reise.gestaltung.kopfzeile)
                } header: {
                    Text("Satzspiegel")
                } footer: {
                    // Bis 1.0.49 gab es Seitenzahl und Kopfzeile NUR im PDF
                    // (gemeldet 09/2026: „Diese kommen auf dem Dokument aber
                    // niemals zum Vorschein."). Seit 1.0.50 stehen sie auch
                    // auf der Seite in der App — gerechnet von derselben
                    // Stelle. Wo sie trotzdem fehlen, sagt der Satz.
                    Text(satzspiegelhinweis)
                }

                // DIE BREITE DER TEXTSPALTE (ab 1.0.37). Sie steht in einem
                // eigenen Abschnitt und nicht zwischen den Rändern: Es ist
                // keine Frage des Papiers, sondern der Lesbarkeit — und die
                // Zahl darunter ist der Grund dafür.
                Section {
                    VStack(alignment: .leading) {
                        LabeledContent(
                            "Höchstbreite",
                            value: "\(Int((werk.reise.gestaltung.textspaltenanteil * 100).rounded())) %"
                        )
                        Slider(value: $werk.reise.gestaltung.textspaltenanteil,
                               in: 0.4...1.0, step: 0.02)
                    }
                } header: {
                    Text("Textspalte")
                } footer: {
                    Text("Über die volle Satzbreite stehen auf einer A4-Seite weit über achtzig "
                         + "Zeichen in einer Zeile; wer am Zeilenende ankommt, findet den Anfang "
                         + "der nächsten nicht mehr sicher wieder. Bequem zu lesen sind 45 bis 75. "
                         + "Was neben dem Text frei bleibt, bekommen die Bilder — und wo keine "
                         + "mehr sind, bleibt es Rand.\n\nWie viele Zeichen in DIESEM Buch wirklich "
                         + "auf einer Zeile stehen, steht unter „…“ → „Als PDF sichern…“ im "
                         + "Abschnitt „Vor dem Ausgeben geprüft“ — gemessen, nicht geschätzt.")
                }

                // DIE KARTEN SIND SEIT 1.0.79 EIN EIGENER MENÜPUNKT.
                //
                // Sie standen hier, solange dieser Bildschirm „Ränder,
                // Karte, Seitenzahlen…" hieß. Seit 1.0.77 heißt er nach den
                // Druckzugaben — und damit war die Karteneinstellung aus
                // dem Menü verschwunden, ohne dass sie sich bewegt hätte
                // (gemeldet 09/2026). Hier bleibt die Zeile als Auskunft
                // stehen: Ein Bildschirm, der einen Wert nicht mehr führt,
                // muss sagen, wo er jetzt steht — dieselbe Regel wie beim
                // Seitenformat seit 1.0.27.
                Section {
                    LabeledContent("Reisepunkte", value: werk.reise.kartenbild.punktstil.name)
                    LabeledContent("Breite der Karte",
                                   value: "\(Int(werk.reise.gestaltung.kartenanteil * 100)) %")
                } header: {
                    Text("Karten")
                } footer: {
                    Text("Eingestellt wird das unter „Ganzes Buch → Karten…“ — dort stehen die Kartenquelle, die Beschriftung, die Reisepunkte und die Breite im Satz. Ein einzelner Tag und eine einzelne Karte dürfen davon abweichen; das steht im Inspektor.")
                }

                Section {
                    LabeledContent("Tage", value: "\(werk.reise.tage.count)")
                    LabeledContent("Fotos", value: "\(werk.reise.fotos.count)")
                    LabeledContent("Seiten", value: "\(werk.reise.seitenzahl)")
                    LabeledContent("Bilder auf der Platte",
                                   value: String(format: "%.1f MB",
                                                 Bildarchiv.shared.groesseInMB(reise: werk.reise.id)))
                } header: {
                    Text("Bestand")
                }
            }
            .navigationTitle("Gestaltung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        // Ein anderes Format heißt ein anderer Satzspiegel.
                        // Die unberührten Tage werden neu gesetzt; wer von
                        // Hand gearbeitet hat, behält seine Arbeit — auch
                        // wenn sie dann über den neuen Rand ragt. Sie ohne
                        // Rückfrage wegzurechnen wäre der größere Schaden.
                        werk.alleNeuAnordnen(nurUnberuehrte: true)
                        Task { await Kartenwerk.shared.vergessen() }
                        schliessen()
                    }
                }
            }
            .sheet(isPresented: $hintergrundOffen) {
                HintergrundView(werk: werk)
            }
        }
    }

    // WARUM DER SATZSPIEGEL WEITER INNEN LIEGT ALS DER SICHERHEITSABSTAND.
    //
    // Gefragt 09/2026, und die Antwort ist: Es sind zwei verschiedene
    // Dinge, und nur eines davon ist eine Vorgabe der Druckerei.
    private var satzspiegelhinweis: String {
        let g = werk.reise.gestaltung
        var text = "Der SICHERHEITSABSTAND ist die technische Untergrenze \u{2014} "
        text += "n\u{00E4}her als "
        text += g.hatSicherheitsabstand ? Druckvorgabe.zahl(g.sicherheitsabstand) + " mm"
                                        : "die eingestellte Zugabe"
        text += " an die Kante darf nichts, was gelesen werden muss. Der RAND hier ist "
        text += "eine Entscheidung \u{00FC}ber das Aussehen: Wo der Flie\u{00DF}text "
        text += "beginnt. Die Vorgaben (16 / 17 / 19 mm) sind \u{00FC}bliche Buchr\u{00E4}nder "
        text += "und gew\u{00E4}hlt, nicht gemessen \u{2014} unten mehr als oben, weil "
        text += "der optische Mittelpunkt \u{00FC}ber dem geometrischen liegt.\n\n"
        text += "Bis an den Sicherheitsabstand heran geht es seit 1.0.82. Was dabei zu "
        text += "bedenken ist: Beim Lesen liegt dort der Daumen, und am Bund verschwindet "
        text += "in der Bindung ohnehin ein Streifen \u{2014} daf\u{00FC}r gibt es den "
        text += "eigenen Innenwert. Seitenzahl und Kopfzeile r\u{00FC}cken automatisch "
        text += "mit und bleiben innerhalb des Sicherheitsabstands; wird der Rand so "
        text += "knapp, dass sie keinen Platz mehr haben, sagt es die Druckpr\u{00FC}fung.\n\n"
        text += "Seitenzahl und Kopfzeile stehen auf der Seite und im PDF. Nicht auf der "
        text += "Titelseite, nicht auf der R\u{00FC}ckseite und nicht auf einer Seite, die "
        text += "ein Bild ganz ausf\u{00FC}llt: Dort st\u{00FC}nde die Zahl auf dem Foto."
        return text
    }

    private var bogentext: String {
        let bogen = werk.reise.gestaltung.bogen(werk.reise.format)
        return "\(Druckmass.mmText(bogen.width)) x \(Druckmass.mmText(bogen.height))"
    }

    // Ob am Bund ein eigener Wert gilt. Das Einschalten setzt ihn auf den
    // äußeren — von dort aus wird geschoben; das Ausschalten nimmt ihn
    // ersatzlos zurück, und dann folgt er wieder dem äußeren.
    private var bundeigen: Binding<Bool> {
        Binding(
            get: { werk.reise.gestaltung.sicherheitsabstandInnen != nil },
            set: { an in
                werk.reise.gestaltung.sicherheitsabstandInnen =
                    an ? werk.reise.gestaltung.sicherheitsabstand : nil
            }
        )
    }

    private var bundwert: Binding<Double> {
        Binding(
            get: { werk.reise.gestaltung.innensicherheit },
            set: { werk.reise.gestaltung.sicherheitsabstandInnen = $0 }
        )
    }

    private func mmRegler(_ name: String, _ wert: Binding<Double>,
                          _ bereich: ClosedRange<Double>, schritt: Double = 1) -> some View
    {
        VStack(alignment: .leading) {
            LabeledContent(name, value: String(format: schritt < 1 ? "%.1f mm" : "%.0f mm",
                                               wert.wrappedValue)
                .replacingOccurrences(of: ".", with: ","))
            Slider(value: wert, in: bereich, step: schritt)
        }
    }
}

// Das Bild für die Titelseite. Ohne eines ist sie ein ruhiges Textblatt,
// mit einem ein Plakat — beides ist richtig, ein kleines Bildchen über
// einem großen Titel wäre es nicht.
struct TitelfotoView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    private let raster = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: raster, spacing: 8) {
                    ForEach(werk.reise.fotos.filter { !$0.abgelegt }) { foto in
                        Button {
                            werk.merken()
                            werk.reise.titelfoto = werk.reise.titelfoto == foto.id ? nil : foto.id
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                ZStack {
                                    Rectangle().fill(Color(.systemGray5))
                                    Ladebild(datei: foto.datei, reise: werk.reise.id,
                                             kante: 300) { bild in
                                        Image(uiImage: bild)
                                            .resizable()
                                            .scaledToFill()
                                    }
                                }
                                .frame(height: 96)
                                .clipped()
                                if werk.reise.titelfoto == foto.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white, Color.accentColor)
                                        .padding(5)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Titelbild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Ohne Bild") {
                        werk.merken()
                        werk.reise.titelfoto = nil
                        schliessen()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }
}
