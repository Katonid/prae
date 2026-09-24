import SwiftUI
import MapKit

/// Ein Eintrag zum Lesen: die Fotos groß, darunter Text, Orte und Karte.
struct EintragView: View {
    @ObservedObject var eintrag: Eintrag
    let palette: Palette

    @Environment(\.dismiss) private var schliessen
    @State private var bearbeiten = false
    @State private var loeschenFragen = false
    @State private var vollbild: Int?
    @State private var darf = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                let fotos = eintrag.fotoListe
                if !fotos.isEmpty {
                    TabView {
                        ForEach(Array(fotos.enumerated()), id: \.offset) { nummer, foto in
                            FotoBild(foto: foto, kante: 1400)
                                .onTapGesture { vollbild = nummer }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: fotos.count > 1 ? .always : .never))
                    .frame(height: 420)
                }

                VStack(alignment: .leading, spacing: 10) {
                    if let d = eintrag.datum {
                        Text("\(Tag.wochentagLang.string(from: d)) · \(Tag.uhrzeit.string(from: d))")
                            .font(.caption.weight(.heavy))
                            .textCase(.uppercase)
                            .foregroundStyle(palette.haupt)
                    }
                    Text(eintrag.anzeigeTitel)
                        .font(Stil.titel(30))
                    if let ort = eintrag.ortsname, !ort.isEmpty, ort != eintrag.anzeigeTitel {
                        Label(ort, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let wetter = eintrag.tageswetter {
                        WetterLeiste(wetter: wetter).padding(.top, 4)
                    }
                    if let text = eintrag.text, !text.isEmpty {
                        Text(text)
                            .font(.body)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .padding(.top, 4)
                    }

                    let orte = eintrag.ortListe
                    if !orte.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(orte.enumerated()), id: \.offset) { nummer, o in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(spacing: 0) {
                                        Circle().fill(palette.haupt).frame(width: 10, height: 10).padding(.top, 5)
                                        if nummer < orte.count - 1 {
                                            Rectangle().fill(palette.haupt.opacity(0.3)).frame(width: 2).frame(maxHeight: .infinity)
                                        }
                                    }
                                    .frame(width: 10)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(o.name).font(.subheadline.weight(.semibold))
                                        if let z = o.zeit {
                                            Text(Tag.uhrzeit.string(from: z)).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.bottom, 12)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.top, 8)
                    }

                    if let k = eintrag.koordinate {
                        Map(initialPosition: .camera(MapCamera(centerCoordinate: k, distance: 2500, heading: 0, pitch: 45)),
                            interactionModes: []) {
                            Marker(eintrag.anzeigeTitel, coordinate: k).tint(palette.haupt)
                            ForEach(Array(orte.enumerated()), id: \.offset) { _, o in
                                Marker(o.name, systemImage: "mappin", coordinate: o.koordinate).tint(palette.hell)
                            }
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .allowsHitTesting(false)
                        .padding(.top, 6)
                    }

                    if let autor = eintrag.autor, !autor.isEmpty {
                        HStack(spacing: 8) {
                            Monogramm(name: autor, groesse: 28, farbe: palette.haupt)
                            Text("Geschrieben von \(autor)").font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 18)
            }
            .padding(.bottom, 30)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if darf {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { bearbeiten = true } label: { Label("Bearbeiten", systemImage: "pencil") }
                        Button(role: .destructive) { loeschenFragen = true } label: { Label("Löschen", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .sheet(isPresented: $bearbeiten) {
            if let reise = eintrag.reise {
                EintragEditor(reise: reise, eintrag: eintrag, tag: eintrag.datum)
            }
        }
        .fullScreenCover(item: Binding(get: { vollbild.map { Nummer(wert: $0) } }, set: { vollbild = $0?.wert })) { n in
            Bildbetrachter(fotos: eintrag.fotoListe, start: n.wert)
        }
        .confirmationDialog("Eintrag löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                let persistenz = Persistenz.shared
                persistenz.kontext.delete(eintrag)
                persistenz.sichern()
                schliessen()
            }
        } message: {
            Text("Der Eintrag und seine Fotos verschwinden aus der Reise — in deiner Fotos-App bleiben die Bilder.")
        }
        .task { darf = Persistenz.shared.darfBearbeiten(eintrag) }
    }

    private struct Nummer: Identifiable {
        let wert: Int
        var id: Int { wert }
    }
}

/// Fotos im Vollbild, zum Durchwischen.
struct Bildbetrachter: View {
    let fotos: [Foto]
    let start: Int
    @Environment(\.dismiss) private var schliessen
    @State private var seite = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $seite) {
                ForEach(Array(fotos.enumerated()), id: \.offset) { nummer, foto in
                    FotoBild(foto: foto, kante: 2048, fuellen: false)
                        .background(Color.black)
                        .tag(nummer)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            Button { schliessen() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
        }
        .onAppear { seite = start }
        .preferredColorScheme(.dark)
    }
}
