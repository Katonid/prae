import SwiftUI

/// Einstellungen für Lehrkraft und Eltern: Kinder, Lehrgang, Vorführung, Stift.
struct EinstellungenAnsicht: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Klasse.self) private var klasse

    @AppStorage(Schluessel.vorfuehren) private var vorfuehren = true
    @AppStorage(Schluessel.stift) private var stift = Stift.blau
    @AppStorage(Schluessel.nurStift) private var nurStift = false
    @AppStorage(Schluessel.heftHoehe) private var heftHoehe = 16.0

    @State private var pfad: [UUID] = []
    @State private var zeigeKlasse = false

    var body: some View {
        @Bindable var klasse = klasse
        NavigationStack(path: $pfad) {
            Form {
                Section {
                    Button {
                        zeigeKlasse = true
                    } label: {
                        Label("Klassenübersicht öffnen", systemImage: "chart.bar.doc.horizontal")
                    }
                } footer: {
                    Text("Welche Buchstaben jedes Kind bearbeitet hat, wie viele Anläufe und Fehlversuche es brauchte, und jede Seite zum Nachsehen.")
                }

                Section {
                    ForEach(klasse.kinder) { kind in
                        NavigationLink(value: kind.id) {
                            HStack(spacing: 12) {
                                Text(kind.tier).font(.title)
                                VStack(alignment: .leading) {
                                    Text(kind.name).font(.headline)
                                    Text("Genauigkeit: \(kind.genauigkeit.titel)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Button {
                        let neu = klasse.hinzufuegen()
                        pfad.append(neu.id)
                    } label: {
                        Label("Kind hinzufügen", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Kinder")
                } footer: {
                    Text("Jedes Kind hat eigene Sterne und eine eigene Genauigkeit. Bei mehreren Kindern fragt die App beim Öffnen, wer schreibt.")
                }

                Section {
                    Toggle("Buchstaben nach Lehrgang freischalten", isOn: $klasse.lehrgangAn)
                    if klasse.lehrgangAn {
                        Picker("Im Unterricht bis", selection: $klasse.freiBis) {
                            ForEach(Zeichenvorrat.schritte.indices, id: \.self) { i in
                                Text("\(i + 1). \(Zeichenvorrat.schritte[i])").tag(i)
                            }
                        }
                    }
                } header: {
                    Text("Lehrgang")
                } footer: {
                    Text("Reihenfolge wie auf dem Merkblatt: A, M, O, I, L, U … samt Au, Ei, Sch usw. Ist das Freischalten an, sind nur die Buchstaben bis zur gewählten Stelle offen, und unter „Wörter“ stehen nur Wörter, die sich daraus schreiben lassen. Schwünge und Ziffern bleiben immer offen.")
                }

                Section {
                    Toggle("Auf Stufe 1 erst vorführen", isOn: $vorfuehren)
                } header: {
                    Text("Vorführen")
                } footer: {
                    Text("Auf den Stufen 2 bis 4 soll das Kind die Bewegung schon kennen; der Knopf ▶ zeigt sie trotzdem jederzeit.")
                }

                Section {
                    Picker("Grundlinie bis Oberlinie", selection: $heftHoehe) {
                        ForEach([12.0, 14.0, 16.0, 20.0, 24.0], id: \.self) { mm in
                            Text("\(Int(mm)) mm").tag(mm)
                        }
                    }
                } header: {
                    Text("Stufe 5: Heftzeile")
                } footer: {
                    Text("So groß wie die Lineatur im Heft der Klasse — auf dem iPad etwa maßstabsgetreu. Eine Heftseite hat mehrere Reihen; am Anfang jeder Reihe steht, was darin geschrieben wird (Großbuchstabe, Kleinbuchstabe, erste Verbindungen). Pflicht sind drei Buchstaben je Reihe, danach darf das Kind die Reihe voll schreiben. Geprüft wird jeder Strich: lesbar, an der richtigen Linie des Schreibhauses begonnen und beendet, in der richtigen Richtung — und dass der Abstand zum vorigen Buchstaben nicht zu groß ist.")
                }

                Section {
                    Picker("Stiftfarbe", selection: $stift) {
                        ForEach(Stift.allCases) { Text($0.titel).tag($0) }
                    }
                    Toggle("Nur mit Apple Pencil schreiben", isOn: $nurStift)
                } header: {
                    Text("Stift")
                } footer: {
                    Text("Mit Apple Pencil werden Finger und Handballen auf dem Bildschirm übergangen.")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                if let kind = klasse.kinder.first(where: { $0.id == id }) {
                    KindBearbeiten(kind: kind)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $zeigeKlasse) {
                KlassenAnsicht().environment(klasse)
            }
        }
    }
}

/// Name, Tier und Genauigkeit eines Kindes.
private struct KindBearbeiten: View {
    @Environment(Klasse.self) private var klasse
    @Environment(\.dismiss) private var dismiss
    @State var kind: Kind
    @State private var frageLoeschen = false
    @State private var frageSterne = false

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $kind.name)
                    .textInputAutocapitalization(.words)
            }
            Section("Tier") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 8) {
                    ForEach(Kind.tiere, id: \.self) { tier in
                        Button { kind.tier = tier } label: {
                            Text(tier)
                                .font(.system(size: 34))
                                .frame(width: 52, height: 52)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(kind.tier == tier ? Farben.akzent.opacity(0.25) : .clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                Picker("Genauigkeit", selection: $kind.genauigkeit) {
                    ForEach(Genauigkeit.allCases) { Text($0.titel).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Wie genau muss geschrieben werden?")
            } footer: {
                Text("Angenommen wird nur, was am richtigen Punkt beginnt, in Schreibrichtung läuft, in der Spur bleibt und erst am Ziel abgesetzt wird. „Streng“ verlangt eine ruhigere Hand, „Locker“ passt für die ersten Versuche. Auf den Stufen 3 und 4 ist das Band von sich aus breiter.")
            }
            Section {
                Button("Sterne dieses Kindes löschen", role: .destructive) { frageSterne = true }
                Button("Kind entfernen", role: .destructive) { frageLoeschen = true }
            }
        }
        .navigationTitle(kind.name.isEmpty ? "Kind" : kind.name)
        .onChange(of: kind) { klasse.aendern(kind) }
        .confirmationDialog("Alle Sterne von \(kind.name) löschen?", isPresented: $frageSterne,
                            titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                klasse.sterneLoeschen(kind.id)
                kind.sterne = [:]
            }
        }
        .confirmationDialog("\(kind.name) entfernen?", isPresented: $frageLoeschen,
                            titleVisibility: .visible) {
            Button("Entfernen", role: .destructive) {
                klasse.entfernen(kind.id)
                dismiss()
            }
        } message: {
            Text("Das Kind, alle seine Sterne und seine gespeicherten Seiten werden gelöscht.")
        }
    }
}

/// Sperre vor den Einstellungen: eine Malaufgabe, die Schulanfänger noch
/// nicht lösen — damit niemand im Unterricht aus Versehen den Lehrgang
/// verstellt oder ein anderes Kind löscht.
struct ErwachsenenTor<Inhalt: View>: View {
    private let inhalt: () -> Inhalt
    private let titel: String

    @Environment(\.dismiss) private var dismiss
    @State private var offen = false
    @State private var a = Int.random(in: 6...9)
    @State private var b = Int.random(in: 4...9)
    @State private var eingabe = ""
    @State private var falsch = false
    @FocusState private var fokus: Bool

    init(titel: String = "Einstellungen", @ViewBuilder inhalt: @escaping () -> Inhalt) {
        self.titel = titel
        self.inhalt = inhalt
    }

    var body: some View {
        if offen {
            inhalt()
        } else {
            NavigationStack {
                Form {
                    Section {
                        TextField("Ergebnis", text: $eingabe)
                            .keyboardType(.numberPad)
                            .focused($fokus)
                            .onSubmit(pruefen)
                        Button("Öffnen", action: pruefen)
                    } header: {
                        Text("Für Erwachsene: Wie viel ist \(a) × \(b)?")
                    } footer: {
                        if falsch { Text("Das stimmt nicht — neue Aufgabe.").foregroundStyle(.red) }
                    }
                }
                .navigationTitle(titel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { dismiss() }
                    }
                }
                .onAppear { fokus = true }
            }
        }
    }

    private func pruefen() {
        if Int(eingabe.trimmingCharacters(in: .whitespaces)) == a * b {
            offen = true
        } else {
            falsch = true
            eingabe = ""
            a = Int.random(in: 6...9)
            b = Int.random(in: 4...9)
        }
    }
}
