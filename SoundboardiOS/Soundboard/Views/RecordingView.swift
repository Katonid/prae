import AVFoundation
import SwiftUI

/// Nimmt über das Mikrofon eine Tondatei auf, die einem Feld zugewiesen wird.
struct RecordingView: View {
    var onAccept: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = VoiceRecorder()

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                if recorder.permissionDenied {
                    Label("Kein Zugriff auf das Mikrofon. Bitte in den iOS-Einstellungen unter „Soundboard“ das Mikrofon erlauben.",
                          systemImage: "mic.slash")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Text(formatTime(recorder.elapsed))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(recorder.isRecording ? .red : .primary)

                if recorder.isRecording {
                    Button {
                        recorder.finishRecording()
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(.red, lineWidth: 4)
                                .frame(width: 88, height: 88)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.red)
                                .frame(width: 34, height: 34)
                        }
                    }
                    Text("Aufnahme läuft – zum Beenden tippen")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if recorder.hasRecording {
                    HStack(spacing: 20) {
                        Button {
                            recorder.togglePreview()
                        } label: {
                            Label(recorder.isPlaying ? "Stopp" : "Vorhören",
                                  systemImage: recorder.isPlaying ? "stop.fill" : "play.fill")
                                .frame(minWidth: 120)
                                .padding(.vertical, 12)
                                .background(.quaternary, in: Capsule())
                        }
                        Button {
                            recorder.discardAndReset()
                        } label: {
                            Label("Neu aufnehmen", systemImage: "arrow.counterclockwise")
                                .frame(minWidth: 120)
                                .padding(.vertical, 12)
                                .background(.quaternary, in: Capsule())
                        }
                    }

                    Button {
                        recorder.stopPreview()
                        onAccept(recorder.fileURL)
                        dismiss()
                    } label: {
                        Label("Aufnahme übernehmen", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: 320)
                            .padding(.vertical, 14)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundStyle(.black)
                    }
                } else {
                    Button {
                        Task { await recorder.startRecording() }
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(.red, lineWidth: 4)
                                .frame(width: 88, height: 88)
                            Circle()
                                .fill(.red)
                                .frame(width: 68, height: 68)
                        }
                    }
                    .disabled(recorder.permissionDenied)
                    Text("Zum Starten der Aufnahme tippen")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Spacer()
            }
            .navigationTitle("Mikrofonaufnahme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        recorder.cleanup()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                recorder.cleanup()
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Kapselt AVAudioRecorder/-Player für die Mikrofonaufnahme.
@MainActor
final class VoiceRecorder: NSObject, ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var hasRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var permissionDenied = false

    let fileURL: URL

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var timer: Timer?

    override init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let name = "Aufnahme \(formatter.string(from: Date())).m4a"
        fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        super.init()
    }

    func startRecording() async {
        guard await AVAudioApplication.requestRecordPermission() else {
            permissionDenied = true
            return
        }
        permissionDenied = false

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
        try? session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            try? FileManager.default.removeItem(at: fileURL)
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.record()
            self.recorder = recorder
            isRecording = true
            hasRecording = false
            elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let current = self.recorder?.currentTime { self.elapsed = current }
                }
            }
        } catch {
            isRecording = false
        }
    }

    func finishRecording() {
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        hasRecording = FileManager.default.fileExists(atPath: fileURL.path)
        restorePlaybackSession()
    }

    func togglePreview() {
        if isPlaying {
            stopPreview()
            return
        }
        guard let player = try? AVAudioPlayer(contentsOf: fileURL) else { return }
        player.delegate = self
        player.play()
        self.player = player
        isPlaying = true
    }

    func stopPreview() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    func discardAndReset() {
        stopPreview()
        try? FileManager.default.removeItem(at: fileURL)
        hasRecording = false
        elapsed = 0
    }

    func cleanup() {
        if isRecording { finishRecording() }
        stopPreview()
        restorePlaybackSession()
    }

    private func restorePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}

extension VoiceRecorder: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.isPlaying = false
        }
    }
}
