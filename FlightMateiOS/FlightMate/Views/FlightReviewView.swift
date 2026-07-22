//
//  FlightReviewView.swift
//  FlightMate
//
//  Flight Review (PRD F5): Nach dem Flug wählt der Nutzer bis zu
//  5 Aufnahmen aus (PhotosPicker — kein Vollzugriff auf die
//  Mediathek, PRD Kap. 11). Die KI bewertet jede entlang der festen
//  Rubrik: max. 2 Stärken, GENAU EIN Verbesserungsvorschlag —
//  Kritik, die man umsetzen kann, statt einer Analyse, die man
//  wegklickt.
//

import SwiftUI
import PhotosUI

struct FlightReviewView: View {
    @ObservedObject private var claude = ClaudeService.shared
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var images: [Data] = []          // verkleinerte JPEGs
    @State private var thumbnails: [UIImage] = []
    @State private var critiques: [ImageCritique] = []
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if !claude.hasKey {
                    ContentUnavailableView {
                        Label("Flight Review", systemImage: "sparkles")
                    } description: {
                        Text("Die KI-Bildkritik braucht deinen Anthropic-API-Schlüssel. Er wird sicher in der Keychain gespeichert und verlässt dein Gerät nur Richtung Claude-API.")
                    } actions: {
                        Button("Schlüssel hinterlegen") { showSettings = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    reviewContent
                }
            }
            .navigationTitle("Review")
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    // MARK: Inhalt

    private var reviewContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images) {
                    Label(images.isEmpty ? "Aufnahmen auswählen (max. 5)" : "Andere Aufnahmen wählen",
                          systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .onChange(of: pickerItems) {
                    Task { await loadSelection() }
                }

                if !thumbnails.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(thumbnails.enumerated()), id: \.offset) { index, thumbnail in
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 96, height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(alignment: .bottomLeading) {
                                        Text("\(index)")
                                            .font(.caption2.bold())
                                            .padding(4)
                                            .background(.thinMaterial, in: Circle())
                                            .padding(4)
                                    }
                            }
                        }
                    }

                    Button {
                        Task { await analyze() }
                    } label: {
                        if isAnalyzing {
                            HStack {
                                ProgressView()
                                Text("Claude schaut sich deine Bilder an …")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        } else {
                            Label("Bildkritik starten", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAnalyzing)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                ForEach(critiques) { critique in
                    critiqueCard(critique)
                }

                if images.isEmpty && critiques.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Wähle nach dem Flug deine besten Aufnahmen aus. Du bekommst zu jeder maximal zwei Stärken und genau einen Verbesserungsvorschlag — den mit dem größten Hebel.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                }

                Text("Ausgewählte Bilder werden verkleinert zur Analyse an die Claude-API übertragen, dort nicht gespeichert und nicht für Training verwendet.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding()
        }
    }

    private func critiqueCard(_ critique: ImageCritique) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if critique.bildIndex < thumbnails.count {
                    Image(uiImage: thumbnails[critique.bildIndex])
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text("Bild \(critique.bildIndex)")
                    .font(.headline)
                Spacer()
            }
            ForEach(critique.staerken.prefix(2), id: \.self) { staerke in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(staerke)
                        .font(.subheadline)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.orange)
                Text(critique.verbesserung)
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Aktionen

    private func loadSelection() async {
        critiques = []
        errorMessage = nil
        var loadedImages: [Data] = []
        var loadedThumbnails: [UIImage] = []
        for item in pickerItems {
            guard let raw = try? await item.loadTransferable(type: Data.self),
                  let prepared = ClaudeService.prepareImage(raw),
                  let thumbnail = UIImage(data: prepared) else { continue }
            loadedImages.append(prepared)
            loadedThumbnails.append(thumbnail)
        }
        images = loadedImages
        thumbnails = loadedThumbnails
    }

    private func analyze() async {
        guard !images.isEmpty else { return }
        isAnalyzing = true
        errorMessage = nil
        critiques = []
        defer { isAnalyzing = false }
        do {
            critiques = try await ClaudeService.shared.critiques(for: images)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
