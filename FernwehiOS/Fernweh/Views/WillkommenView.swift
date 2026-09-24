import SwiftUI
import MapKit
import Photos

/// Der erste Eindruck: ein Flug über echte Landschaft in 3D, darüber der
/// Name, Buchstabe für Buchstabe. Danach drei Karten, was die App kann, und
/// zum Schluss die zwei Erlaubnisse — erklärt, nicht erzwungen.
///
/// Keine Erlaubnis ist Bedingung zum Weiterkommen (die Lehre aus Schulalarm:
/// Apple lehnt eine App ab, die ohne Zustimmung eine Sackgasse ist). Ohne
/// Ortung gibt es keine Spur, ohne Mediathek keine Fotovorschläge — der Rest
/// geht.
struct WillkommenView: View {
    var fertig: () -> Void

    enum Schritt { case titel, erklaerung, erlaubnis }
    @State private var schritt: Schritt = .titel

    var body: some View {
        ZStack {
            Flugkulisse()
                .ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.55), .clear, .black.opacity(0.25), .black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            switch schritt {
            case .titel:
                TitelBuehne { withAnimation(.spring(duration: 0.7)) { schritt = .erklaerung } }
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .top).combined(with: .opacity)))
            case .erklaerung:
                Erklaerung { withAnimation(.spring(duration: 0.7)) { schritt = .erlaubnis } }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .erlaubnis:
                Erlaubnisse(fertig: fertig)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Der Flug

/// Eine Kamera, die um berühmte Landschaften kreist und zwischen ihnen
/// schneidet — wie der Vorspann eines Reisefilms.
private struct Flugkulisse: View {
    struct Ziel {
        let name: String
        let land: String
        let breite: Double
        let laenge: Double
        let entfernung: Double
        let neigung: Double
    }

    static let ziele: [Ziel] = [
        Ziel(name: "Matterhorn", land: "Schweiz", breite: 45.9763, laenge: 7.6586, entfernung: 5200, neigung: 72),
        Ziel(name: "Santorini", land: "Griechenland", breite: 36.4618, laenge: 25.3753, entfernung: 3200, neigung: 65),
        Ziel(name: "Drei Zinnen", land: "Italien", breite: 46.6186, laenge: 12.3025, entfernung: 3600, neigung: 74),
        Ziel(name: "Reine, Lofoten", land: "Norwegen", breite: 67.9326, laenge: 13.0893, entfernung: 4200, neigung: 70),
        Ziel(name: "Grand Canyon", land: "USA", breite: 36.0999, laenge: -112.1127, entfernung: 6500, neigung: 70),
        Ziel(name: "Sydney", land: "Australien", breite: -33.8568, laenge: 151.2153, entfernung: 2400, neigung: 68),
    ]

    @State private var nummer = 0
    @State private var richtung: Double = 20
    @State private var kamera: MapCameraPosition = .camera(Flugkulisse.kamera(Flugkulisse.ziele[0], richtung: 20))
    @State private var vorhang = 1.0

    static func kamera(_ ziel: Ziel, richtung: Double) -> MapCamera {
        MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: ziel.breite, longitude: ziel.laenge),
                  distance: ziel.entfernung, heading: richtung, pitch: ziel.neigung)
    }

    var body: some View {
        let ziel = Self.ziele[nummer]
        ZStack(alignment: .bottomLeading) {
            Map(position: $kamera, interactionModes: [])
                .mapStyle(.imagery(elevation: .realistic))
                .allowsHitTesting(false)
            Color.black.opacity(vorhang).allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 2) {
                Text(ziel.name.uppercased())
                    .font(.caption.weight(.heavy))
                    .tracking(2.5)
                Text(ziel.land)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
            .padding(.leading, 20)
            .padding(.bottom, 10)
            .id(nummer)
            .transition(.opacity)
            .allowsHitTesting(false)
        }
        .task { await fliegen() }
    }

    private func fliegen() async {
        withAnimation(.easeOut(duration: 1.6)) { vorhang = 0 }
        var runde = 0
        while !Task.isCancelled {
            // Zweimal kreisen …
            richtung += 55
            withAnimation(.linear(duration: 8)) {
                kamera = .camera(Self.kamera(Self.ziele[nummer], richtung: richtung))
            }
            try? await Task.sleep(nanoseconds: 7_800_000_000)
            runde += 1
            guard runde % 2 == 0 else { continue }
            // … dann ein Schnitt zum nächsten Ziel.
            withAnimation(.easeIn(duration: 0.7)) { vorhang = 1 }
            try? await Task.sleep(nanoseconds: 750_000_000)
            nummer = (nummer + 1) % Self.ziele.count
            richtung = Double.random(in: 0..<360)
            kamera = .camera(Self.kamera(Self.ziele[nummer], richtung: richtung))
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeOut(duration: 1.2)) { vorhang = 0 }
        }
    }
}

