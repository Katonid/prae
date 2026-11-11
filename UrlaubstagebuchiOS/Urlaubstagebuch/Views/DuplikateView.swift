import SwiftUI

// DOPPELTE FOTOS SUCHEN UND ENTFERNEN (ab 1.0.128).
//
// Die Suche läuft beim Öffnen von selbst und abseits des Hauptfadens; sie
// rechnet für jedes Foto, das nach Zeit und Format in Frage kommt, ein
// kleines Vorschaubild. Danach steht da, was gefunden wurde — je Gruppe das
// Foto, das bleibt, und die, die gehen —, und EIN Knopf entfernt alle.
// Gelöscht wird erst beim Schließen des Buches; bis dahin nimmt
// „Widerrufen" alles in einem Schritt zurück. Wann zwei Fotos dasselbe
// sind, steht in `Dienste/Duplikate.swift`.
struct DuplikateView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    @State private var befund: Duplikate.Befund?
    @State private var stand: (fertig: Int, von: Int) = (0, 0)
    @State private var bericht: Reisewerk.Duplikatbericht?

    var body: some View {
        NavigationStack {
            Group {
                if let bericht {
                    erledigt(bericht)
                } else if let befund {
                    if befund.gruppen.isEmpty {
                        ContentUnavailableView {
                            Label("Keine doppelten Fotos", systemImage: "checkmark.circle")
                        } description: {
                            Text(zahlen(befund))
                        }
                    } else {
                        liste(befund)
                    }
                } else {
                    VStack(spacing: 12) {
                        ProgressView(value: Double(stand.fertig), total: Double(max(stand.von, 1)))
                            .frame(maxWidth: 260)
                        Text(stand.von == 0
                             ? "Fotos werden verglichen \u{2026}"
                             : "\(stand.fertig) von \(stand.von) Fotos angesehen")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .navigationTitle("Doppelte Fotos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
        .task { await suchen() }
    }

    private func suchen() async {
        let fotos = werk.reise.fotos
        let reiseID = werk.reise.id
        let benutzt = Self.benutzteFotos(werk.reise)
        let ergebnis = await Task.detached(priority: .userInitiated) {
            Duplikate.suchen(fotos: fotos, reise: reiseID, benutzt: benutzt) { fertig, von in
                Task { @MainActor in stand = (fertig, von) }
            }
        }.value
        befund = ergebnis
    }

    // Welche Fotos auf einer Seite stehen — bei gleicher Größe bleibt das.
    static func benutzteFotos(_ reise: Reise) -> Set<UUID> {
        var ids = Set<UUID>()
        for tag in reise.tage {
            for seite in tag.seiten {
                for block in seite.bloecke { if let id = block.fotoID { ids.insert(id) } }
            }
        }
        if let titel = reise.titelfoto { ids.insert(titel) }
        return ids
    }

    private func zahlen(_ befund: Duplikate.Befund) -> String {
        var satz = "\(befund.geprueft) Fotos geprüft, \(befund.verglichen) Paare näher angesehen"
        let sekunden = String(format: "%.1f", befund.dauer).replacingOccurrences(of: ".", with: ",")
        satz += ", \(sekunden) s."
        if befund.nichtLesbar > 0 {
            satz += " \(befund.nichtLesbar) Fotos ließen sich nicht lesen (liegen sie noch in iCloud?) "
                + "und sind nicht verglichen."
        }
        return satz
    }

    private func liste(_ befund: Duplikate.Befund) -> some View {
        List {
            Section {
                Button(role: .destructive) {
                    bericht = werk.duplikateEntfernen(befund.gruppen)
                } label: {
                    Label(befund.zuEntfernen == 1
                          ? "Das Doppel entfernen"
                          : "Alle \(befund.zuEntfernen) Doppel entfernen",
                          systemImage: "trash")
                }
            } header: {
                Text(befund.gruppen.count == 1
                     ? "1 Foto ist mehrfach im Buch"
                     : "\(befund.gruppen.count) Fotos sind mehrfach im Buch")
            } footer: {
                Text("Behalten wird je Gruppe das größte Bild; was das Doppel trägt und ihm "
                     + "fehlt (Bildunterschrift, Ort), geht mit hinüber. Wo ein Doppel auf einer "
                     + "Seite stand, steht danach das behaltene Foto. Tage ohne Handarbeit werden "
                     + "neu angeordnet. \u{201E}Widerrufen\u{201C} nimmt alles in einem Schritt "
                     + "zurück; die Dateien gehen erst beim Schließen des Buches von der Platte.\n\n"
                     + zahlen(befund))
            }
            ForEach(befund.gruppen) { gruppe in
                Section(gruppe.grund.satz) {
                    if let bleibt = werk.reise.foto(gruppe.behalten) {
                        zeile(bleibt, bleibt: true)
                    }
                    ForEach(gruppe.weg, id: \.self) { id in
                        if let weg = werk.reise.foto(id) { zeile(weg, bleibt: false) }
                    }
                }
            }
        }
    }

    private func zeile(_ foto: Foto, bleibt: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: bleibt ? "checkmark.circle.fill" : "minus.circle.fill")
                .foregroundStyle(bleibt ? Color.green : Color.red)
            FotoZeile(werk: werk, foto: foto)
            Text(bleibt ? "bleibt" : "geht")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(Int(foto.breite)) \u{00D7} \(Int(foto.hoehe))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func erledigt(_ bericht: Reisewerk.Duplikatbericht) -> some View {
        List {
            Section {
                Label(bericht.entfernt == 1
                      ? "1 Doppel entfernt"
                      : "\(bericht.entfernt) Doppel entfernt",
                      systemImage: "checkmark.circle.fill")
                if bericht.neuGesetzt > 0 {
                    Text("\(bericht.neuGesetzt) Tage neu angeordnet.")
                }
                if bericht.handarbeit > 0 {
                    Text("\(bericht.handarbeit) Tage mit Handarbeit sind nicht neu angeordnet \u{2014} "
                         + "wo dort ein Doppel stand, ist jetzt eine Lücke oder das behaltene Foto.")
                        .foregroundStyle(.orange)
                }
            } footer: {
                Text("\u{201E}Widerrufen\u{201C} nimmt das in einem Schritt zurück, solange das Buch offen ist.")
            }
        }
    }
}
