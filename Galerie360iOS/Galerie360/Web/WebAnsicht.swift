import CoreImage.CIFilterBuiltins
import SwiftUI

/// „Im Web teilen" einer Galerie (seit 1.0.21): Einrichtung des Webspace (einmal), Veröffentlichen
/// bzw. Aktualisieren, Link mit QR-Code. Die Web-Galerie ist ein Spiegel der App — bearbeitet wird
/// nur hier.
struct WebAnsicht: View {
    let galerie: GalerieInfo
    @Environment(FotoBibliothek.self) private var bibliothek
    @Environment(Notizen.self) private var notizen
    @Environment(\.dismiss) private var schliessen
    @State private var lauf = WebVeroeffentlichung.gemeinsam
    @State private var adresse = WebVeroeffentlichung.adresse
    @State private var mitOriginal = WebVeroeffentlichung.mitOriginal
    @State private var verbindung: String?
    @State private var verbindungOk = false
    @State private var paket: TeilenPaket?
    @State private var linkTeilen: LinkZiel?
    @State private var entfernenFragen = false
    @State private var meldung: String?
    @State private var link: URL?
    @State private var zuletzt: Date?

    var body: some View {
        NavigationStack {
            Form {
                galerieAbschnitt
                einrichtung
                Section {
                    Toggle("Videos zusätzlich im Original", isOn: $mitOriginal)
                        .onChange(of: mitOriginal) { WebVeroeffentlichung.mitOriginal = mitOriginal }
                } header: { Text("Videoqualität") } footer: {
                    Text("Immer dabei: 4K (H.264, 50 Mbit/s) — spielt in jedem Browser, auch unter Windows und Android. Mit dem Original zusätzlich die volle Auflösung ohne Neukodierung für iPhone, iPad und Mac — schärfer, aber etwa doppelt so viel hochzuladen.")
                }
            }
            .navigationTitle("Im Web teilen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } } }
            .sheet(item: $paket) { p in TeilenBlatt(paket: p) { paket = nil } }
            .sheet(item: $linkTeilen) { z in LinkTeilen(url: z.url) { linkTeilen = nil } }
            .confirmationDialog("Galerie aus dem Web entfernen?", isPresented: $entfernenFragen, titleVisibility: .visible) {
                Button("Vom Webspace löschen", role: .destructive) {
                    Task {
                        do { try await lauf.entfernen(galerieId: galerie.id); auffrischen() } catch { meldung = error.localizedDescription }
                    }
                }
            } message: { Text("Der Link funktioniert danach nicht mehr. In der App und in Fotos bleibt alles.") }
            .alert("Hinweis", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(meldung ?? "") }
            .onAppear(perform: auffrischen)
            .onChange(of: lauf.zustand) { auffrischen() }
        }
    }

    private func auffrischen() {
        link = WebVeroeffentlichung.link(galerie.id)
        zuletzt = WebVeroeffentlichung.zuletzt(galerie.id)
    }

    // MARK: Galerie

    @ViewBuilder
    private var galerieAbschnitt: some View {
        Section {
            if let link {
                VStack(alignment: .leading, spacing: 10) {
                    Text(link.absoluteString).font(.footnote.monospaced()).textSelection(.enabled)
                    if let qr = qrCode(link.absoluteString) {
                        Image(uiImage: qr).interpolation(.none).resizable().frame(width: 150, height: 150)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("QR-Code zum Link")
                    }
                    HStack {
                        Button { UIPasteboard.general.url = link } label: { Label("Kopieren", systemImage: "doc.on.doc") }
                        Spacer()
                        Button { linkTeilen = LinkZiel(url: link) } label: {
                            Label("Teilen", systemImage: "square.and.arrow.up")
                        }
                    }
                    .buttonStyle(.borderless)
                    if let zuletzt { Text("Zuletzt aktualisiert: " + zuletzt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
                }
            }
            switch lauf.zustand {
            case .laeuft:
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: lauf.fortschritt)
                    Text(lauf.schritt).font(.subheadline)
                    Text("Bitte die App geöffnet lassen, bis es fertig ist.").font(.caption).foregroundStyle(.secondary)
                    Button("Abbrechen", role: .destructive) { lauf.abbrechen() }.buttonStyle(.borderless)
                }
            default:
                Button {
                    lauf.starten(galerie: galerie, bibliothek: bibliothek, notizen: notizen)
                } label: {
                    Label(link == nil ? "Im Web veröffentlichen" : "Aktualisieren", systemImage: link == nil ? "globe" : "arrow.triangle.2.circlepath")
                        .font(.headline)
                }
                .disabled(WebEmpfang.basis(aus: adresse) == nil)
            }
            if case .fehler(let t) = lauf.zustand { Label(t, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.footnote) }
            if case .fertig = lauf.zustand { Label("Die Web-Galerie ist auf dem neuesten Stand.", systemImage: "checkmark.circle").foregroundStyle(.green).font(.footnote) }
            ForEach(lauf.hinweise, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
            if link != nil, lauf.zustand != .laeuft {
                Button("Aus dem Web entfernen …", role: .destructive) { entfernenFragen = true }
            }
        } header: {
            Text(galerie.titel)
        } footer: {
            Text("Wer den langen Link hat, kann die Galerie im Browser ansehen — auf jedem Gerät, ohne App und ohne Konto. Suchmaschinen finden sie nicht; herunterladen kann man nichts. Beim Aktualisieren wird nur hochgeladen, was neu oder geändert ist.")
        }
    }

    // MARK: Einrichtung

    private var einrichtung: some View {
        Section {
            TextField("https://…/360Grad/", text: $adresse)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: adresse) { WebVeroeffentlichung.adresse = adresse; verbindung = nil }
            Button { empfangsdatei() } label: { Label("Empfangsdatei sichern …", systemImage: "doc.badge.arrow.up") }
            Button { pruefen() } label: { Label("Verbindung prüfen", systemImage: "network") }
            if let verbindung {
                Label(verbindung, systemImage: verbindungOk ? "checkmark.circle" : "exclamationmark.triangle")
                    .foregroundStyle(verbindungOk ? .green : .red).font(.footnote)
            }
        } header: {
            Text("Webspace (einmal einrichten)")
        } footer: {
            Text("1. „Empfangsdatei sichern …" und die Datei galerie360-empfang.php in „Dateien" ablegen.\n2. Sie im Strato-Kundenbereich (Dateimanager) oder mit einem FTP-Programm in genau den Ordner oben hochladen (Vorgabe: apps/galerie360/360Grad).\n3. „Verbindung prüfen".\nDie Datei enthält nur eine Prüfsumme deines geheimen Schlüssels; der Schlüssel selbst bleibt auf diesem Gerät.")
        }
    }

    private func empfangsdatei() {
        guard let text = WebEmpfang.empfangsdatei(schluessel: WebSchluessel.holenOderAnlegen()) else {
            meldung = "Die Vorlage fehlt in der App."
            return
        }
        do {
            let ordner = FileManager.default.temporaryDirectory.appendingPathComponent("Empfang-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
            let datei = ordner.appendingPathComponent(WebEmpfang.dateiname)
            try Data(text.utf8).write(to: datei)
            paket = TeilenPaket(ordner: ordner, dateien: [datei])
        } catch {
            meldung = error.localizedDescription
        }
    }

    private func pruefen() {
        guard let basis = WebEmpfang.basis(aus: adresse) else {
            verbindung = WebFehler.adresse.localizedDescription
            verbindungOk = false
            return
        }
        verbindung = "Wird geprüft …"
        verbindungOk = false
        Task {
            do {
                _ = try await WebEmpfang(basis: basis, schluessel: WebSchluessel.holenOderAnlegen()).pruefen()
                verbindung = "Verbindung steht — die App darf hochladen."
                verbindungOk = true
            } catch {
                verbindung = error.localizedDescription
            }
        }
    }

    private func qrCode(_ text: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "M"
        guard let bild = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cg = CIContext().createCGImage(bild, from: bild.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

private struct LinkZiel: Identifiable {
    let id = UUID()
    let url: URL
}

/// Teilen-Fenster für einen Link (ohne Dateien zum Aufräumen).
private struct LinkTeilen: UIViewControllerRepresentable {
    let url: URL
    var fertig: () -> Void
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let v = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        v.completionWithItemsHandler = { _, _, _, _ in fertig() }
        return v
    }
    func updateUIViewController(_ v: UIActivityViewController, context: Context) {}
}
