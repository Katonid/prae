import SwiftUI

// Die Stilauswahl — mit einer Vorschau, die aus den eigenen Fotos gebaut
// ist und nicht aus einem Werbebild.
//
// Ein Stil ändert Schrift, Farbe, Ränder, Fugen, Schatten und die Vorliebe
// für bestimmte Seitenmuster auf einmal. Wer das an acht Reglern einzeln
// einstellen müsste, bekäme nie ein Buch, das nach einer Handschrift
// aussieht — die Regler ziehen gegeneinander.
struct StilView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen
    @State private var frage: Buchstil?
    @State private var handarbeit = 0

    private var tagwort: String {
        handarbeit == 1 ? "einem Tag" : "\(handarbeit) Tagen"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Buchstil.alle) { stil in
                        Button {
                            handarbeit = werk.handarbeitstage()
                            if handarbeit > 0 {
                                frage = stil
                            } else {
                                werk.stilAnwenden(stil)
                                schliessen()
                            }
                        } label: {
                            StilZeile(stil: stil, gewaehlt: werk.reise.stil == stil.id,
                                      werk: werk)
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Der Stil ist ein Anfang und keine Schranke: Schrift, Ränder und jedes einzelne Bild lassen sich danach weiter ändern. Gibt es von Hand bearbeitete Seiten, fragt die App, ob auch sie neu gesetzt werden sollen.")
                }
            }
            .navigationTitle("Stil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            .alert("Stil wechseln?", isPresented: .init(
                get: { frage != nil }, set: { if !$0 { frage = nil } }
            )) {
                Button("Bearbeitete Seiten behalten") {
                    if let stil = frage { werk.stilAnwenden(stil) }
                    frage = nil
                    schliessen()
                }
                Button("Alles neu setzen", role: .destructive) {
                    if let stil = frage { werk.stilAnwenden(stil, auchHandarbeit: true) }
                    frage = nil
                    schliessen()
                }
                Button("Abbrechen", role: .cancel) { frage = nil }
            } message: {
                Text("An \(tagwort) wurde von Hand gearbeitet. \u{201E}Behalten\u{201C} lässt deren Anordnung stehen und gibt ihnen nur die neue Schrift. \u{201E}Alles neu setzen\u{201C} ordnet auch sie neu an — die Handarbeit an diesen Tagen ist dann weg. Mit \u{201E}Widerrufen\u{201C} lässt sich beides zurücknehmen.")
            }
        }
    }
}

private struct StilZeile: View {
    let stil: Buchstil
    let gewaehlt: Bool
    @ObservedObject var werk: Reisewerk

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(stil.name)
                    .font(.headline)
                Spacer()
                if gewaehlt {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            Text(stil.beschreibung)
                .font(.caption)
                .foregroundStyle(.secondary)
            Stilprobe(stil: stil, werk: werk)
                .frame(height: 118)
        }
        .padding(.vertical, 5)
    }
}

// Eine kleine Seite in diesem Stil, gesetzt mit demselben Setzer wie das
// Buch. Ein gemaltes Beispielbild wäre einfacher und gälte nichts: Was hier
// steht, ist genau das, was danach herauskommt.
private struct Stilprobe: View {
    let stil: Buchstil
    @ObservedObject var werk: Reisewerk

    private var beispielfoto: Foto? {
        werk.reise.fotos.first { !$0.abgelegt }
    }

    var body: some View {
        GeometryReader { raum in
            let hoehe = raum.size.height
            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    stil.papier.farbe
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MONTAG, 12. AUGUST")
                            .font(.system(size: 5.5, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(stil.akzent.farbe)
                        Text("Über den Pass")
                            .font(probeschrift(stil.typografie.titel, groesse: 13))
                            .foregroundStyle(stil.typografie.titel.farbe.farbe)
                        Rectangle()
                            .fill(stil.akzent.farbe.opacity(0.5))
                            .frame(height: 0.5)
                            .padding(.vertical, 1)
                        HStack(alignment: .top, spacing: 5) {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(0..<4, id: \.self) { _ in
                                    Rectangle()
                                        .fill(stil.typografie.flieText.farbe.farbe.opacity(0.32))
                                        .frame(height: 2)
                                }
                                Rectangle()
                                    .fill(stil.typografie.flieText.farbe.farbe.opacity(0.32))
                                    .frame(width: 34, height: 2)
                            }
                            probebild(breite: 44, hoehe: 32)
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 4) {
                            probebild(breite: 32, hoehe: 24)
                            probebild(breite: 32, hoehe: 24)
                            probebild(breite: 24, hoehe: 24)
                        }
                    }
                    .padding(.horizontal, stil.randAussen / 2.4)
                    .padding(.vertical, stil.randOben / 2.6)
                }
                .frame(width: hoehe * 1.41)
                .clipped()
                Spacer(minLength: 0)
            }
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .strokeBorder(Color.primary.opacity(0.12))
                    .frame(width: hoehe * 1.41, height: hoehe)
            }
        }
    }

    private func probeschrift(_ bild: Schriftbild, groesse: CGFloat) -> Font {
        Font(bild.familie.uiFont(groesse: groesse, fett: bild.fett, kursiv: bild.kursiv) as CTFont)
    }

    @ViewBuilder
    private func probebild(breite: CGFloat, hoehe: CGFloat) -> some View {
        let inhalt = Group {
            if let foto = beispielfoto,
               let bild = Bildarchiv.shared.vorschau(foto.datei, reise: werk.reise.id, kante: 200)
            {
                Image(uiImage: bild).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [stil.akzent.farbe.opacity(0.55),
                                        stil.akzent.farbe.opacity(0.2)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        inhalt
            .frame(width: breite, height: hoehe)
            .clipped()
            .padding(stil.fotorand / 1.6)
            .background(stil.fotorand > 0 ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: stil.eckenradius / 1.8))
            .shadow(color: .black.opacity(stil.schatten == .keiner ? 0 : 0.25),
                    radius: stil.schatten == .weich ? 2.2 : 1, y: 1)
    }
}
