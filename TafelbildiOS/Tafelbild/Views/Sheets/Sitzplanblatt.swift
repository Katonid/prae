import SwiftUI

/// Einstellungen des Sitzplans: Liste, Raum, Anzahl der Plätze, was „nah"
/// heißt — und die beiden Unterseiten, auf denen die eigentliche Arbeit
/// passiert (Plätze anordnen, Regeln pflegen).
///
/// **Warum die Regeln nicht hier stehen.** Sie gehören der Klasse, nicht
/// dem Raum: Dieselben Kinder sollen nicht nebeneinandersitzen, egal wie
/// die Tische stehen und auf welcher Tafel der Plan liegt. Deshalb liegen
/// sie in der Namensliste (`NameList.sitzregeln`); von hier führt nur ein
/// Weg dorthin.
struct SitzplanSettings: View {
    @EnvironmentObject private var store: BoardStore
    @Binding var content: SitzplanContent

    private var list: NameList? { store.nameList(content.listID) }

    var body: some View {
        Group {
            Section {
                Picker("Namensliste", selection: Binding(
                    get: { content.listID ?? "" },
                    set: { content.listID = $0.nonEmpty }
                )) {
                    Text("Keine").tag("")
                    ForEach(store.visibleNameLists) { liste in
                        Text(liste.name).tag(liste.id)
                    }
                }
                TextField("Überschrift", text: $content.titel,
                          prompt: Text(list?.name ?? "Sitzplan"))
            } header: {
                Text("Wer verteilt wird")
            } footer: {
                if let liste = list {
                    Text("\(liste.activeEntries.count) Kinder, "
                         + "\(content.offenePlaetze.count) freie Plätze.")
                } else {
                    Text("Ohne Liste bleibt der Plan leer.")
                }
            }

            Section {
                Button {
                    // Erst das Einstellungsblatt zu, dann der Editor über
                    // die ganze Fläche (siehe `BoardStore.sitzplanWidgetID`).
                    let ziel = store.settingsWidgetID
                    store.settingsWidgetID = nil
                    store.sitzplanWidgetID = ziel
                } label: {
                    LabeledContent("Plätze anordnen",
                                   value: "\(content.plaetze.count)")
                }

                Picker("Tafel hängt", selection: Binding(
                    get: { content.tafelseite },
                    set: { content.tafel = $0.rawValue }
                )) {
                    ForEach(Tafelseite.allCases) { seite in
                        Text(seite.titel).tag(seite)
                    }
                }

                Picker("Raum", selection: Binding(
                    get: { content.raumform },
                    set: { content.raum = $0.rawValue }
                )) {
                    ForEach(Raumform.allCases) { form in
                        Text(form.titel).tag(form)
                    }
                }
            } header: {
                Text("Der Raum")
            } footer: {
                Text("An der Tafelwand hängt, was „vorne“ heißt. Ohne sie "
                     + "wäre der Grundriss ein Rechteck ohne Richtung, und "
                     + "die Wünsche „möglichst vorne“ und „möglichst hinten“ "
                     + "hätten keinen Bezug.\n\n"

                     + "Beim Einrichten hängt die Tafel dort, wo sie im Raum "
                     + "hängt — du schaust von ihr aus in die Klasse. **Auf "
                     + "der Tafel selbst wird der Plan gedreht, bis die "
                     + "Tafelwand oben liegt**: Dort schauen die Kinder "
                     + "darauf, und für sie ist vorne oben. Dass dabei links "
                     + "und rechts tauschen, gehört dazu — nur so findet ein "
                     + "Kind seinen Platz da, wo es ihn erwartet.")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Nah heißt", value: naeheText(content.naehe))
                    Slider(value: $content.naehe, in: 1...4, step: 0.2)
                }
            } header: {
                Text("Was „nah“ bedeutet")
            } footer: {
                Text("Gemessen wird der Abstand zweier Tischmitten in "
                     + "Tischbreiten. Damit zählt der Nachbar genauso wie der "
                     + "Platz gegenüber und der schräg dahinter — ohne dass "
                     + "die Tische im Raster stehen müssten.\n\n"

                     + "Diese Zahl gilt für alle Regeln, die nichts eigenes "
                     + "sagen.")
            }

            if let liste = list, !liste.merkmale.isEmpty {
                Section {
                    Picker("Merkmal", selection: Binding(
                        get: { content.merkmalID },
                        set: { content.merkmalID = $0 }
                    )) {
                        Text("Keines").tag("")
                        ForEach(liste.merkmale) { merkmal in
                            Text(merkmal.name).tag(merkmal.id)
                        }
                    }
                    if !content.merkmalID.isEmpty {
                        Picker("Nachbarn", selection: Binding(
                            get: { content.vorgabe },
                            set: { content.merkmalsregel = $0.rawValue }
                        )) {
                            ForEach(Merkmalsvorgabe.allCases) { wahl in
                                Text(wahl.title).tag(wahl)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                } header: {
                    Text("Nach Merkmal sortieren")
                } footer: {
                    Text(merkmalstext)
                }
            }

            Section {
                if let liste = list {
                    NavigationLink {
                        SitzregelnSeite(listID: liste.id)
                    } label: {
                        LabeledContent("Regeln und Wünsche",
                                       value: "\(liste.gueltigeSitzregeln().count)")
                    }
                } else {
                    Text("Erst eine Namensliste wählen.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Wer nicht nebeneinander soll")
            } footer: {
                Text("Die Regeln gehören zur Namensliste, nicht zu diesem "
                     + "Element — dieselbe Klasse behält sie, auch wenn die "
                     + "Tische umgestellt werden oder der Plan auf einer "
                     + "anderen Tafel liegt.")
            }

            Section {
                Toggle("Namen nacheinander aufdecken", isOn: $content.mitAuftritt)
                Toggle("Mit Klang", isOn: $content.mitKlang)
                if content.verteilt {
                    Button(role: .destructive) {
                        content.belegung = [:]
                        content.reihenfolge = []
                        content.namen = [:]
                        content.bericht = []
                        content.aufgedeckt = 0
                    } label: {
                        Label("Verteilung löschen", systemImage: "arrow.counterclockwise")
                    }
                }
            } header: {
                Text("Die Auslosung")
            } footer: {
                Text("Jede Auslosung sucht von vorn. Zwei Läufe mit denselben "
                     + "Regeln geben deshalb verschiedene, gleich gute Pläne — "
                     + "es bleibt eine Auslosung.")
            }
        }
    }

    /// Was die gewählte Regel für Sitznachbarn bedeutet.
    ///
    /// Eigene Texte statt `Merkmalsvorgabe.erklaerung`: Dort ist von
    /// Gruppen die Rede, hier geht es um Nachbarschaften — dieselbe
    /// Aufzählung, ein anderer Zusammenhang.
    private var merkmalstext: String {
        guard !content.merkmalID.isEmpty else {
            return "Zum Beispiel „Jungen und Mädchen“ oder „Lesestufe“. "
                 + "Gepflegt werden die Merkmale in der Namensliste."
        }
        switch content.vorgabe {
        case .egal:
            return "Das Merkmal spielt beim Verteilen keine Rolle."
        case .unterschiedlich:
            return "Nachbarn sollen sich möglichst unterscheiden — Jungen "
                 + "neben Mädchen, verschiedene Lesestufen nebeneinander.\n\n"
                 + "Als „Nachbarn“ zählt, was der Regler oben als nah "
                 + "bestimmt. Wer kein Merkmal eingetragen hat, macht nichts "
                 + "anders — es wird nichts geraten.\n\n"
                 + "Das ist ein Wunsch, keine Regel: Er tritt zurück, wenn "
                 + "sonst eine Trennung bräche."
        case .gleich:
            return "Nachbarn sollen möglichst gleich sein — Jungen neben "
                 + "Jungen, Mädchen neben Mädchen, gleiche Lesestufen "
                 + "beieinander.\n\n"
                 + "Als „Nachbarn“ zählt, was der Regler oben als nah "
                 + "bestimmt. Wer kein Merkmal eingetragen hat, macht nichts "
                 + "anders — es wird nichts geraten.\n\n"
                 + "Das ist ein Wunsch, keine Regel: Er tritt zurück, wenn "
                 + "sonst eine Trennung bräche."
        }
    }

    private func naeheText(_ wert: Double) -> String {
        switch wert {
        case ..<1.3:  return "direkter Nachbar"
        case ..<1.9:  return "Nachbar und schräg gegenüber"
        case ..<2.7:  return "bis zum übernächsten Platz"
        case ..<3.5:  return "zwei Plätze dazwischen"
        default:      return "drei Plätze dazwischen"
        }
    }
}

// MARK: - Plätze anordnen

/// Hülle für den Vollbild-Editor: holt sich das Element aus dem Speicher
/// und macht daraus eine Bindung.
struct SitzplaneditorBlatt: View {
    @EnvironmentObject private var store: BoardStore
    let boardID: String
    let widgetID: String

    var body: some View {
        if case .sitzplan(let wert)? = store.widget(widgetID, in: boardID)?.content {
            Sitzplaneditor(content: Binding(
                get: {
                    if case .sitzplan(let jetzt)? = store.widget(widgetID, in: boardID)?.content {
                        return jetzt
                    }
                    return wert
                },
                set: { store.setContent(.sitzplan($0), widgetID: widgetID, boardID: boardID) }
            ))
        } else {
            Text("Der Sitzplan ist nicht mehr da.")
                .foregroundStyle(.secondary)
        }
    }
}

/// Der Grundriss zum Anfassen: Plätze schieben, drehen, sperren, dazu die
/// Anzahl und die Tafelwand.
///
/// **Über die ganze Fläche.** In einem Blatt bekam der Grundriss auf dem
/// iPad ein Drittel der Höhe und ein Fünftel der Breite — dreißig Tische
/// darin mit dem Finger zu treffen war Fummelei (gemeldet 08/2026). Der
/// Editor liegt deshalb als Vollbild an der Wurzel.
///
/// **Antippen zeigt die Nachbarschaft.** Wer einen Platz antippt, sieht
/// alle Plätze aufleuchten, die nach der aktuellen Einstellung als „nah"
/// gelten. Das ist wichtiger, als es aussieht: Die ganze Verteilung hängt
/// an dieser Rechnung, und niemand soll ihr glauben müssen.
struct Sitzplaneditor: View {
    @Binding var content: SitzplanContent
    @Environment(\.dismiss) private var dismiss
    @State private var gewaehlt: String?
    @State private var anzahlWunsch: Double = 30
    @State private var frageNeuOrdnen = false
    @State private var zugStart: [String: CGPoint] = [:]

    private var raum: Raumform { content.raumform }
    private var tafel: Tafelseite { content.tafelseite }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    flaeche(in: geo.size)
                }
                .background(Color(.secondarySystemBackground))

                werkzeuge
            }
            .navigationTitle("Plätze anordnen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onAppear { anzahlWunsch = Double(max(1, content.plaetze.count)) }
            .alert("Plätze neu anordnen?", isPresented: $frageNeuOrdnen) {
                Button("Neu anordnen", role: .destructive) {
                    content.plaetze = Sitzordnung.vorschlag(anzahl: Int(anzahlWunsch),
                                                            raum: raum, tafel: tafel)
                    gewaehlt = nil
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Alle Plätze werden paarweise in Reihen zur Tafel gelegt. "
                     + "Was du von Hand geschoben hast, geht dabei verloren.")
            }
        }
    }

