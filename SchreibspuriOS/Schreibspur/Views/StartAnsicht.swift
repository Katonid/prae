import SwiftUI

/// Übersicht: Bereich wählen, dann ein Zeichen antippen.
struct StartAnsicht: View {
    struct Auswahl: Identifiable {
        let gruppe: Gruppe
        let index: Int
        var id: String { "\(gruppe.rawValue)-\(index)" }
    }

    @Environment(Fortschritt.self) private var fortschritt
    @AppStorage("letzteGruppe") private var gruppe = Gruppe.grossbuchstaben
    @State private var auswahl: Auswahl?
    @State private var zeigeEinstellungen = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Schreibspur")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Knopf(symbol: "gearshape.fill", name: "Einstellungen") { zeigeEinstellungen = true }
            }

            HStack(spacing: 10) {
                ForEach(Gruppe.allCases) { g in
                    Button {
                        withAnimation(.snappy) { gruppe = g }
                    } label: {
                        VStack(spacing: 2) {
                            Label(g.titel, systemImage: g.symbol)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("\(fortschritt.geschafft(in: g)) von \(g.zeichen.count)")
                                .font(.system(.caption, design: .rounded))
                        }
                        .foregroundStyle(gruppe == g ? Farben.blatt : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(gruppe == g ? Color.white : Color.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 14)], spacing: 14) {
                    ForEach(Array(gruppe.zeichen.enumerated()), id: \.element.id) { i, zeichen in
                        Button {
                            auswahl = Auswahl(gruppe: gruppe, index: i)
                        } label: {
                            Kachel(zeichen: zeichen, gruppe: gruppe, sterne: fortschritt.sterne(fuer: zeichen))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(Farben.blatt.ignoresSafeArea())
        .fullScreenCover(item: $auswahl) { a in
            UebenAnsicht(gruppe: a.gruppe, start: a.index)
                .environment(fortschritt)
        }
        .sheet(isPresented: $zeigeEinstellungen) { EinstellungenAnsicht().environment(fortschritt) }
    }
}

private struct Kachel: View {
    let zeichen: Zeichen
    let gruppe: Gruppe
    let sterne: Int

    var body: some View {
        VStack(spacing: 6) {
            ZeichenBild(zeichen: zeichen, gruppe: gruppe)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < sterne ? "star.fill" : "star")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(i < sterne ? Farben.stern : .white.opacity(0.45))
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.15)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(zeichen.text), \(sterne) von 3 Sternen"))
        .accessibilityAddTraits(.isButton)
    }
}
