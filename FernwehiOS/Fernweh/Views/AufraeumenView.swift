import SwiftUI
import CoreData

/// Doppelte Fotos und doppelte Tageseinträge einer Reise finden und
/// entfernen (ab 1.0.40, siehe `Doppelfotos`). Erreichbar über Reise → „…"
/// → „Doppelte Fotos aufräumen …" und über den Hinweis oben in der Reise.
/// Beide Schritte lassen sich rückgängig machen.
struct AufraeumenView: View {
    @ObservedObject var reise: Reise
    @Environment(\.dismiss) private var schliessen
    @ObservedObject private var rueckgaengig = Rueckgaengig.shared
    @State private var gruppen: [Doppelfotos.Gruppe] = []
    @State private var buendel: [Doppelfotos.Tagesbuendel] = []
    @State private var geladen = false
    @State private var meldung: String?

    private var doppelteZahl: Int { gruppen.reduce(0) { $0 + $1.doppelte.count } }

    var body: some View {
        NavigationStack {
            List {
                if let meldung {
                    Section { Label(meldung, systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                }
                doppelteAbschnitt
                buendelAbschnitt
            }
            .navigationTitle("Aufräumen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if rueckgaengig.letzter != nil {
                        Button {
                            rueckgaengig.zuruecknehmen()
                            meldung = nil
                            suchen()
                        } label: { Label("Rückgängig", systemImage: "arrow.uturn.backward") }
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
            }
            .task { suchen() }
        }
    }

    private func suchen() {
        gruppen = Doppelfotos.finden(in: reise)
        buendel = Doppelfotos.buendel(in: reise)
        geladen = true
    }

    // MARK: - Doppelte Fotos

    @ViewBuilder
    private var doppelteAbschnitt: some View {
        Section {
            if !geladen {
                ProgressView()
            } else if gruppen.isEmpty {
                Label("Keine doppelten Fotos in dieser Reise.", systemImage: "checkmark.seal")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(gruppen) { g in
                    HStack(spacing: 8) {
                        FotoBild(foto: g.behalten, kante: 160)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.white, .green)
                                    .padding(2)
                            }
                        ForEach(g.doppelte, id: \.objectID) { f in
                            FotoBild(foto: f, kante: 160)
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .opacity(0.45)
                                .overlay {
                                    Image(systemName: "trash.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white, .red)
                                }
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 2) {
                            if let d = g.behalten.aufnahme {
                                Text(Tag.text(d, "d. MMM, HH:mm", zone: g.behalten.eintrag?.zone ?? .current))
                                    .font(.caption.monospacedDigit())
                            }
                            Text(g.behalten.eintrag?.anzeigeTitel ?? "")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Button(role: .destructive) {
                    let zahl = doppelteZahl
                    Doppelfotos.entfernen(gruppen)
                    meldung = zahl == 1 ? "1 doppeltes Foto entfernt." : "\(zahl) doppelte Fotos entfernt."
                    suchen()
                } label: {
                    Label(doppelteZahl == 1 ? "1 doppeltes Foto entfernen" : "\(doppelteZahl) doppelte Fotos entfernen",
                          systemImage: "trash")
                }
            }
        } header: {
            Text("Doppelte Fotos")
        } footer: {
            Text("Dasselbe Foto erkennt Fernweh an seiner Kennung in der Mediathek — auch wenn es auf einem anderen Gerät übernommen wurde — oder an Aufnahmezeit auf die Millisekunde und Bildgröße. Behalten wird das Foto (grüner Haken) im Eintrag mit Text, sonst im Eintrag mit den meisten Fotos; ein Bildtext eines entfernten Doppels geht an das behaltene Foto, wenn dieses noch keinen hat.")
        }
    }

    // MARK: - Mehrere Einträge je Tag

    @ViewBuilder
    private var buendelAbschnitt: some View {
        if geladen && !buendel.isEmpty {
            Section {
                ForEach(buendel) { b in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Tag.datum(schluessel: b.tag).map { Tag.wochentagLang.string(from: $0) } ?? b.tag)
                            .font(.subheadline.weight(.semibold))
                        Text("\(b.aufzuloesen.count + 1) Einträge → einer: „\(b.ziel.anzeigeTitel)“")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text((b.aufzuloesen).map { "„\($0.anzeigeTitel)“ · \($0.fotoListe.count) Fotos" }.joined(separator: "\n"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    let zahl = buendel.reduce(0) { $0 + $1.aufzuloesen.count }
                    Doppelfotos.zusammenfuehren(buendel)
                    meldung = zahl == 1 ? "1 Eintrag zusammengeführt." : "\(zahl) Einträge zusammengeführt."
                    suchen()
                } label: {
                    Label("Fotos je Tag in einem Eintrag sammeln", systemImage: "rectangle.stack.badge.plus")
                }
            } header: {
                Text("Mehrere Einträge an einem Tag")
            } footer: {
                Text("Einträge ohne eigenen Text — so legte „Fotos übernehmen“ bis Fassung 1.0.39 bei jedem Lauf neue an. Ihre Fotos und Orte wandern in den Eintrag des Tages (den mit Text, sonst den mit den meisten Fotos), doppelte Fotos fallen dabei weg. Einträge mit eigenem Text bleiben immer, wie sie sind.")
            }
        }
    }
}
