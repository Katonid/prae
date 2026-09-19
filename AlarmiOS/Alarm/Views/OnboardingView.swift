//  OnboardingView.swift
//  The checklist, and the self-test that ends it.
//
//  Zwei Regeln stehen hier gegeneinander, und beide sind teuer bezahlt.
//
//  Die erste: Grüne Häkchen beschreiben Einstellungen, eine angekommene
//  Meldung beschreibt die Wirklichkeit — und nur auf die zweite verlässt sich
//  eine Schule. Deshalb steht hier eine Prüfliste und nicht ein Willkommensbild.
//
//  Die zweite: **Diese Liste sperrt niemanden aus.** „Einrichtung abschließen"
//  ist immer tippbar, auch wenn keine einzige Zeile grün ist. Bis 1.1.0
//  (Build 42) war der Knopf grau, solange die Mitteilungserlaubnis fehlte —
//  wer die Systemfrage mit „Nicht erlauben" beantwortete, kam damit nie in die
//  App. Apple hat die Fassung dafür abgelehnt (Guideline 4.5.4), und die
//  Ablehnung war richtig: Mitteilungen machen diese App LAUT, sie machen sie
//  nicht erst benutzbar. Was fehlt, steht als Satz darunter und als Warnband
//  auf dem Startbildschirm — es hält niemanden auf.

