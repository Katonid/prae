//
//  ChecklistView.swift
//  FlightMate
//
//  Vorflug-Checkliste (Nutzerwunsch nach App-Vorbild): kurze,
//  abhakbare Liste vor dem Start — pro Tag gemerkt (UserDefaults),
//  um Mitternacht beginnt sie leer. Dazu dynamische Punkte aus den
//  Live-Daten: KP-Warnung (Kompass kalibrieren) und Kälte-Hinweis
//  (Akkus warm halten) erscheinen nur, wenn sie heute relevant sind.
//

import SwiftUI

struct ChecklistItem: Identifiable {
    let id: String
    let title: String
    var subtitle: String? = nil
}

enum PreflightChecklist {
    static let baseItems: [ChecklistItem] = [
        ChecklistItem(id: "battery", title: "Akkus geladen",
                      subtitle: "Drohne, Controller, Handy"),
        ChecklistItem(id: "card", title: "Speicherkarte eingelegt & Platz frei"),
        ChecklistItem(id: "props", title: "Propeller & Gimbal geprüft",
                      subtitle: "Risse, Schutz entfernt"),
        ChecklistItem(id: "rth", title: "RTH-Höhe fürs Gelände gesetzt"),
        ChecklistItem(id: "legal", title: "Legal-Check für den Startpunkt gemacht",
                      subtitle: "Karte antippen oder Spot-Briefing"),
        ChecklistItem(id: "weather", title: "Böen & Kurzfrist-Blick geprüft"),
        ChecklistItem(id: "eid", title: "e-ID an der Drohne, Versicherung dabei"),
        ChecklistItem(id: "site", title: "Startplatz frei",
                      subtitle: "Menschen, Tiere, Hindernisse, Ausweichraum"),
    ]

    private static var storageKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "checklist-" + formatter.string(from: Date())
    }

    static func checkedIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
    }

    static func setChecked(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: storageKey)
    }
}

struct ChecklistView: View {
    @Environment(\.dismiss) private var dismiss
    /// Dynamische Zusatzpunkte (KP, Kälte) — vom Heute-Tab übergeben.
    let extraItems: [ChecklistItem]

    @State private var checked = PreflightChecklist.checkedIDs()

    private var items: [ChecklistItem] {
        extraItems + PreflightChecklist.baseItems
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { item in
                        Button {
                            if checked.contains(item.id) {
                                checked.remove(item.id)
                            } else {
                                checked.insert(item.id)
                            }
                            PreflightChecklist.setChecked(checked)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: checked.contains(item.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(checked.contains(item.id) ? .green : .secondary)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .strikethrough(checked.contains(item.id), color: .secondary)
                                    if let subtitle = item.subtitle {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    if checked.count >= items.count {
                        Label("Alles erledigt — guten Flug!", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("\(checked.count) von \(items.count) erledigt · gilt für heute")
                    }
                }
            }
            .navigationTitle("Vorflug-Checkliste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zurücksetzen") {
                        checked = []
                        PreflightChecklist.setChecked([])
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
