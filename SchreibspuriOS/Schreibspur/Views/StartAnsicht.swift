import SwiftUI

/// Übersicht: Bereich wählen, dann ein Zeichen antippen.
struct StartAnsicht: View {
    struct Auswahl: Identifiable {
        let bereich: Bereich
        let index: Int
        var id: String { "\(bereich.rawValue)-\(index)" }
    }

    @Environment(Klasse.self) private var klasse
    @AppStorage("letzterBereich") private var bereich = Bereich.buchstaben
    @State private var auswahl: Auswahl?
    @State private var zeigeEinstellungen = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Text("Schreibspur")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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
                        .foregroundStyle(Farben.blatt)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white))
                    }
                    .buttonStyle(.plain)
                    .disabled(klasse.kinder.count < 2)
                    .accessibilityLabel(Text("\(kind.name) schreibt. Kind wechseln"))
                }
                Knopf(symbol: "gearshape.fill", name: "Einstellungen für Erwachsene") { zeigeEinstellungen = true }
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
                            Text("\(b.zeichen.filter { klasse.geuebt($0) }.count) von \(b.zeichen.count)")
                                .font(.system(.caption, design: .rounded))
                        }
                        .foregroundStyle(bereich == b ? Farben.blatt : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(bereich == b ? Color.white : Color.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView {
                let breite: CGFloat = bereich == .schwuenge ? 200 : 104
                LazyVGrid(columns: [GridItem(.adaptive(minimum: breite), spacing: 14)], spacing: 14) {
                    ForEach(Array(bereich.zeichen.enumerated()), id: \.element.id) { i, zeichen in
                        let offen = klasse.istOffen(zeichen)
                        Button {
                            auswahl = Auswahl(bereich: bereich, index: i)
                        } label: {
                            Kachel(zeichen: zeichen, stufen: Stufe.stufen(fuer: zeichen).count,
                                   gemeistert: klasse.gemeistert(zeichen),
                                   geuebt: klasse.geuebt(zeichen), offen: offen)
                        }
                        .buttonStyle(.plain)
                        .disabled(!offen)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(Farben.blatt.ignoresSafeArea())
        .fullScreenCover(item: $auswahl) { a in
            UebenAnsicht(liste: a.bereich.zeichen, start: a.index)
                .environment(klasse)
        }
        .sheet(isPresented: $zeigeEinstellungen) {
            ErwachsenenTor { EinstellungenAnsicht() }
                .environment(klasse)
        }
    }
}

/// Kachel eines Zeichens: Bild, darunter ein Punkt je Stufe
/// (voll = mit drei Sternen geschafft). Im Lehrgang noch gesperrte
/// Buchstaben sind abgedunkelt und tragen ein Schloss.
private struct Kachel: View {
    let zeichen: Zeichen
    let stufen: Int
    let gemeistert: Int
    let geuebt: Bool
    let offen: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZeichenBild(zeichen: zeichen)
                .aspectRatio(zeichen.istSchwung ? 2 : 1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    if !offen {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.35))
                            Image(systemName: "lock.fill")
                                .font(.title.weight(.bold))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
            HStack(spacing: 4) {
                ForEach(0..<stufen, id: \.self) { i in
                    Circle()
                        .fill(i < gemeistert ? Farben.stern : .white.opacity(geuebt ? 0.45 : 0.25))
                        .frame(width: 9, height: 9)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.15)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(offen ? "\(zeichen.text), \(gemeistert) von \(stufen) Stufen geschafft" : "\(zeichen.text), noch gesperrt"))
        .accessibilityAddTraits(.isButton)
    }
}