import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject private var model: AppModel
    @State private var testRequestedAt: Date?

    var body: some View {
        NavigationStack {
            List {
                if let code = model.freshInviteCode { codeSection(code) }

                Section {
                    Text("Damit dieses \(Geraetename.wort) im Ernstfall laut wird — auch "
                         + "gesperrt und bei laufendem Fokus —, sollten die "
                         + "folgenden Punkte stehen. Aufgehalten wird hier "
                         + "niemand: Was offen bleibt, steht dabei, und die "
                         + "Liste ist danach dauerhaft in den Einstellungen zu "
                         + "finden.")
                        .font(.callout)
                }

                mitteilungsSection

                Section("Von der App prüfbar") {
                    ForEach(model.checklist) { item in
                        checklistRow(item)
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
                } footer: {
                    Text(abschlusshinweis)
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

    /// Die Einwilligung — ausdrücklich, erklärt, und mit einem Weg daran vorbei.
    ///
    /// Apples Vorgabe zu 4.5.4 lautet: Mitteilungen müssen freiwillig sein und
    /// die Einwilligung muss IN der App eingeholt werden. Beides steht hier:
    /// der Knopf, der die Systemfrage auslöst, davor ein Satz, wozu, und
    /// darunter der Satz, was ohne sie noch geht. Der Systemdialog allein
    /// erklärt nichts — er fragt nur.
    @ViewBuilder
    private var mitteilungsSection: some View {
        Section {
            if model.mitteilungenErlaubt {
                Label("Mitteilungen sind erlaubt", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    Task { await model.requestPermissions() }
                } label: {
                    Label("Mitteilungen erlauben", systemImage: "bell.badge")
                        .fontWeight(.semibold)
                }
            }
            NavigationLink {
                OhneMitteilungenView().environmentObject(model)
            } label: {
                Label("Was ohne Mitteilungen geht", systemImage: "questionmark.circle")
            }
        } header: {
            Text("Mitteilungen — freiwillig")
        } footer: {
            Text("Mitteilungen sind der Weg, auf dem ein Alarm dieses "
                 + "\(Geraetename.wort) erreicht, während es gesperrt ist oder eine andere "
                 + "App vorn liegt. Genau dafür ist diese App gebaut, und "
                 + "deshalb wird hier darum gebeten.\n\n"
                 + "Erlauben musst du es trotzdem nicht. Ohne Mitteilungen "
                 + "bleibt die App vollständig benutzbar — sie wird nur nicht "
                 + "von selbst laut. Die Entscheidung lässt sich jederzeit "
                 + "ändern, hier oder in den Einstellungen des Geräts.")
        }
    }

    /// Was am Abschlussknopf steht — eine Auskunft, keine Bedingung.
    private var abschlusshinweis: String {
        var teile: [String] = []
        if !model.blockingItems.isEmpty {
            teile.append("Noch offen: "
                         + model.blockingItems.map(\.title).joined(separator: ", ")
                         + ". Das hält hier nichts auf — die Prüfliste steht "
                         + "dauerhaft in den Einstellungen, und was rot bleibt, "
                         + "zeigt der Startbildschirm als Warnband an.")
        }
        if model.letzterPush == nil {
            teile.append("Der Zustellnachweis braucht ein zweites Gerät und "
                         + "kann deshalb hier gar nicht erbracht werden. Bis "
                         + "dahin gilt dieses \(Geraetename.wort) als ungeprüft.")
        }
        if teile.isEmpty {
            return "Alles Prüfbare steht. Wiederholt wird die Prüfung trotzdem "
                + "bei jedem Start — Berechtigungen ändern sich hinter dem "
                + "Rücken einer App."
        }
        return teile.joined(separator: "\n\n")
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
            Text("Sperre das \(Geraetename.wort) jetzt und lege es hin. In \(Int(Tontest.vorlauf)) "
                 + "Sekunden weckt es sich selbst — mit dem Alarmton, in der "
                 + "Dringlichkeitsstufe des Ernstfalls.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Ich habe den Ton gehört") { model.confirmTontest() }
                .fontWeight(.semibold)
        } header: {
            Text("1. Tontest — ohne Netz")
        } footer: {
            Text("Dieser Test läuft ganz auf dem Gerät. Er beweist, dass das \(Geraetename.wort) "
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

        2. Eine gekoppelte Apple Watch. Wird sie getragen, leitet iOS die         Mitteilung ans Handgelenk und das iPhone bleibt still — und die Uhr         spielt nie den eigenen Ton einer App, sondern ihren Systemton.         Dauerhaft abstellen: App „Watch“ → Mitteilungen → „Mitteilungen von         iPhone spiegeln“ → Schulalarm aus. Für den Augenblick reicht es, sie         abzulegen.

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
            Text("Diesen Haken setzt dieses \(Geraetename.wort) nicht selbst: CloudKit stellt "
                 + "einem Gerät keine Meldung zu einem Datensatz zu, den es "
                 + "selbst geschrieben hat. Ein Gerät kann sich die Zustellung "
                 + "nicht selbst beweisen — und ein Knopf, der so täte, wäre in "
                 + "dieser App das Letzte, was hier stehen dürfte.\n\n"
                 + "Weil dafür ein zweites Gerät nötig ist, hält dieser Punkt "
                 + "die Einrichtung nicht auf. Offen bleibt er trotzdem.")
        }
    }

    /// Wer was zu tun hat, hängt davon ab, wer man ist.
    private var zustellHilfe: String {
        if model.letzterPush != nil {
            return "Auf diesem \(Geraetename.wort) ist bereits eine Meldung eingetroffen. Der "
                + "Nachweis steht."
        }
        if model.isAdmin {
            return """
            Du bist Admin. Schicke aus Verwaltung → Mitglieder je einen             Testalarm an die Geräte der Kolleginnen; auf deren Geräten setzt             sich der Haken damit von selbst.

            Für dein EIGENES Gerät braucht es jemand anderen: Mach unter             Verwaltung → Mitglieder eine zweite Person zum Admin — sie             schickt dir dann den Testalarm zurück. Zwei Admins sollten es             ohnehin sein, damit die Schule nicht an einem einzigen Gerät hängt.
            """
        }
        return "Bitte einen Admin, dir einen Testalarm zu schicken "
            + "(Verwaltung → Mitglieder → „Testalarm senden“). Sobald er hier "
            + "eintrifft, setzt sich der Haken von selbst."
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView().environmentObject(PreviewModels.joined())
    }
}