// MARK: - Der Titel

private struct TitelBuehne: View {
    var weiter: () -> Void
    @State private var sichtbar = false
    @State private var schwebt = false

    private let wort = Array("Fernweh")

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 0) {
                ForEach(Array(wort.enumerated()), id: \.offset) { nummer, zeichen in
                    Text(String(zeichen))
                        .font(.system(size: 66, weight: .heavy, design: .rounded))
                        .offset(y: sichtbar ? 0 : 36)
                        .opacity(sichtbar ? 1 : 0)
                        .blur(radius: sichtbar ? 0 : 10)
                        .animation(.spring(response: 0.8, dampingFraction: 0.65).delay(0.25 + 0.09 * Double(nummer)), value: sichtbar)
                }
            }
            .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFFD7A8)], startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.45), radius: 18, y: 6)

            Text("Deine Reisen. Eure Geschichten.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 6)
                .opacity(sichtbar ? 1 : 0)
                .offset(y: sichtbar ? 0 : 12)
                .animation(.easeOut(duration: 0.9).delay(1.1), value: sichtbar)

            Spacer()

            HStack(spacing: -14) {
                Polaroid(symbol: "map.fill", farben: Palette.meer.farben, drehung: -9)
                    .offset(y: schwebt ? -6 : 6)
                Polaroid(symbol: "camera.fill", farben: Palette.sonne.farben, drehung: 4)
                    .offset(y: schwebt ? 5 : -5)
                    .zIndex(1)
                Polaroid(symbol: "person.2.fill", farben: Palette.abend.farben, drehung: 11)
                    .offset(y: schwebt ? -4 : 7)
            }
            .opacity(sichtbar ? 1 : 0)
            .scaleEffect(sichtbar ? 1 : 0.7)
            .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(1.4), value: sichtbar)
            .padding(.bottom, 34)

            Button("Reise beginnen", action: weiter)
                .buttonStyle(VerlaufKnopf())
                .padding(.horizontal, 32)
                .opacity(sichtbar ? 1 : 0)
                .animation(.easeOut(duration: 0.7).delay(1.9), value: sichtbar)
                .padding(.bottom, 54)
        }
        .onAppear {
            sichtbar = true
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { schwebt = true }
        }
    }
}

private struct Polaroid: View {
    let symbol: String
    let farben: [Color]
    let drehung: Double

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: farben, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .frame(width: 78, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            Color.clear.frame(height: 18)
        }
        .padding(6)
        .background(.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
        .rotationEffect(.degrees(drehung))
    }
}

// MARK: - Was die App kann

private struct Erklaerung: View {
    var weiter: () -> Void
    @State private var seite = 0

    private struct Karte: Identifiable {
        let id: Int
        let symbol: String
        let titel: String
        let text: String
        let palette: Palette
    }

