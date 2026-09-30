import SwiftUI

/// Übersicht: Bereich wählen, dann ein Zeichen antippen.
struct StartAnsicht: View {
    struct Auswahl: Identifiable {
        let liste: [Zeichen]
        let index: Int
        let id = UUID()
    }

    @Environment(Klasse.self) private var klasse
    @AppStorage("letzterBereich") private var bereich = Bereich.buchstaben
    @State private var auswahl: Auswahl?
    @State private var zeigeEinstellungen = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Titel()
                Spacer()
                if let kind = klasse.aktiv {
                    Button {
                        klasse.aktivID = nil
                    } label: {
                        HStack(spacing: 6) {
                            Text(kind.tier).font(.system(size: 30))
                            Text(kind.name)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Farben.tinteDunkel)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white).shadow(color: .black.opacity(0.1), radius: 4, y: 2))
                    }
                    .buttonStyle(.plain)
                    .disabled(klasse.kinder.count < 2 || klasse.rolle != .allein)
                    .accessibilityLabel(Text("\(kind.name) schreibt. Kind wechseln"))
                }
                switch klasse.rolle {
                case .lehrer?:
                    // Die Lehrkraft probiert aus — zurück zur Klasse.
                    Button {
                        klasse.probe = false
                    } label: {
                        Label("Fertig", systemImage: "checkmark")
                    }
                    .buttonStyle(RundKnopf(farbe: Farben.akzent))
                case .kind?:
                    // Auf dem Gerät des Kindes stellt die Lehrkraft alles
                    // von ihrem Gerät aus ein.
                    EmptyView()
                default:
                    Knopf(symbol: "gearshape.fill", name: "Lehrerbereich: Einstellungen") { zeigeEinstellungen = true }
                }
            }

            HStack(spacing: 10) {
                ForEach(Bereich.allCases) { b in
                    Button {
                        withAnimation(.snappy) { bereich = b }
                    } label: {
                        VStack(spacing: 2) {
                            Label(b.titel, systemImage: b.symbol)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            let liste = klasse.zeichen(in: b)
                            Text("\(liste.filter { klasse.geuebt($0) }.count) von \(liste.count)")
                                .font(.system(.caption, design: .rounded))
                        }
                        .foregroundStyle(bereich == b ? .white : Farben.farbe(b))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(bereich == b ? Farben.farbe(b) : Color.white)
                            .shadow(color: .black.opacity(bereich == b ? 0.18 : 0.08), radius: 5, y: 2))
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView {
                let liste = klasse.zeichen(in: bereich)
                let breit = bereich == .schwuenge || bereich == .woerter
                LazyVGrid(columns: [GridItem(.adaptive(minimum: breit ? 200 : 104), spacing: 14)], spacing: 14) {
                    if bereich == .woerter {
                        Button {
                            auswahl = Auswahl(liste: [klasse.mischung()], index: 0)
                        } label: {
                            GemischtKachel(farbe: Farben.farbe(.woerter))
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(Array(liste.enumerated()), id: \.element.id) { i, zeichen in
                        let offen = klasse.istOffen(zeichen)
                        Button {
                            auswahl = Auswahl(liste: liste, index: i)
                        } label: {
                            Kachel(zeichen: zeichen, farbe: Farben.farbe(bereich), stufen: Stufe.stufen(fuer: zeichen).count,
                                   gemeistert: klasse.gemeistert(zeichen),
                                   geuebt: klasse.geuebt(zeichen), offen: offen)
                        }
                        .buttonStyle(.plain)
                        .disabled(!offen)
                    }
                }
                .padding(.bottom, 24)
                if bereich == .woerter, liste.isEmpty {
                    Text("Sobald ein paar Buchstaben mehr gelernt sind, stehen hier Wörter zum Schreiben.")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(Farben.tinteDunkel)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(Farben.verlauf.ignoresSafeArea())
        .fullScreenCover(item: $auswahl) { a in
            UebenAnsicht(liste: a.liste, start: a.index)
                .environment(klasse)
        }
        .sheet(isPresented: $zeigeEinstellungen) {
            LehrerTor { EinstellungenAnsicht() }
                .environment(klasse)
        }
    }
}

/// Kachel eines Zeichens: Bild, darunter ein Punkt je Stufe
/// (voll = mit drei Sternen geschafft). Im Lehrgang noch gesperrte
/// Buchstaben sind abgedunkelt und tragen ein Schloss.
private struct Kachel: View {
    let zeichen: Zeichen
    let farbe: Color
    let stufen: Int
    let gemeistert: Int
    let geuebt: Bool
    let offen: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZeichenBild(zeichen: zeichen)
                .aspectRatio(zeichen.istSchwung || zeichen.istFolge ? 2 : 1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    if !offen {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.7))
                            Image(systemName: "lock.fill")
                                .font(.title.weight(.bold))
                                .foregroundStyle(Farben.linie)
                        }
                    }
                }
            HStack(spacing: 4) {
                ForEach(0..<stufen, id: \.self) { i in
                    Circle()
                        .fill(i < gemeistert ? Farben.stern : farbe.opacity(geuebt ? 0.35 : 0.15))
                        .frame(width: 9, height: 9)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 18).fill(.white)
            .shadow(color: .black.opacity(0.1), radius: 6, y: 3))
        .overlay(alignment: .top) {
            // Farbiger Rand oben: zu welchem Bereich die Kachel gehört.
            UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18)
                .fill(farbe)
                .frame(height: 5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(offen ? "\(zeichen.text), \(gemeistert) von \(stufen) Stufen geschafft" : "\(zeichen.text), noch gesperrt"))
        .accessibilityAddTraits(.isButton)
    }
}

/// „Gemischt üben": schon gelernte Buchstaben durcheinander, jedes Mal neu
/// zusammengestellt — die mit wenig Sternen öfter.
private struct GemischtKachel: View {
    let farbe: Color

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 4) {
                Image(systemName: "shuffle")
                    .font(.system(size: 34, weight: .bold))
                Text("Gemischt üben")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text("Bekannte Buchstaben wiederholen")
                    .font(.system(.caption, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .aspectRatio(2, contentMode: .fit)
            .background(RoundedRectangle(cornerRadius: 14).fill(farbe))
            Color.clear.frame(height: 9)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 18).fill(.white)
            .shadow(color: .black.opacity(0.1), radius: 6, y: 3))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Gemischt üben: bekannte Buchstaben wiederholen"))
        .accessibilityAddTraits(.isButton)
    }
}

/// Der Schriftzug: jeder Buchstabe in einer der Bereichsfarben — bunt,
/// aber ruhig.
struct Titel: View {
    private let farben: [Color] = Bereich.allCases.map { Farben.farbe($0) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array("Schreibspur".enumerated()), id: \.offset) { i, c in
                Text(String(c)).foregroundStyle(farben[i % farben.count])
            }
        }
        .font(.system(size: 38, weight: .heavy, design: .rounded))
        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Schreibspur"))
    }
}
