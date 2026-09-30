import SwiftUI

/// Erster Start: Wofür ist dieses Gerät da? (seit 1.0.11)
struct Willkommen: View {
    @Environment(Klasse.self) private var klasse
    @State private var kindHinweis = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Titel()
                    .padding(.top, 30)
                if kindHinweis {
                    anmeldekarteHinweis
                } else {
                    Text("Wer benutzt dieses iPad?")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Farben.tinteDunkel)
                    wahl("🧒", "Ich übe in meiner Klasse",
                         "Mit der Anmeldekarte von deiner Lehrerin oder deinem Lehrer.",
                         Farben.farbe(.woerter)) { kindHinweis = true }
                    wahl("🧑‍🏫", "Ich bin Lehrerin oder Lehrer",
                         "Klasse anlegen, Anmeldekarten drucken und sehen, was jedes Kind geschrieben hat.",
                         Farben.farbe(.buchstaben)) { klasse.alsLehrergeraet() }
                    wahl("🏠", "Ohne Klasse üben",
                         "Zu Hause oder ein iPad für ein oder mehrere Kinder — alles bleibt auf diesem Gerät.",
                         Farben.farbe(.ziffern)) { klasse.rolle = .allein }
                }
            }
            .frame(maxWidth: 620)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Farben.verlauf.ignoresSafeArea())
    }

    private var anmeldekarteHinweis: some View {
        VStack(spacing: 18) {
            Text("📷").font(.system(size: 80))
            Text("Scanne deine Anmeldekarte")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Farben.tinteDunkel)
            Text("Öffne die Kamera des iPads und halte sie über den Code auf deiner Karte. Tippe dann auf den Hinweis, der erscheint, und auf „Öffnen“.")
                .font(.system(.title3, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Farben.tinteDunkel)
            Text("Das geht nur einmal — danach weiß das iPad, wer hier schreibt.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
            Button("Zurück") { kindHinweis = false }
                .buttonStyle(RundKnopf(farbe: Farben.knopf))
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 28).fill(.white).shadow(color: .black.opacity(0.1), radius: 10, y: 4))
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

/// Kindergerät: Die Karte ist gescannt, das Profil kommt noch aus iCloud.
struct KindWartet: View {
    @Environment(Klasse.self) private var klasse

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().controlSize(.large)
            Text("Einen Moment — deine Klasse wird geladen.")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Farben.tinteDunkel)
            if let wolke = klasse.wolke {
                Text(wolke.status).font(.callout).foregroundStyle(.secondary)
                Button("Noch einmal versuchen") { Task { await wolke.abgleichen() } }
                    .buttonStyle(RundKnopf(farbe: Farben.akzent))
                    .disabled(wolke.arbeitet)
            }
            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .background(Farben.verlauf.ignoresSafeArea())
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
                    Label(wolke.status, systemImage: "icloud")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    kachel("chart.bar.doc.horizontal", "Klassenübersicht",
                           "Buchstaben, Versuche und Seiten jedes Kindes", Farben.farbe(.buchstaben)) {
                        zeigeUebersicht = true
                    }
                    kachel("person.2.fill", "Kinder & Anmeldekarten",
                           "Klasse anlegen, Karten drucken, Lehrgang", Farben.farbe(.woerter)) {
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
                if klasse.kinder.isEmpty {
                    Text("Noch keine Kinder. Lege sie unter „Kinder & Anmeldekarten“ an und drucke für jedes Kind seine Karte.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                        ForEach(klasse.kinder) { kind in
                            let beigetreten = klasse.wolke?.freigaben[kind.id]?.beigetreten ?? false
                            HStack(spacing: 10) {
                                Text(kind.tier).font(.system(size: 34))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kind.name).font(.system(.headline, design: .rounded)).lineLimit(1)
                                    Label(beigetreten ? "angemeldet" : "Karte noch nicht gescannt",
                                          systemImage: beigetreten ? "checkmark.circle.fill" : "qrcode")
                                        .font(.caption)
                                        .foregroundStyle(beigetreten ? Farben.start : .secondary)
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
        .task { await klasse.wolke?.freigabenAktualisieren() }
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