    // MARK: Die Fläche

    private func flaeche(in groesse: CGSize) -> some View {
        let masse = raum.masse
        let rand: Double = 10
        let mass = min((groesse.width - rand * 2) / masse.width,
                       (groesse.height - rand * 2) / masse.height)
        let breit = masse.width * mass
        let hoch = masse.height * mass
        let links = (groesse.width - breit) / 2
        let oben = (groesse.height - hoch) / 2
        let band = tafel.band(in: masse, tiefe: raum.tafeltiefe)

        let nachbarn: Set<String> = {
            guard let id = gewaehlt,
                  let platz = content.plaetze.first(where: { $0.id == id })
            else { return [] }
            return Sitzverteilung.nahe(platz, in: content.plaetze, hoechstens: content.naehe)
        }()

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.tertiary, lineWidth: 1)
                }
                .frame(width: breit, height: hoch)
                .offset(x: links, y: oben)

            RoundedRectangle(cornerRadius: min(band.width, band.height) * mass * 0.45,
                             style: .continuous)
                .fill(.tertiary)
                .frame(width: band.width * mass, height: band.height * mass)
                .overlay {
                    Text("Tafel")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .rotationEffect(.degrees(tafel.senkrecht ? -90 : 0))
                }
                .offset(x: links + band.minX * mass, y: oben + band.minY * mass)

            ForEach(content.plaetze) { platz in
                kachel(platz, mass: mass, nah: nachbarn.contains(platz.id))
                    .offset(x: links + (platz.x - platz.breite / 2) * mass,
                            y: oben + (platz.y - platz.hoehe / 2) * mass)
                    .gesture(zug(platz, mass: mass))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { gewaehlt = nil }
    }

    private func kachel(_ platz: Sitzplatz, mass: Double, nah: Bool) -> some View {
        let w = platz.breite * mass
        let h = platz.hoehe * mass
        let aktiv = gewaehlt == platz.id
        return ZStack {
            RoundedRectangle(cornerRadius: min(w, h) * 0.2, style: .continuous)
                .fill(farbe(platz, aktiv: aktiv, nah: nah))
            RoundedRectangle(cornerRadius: min(w, h) * 0.2, style: .continuous)
                .strokeBorder(aktiv ? Color.accentColor : .secondary.opacity(0.4),
                              lineWidth: aktiv ? 2.5 : 1)
            if platz.gesperrt {
                Image(systemName: "xmark")
                    .font(.system(size: max(8, h * 0.4), weight: .bold))
                    .foregroundStyle(.secondary)
            } else if let nummer = content.plaetze.firstIndex(where: { $0.id == platz.id }) {
                Text("\(nummer + 1)")
                    .font(.system(size: max(7, h * 0.34), weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: w, height: h)
        .shadow(color: aktiv ? .accentColor.opacity(0.5) : .clear, radius: 8)
    }

    private func farbe(_ platz: Sitzplatz, aktiv: Bool, nah: Bool) -> Color {
        if platz.gesperrt { return Color.secondary.opacity(0.12) }
        if aktiv { return .accentColor.opacity(0.35) }
        if nah { return Color.orange.opacity(0.35) }
        return Color.secondary.opacity(0.18)
    }

    /// Schieben. Beim Loslassen wird auf ein feines Raster gefangen, damit
    /// Reihen gerade werden, ohne dass man zielen muss.
    private func zug(_ platz: Sitzplatz, mass: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { wert in
                gewaehlt = platz.id
                guard let stelle = content.plaetze.firstIndex(where: { $0.id == platz.id })
                else { return }
                verschiebe(stelle, um: wert.translation, mass: mass, fangen: false)
            }
            .onEnded { wert in
                guard let stelle = content.plaetze.firstIndex(where: { $0.id == platz.id })
                else { return }
                if abs(wert.translation.width) < 3 && abs(wert.translation.height) < 3 {
                    // Ein Tipp, kein Zug: nur auswählen und die Nachbarn zeigen.
                    zugStart[platz.id] = nil
                    Haptics.tap()
                    return
                }
                verschiebe(stelle, um: wert.translation, mass: mass, fangen: true)
            }
    }

    private func verschiebe(_ stelle: Int, um versatz: CGSize, mass: Double, fangen: Bool) {
        let platz = content.plaetze[stelle]
        let start = zugStart[platz.id] ?? CGPoint(x: platz.x, y: platz.y)
        if zugStart[platz.id] == nil { zugStart[platz.id] = start }

        var x = start.x + versatz.width / mass
        var y = start.y + versatz.height / mass
        if fangen {
            let raster = Sitzmasse.tief / 3
            x = (x / raster).rounded() * raster
            y = (y / raster).rounded() * raster
            zugStart[platz.id] = nil
        }
        let masse = raum.masse
        x = min(max(platz.breite / 2, x), masse.width - platz.breite / 2)
        y = min(max(platz.hoehe / 2, y), masse.height - platz.hoehe / 2)
        content.plaetze[stelle].x = x
        content.plaetze[stelle].y = y
    }

    // MARK: Die Werkzeugleiste

    private var werkzeuge: some View {
        VStack(spacing: 10) {
            if let id = gewaehlt,
               let stelle = content.plaetze.firstIndex(where: { $0.id == id }) {
                HStack(spacing: 14) {
                    Button {
                        content.plaetze[stelle].quer.toggle()
                        Haptics.tap()
                    } label: {
                        Label("Drehen", systemImage: "rotate.right")
                    }
                    Button {
                        content.plaetze[stelle].gesperrt.toggle()
                        Haptics.tap()
                    } label: {
                        Label(content.plaetze[stelle].gesperrt ? "Freigeben" : "Sperren",
                              systemImage: content.plaetze[stelle].gesperrt
                                          ? "lock.open" : "lock")
                    }
                    Spacer(minLength: 0)
                    Button(role: .destructive) {
                        content.plaetze.remove(at: stelle)
                        gewaehlt = nil
                        Haptics.tap()
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
                .buttonStyle(.bordered)
                .font(.footnote)
            }

            HStack(spacing: 14) {
                Button {
                    let neu = Sitzordnung.freierPlatz(in: content.plaetze,
                                                      raum: raum, tafel: tafel)
                    content.plaetze.append(neu)
                    gewaehlt = neu.id
                    Haptics.tap()
                } label: {
                    Label("Platz dazu", systemImage: "plus")
                }

                Picker("Tafel", selection: Binding(
                    get: { tafel },
                    set: { content.tafel = $0.rawValue }
                )) {
                    ForEach(Tafelseite.allCases) { seite in
                        Image(systemName: seite.symbol).tag(seite)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)

                Spacer(minLength: 0)
                Button {
                    frageNeuOrdnen = true
                } label: {
                    Label("Neu anordnen", systemImage: "square.grid.3x3")
                }
            }
            .buttonStyle(.bordered)
            .font(.footnote)

            HStack {
                Text("Anzahl")
                Slider(value: $anzahlWunsch, in: 1...48, step: 1)
                Text("\(Int(anzahlWunsch))")
                    .monospacedDigit()
                    .frame(width: 34, alignment: .trailing)
            }
            .font(.footnote)

            Text(gewaehlt == nil
                 ? "Platz antippen: zeigt, welche Plätze als „nah“ gelten. Ziehen "
                   + "verschiebt. Hier siehst du den Raum aus deiner Sicht; auf der "
                   + "Tafel steht er aus der Sicht der Kinder."
                 : "Orange sind die Plätze, die zu diesem als nah zählen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.bar)
    }
}

// MARK: - Regeln und Wünsche

/// Die Regeln der Klasse: wer getrennt sitzen soll, wer gern zusammen, wer
/// Platz braucht, wer nach vorne gehört.
struct SitzregelnSeite: View {
    @EnvironmentObject private var store: BoardStore
    let listID: String

    @State private var neueRegel = false

    private var liste: NameList? { store.nameList(listID) }

    var body: some View {
        List {
            if let liste {
                Section {
                    ForEach(liste.sitzregeln) { regel in
                        regelZeile(regel, in: liste)
                    }
                    .onDelete { stellen in
                        var kopie = liste
                        kopie.sitzregeln.remove(atOffsets: stellen)
                        store.updateNameList(kopie)
                    }
                    Button {
                        neueRegel = true
                    } label: {
                        Label("Regel hinzufügen", systemImage: "plus")
                    }
                } header: {
                    Text("Paare")
                } footer: {
                    Text("„Nicht nah beieinander“ wiegt am schwersten — es ist "
                         + "der Grund, aus dem man einen Sitzplan überhaupt plant. "
                         + "Was trotzdem nicht aufgeht, meldet die Auslosung "
                         + "hinterher.")
                }

                Section {
                    ForEach(liste.entries) { eintrag in
                        kindZeile(eintrag, in: liste)
                    }
                } header: {
                    Text("Einzelne Kinder")
                } footer: {
                    Text("„Platz daneben frei“ versucht, keinen Nachbarn im "
                         + "Umkreis einer Tischbreite zu setzen. Vorne und hinten "
                         + "sind Wünsche, keine Regeln: Sie treten zurück, wenn "
                         + "sonst eine Trennung bräche.")
                }
            } else {
                Text("Die Liste ist nicht (mehr) da.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Regeln und Wünsche")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $neueRegel) {
            if let liste {
                NeueSitzregelSheet(listID: liste.id)
            }
        }
    }

    @ViewBuilder
    private func regelZeile(_ regel: Sitzregel, in liste: NameList) -> some View {
        let a = liste.entries.first { $0.id == regel.a }?.text ?? "?"
        let b = liste.entries.first { $0.id == regel.b }?.text ?? "?"
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: regel.regelart.symbol)
                    .foregroundStyle(regel.regelart == .getrennt ? .red : .green)
                Text("\(a) \u{2013} \(b)")
                    .font(.body.weight(.medium))
                Spacer(minLength: 0)
            }
            Text(regel.regelart.titel)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text(regel.abstand > 0
                     ? "Abstand: \(zahl(regel.abstand)) Plätze"
                     : "Abstand: wie eingestellt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { regel.abstand },
                    set: { neu in
                        var kopie = liste
                        guard let stelle = kopie.sitzregeln.firstIndex(where: { $0.id == regel.id })
                        else { return }
                        kopie.sitzregeln[stelle].abstand = neu < 0.9 ? 0 : neu
                        store.updateNameList(kopie)
                    }
                ), in: 0...4, step: 0.2)
            }
        }
    }

    @ViewBuilder
    private func kindZeile(_ eintrag: NameEntry, in liste: NameList) -> some View {
        HStack {
            Text(eintrag.text.nonEmpty ?? "Ohne Namen")
            Spacer(minLength: 0)
            if eintrag.alleine {
                Image(systemName: "person.crop.circle.badge.minus")
                    .foregroundStyle(.orange)
            }
            Menu {
                Picker("Wo", selection: Binding(
                    get: { Sitzwunsch.aus(eintrag.sitzwunsch) },
                    set: { neu in aendere(eintrag, in: liste) { $0.sitzwunsch = neu.rawValue } }
                )) {
                    ForEach(Sitzwunsch.allCases) { wunsch in
                        Label(wunsch.titel, systemImage: wunsch.symbol).tag(wunsch)
                    }
                }
                Divider()
                Toggle(isOn: Binding(
                    get: { eintrag.alleine },
                    set: { neu in aendere(eintrag, in: liste) { $0.alleine = neu } }
                )) {
                    Label("Platz daneben frei", systemImage: "person.crop.circle.badge.minus")
                }
            } label: {
                let wunsch = Sitzwunsch.aus(eintrag.sitzwunsch)
                Label(wunsch == .egal ? "Egal" : wunsch.titel, systemImage: wunsch.symbol)
                    .font(.caption)
            }
        }
    }

    private func aendere(_ eintrag: NameEntry, in liste: NameList,
                         _ arbeit: (inout NameEntry) -> Void) {
        var kopie = liste
        guard let stelle = kopie.entries.firstIndex(where: { $0.id == eintrag.id }) else { return }
        arbeit(&kopie.entries[stelle])
        store.updateNameList(kopie)
    }

    private func zahl(_ wert: Double) -> String {
        String(format: "%.1f", wert).replacingOccurrences(of: ".", with: ",")
    }
}

/// Zwei Kinder wählen und sagen, wie sie zueinander sitzen sollen.
struct NeueSitzregelSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss
    let listID: String

    @State private var a = ""
    @State private var b = ""
    @State private var art = Regelart.getrennt

    private var liste: NameList? { store.nameList(listID) }

    var body: some View {
        NavigationStack {
            Form {
                if let liste {
                    Section {
                        Picker("Erstes Kind", selection: $a) {
                            Text("Wählen").tag("")
                            ForEach(liste.entries) { eintrag in
                                Text(eintrag.text.nonEmpty ?? "Ohne Namen").tag(eintrag.id)
                            }
                        }
                        Picker("Zweites Kind", selection: $b) {
                            Text("Wählen").tag("")
                            ForEach(liste.entries) { eintrag in
                                Text(eintrag.text.nonEmpty ?? "Ohne Namen").tag(eintrag.id)
                            }
                        }
                    }
                    Section {
                        Picker("Regel", selection: $art) {
                            ForEach(Regelart.allCases) { wahl in
                                Text(wahl.titel).tag(wahl)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
            }
            .navigationTitle("Neue Regel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { sichern() }
                        .disabled(a.isEmpty || b.isEmpty || a == b)
                }
            }
        }
    }

    private func sichern() {
        guard var kopie = liste, !a.isEmpty, !b.isEmpty, a != b else { return }
        kopie.sitzregeln.append(Sitzregel(a: a, b: b, art: art.rawValue))
        store.updateNameList(kopie)
        dismiss()
    }
}
