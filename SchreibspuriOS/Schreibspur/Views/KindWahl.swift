import SwiftUI

/// „Wer schreibt heute?" — große Tierkarten, damit auch Kinder, die noch
/// nicht lesen, sich selbst finden.
struct KindWahl: View {
    @Environment(Klasse.self) private var klasse
    @State private var zeigeEinstellungen = false

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Wer schreibt?")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(Farben.tinteDunkel)
                Spacer()
                Knopf(symbol: "gearshape.fill", name: "Einstellungen für Erwachsene") { zeigeEinstellungen = true }
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                    ForEach(klasse.kinder) { kind in
                        Button {
                            withAnimation(.snappy) { klasse.aktivID = kind.id }
                        } label: {
                            VStack(spacing: 6) {
                                Text(kind.tier).font(.system(size: 72))
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 3)
                                Text(kind.name)
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(Farben.tinteDunkel)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(RoundedRectangle(cornerRadius: 24).fill(.white)
                                .shadow(color: .black.opacity(0.1), radius: 8, y: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(Farben.verlauf.ignoresSafeArea())
        .sheet(isPresented: $zeigeEinstellungen) {
            ErwachsenenTor { EinstellungenAnsicht() }
                .environment(klasse)
        }
    }
}
