import SwiftUI

/// Einstellungen für Lehrkraft und Eltern: Kinder, Lehrgang, Vorführung,
/// Stift — im Lehrerbereich hinter dem Code (`LehrerTor`).
struct EinstellungenAnsicht: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Klasse.self) private var klasse

    @AppStorage(Schluessel.vorfuehren) private var vorfuehren = true
    @AppStorage(Schluessel.stift) private var stift = Stift.blau
    @AppStorage(Schluessel.nurStift) private var nurStift = false
    @AppStorage(Schluessel.heftHoehe) private var heftHoehe = 16.0

    @State private var pfad: [UUID] = []
    @State private var zeigeKlasse = false
    @State private var frageLehrer = false
    @State private var frageUmstellen = false
    @AppStorage(Lehrerzugang.biometrieSchluessel) private var mitBiometrie = false

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
                    NavigationLink("Code ändern") { CodeAendern() }
                    if let name = Lehrerzugang.biometrieName {
                        Toggle("Mit \(name) öffnen", isOn: $mitBiometrie)
                    }
                } header: {
                    Text("Lehrerbereich")
                } footer: {
                    Text("Klassenübersicht und Einstellungen öffnen nur mit dem Code. Geht die App in den Hintergrund, schließt sich der Bereich. Tipp: Mit „Geführter Zugriff“ (Einstellungen des iPads → Bedienungshilfen) können Kinder die App gar nicht erst verlassen.")
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
                    if klasse.rolle == .lehrer { AnmeldekartenDruck() }
                } header: {
                    Text(klasse.rolle == .lehrer ? "Kinder der Klasse" : "Kinder")
                } footer: {
                    if klasse.rolle == .lehrer {
                        Text("Jedes Kind bekommt eine Anmeldekarte mit QR-Code. Es scannt sie einmal auf seinem iPad (angemeldet mit seiner eigenen Apple-ID) — danach landet alles, was es schreibt, hier. Name, Tier und Genauigkeit stellst du hier ein, sie gelten dann auf dem iPad des Kindes.")
                    } else {
                        Text("Jedes Kind hat eigene Sterne und eine eigene Genauigkeit. Bei mehreren Kindern fragt die App beim Öffnen, wer schreibt.")
                    }
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

                Section {
                    if klasse.rolle == .lehrer {
                        if let wolke = klasse.wolke { Label(wolke.status, systemImage: "icloud") }
                        Button("Dieses Gerät umstellen …") { frageUmstellen = true }
                    } else {
                        Button("Als Lehrergerät einrichten …") { frageLehrer = true }
                    }
                } header: {
                    Text("Klasse über iCloud")
                } footer: {
                    if klasse.rolle == .lehrer {
                        Text("Dies ist das Gerät der Lehrkraft. Die Klasse liegt in deinem iCloud; Lehrgang, Vorführen, Heftgröße und „Nur Apple Pencil“ gelten für alle iPads der Klasse.")
                    } else {
                        Text("Haben die Kinder eigene iPads (auch geteilte iPads mit verwalteter Apple-ID), wird dieses Gerät das Lehrergerät: Die Kinder hier werden die Klasse, jedes bekommt eine Anmeldekarte.")
                    }
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
            .confirmationDialog("Als Lehrergerät einrichten?", isPresented: $frageLehrer, titleVisibility: .visible) {
                Button("Einrichten") {
                    klasse.alsLehrergeraet()
                    dismiss()
                }
            } message: {
                Text("Die Kinder auf diesem Gerät werden die Klasse und in deinem iCloud gespeichert. Üben tun sie dann auf ihren eigenen iPads.")
            }
            .confirmationDialog("Dieses Gerät umstellen?", isPresented: $frageUmstellen, titleVisibility: .visible) {
                Button("Umstellen", role: .destructive) {
                    klasse.rolleZuruecksetzen()
                    dismiss()
                }
            } message: {
                Text("Die App fragt dann wieder, wer das Gerät benutzt. Die Klasse in iCloud bleibt erhalten; richtest du das Gerät wieder als Lehrergerät ein, kommt sie zurück.")
            }
            .onChange(of: vorfuehren) { klasse.wolke?.klasseGeaendert() }
            .onChange(of: heftHoehe) { klasse.wolke?.klasseGeaendert() }
            .onChange(of: nurStift) { klasse.wolke?.klasseGeaendert() }
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
            if klasse.rolle == .lehrer {
                Section {
                    NavigationLink {
                        AnmeldekarteAnsicht(kind: kind)
                    } label: {
                        Label("Anmeldekarte", systemImage: "qrcode")
                    }
                }
            }
            Section {
                if klasse.rolle != .lehrer {
                    Button("Sterne dieses Kindes löschen", role: .destructive) { frageSterne = true }
                }
                Button(klasse.rolle == .lehrer ? "Aus der Klasse nehmen" : "Kind entfernen", role: .destructive) {
                    frageLoeschen = true
                }
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
            Text(klasse.rolle == .lehrer
                 ? "Das Kind, seine Sterne und seine Seiten werden auch in iCloud gelöscht; auf seinem iPad endet die Anmeldung."
                 : "Das Kind, alle seine Sterne und seine gespeicherten Seiten werden gelöscht.")
        }
    }
}
