//  OnboardingView.swift
//  The checklist, and the self-test that ends it.
//
//  The rule this screen exists to enforce: onboarding is not finished when
//  every line is green. It is finished when a test alarm has actually arrived
//  on this device and somebody confirmed hearing it. Green ticks describe
//  settings; a delivered notification describes reality, and only the second
//  one is what the school is relying on.

import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject private var model: AppModel
    @State private var testRequestedAt: Date?

    var body: some View {
        NavigationStack {
            List {
                if let code = model.freshInviteCode { codeSection(code) }

                Section {
                    Text("Dieses iPad muss laut werden können, auch wenn es "
                         + "gesperrt ist und ein Fokus läuft. Die folgenden Punkte "
                         + "sind dafür nötig.")
                        .font(.callout)
                }

                Section("Von der App prüfbar") {
                    ForEach(model.checklist) { item in
                        checklistRow(item)
                    }
                }

                Section {
                    Button {
                        Task { await model.requestPermissions() }
                    } label: {
                        Label("Berechtigungen anfragen", systemImage: "bell.badge")
                    }
                }

                Section {
                    ForEach(OnboardingChecklist.manualHints, id: \.title) { hint in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(hint.title, systemImage: "hand.point.right")
                                .font(.headline)
                            Text(hint.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Von Hand, einmal je Gerät")
                } footer: {
                    Text("Diese drei Punkte kann keine App nachsehen — iOS gibt sie "
                         + "nicht heraus. Sie stehen hier als Anleitung und nicht als "
                         + "Häkchen, weil ein Häkchen ohne Prüfung eine Behauptung wäre.")
                }

                tontestSection
                selfTestSection

                Section {
                    Button {
                        model.finishOnboarding()
                    } label: {
                        Text("Einrichtung abschließen").fontWeight(.semibold)
                    }
                    .disabled(!model.finishBlockers.isEmpty)
                } footer: {
                    if !model.finishBlockers.isEmpty {
                        Text("Noch offen: "
                             + model.finishBlockers.map(\.title).joined(separator: ", "))
                    } else if model.letzterPush == nil {
                        Text("Der Zustellnachweis steht noch aus — er braucht ein "
                             + "zweites Gerät und hält die Einrichtung deshalb "
                             + "nicht auf. Bis er erbracht ist, steht auf dem "
                             + "Startbildschirm ein Warnband, und dieses iPad "
                             + "gilt nicht als geprüft.")
                    }
                }
            }
            .navigationTitle("Einrichtung")
            .refreshable { await model.refresh() }
            .task { await model.rebuildChecklist() }
        }
    }

    /// Der Code, mit dem das Kollegium hereinkommt — genau einmal, hier, wo
    /// die einrichtende Person ohnehin steht.
    ///
    /// Ein Code, der nur unter „Verwaltung → Beitrittscodes" liegt, ist ein
    /// Code, nach dem gefragt wird. Wiederzufinden ist er dort trotzdem.
    private func codeSection(_ code: InviteCode) -> some View {
        Section {
            VStack(spacing: 14) {
                Text(code.id)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                QRCodeView(text: code.id, size: 180)
                Text("Damit tritt das Kollegium bei: Code abtippen oder scannen. "
                     + "Wiederzufinden unter Verwaltung → Beitrittscodes.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Verstanden") { model.freshInviteCode = nil }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } header: {
            Text("Die Schule ist eingerichtet")
        }
    }

    private func checklistRow(_ item: ChecklistItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.state.symbol)
                .foregroundStyle(item.state == .ok ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.headline)
                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if item.isBlocking, let url = item.settingsURL {
                Link("Öffnen", destination: url).font(.footnote)
            }
        }
        .padding(.vertical, 4)
    }

    /// Zuerst der Ton, dann die Zustellung. Die Reihenfolge ist die
    /// Fehlersuche: Wer den Ton nicht hört, braucht über die Zustellung noch
    /// gar nicht nachzudenken.
    /// Zuerst der Ton, dann die Zustellung. Die Reihenfolge ist die
    /// Fehlersuche: Wer den Ton nicht hört, braucht über die Zustellung noch
    /// gar nicht nachzudenken.
    @ViewBuilder
    private var tontestSection: some View {
        Section {
            Button {
                Task { await model.runTontest() }
            } label: {
                Label("Tontest starten", systemImage: "speaker.wave.3")
            }
            Text("Sperre das iPad jetzt und lege es hin. In \(Int(Tontest.vorlauf)) "
                 + "Sekunden weckt es sich selbst — mit dem Alarmton, in der "
                 + "Dringlichkeitsstufe des Ernstfalls.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Ich habe den Ton gehört") { model.confirmTontest() }
                .fontWeight(.semibold)
        } header: {
            Text("1. Tontest — ohne Netz")
        } footer: {
            Text("Dieser Test läuft ganz auf dem Gerät. Er beweist, dass das iPad "
                 + "laut werden DARF — nicht, dass ein Alarm von einer Kollegin "
                 + "ankommt. Dafür ist der nächste da.")
        }

        Section {
            Button {
                model.spieleTonprobe()
            } label: {
                Label("Ton direkt abspielen", systemImage: "waveform")
            }
            Button("Abspielen beenden") { model.haltTonprobeAn() }
            Button {
                Task { await model.runTontest(mitStandardton: true) }
            } label: {
                Label("Tontest mit Standardton", systemImage: "bell")
            }
        } header: {
            Text("Wenn die Mitteilung kommt, aber stumm bleibt")
        } footer: {
            Text(tonHilfe)
        }
    }

    /// Die Reihenfolge ist nach Häufigkeit sortiert — und der erste Punkt ist
    /// der, den fast alle übersehen.
    private var tonHilfe: String {
        """
        Die beiden Knöpfe oben grenzen die Ursache ein:

        • „Ton direkt abspielen" spielt die Datei an den Mitteilungen vorbei         und auch bei stummem Gerät. Hörbar heißt: Die Datei ist in Ordnung.

        • „Tontest mit Standardton" schickt dieselbe Mitteilung mit dem         System-Ton. Hörst du DIESEN, aber nicht den Alarmton, liegt es doch         an der Datei. Sind BEIDE stumm, liegt es am Gerät — dann diese drei         Punkte in dieser Reihenfolge:

        1. Klingeltonlautstärke. Sie ist NICHT dieselbe wie die         Medienlautstärke. Die Lautstärketasten regeln die Medien, solange         etwas spielt — genau das tut „Ton direkt abspielen". Drücke die         Tasten, wenn nichts läuft, oder stelle sie unter Einstellungen →         Töne & Haptik ein.

        2. Eine gekoppelte Apple Watch. Wird sie getragen, leitet iOS die         Mitteilung ans Handgelenk und das iPhone bleibt still — und die Uhr         spielt nie den eigenen Ton einer App, sondern ihren Systemton. Lege         sie ab oder nimm ein iPad.

        3. Der Lautlos-Schalter. Ohne die Berechtigung für kritische Hinweise         macht auch eine zeitkritische Meldung bei stummem Gerät keinen Ton.
        """
    }

    @ViewBuilder
    private var selfTestSection: some View {
        Section {
            NavigationLink {
                DiagnoseView().environmentObject(model)
            } label: {
                Label("Zustellung prüfen", systemImage: "stethoscope")
            }
            Text(zustellHilfe)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("2. Zustellung — über iCloud")
        } footer: {
            Text("Diesen Haken setzt dieses iPad nicht selbst: CloudKit stellt "
                 + "einem Gerät keine Meldung zu einem Datensatz zu, den es "
                 + "selbst geschrieben hat. Ein iPad kann sich die Zustellung "
                 + "nicht selbst beweisen — und ein Knopf, der so täte, wäre in "
                 + "dieser App das Letzte, was hier stehen dürfte.\n\n"
                 + "Weil dafür ein zweites Gerät nötig ist, hält dieser Punkt "
                 + "die Einrichtung nicht auf. Offen bleibt er trotzdem.")
        }
    }

    /// Wer was zu tun hat, hängt davon ab, wer man ist.
    private var zustellHilfe: String {
        if model.letzterPush != nil {
            return "Auf diesem iPad ist bereits eine Meldung eingetroffen. Der "
                + "Nachweis steht."
        }
        if model.isAdmin {
            return """
            Du bist die Leitung. Schicke aus Verwaltung → Mitglieder je einen             Testalarm an die iPads der Kolleginnen; auf deren Geräten setzt             sich der Haken damit von selbst.

            Für dein EIGENES iPad braucht es jemand anderen: Mach unter             Verwaltung → Mitglieder eine zweite Person zur Leitung — sie             schickt dir dann den Testalarm zurück. Zwei Leitungen sollten es             ohnehin sein, damit die Schule nicht an einem einzigen Gerät hängt.
            """
        }
        return "Bitte die Schulleitung, dir einen Testalarm zu schicken "
            + "(Verwaltung → Mitglieder → „Testalarm senden“). Sobald er hier "
            + "eintrifft, setzt sich der Haken von selbst."
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView().environmentObject(PreviewModels.joined())
    }
}
