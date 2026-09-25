import SwiftUI
import UIKit

// BUCH AUFBAUEN — der Weg, den die App eigentlich geht.
//
// Ansage des Nutzers, 09/2026: erst den Tagebuchtext einlesen, daraufhin
// entstehen die Tage; dann die Reisespur, die an jedem Tag eine Karte
// hinterlässt; zum Schluss die Fotos, die sich auf die Tage verteilen.
// Genau so ist die App gebaut — nur stand jeder der drei Schritte für sich
// in einem Menü, und in welcher Reihenfolge sie zusammengehören, stand
// nirgends. Daher der Befund „eher ein noch etwas sperrig zu bedienender
// Bild- und Texteditor": Was die App auszeichnet, war nicht zu sehen.
//
// Dieser Bildschirm ist kein neuer Einleseweg. Er ist die Reihenfolge, der
// Stand und der Bericht. Die Arbeit machen unverändert `TextimportView`,
// `SpurimportView` und `FotoeinfuhrView` — ein zweiter Weg zu derselben
// Sache liefe irgendwann auseinander.
struct AufbauView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    // Wohin es weitergeht. Die Blätter werden NICHT ineinander gestapelt:
    // Ein Blatt über einem Blatt ist auf dem iPad ein Kärtchen auf einem
    // Kärtchen, und die drei Einleseansichten bringen je einen eigenen
    // `NavigationStack` mit. Stattdessen macht dieses Blatt zu, die Wurzel
    // öffnet das nächste — und wenn das zugeht, kommt dieses zurück.
    var weiter: (ReiseView.Blatt) -> Void

    // Gerechnet wird EINMAL beim Öffnen und nicht im Körper: Der Bericht
    // geht über alle Tage und alle Fotos (dieselbe Falle wie bei der
    // Druckprüfung in 1.0.0).
    @State private var bericht = Aufbaubericht()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Aus einem Tagebuchtext, einer Reisespur und einem Stapel Fotos "
                         + "setzt die App die Seiten selbst. Die Reihenfolge ist die hier \u{2014} "
                         + "der Text legt die Tage an, alles Weitere hängt sich daran.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // DER KURZE WEG (ab 1.0.106): Wer in Fernweh geschrieben
                // hat, hat Text, Orte, Spur und Fotos schon beisammen. Eine
                // Übergabedatei erledigt die drei Schritte darunter auf
                // einmal; einzeln bleiben sie für alles andere.
                Section {
                    Button("Übergabe aus Fernweh einlesen\u{2026}", systemImage: "suitcase") {
                        los(.fernweh)
                    }
                } footer: {
                    Text("Aus dem Reisetagebuch Fernweh kommen Texte, Orte, Wetter, Reisespur "
                         + "und Fotos in einem Zug. Die drei Schritte darunter sind der Weg für "
                         + "alles andere.")
                }

                schritt(
                    nummer: 1,
                    titel: "Tagebuchtext",
                    zeichen: "text.book.closed",
                    erledigt: bericht.tageMitText > 0,
                    stand: bericht.tage == 0
                        ? "Noch nichts eingelesen."
                        : "\(bericht.tage) Tage angelegt, \(bericht.tageMitText) davon mit Text.",
                    erklaerung: "Jede erkannte Datumszeile wird ein Tag. Reiner Text, "
                        + "Word (.docx), PDF und RTF gehen; vor dem Übernehmen steht da, "
                        + "welche Zeile als Datum gelesen wurde."
                ) {
                    Button("Text einlesen\u{2026}") { los(.textimport) }
                }

                schritt(
                    nummer: 2,
                    titel: "Reisespur",
                    zeichen: "point.topleft.down.curvedto.point.bottomright.up",
                    erledigt: bericht.tageMitSpur > 0,
                    stand: bericht.tageMitSpur == 0
                        ? "Noch keine Orte."
                        : "\(bericht.tageMitSpur) von \(bericht.tage) Tagen haben Orte.",
                    erklaerung: "Aus der Tagesspur-App (Sicherung oder GPX). Ein Tag mit "
                        + "Orten bekommt eine Karte auf seiner Seite. Fotos bringen ihre "
                        + "Aufnahmeorte ohnehin mit \u{2014} die Spur kennt den Weg dazwischen."
                ) {
                    Button("Reisespur einlesen\u{2026}") { los(.tagesspur) }
                }

                schritt(
                    nummer: 3,
                    titel: "Fotos",
                    zeichen: "photo.on.rectangle",
                    erledigt: bericht.tageMitFotos > 0,
                    stand: bericht.fotosGesamt == 0
                        ? "Noch keine Fotos."
                        : "\(bericht.fotosGesamt) Fotos, verteilt auf \(bericht.tageMitFotos) Tage.",
                    erklaerung: "Zugeordnet wird über das Aufnahmedatum \u{2014} aus dem Bild, "
                        + "sonst aus der Mediathek, sonst aus dem Dateinamen. Ein Tag, den es "
                        + "noch nicht gibt, entsteht dabei von selbst. Was gar kein Datum "
                        + "trägt, geht an den Tag, den du beim Einlesen dafür wählst."
                ) {
                    Button("Fotos aus der Mediathek\u{2026}") { los(.fotos) }
                    Button("Bilder aus Dateien\u{2026}") { los(.dateien) }
                    if bericht.inAblage > 0 {
                        Button("\(bericht.inAblage) Fotos in der Ablage ansehen\u{2026}") {
                            los(.ablage)
                        }
                    }
                }

                if bericht.tage > 0 { berichtsteil }
            }
            .navigationTitle("Buch aufbauen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
        .task { bericht = Aufbaubericht(werk.reise) { werk.hatHandarbeit($0) } }
    }

    // MARK: - Bericht

    @ViewBuilder
    private var berichtsteil: some View {
        Section {
            ForEach(bericht.zeilen) { zeile in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(zeile.datum).font(.subheadline.weight(.semibold))
                        if !zeile.ueberschrift.isEmpty {
                            Text(zeile.ueberschrift)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if zeile.ausgeblendet {
                            Image(systemName: "eye.slash").font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if zeile.handarbeit {
                            Image(systemName: "hand.draw").font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(zeile.inhalt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !zeile.fehlt.isEmpty {
                        // Kein rotes Ausrufezeichen: Ein Tag ohne Foto ist
                        // kein Fehler. Gesagt wird es trotzdem, sonst
                        // bemerkt es niemand.
                        Text("fehlt: " + zeile.fehlt.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Was zugeordnet wurde")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Fotos insgesamt \(bericht.fotosGesamt) \u{00B7} in der Ablage "
                     + "\(bericht.inAblage) \u{00B7} ohne Datum \(bericht.ohneDatum) "
                     + "\u{00B7} ohne Ort \(bericht.ohneOrt). Seiten aus den Tagen: "
                     + "\(bericht.seitenGesamt).")
                Text("Ein Tag ohne Text, Foto oder Ort ist kein Fehler \u{2014} er steht "
                     + "hier, damit er nicht unbemerkt so bleibt. Tage, an denen von Hand "
                     + "gearbeitet wurde, werden beim Einlesen nicht überschrieben.")
                Button("Bericht kopieren", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = bericht.text
                    werk.meldung = Reisewerk.Meldung(text: "Der Bericht liegt in der Zwischenablage.")
                }
                .font(.footnote)
            }
        }
    }

    // MARK: - Bausteine

    @ViewBuilder
    private func schritt<Knoepfe: View>(nummer: Int, titel: String, zeichen: String,
                                        erledigt: Bool, stand: String, erklaerung: String,
                                        @ViewBuilder knoepfe: () -> Knoepfe) -> some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stand)
                    Text(erklaerung)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: erledigt ? "checkmark.circle.fill" : zeichen)
                    .foregroundStyle(erledigt ? Color.green : Color.accentColor)
            }
            knoepfe()
        } header: {
            Text("\(nummer) \u{00B7} \(titel)")
        }
    }

    private func los(_ ziel: ReiseView.Blatt) {
        weiter(ziel)
        schliessen()
    }
}
