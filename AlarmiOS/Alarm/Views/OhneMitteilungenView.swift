//  OhneMitteilungenView.swift
//  Was diese App ohne Mitteilungserlaubnis noch kann — und was nicht.
//
//  Diese Seite ist die Antwort auf Apples Guideline 4.5.4: Mitteilungen dürfen
//  für eine App nicht Bedingung sein. Bis 1.1.0 (Build 42) waren sie es hier —
//  „Einrichtung abschließen" blieb grau, und wer die Systemfrage verneinte,
//  saß fest. Apple hat die Fassung deshalb abgelehnt.
//
//  Der Knopf, der hierher führt, steht direkt neben dem, der die Erlaubnis
//  erbittet. Das ist Absicht: Eine Bitte, neben der die Folgen einer Absage
//  stehen, ist eine Frage; eine Bitte ohne sie ist Druck.
//
//  **Geschrieben wird hier NICHTS schöner, als es ist.** Ohne Mitteilungen
//  bleibt ein Gerät im Ernstfall still, solange die App nicht offen ist — das
//  ist der ganze Zweck dieser App, und der Satz steht als Erstes auf der
//  Seite. Was daneben steht, ist trotzdem kein Trost, sondern eine Tatsache:
//  Die Abfrage alle fünf Sekunden läuft unabhängig von jeder Erlaubnis, und
//  eine offene App zeigt einen Alarm damit binnen Sekunden von selbst.

import SwiftUI

struct OhneMitteilungenView: View {

    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section {
                Text("Mitteilungen sind freiwillig. Diese App bleibt ohne sie "
                     + "benutzbar — sie wird nur nicht von selbst laut.")
                    .font(.callout)
            }

            Section {
                zeile("Alarm auslösen", "Voll nutzbar. Der Alarm geht an alle "
                      + "Geräte des Kollegiums, die Mitteilungen erlauben.",
                      geht: true)
                zeile("Laufenden Alarm sehen",
                      "Voll nutzbar, solange die App offen ist. Sie fragt bei "
                      + "laufendem Alarm alle fünf Sekunden nach, sonst alle "
                      + "dreißig — unabhängig von jeder Erlaubnis.",
                      geht: true)
                zeile("Rückmelden, Nachrichten, Entwarnen",
                      "Voll nutzbar.", geht: true)
                zeile("Verwaltung, Mitglieder, Beitrittscodes",
                      "Voll nutzbar.", geht: true)
                zeile("Prüfliste und Diagnose",
                      "Voll nutzbar.", geht: true)
            } header: {
                Text("Was ohne Mitteilungen geht")
            }

            Section {
                zeile("Ton bei geschlossener App",
                      "Fällt weg. Liegt dieses \(Geraetename.wort) gesperrt auf dem Tisch oder "
                      + "ist eine andere App vorn, bleibt ein Alarm hier "
                      + "unbemerkt, bis jemand die App öffnet.",
                      geht: false)
                zeile("Nachfassen alle 30 Sekunden",
                      "Fällt weg. Die zehn Erinnerungen, die jemanden auffangen, "
                      + "der die erste Meldung verpasst hat, sind selbst "
                      + "Mitteilungen.",
                      geht: false)
                zeile("Tontest",
                      "Fällt weg. Er weckt das \(Geraetename.wort) über eine Mitteilung an "
                      + "sich selbst.",
                      geht: false)
            } header: {
                Text("Was ohne Mitteilungen fehlt")
            } footer: {
                Text("Auf einem Dienstgerät, das im Ernstfall laut werden soll, "
                     + "gehören diese drei Punkte dazu. Ohne sie ist dieses "
                     + "\(Geraetename.wort) kein Alarmgerät, sondern eine Ansicht — das ist "
                     + "eine Entscheidung, keine Störung, und sie liegt bei dir.")
            }

            if !model.mitteilungenErlaubt {
                Section {
                    Button {
                        Task { await model.requestPermissions() }
                    } label: {
                        Label("Mitteilungen jetzt erlauben", systemImage: "bell.badge")
                            .fontWeight(.semibold)
                    }
                } footer: {
                    Text("Hat iOS die Frage schon einmal beantwortet, zeigt es "
                         + "sie kein zweites Mal. Dann steht der Schalter in den "
                         + "Einstellungen des Geräts unter „Mitteilungen“ → "
                         + "Schulalarm.")
                }
            }
        }
        .navigationTitle("Ohne Mitteilungen")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func zeile(_ titel: String, _ text: String, geht: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: geht ? "checkmark.circle.fill" : "minus.circle.fill")
                .foregroundStyle(geht ? .green : .orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(titel).font(.headline)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 3)
    }
}

struct OhneMitteilungenView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { OhneMitteilungenView() }
            .environmentObject(PreviewModels.joined())
    }
}
