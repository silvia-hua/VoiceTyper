import AVFoundation
import Foundation

struct AudioRecording {
    let url: URL
    let duration: TimeInterval
    let peakPower: Float
}

@MainActor
final class AudioRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private var startedAt: Date?
    private var meteringTimer: Timer?
    private var peakPower: Float = -160

    func requestPermission() async -> Bool {
        await MicrophonePermission.request()
    }

    func startRecording() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceTyperRecordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("recording-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let newRecorder = try AVAudioRecorder(url: url, settings: settings)
        newRecorder.isMeteringEnabled = true
        newRecorder.prepareToRecord()
        guard newRecorder.record() else {
            throw AudioRecorderError.couldNotStart
        }

        recorder = newRecorder
        startedAt = Date()
        peakPower = -160
        meteringTimer?.invalidate()
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePeakPower()
            }
        }
        RunLoop.main.add(meteringTimer!, forMode: .common)
    }

    func stopRecording() throws -> AudioRecording {
        guard let recorder else {
            throw AudioRecorderError.notRecording
        }

        let url = recorder.url
        let duration = startedAt.map { Date().timeIntervalSince($0) } ?? recorder.currentTime
        updatePeakPower()
        recorder.stop()
        meteringTimer?.invalidate()
        meteringTimer = nil
        self.recorder = nil
        startedAt = nil

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioRecorderError.missingFile
        }

        return AudioRecording(url: url, duration: duration, peakPower: peakPower)
    }

    private func updatePeakPower() {
        guard let recorder else { return }
        recorder.updateMeters()
        peakPower = max(peakPower, recorder.peakPower(forChannel: 0))
    }
}

private enum MicrophonePermission {
    static func request() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }
}

enum AudioRecorderError: LocalizedError {
    case couldNotStart
    case notRecording
    case missingFile

    var errorDescription: String? {
        switch self {
        case .couldNotStart: "无法开始录音"
        case .notRecording: "当前没有录音"
        case .missingFile: "录音文件没有生成"
        }
    }
}
