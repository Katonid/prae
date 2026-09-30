import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// QR-Code aus einem Link — scharf vergrößert (ohne Weichzeichnen).
enum QRCode {
    static func bild(_ text: String, groesse: CGFloat = 600) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let roh = filter.outputImage else { return nil }
        let faktor = groesse / roh.extent.width
        let gross = roh.transformed(by: CGAffineTransform(scaleX: faktor, y: faktor))
        guard let cg = CIContext().createCGImage(gross, from: gross.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Die Anmeldekarte eines Kindes (Lehrergerät): QR-Code der Freigabe
/// seiner Zone. Das Kind scannt sie einmal auf seinem iPad, angemeldet mit
/// seiner eigenen (verwalteten) Apple-ID.
struct AnmeldekarteAnsicht: View {
    let kind: Kind
    @Environment(Klasse.self) private var klasse
    @State private var freigabe: Wolke.Freigabe?
    @State private var fehler: String?
    @State private var appleID = ""
    @State private var laedt = false

    var body: some View {
        Form {
            Section {
                if let link = freigabe?.link, let bild = QRCode.bild(link.absoluteString) {
                    VStack(spacing: 10) {
                        Text("\(kind.tier) \(kind.name)")
                            .font(.system(.title, design: .rounded, weight: .bold))
                        Image(uiImage: bild)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 240, height: 240)
                        Text("Auf dem iPad des Kindes mit der Kamera scannen.")
                            .font(.footnote).foregroundStyle(.secondary)
                        ShareLink(item: link) { Label("Link teilen", systemImage: "square.and.arrow.up") }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else if laedt {
                    HStack { ProgressView(); Text("Karte wird angelegt …") }
                } else if let fehler {
                    Text(fehler).foregroundStyle(.red)
                    Button("Noch einmal") { Task { await laden() } }
                }
            } footer: {
                if let f = freigabe {
                    Label(f.beigetreten ? "Das Kind hat seine Karte gescannt." : "Noch nicht gescannt.",
                          systemImage: f.beigetreten ? "checkmark.circle.fill" : "clock")
                }
            }

            if freigabe?.nurEingeladen == true {
                Section {
                    TextField("Apple-ID des Kindes", text: $appleID)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Einladen") { Task { await einladen() } }
                        .disabled(!appleID.contains("@") || laedt)
                    ForEach(freigabe?.eingeladen ?? [], id: \.self) { Text($0).foregroundStyle(.secondary) }
                } header: {
                    Text("Einladung mit Apple-ID")
                } footer: {
                    Text("iCloud erlaubt für diese Apple-ID keinen offenen Link. Dann gilt die Karte nur für eingeladene Apple-IDs: Trage die verwaltete Apple-ID des Kindes ein (z. B. vorname.nachname@schule.appleid.com), dann scannt das Kind die Karte wie gewohnt.")
                }
            }

            Section {
                Text("Die Karte gehört nur diesem Kind: Wer sie scannt, schreibt als \(kind.name). Das Kind sieht nur seine eigenen Seiten, nie die der anderen.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Anmeldekarte")
        .task { await laden() }
    }

    private func laden() async {
        guard let wolke = klasse.wolke else {
            fehler = "Dieses Gerät ist kein Lehrergerät."
            return
        }
        laedt = true
        fehler = nil
        do {
            freigabe = try await wolke.freigabe(fuer: kind)
            if freigabe?.link == nil { fehler = "iCloud hat keinen Link geliefert." }
        } catch {
            fehler = Wolke.klartext(error)
        }
        laedt = false
    }

    private func einladen() async {
        guard let wolke = klasse.wolke else { return }
        laedt = true
        do {
            try await wolke.einladen(kind, appleID: appleID.trimmingCharacters(in: .whitespaces))
            freigabe = wolke.freigaben[kind.id]
            appleID = ""
        } catch {
            fehler = Wolke.klartext(error)
        }
        laedt = false
    }
}

/// Alle Anmeldekarten als PDF zum Ausdrucken (A4, acht Karten je Seite).
struct AnmeldekartenDruck: View {
    @Environment(Klasse.self) private var klasse
    @State private var datei: URL?
    @State private var fortschritt = 0
    @State private var fehler: String?
    @State private var laeuft = false

    var body: some View {
        Group {
            if let datei {
                ShareLink(item: datei) { Label("Anmeldekarten (PDF) teilen oder drucken", systemImage: "printer") }
            } else if laeuft {
                HStack {
                    ProgressView()
                    Text("Karten werden angelegt … \(fortschritt) von \(klasse.kinder.count)")
                }
            } else {
                Button {
                    Task { await erstellen() }
                } label: {
                    Label("Anmeldekarten aller Kinder als PDF", systemImage: "qrcode")
                }
                .disabled(klasse.kinder.isEmpty || klasse.wolke == nil)
            }
            if let fehler { Text(fehler).font(.footnote).foregroundStyle(.red) }
        }
    }

    private func erstellen() async {
        guard let wolke = klasse.wolke else { return }
        laeuft = true
        fehler = nil
        fortschritt = 0
        var karten: [(Kind, URL)] = []
        for kind in klasse.kinder {
            do {
                if let link = try await wolke.freigabe(fuer: kind).link { karten.append((kind, link)) }
            } catch {
                fehler = "\(kind.name): \(Wolke.klartext(error))"
            }
            fortschritt += 1
        }
        datei = Self.pdf(karten)
        laeuft = false
    }

    static func pdf(_ karten: [(Kind, URL)]) -> URL? {
        let seite = CGRect(x: 0, y: 0, width: 595, height: 842)   // A4 in Punkten
        let rand: CGFloat = 30, spalten = 2, zeilen = 4
        let breite = (seite.width - 2 * rand) / CGFloat(spalten)
        let hoehe = (seite.height - 2 * rand) / CGFloat(zeilen)
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent("Anmeldekarten.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: seite)
        do {
            try renderer.writePDF(to: ziel) { ctx in
                for (i, (kind, link)) in karten.enumerated() {
                    if i % (spalten * zeilen) == 0 { ctx.beginPage() }
                    let n = i % (spalten * zeilen)
                    let feld = CGRect(x: rand + CGFloat(n % spalten) * breite, y: rand + CGFloat(n / spalten) * hoehe,
                                      width: breite, height: hoehe).insetBy(dx: 8, dy: 8)
                    let rahmen = UIBezierPath(roundedRect: feld, cornerRadius: 14)
                    rahmen.setLineDash([6, 4], count: 2, phase: 0)
                    UIColor.gray.setStroke()
                    rahmen.lineWidth = 1
                    rahmen.stroke()
                    let titel = "\(kind.tier) \(kind.name)" as NSString
                    titel.draw(at: CGPoint(x: feld.minX + 12, y: feld.minY + 10),
                               withAttributes: [.font: UIFont.systemFont(ofSize: 20, weight: .bold)])
                    let qr = min(feld.height - 60, feld.width - 24)
                    QRCode.bild(link.absoluteString, groesse: 400)?
                        .draw(in: CGRect(x: feld.midX - qr / 2, y: feld.minY + 42, width: qr, height: qr))
                    ("Schreibspur · mit der Kamera scannen" as NSString)
                        .draw(at: CGPoint(x: feld.minX + 12, y: feld.maxY - 20),
                              withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.gray])
                }
            }
            return ziel
        } catch {
            return nil
        }
    }
}
