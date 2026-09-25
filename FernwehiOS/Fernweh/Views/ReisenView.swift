import SwiftUI
import CoreData

/// Die Startseite: alle Reisen als große Karten — die laufende zuerst.
struct ReisenView: View {
    @FetchRequest(fetchRequest: Reise.alle(), animation: .spring(duration: 0.5))
    private var reisen: FetchedResults<Reise>

    @EnvironmentObject private var aufzeichner: Aufzeichner
    @State private var neueReise = false
    @State private var einstellungen = false
    @State private var pfad = NavigationPath()

    private var sortiert: [Reise] {
        reisen.sorted { a, b in
            if a.laeuft != b.laeuft { return a.laeuft }
            if a.liegtInZukunft != b.liegtInZukunft { return a.liegtInZukunft }
            return a.anfang > b.anfang
        }
    }

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                LazyVStack(spacing: 22) {
                    Kopf(anzahl: reisen.count)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    if reisen.isEmpty {
                        LeereReisen { neueReise = true }
                            .padding(.horizontal, 20)
                    } else {
                        ForEach(sortiert) { reise in
                            NavigationLink(value: reise.objectID) {
                                ReiseKarte(reise: reise)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Hintergrund())
            .navigationDestination(for: NSManagedObjectID.self) { kennung in
                if let reise = try? Persistenz.shared.kontext.existingObject(with: kennung) as? Reise {
                    ReiseView(reise: reise)
                } else {
                    ContentUnavailableView("Reise nicht gefunden", systemImage: "suitcase")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { einstellungen = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Einstellungen")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { neueReise = true } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Palette.sonne.verlauf, in: Circle())
                    }
                    .accessibilityLabel("Neue Reise")
                }
            }
            .sheet(isPresented: $neueReise) {
                ReiseFormular(reise: nil) { neu in
                    if let neu { pfad.append(neu.objectID) }
                }
            }
            .sheet(isPresented: $einstellungen) { EinstellungenView() }
            .refreshable { aufzeichner.uebertragen() }
        }
    }

    private struct Kopf: View {
        let anzahl: Int
        var body: some View {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(gruss)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Deine Reisen")
                        .font(Stil.titel(34))
                }
                Spacer()
            }
        }

        private var gruss: String {
            let name = Geraet.name
            let stunde = Calendar.current.component(.hour, from: Date())
            let tageszeit = stunde < 11 ? "Guten Morgen" : (stunde < 18 ? "Hallo" : "Guten Abend")
            return name.isEmpty ? tageszeit : "\(tageszeit), \(name)"
        }
    }

    private struct Hintergrund: View {
        var body: some View {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                RadialGradient(colors: [Palette.sonne.hell.opacity(0.22), .clear], center: .topTrailing, startRadius: 10, endRadius: 420)
                RadialGradient(colors: [Palette.meer.hell.opacity(0.16), .clear], center: .bottomLeading, startRadius: 10, endRadius: 480)
            }
            .ignoresSafeArea()
        }
    }
}

/// Noch keine Reise — der Weg zur ersten.
private struct LeereReisen: View {
    var anlegen: () -> Void
    @State private var dreht = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Palette.meer.verlauf).frame(width: 130, height: 130)
                    .shadow(color: Palette.meer.haupt.opacity(0.4), radius: 20, y: 10)
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(.white.opacity(0.95))
                    .rotationEffect(.degrees(dreht ? 8 : -8))
                Image(systemName: "airplane")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: dreht ? 58 : -58, y: dreht ? -52 : -40)
                    .rotationEffect(.degrees(dreht ? 12 : -4))
            }
            .padding(.top, 30)
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { dreht = true }
            }
            Text("Wohin geht’s als Nächstes?")
                .font(Stil.titel(24))
                .multilineTextAlignment(.center)
            Text("Leg deine erste Reise an. Solange sie läuft, sammelt Fernweh deine Spur — und die Fotos des Tages warten schon, wenn du abends schreibst.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Erste Reise anlegen", action: anlegen)
                .buttonStyle(VerlaufKnopf())
                .padding(.top, 6)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

/// Eine Reise als Karte: Titelbild, Farbe, Zahlen.
struct ReiseKarte: View {
    @ObservedObject var reise: Reise

    var body: some View {
        let persistenz = Persistenz.shared
        let geteilt = persistenz.liegtImGeteiltenSpeicher(reise)
        let darf = persistenz.darfBearbeiten(reise)
        ZStack(alignment: .bottomLeading) {
            Titelbild(reise: reise)
                .frame(height: 250)
                .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.15), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if reise.laeuft {
                        HStack(spacing: 6) {
                            Pulspunkt(farbe: .white)
                            Text("Unterwegs · Tag \(Tag.abstand(von: reise.anfang, bis: Date()) + 1)")
                        }
                        .etikett(reise.palette.haupt)
                    } else if reise.liegtInZukunft {
                        Text("In \(Tag.abstand(von: Date(), bis: reise.anfang)) Tagen")
                            .etikett(.black.opacity(0.35))
                    }
                    if geteilt {
                        Label(darf ? "Miturlaub" : "Du schaust zu", systemImage: darf ? "person.2.fill" : "eye.fill")
                            .etikett(.black.opacity(0.35))
                    }
                    Spacer()
                }
                Reisesymbol.mitTitel(reise.emoji, reise.anzeigeTitel)
                    .font(Stil.titel(28))
                    .lineLimit(2)
                    .foregroundStyle(.white)
                HStack(spacing: 14) {
                    Label(Tag.zeitraum(reise.anfang, reise.ende), systemImage: "calendar")
                    if reise.kilometer >= 1 {
                        Label("\(Int(reise.kilometer)) km", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                    if reise.fotoAnzahl > 0 {
                        Label("\(reise.fotoAnzahl)", systemImage: "photo")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .shadow(color: reise.palette.haupt.opacity(0.28), radius: 18, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// Das Bild einer Reise: gewähltes Titelbild, sonst das erste Foto, sonst
/// ein Verlauf mit dem Symbol der Reise.
struct Titelbild: View {
    @ObservedObject var reise: Reise
    @State private var bild: UIImage?

    var body: some View {
        Rectangle()
            .fill(reise.palette.verlauf)
            .overlay {
                if let bild {
                    Image(uiImage: bild).resizable().scaledToFill()
                        .transition(.opacity)
                } else {
                    ReisesymbolBild(wert: reise.emoji)
                        .opacity(0.9)
                        .shadow(radius: 10)
                }
            }
            .clipped()
        .task(id: schluessel) {
            if let daten = reise.titelbild {
                let geladen = await Task.detached { Bildwerk.entpackt(daten, kante: 1200) }.value
                withAnimation { bild = geladen }
            } else if let foto = reise.erstesFoto {
                let geladen = await Bildvorrat.shared.bild(foto, kante: 600)
                withAnimation { bild = geladen }
            } else {
                bild = nil
            }
        }
    }

    private var schluessel: String {
        "\(reise.titelbild?.count ?? 0)|\(reise.erstesFoto?.objectID.uriRepresentation().absoluteString ?? "")|\(reise.erstesFoto?.geaendert?.timeIntervalSince1970 ?? 0)"
    }
}

extension View {
    func etikett(_ farbe: Color) -> some View {
        self
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(farbe, in: Capsule())
    }
}
