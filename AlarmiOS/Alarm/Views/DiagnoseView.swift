//  DiagnoseView.swift
//  „Es kommt nichts an" in eine Zeile verwandeln, die man weiterreichen kann.
//
//  Diese Ansicht behauptet nichts. Sie fragt jedes Glied der Kette einzeln und
//  schreibt hin, was zurückkam — im Wortlaut des Dienstes, nicht in meinem.
//  „Field 'groupRef' is not marked queryable" ist für die Person, die es
//  richten muss, mehr wert als ein aufgeräumtes „Verbindung fehlgeschlagen".

import SwiftUI
import UIKit

struct DiagnoseView: View {

    @EnvironmentObject private var model: AppModel
    @State private var kopiert = false

    var body: some View {
        List {
            Section {
                Text("Geprüft wird von unten nach oben: Konto, Datenbank, "
                     + "Subscriptions, Anmeldung bei Apple. Das erste rote Kreuz "
                     + "ist die Ursache — alles darunter kann gar nicht gehen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if model.diagnoseLaeuft {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Wird geprüft …")
                    }
                }
            }

            ForEach(model.diagnose) { zeile in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: zeile.symbol)
                        .foregroundStyle(farbe(zeile.befund))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(zeile.titel).font(.headline)
                        Text(zeile.text)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 3)
            }

            Section {
                Button("Erneut prüfen") { Task { await model.runDiagnose() } }
                Button("Subscriptions neu anlegen") {
                    Task { await model.subscriptionsErneuern() }
                }
                // Der Nutzer arbeitet am iPad. Eine Zeile, die sich nicht
                // kopieren lässt, ist eine Zeile, die abgetippt werden muss.
                Button(kopiert ? "Kopiert" : "Befund kopieren") {
                    UIPasteboard.general.string = alsText
                    kopiert = true
                }
            }

            Section {
                Text(hinweis)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Wenn eine Abfrage oder eine Subscription rot ist")
            }
        }
        .navigationTitle("Zustellung prüfen")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.runDiagnose() }
    }

    private func farbe(_ befund: Diagnose.Befund) -> Color {
        switch befund {
        case .gut: return .green
        case .schlecht: return .red
        case .hinweis: return .secondary
        }
    }

    private var alsText: String {
        model.diagnose.map { "\($0.titel): \($0.text)" }.joined(separator: "\n")
    }

    private var hinweis: String {
        """
        Dann fehlt in der CloudKit-Konsole etwas — die App kann das nicht selbst \
        richten, weil ein Index keine Sache der App ist.

        1. icloud.developer.apple.com/dashboard öffnen, den Container dieser App \
        wählen, Umgebung „Development".
        2. Unter „Indexes" für jeden Record-Typ das Feld groupRef auf QUERYABLE \
        setzen; bei Alarm zusätzlich status und targetUser, bei Ack und Message \
        alarmRef, bei Ping targetUser. createdTimestamp bei Alarm, Ack und \
        Message auf QUERYABLE und SORTABLE.
        3. „Deploy Schema Changes to Production" — sonst gilt alles nur für \
        Geräte, auf die die App aus Xcode kam.

        Die vollständige Tabelle steht im README unter „CloudKit einrichten".
        """
    }
}

struct DiagnoseView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DiagnoseView().environmentObject(PreviewModels.joined())
        }
    }
}