    private let karten = [
        Karte(id: 0, symbol: "point.topleft.down.to.point.bottomright.curvepath.fill",
              titel: "Deine Spur, ganz von selbst",
              text: "Solange eine Reise läuft, zeichnet Fernweh auf, wo du warst — auch mit dem iPhone in der Tasche. Am Abend weiß die App, welche Orte dein Tag hatte.",
              palette: .meer),
        Karte(id: 1, symbol: "photo.stack.fill",
              titel: "Die Fotos des Tages",
              text: "Beim Schreiben liegen die Fotos des Tages schon bereit. Bearbeitest du eins später in der Fotos-App, zeigt das Tagebuch die neue Fassung.",
              palette: .sonne),
        Karte(id: 2, symbol: "person.2.wave.2.fill",
              titel: "Gemeinsam schreiben",
              text: "Lade Miturlauber ein, die mitschreiben — und Familie oder Freunde, die eure Reise nur verfolgen. Alles bleibt in eurer iCloud.",
              palette: .abend),
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            TabView(selection: $seite) {
                ForEach(karten) { karte in
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: karte.symbol)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 68, height: 68)
                            .background(karte.palette.verlauf, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: karte.palette.haupt.opacity(0.5), radius: 12, y: 6)
                        Text(karte.titel)
                            .font(Stil.titel(26))
                        Text(karte.text)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(.horizontal, 24)
                    .tag(karte.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 380)

            Button(seite < karten.count - 1 ? "Weiter" : "Fast geschafft") {
                if seite < karten.count - 1 { withAnimation { seite += 1 } } else { weiter() }
            }
            .buttonStyle(VerlaufKnopf(palette: karten[seite].palette))
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Erlaubnisse

private struct Erlaubnisse: View {
    var fertig: () -> Void
    @EnvironmentObject private var aufzeichner: Aufzeichner
    @EnvironmentObject private var fotodienst: Fotodienst
    @State private var name = Geraet.name

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack(alignment: .leading, spacing: 18) {
                Text("Noch drei Dinge")
                    .font(Stil.titel(28))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wie sollen dich deine Miturlauber sehen?")
                        .font(.subheadline.weight(.semibold))
                    TextField("Dein Vorname", text: $name)
                        .textContentType(.givenName)
                        .padding(12)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Zeile(symbol: "location.fill", farbe: Palette.meer.haupt,
                      titel: "Ortung für die Reisespur",
                      text: ortText,
                      erledigt: aufzeichner.hatImmer,
                      knopf: aufzeichner.erlaubnis == .authorizedWhenInUse ? "Auf „Immer“" : "Erlauben") {
                    aufzeichner.erlaubnisAnfragen()
                }
                Zeile(symbol: "photo.on.rectangle.angled", farbe: Palette.sonne.haupt,
                      titel: "Fotos des Tages",
                      text: "Damit dir beim Schreiben die Fotos des Tages angeboten werden.",
                      erledigt: fotodienst.darfLesen,
                      knopf: "Erlauben") {
                    Task { await fotodienst.erlaubnisAnfragen() }
                }
                Text("Beides lässt sich jederzeit in den Einstellungen ändern. Ohne Erlaubnis geht alles andere trotzdem.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 20)

            Button("Los geht’s") {
                Geraet.name = name
                fertig()
            }
            .buttonStyle(VerlaufKnopf())
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .foregroundStyle(.white)
    }

    private var ortText: String {
        switch aufzeichner.erlaubnis {
        case .authorizedAlways: return "Die Spur läuft auch im Hintergrund weiter."
        case .authorizedWhenInUse: return "Für eine lückenlose Spur braucht die App „Immer“ — sonst nur, solange sie offen ist."
        case .denied, .restricted: return "Abgelehnt. In den iOS-Einstellungen unter Fernweh → Standort änderbar."
        default: return "Für den Ort jedes Eintrags und die Spur des Tages."
        }
    }

    private struct Zeile: View {
        let symbol: String
        let farbe: Color
        let titel: String
        let text: String
        let erledigt: Bool
        let knopf: String
        let aktion: () -> Void

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(farbe.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(titel).font(.subheadline.weight(.semibold))
                    Text(text).font(.caption).foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if erledigt {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Button(knopf, action: aktion)
                        .font(.caption.weight(.bold))
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                }
            }
            .animation(.spring(duration: 0.4), value: erledigt)
        }
    }
}
