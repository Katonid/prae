import SwiftUI

/// Erster Start: Wofür ist dieses Gerät da? (seit 1.0.11)
struct Willkommen: View {
    @Environment(Klasse.self) private var klasse
    @State private var kindHinweis = false

    var body: some View {
        if kindHinweis {
            KlassencodeEingabe(zurueck: { kindHinweis = false })
        } else {
            wahlSeite
        }
    }

    private var wahlSeite: some View {
        ScrollView {
            VStack(spacing: 22) {
                Titel()
                    .padding(.top, 30)
                Text("Wer benutzt dieses iPad?")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Farben.tinteDunkel)
                    wahl("🧒", "Ich übe in meiner Klasse",
                         "Mit dem Klassencode von deiner Lehrerin oder deinem Lehrer.",
                         Farben.farbe(.woerter)) { kindHinweis = true }
                    wahl("🧑‍🏫", "Ich bin Lehrerin oder Lehrer",
                         "Klasse mit Code anlegen und sehen, was jedes Kind geschrieben hat.",
                         Farben.farbe(.buchstaben)) { klasse.alsLehrergeraet() }
                    wahl("🏠", "Ohne Klasse üben",
                         "Zu Hause oder ein iPad für ein oder mehrere Kinder — alles bleibt auf diesem Gerät.",
                         Farben.farbe(.ziffern)) { klasse.rolle = .allein }
            }
            .frame(maxWidth: 620)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Farben.verlauf.ignoresSafeArea())
    }

    private func wahl(_ bild: String, _ titel: String, _ text: String, _ farbe: Color,
                      aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            HStack(spacing: 18) {
                Text(bild).font(.system(size: 54))
                VStack(alignment: .leading, spacing: 4) {
                    Text(titel)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(farbe)
                    Text(text)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Farben.tinteDunkel)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.title3.bold()).foregroundStyle(farbe)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24).fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(farbe.opacity(0.35), lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

/// Startseite auf dem Gerät der Lehrkraft.
struct LehrerStart: View {
    @Environment(Klasse.self) private var klasse
    @State private var zeigeUebersicht = false
    @State private var zeigeEinstellungen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Titel()
                    Spacer()
                    if let wolke = klasse.wolke {
                        Button {
                            Task { await wolke.abgleichen() }
                        } label: {
                            Label("Aktualisieren", systemImage: "arrow.clockwise")
                        }
                        .disabled(wolke.arbeitet)
                    }
                }
                if let wolke = klasse.wolke {
                    Label(wolke.status, systemImage: wolke.icloud ? "icloud" : "antenna.radiowaves.left.and.right")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    kachel("chart.bar.doc.horizontal", "Klassenübersicht",
                           "Buchstaben, Versuche und Seiten jedes Kindes", Farben.farbe(.buchstaben)) {
                        zeigeUebersicht = true
                    }
                    kachel("person.2.fill", "Klassen & Einstellungen",
                           "Klassencode, Kinder, Lehrgang", Farben.farbe(.woerter)) {
                        zeigeEinstellungen = true
                    }
                    kachel("hand.draw.fill", "Selbst ausprobieren",
                           "Alle Stufen offen, nichts wird gezählt", Farben.farbe(.ziffern)) {
                        klasse.probe = true
                    }
                }

                Text("Klasse")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Farben.tinteDunkel)
                if let wolke = klasse.wolke, !wolke.klassen.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(wolke.klassen) { k in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Klasse \(k.name)").font(.system(.headline, design: .rounded))
                                Text(Klassencode.anzeige(k.code))
                                    .font(.system(.title2, design: .monospaced, weight: .bold))
                                    .foregroundStyle(k.offen ? Farben.farbe(.woerter) : .secondary)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.white)
                                .shadow(color: .black.opacity(0.08), radius: 5, y: 2))
                        }
                    }
                }
                if klasse.kinder.isEmpty {
                    Text("Noch keine Kinder. Lege unter „Klassen & Einstellungen“ eine Klasse an und schreib ihren Code an die Tafel — die Kinder melden sich damit auf ihren iPads selbst an.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                        ForEach(klasse.kinder) { kind in
                            HStack(spacing: 10) {
                                Text(kind.tier).font(.system(size: 34))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kind.name).font(.system(.headline, design: .rounded)).lineLimit(1)
                                    Text(klassenName(kind))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.white)
                                .shadow(color: .black.opacity(0.08), radius: 5, y: 2))
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Farben.verlauf.ignoresSafeArea())
        .fullScreenCover(isPresented: $zeigeUebersicht) {
            LehrerTor(titel: "Klassenübersicht") { KlassenAnsicht() }
                .environment(klasse)
        }
        .sheet(isPresented: $zeigeEinstellungen) {
            LehrerTor { EinstellungenAnsicht() }
                .environment(klasse)
        }
        .task { await klasse.wolke?.abgleichen() }
    }

    private func klassenName(_ kind: Kind) -> String {
        guard let code = kind.klasse else { return "ohne Klasse" }
        return klasse.wolke?.klassen.first(where: { $0.code == code }).map { "Klasse \($0.name)" } ?? code
    }

    private func kachel(_ symbol: String, _ titel: String, _ text: String, _ farbe: Color,
                        aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol).font(.system(size: 30, weight: .bold)).foregroundStyle(farbe)
                Text(titel).font(.system(.headline, design: .rounded, weight: .bold)).foregroundStyle(Farben.tinteDunkel)
                Text(text).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 3))
        }
        .buttonStyle(.plain)
    }
}
