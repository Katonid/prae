//  SettingsView.swift
//  The checklist stays reachable, for ever.
//
//  Settings change behind an app's back: a colleague turns off a Focus
//  exception, iOS updates and resets a permission, somebody signs out of
//  iCloud to free up storage. So the checklist is not a one-time wizard. It is
//  a page in Settings, re-checked at every launch, and a failing line puts a
//  banner on the home screen.

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// Der Dateiwähler hängt AN DER WURZEL dieses Blattes, nicht an der Zeile.
    ///
    /// Eine `List` baut ihre Zeilen erst auf, wenn sie in Sichtweite kommen —
    /// an einer Zeile mitten in der Liste ist der Wähler beim Tippen oft noch
    /// gar nicht da. Dieselbe Lehre wie in Tafelbild, dort einmal teuer
    /// bezahlt. Und genau EINER je Blatt.
    @State private var zeigtDateiwahl = false

    /// Fragt vor dem Austritt nach. Nicht aus Höflichkeit: Wer hier
    /// versehentlich tippt, ist im Ernstfall nicht mehr erreichbar.
    @State private var zeigtAustritt = false

    var body: some View {
        NavigationStack {
            List {
                Section("Einsatzbereitschaft") {
                    ForEach(model.checklist) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.state.symbol)
                                .foregroundStyle(item.state == .ok ? .green : .orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.headline)
                                Text(item.detail).font(.footnote).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if item.isBlocking, let url = item.settingsURL {
                                Link("Öffnen", destination: url).font(.footnote)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    Button("Erneut prüfen") { Task { await model.refresh() } }
                }

                Section {
                    ForEach(Alarmklang.allCases) { klang in
                        Button {
                            // Ein eigener Ton, den es noch nicht gibt, lässt
                            // sich nicht wählen — der Tipp holt erst die Datei.
                            if klang == .eigen, !klang.vorhanden {
                                zeigtDateiwahl = true
                            } else {
                                model.setzeAlarmklang(klang)
                                model.spieleTonprobe(klang)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: model.alarmklang == klang
                                      ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(model.alarmklang == klang
                                                     ? Color.accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(klang.titel).font(.headline)
                                        if klang.verraetSichVorDerKlasse {
                                            Label("laut", systemImage: "speaker.wave.3.fill")
                                                .font(.caption2)
                                                .labelStyle(.iconOnly)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    Text(klang.beschreibung)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button(Alarmklang.eigen.vorhanden
                           ? "Eigenen Ton austauschen …" : "Eigenen Ton wählen …") {
                        zeigtDateiwahl = true
                    }
                    if Alarmklang.eigen.vorhanden {
                        Button("Eigenen Ton entfernen", role: .destructive) {
                            model.entferneEigenenKlang()
                        }
                    }
                    Button("Abspielen beenden") { model.haltTonprobeAn() }
                } header: {
                    Text("Alarmton")
                } footer: {
                    Text("Ein Tipp wählt den Ton UND spielt ihn vor.\n\n"
                         + "Der Ton gilt für dieses iPad. Soll das Kollegium im "
                         + "Ernstfall vor den Kindern unauffällig bleiben, muss "
                         + "ihn jedes Gerät gewählt haben — die App kann das "
                         + "nicht für alle entscheiden.\n\n"
                         + "Die Lautstärke steckt im Ton selbst. Kritische "
                         + "Hinweise spielen immer mit voller Lautstärke, "
                         + "unabhängig vom Lautstärkeregler — deshalb sind die "
                         + "drei leisen Töne leise GERECHNET und nicht "
                         + "leiser gestellt. Ein Regler dafür wäre wirkungslos.\n\n"
                         + "„Alarm“ ist vor einer Klasse nicht zu verbergen. Die "
                         + "drei anderen schon — dafür werden sie in einem lauten "
                         + "Raum eher überhört. Die Erinnerungsreihe wiederholt "
                         + "den Ton, bis jemand antwortet.\n\n"
                         + "Ein eigener Ton darf WAV, AIFF, CAF, MP3 oder M4A "
                         + "sein und höchstens 30 Sekunden lang — darüber "
                         + "spielt iOS gar nichts. Die App rechnet ihn um und "
                         + "bringt ihn auf dieselbe Lautstärke wie „Holzton“; "
                         + "ohne das wäre er auf allen Geräten unerwartet laut.")
                }

                Section {
                    Button("Tontest — das iPad weckt sich selbst") {
                        Task { await model.runTontest() }
                    }
                    Button("Tontest mit Standardton") {
                        Task { await model.runTontest(mitStandardton: true) }
                    }
                    Button("Gewählten Ton direkt abspielen") { model.spieleTonprobe() }
                    Button("Abspielen beenden") { model.haltTonprobeAn() }
                    NavigationLink {
                        DiagnoseView().environmentObject(model)
                    } label: {
                        Label("Zustellung prüfen", systemImage: "stethoscope")
                    }
                } header: {
                    Text("Prüfen")
                } footer: {
                    Text("Bleibt die Mitteilung stumm: „Ton direkt abspielen“ "
                         + "prüft die Datei, „Tontest mit Standardton“ prüft das "
                         + "Gerät. Sind beide stumm, liegt es an der "
                         + "Klingeltonlautstärke (nicht der Medienlautstärke), an "
                         + "einer getragenen Apple Watch (App „Watch“ → Mitteilungen "
                         + "→ Spiegelung für Schulalarm aus) oder am "
                         + "Lautlos-Schalter.\n\nDie Zustellung "
                         + "beweist nur ein zweites Gerät: Ein Admin schickt "
                         + "einen Testalarm hierher (Verwaltung → Mitglieder). "
                         + "„Zustellung prüfen“ zeigt, an welcher Stelle die Kette "
                         + "reißt.")
                }

                Section("Dieses Gerät") {
                    labelled("Kürzel", model.displayName)
                    labelled("Rolle", model.isAdmin ? MemberRole.admin.label
                                                    : MemberRole.member.label)
                    labelled("Gruppe", model.group?.name ?? "—")
                    labelled("App", DeviceFacts.appVersion)
                    labelled("Gerät", DeviceFacts.model)
                    labelled("Gegenstelle", BackendConfiguration.standard.label)
                }

                if model.isJoined {
                    Section {
                        Button("Verbindung zur Schule lösen", role: .destructive) {
                            zeigtAustritt = true
                        }
                        .disabled(model.isWorking)
                    } header: {
                        Text("Schule verlassen")
                    } footer: {
                        Text("Danach gehört dieses Gerät zu keiner Schule mehr: "
                             + "keine Alarme, keine Rückmeldungen. Das Kürzel "
                             + "verschwindet aus der Mitgliederliste, und die "
                             + "Abonnements werden abgeräumt — sonst klingelte "
                             + "dieses iPad weiter für eine Schule, zu der es "
                             + "nicht mehr gehört.\n\n"
                             + "Schon geschriebene Rückmeldungen und Nachrichten "
                             + "bleiben stehen. Sie sind ein Nachweis und gehören "
                             + "der Schule, nicht diesem Gerät.\n\n"
                             + "Braucht eine Verbindung: Ein halb gelöster Zustand "
                             + "wäre schlimmer als keiner.\n\n"
                             + "Danach steht wieder der Beitrittsbildschirm da — "
                             + "dieses Gerät kann einer anderen Schule beitreten "
                             + "oder eine eigene einrichten. So entsteht eine "
                             + "Teststrecke: eigene Schule, eigene Geräte, kein "
                             + "Kontakt zum echten Kollegium.")
                    }
                }

                Section {
                    ForEach(OnboardingChecklist.manualHints, id: \.title) { hint in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(hint.title).font(.headline)
                            Text(hint.detail).font(.footnote).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 3)
                    }
                } header: {
                    Text("Nicht prüfbar")
                }

                Section {
                    Text("Diese App ersetzt keinen Notruf. 110 und 112 bleiben der "
                         + "Weg nach draußen; die App verständigt nur das Kollegium.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task { await model.rebuildChecklist() }
            .alert("Verbindung zur Schule lösen?", isPresented: $zeigtAustritt) {
                Button("Lösen", role: .destructive) {
                    Task { await model.verlasseSchule() }
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Dieses Gerät bekommt danach keine Alarme dieser Schule "
                     + "mehr, und das Kürzel verschwindet aus der "
                     + "Mitgliederliste.\n\nZum Wiederkommen braucht es einen "
                     + "Beitrittscode von einem Admin.")
            }
            .fileImporter(isPresented: $zeigtDateiwahl,
                          allowedContentTypes: [.audio],
                          allowsMultipleSelection: false) { ergebnis in
                switch ergebnis {
                case .success(let dateien):
                    if let erste = dateien.first {
                        model.uebernehmeEigenenKlang(von: erste)
                    }
                case .failure(let fehler):
                    model.problem = fehler.localizedDescription
                }
            }
        }
    }

    private func labelled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(PreviewModels.joined())
    }
}
