import SwiftUI

// ZULETZT EINGELESENE FOTOS (Kapitelweise, ab 1.0.40).
//
// Gemeldet 11/2026: „ich mehrfach versucht habe, Bilder zu importieren und
// mir gesagt wird, dass diese bereits im Projekt enthalten seien. Ich finde
// sie aber an keiner Stelle. Hier muss es irgendeine Funktion geben, dass
// ich zu den zuletzt hinzugefügten Fotos springen kann und diese aktiviert
// sind." Die Liste zeigt die Fotos des letzten Einlesens (neue und
// übersprungene) mit ihrem Fundort; antippen springt hin und wählt das Foto.
// Steht eines auf keiner Seite (in einem gestalteten Kapitel oder in der
// Ablage), bringt „Auf eine Seite bringen" es neben seinen zeitlichen
// Nachbarn.
struct ZuletztView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            List {
                if werk.zuletztEingelesen.isEmpty {
                    Text("Seit dem Öffnen des Buches wurden noch keine Fotos eingelesen.")
                        .foregroundStyle(.secondary)
                }
                ForEach(werk.zuletztEingelesen, id: \.self) { id in
                    if let foto = werk.foto(id) {
                        zeile(foto)
                    }
                }
            }
            .navigationTitle("Zuletzt eingelesene Fotos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }

    @ViewBuilder
    private func zeile(_ foto: Foto) -> some View {
        let fund = werk.fundort(foto.id)
        HStack(spacing: 12) {
            Ladebild(datei: foto.datei, reise: werk.reise.id, kante: 200) { bild in
                Image(uiImage: bild).resizable().scaledToFill()
            }
            .frame(width: 72, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 4) {
                if let wann = foto.aufnahme {
                    Text(wann.formatted(date: .long, time: .shortened)).font(.subheadline)
                }
                Text(werk.fundortText(foto.id))
                    .font(.footnote)
                    .foregroundStyle(fund.block == nil ? .orange : .secondary)
                if fund.block == nil {
                    Button("Auf eine Seite bringen") {
                        if werk.fotoAufSeiteBringen(foto.id) { schliessen() }
                    }
                    .buttonStyle(.bordered)
                    .font(.footnote)
                }
            }
            Spacer()
            if fund.block != nil {
                Image(systemName: "arrow.right.circle").foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard fund.block != nil else { return }
            werk.fotoZeigen(foto.id)
            schliessen()
        }
    }
}
