import AppKit
import AVFoundation
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            settingsStore.save(settings)
            registerHotkey()
        }
    }

    @Published private(set) var status: VoiceInputStatus = .idle
    @Published private(set) var hotkeyError: String?
    @Published private(set) var accessibilityTrusted = false

    var isRecording: Bool {
        if case .recording = status { return true }
        return false
    }

    var menuBarSystemImage: String {
        switch status {
        case .recording:
            "mic.fill"
        case .transcribing, .inserting:
            "waveform"
        case .failure:
            "exclamationmark.triangle"
        default:
            "mic"
        }
    }

    private let settingsStore = AppSettingsStore()
    private let recorder = AudioRecorder()
    private let transcriber = WhisperTranscriber()
    private let inserter = TextInserter()
    private let hotkeyManager = HotkeyManager()
    private var settingsWindowController: SettingsWindowController?
    private var permissionRefreshTimer: Timer?
    private var isStopping = false

    init() {
        settings = settingsStore.load()
        hotkeyManager.onPressed = { [weak self] in
            Task { @MainActor in
                self?.hotkeyPressed()
            }
        }
        hotkeyManager.onReleased = { [weak self] in
            Task { @MainActor in
                self?.hotkeyReleased()
            }
        }
        registerHotkey()
        refreshPermissionStatus()
        permissionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissionStatus()
            }
        }
    }

    func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(appState: self)
        }
        settingsWindowController?.show()
    }

    func requestRequiredPermissions() {
        Task {
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                _ = await recorder.requestPermission()
            }
            refreshPermissionStatus()
            if !accessibilityTrusted {
                _ = inserter.requestAccessibilityTrust()
                refreshPermissionStatus()
            }
            openSettings()
        }
    }

    func requestMicrophonePermission() {
        Task {
            _ = await recorder.requestPermission()
            openSettings()
        }
    }

    func requestAccessibilityPermission() {
        refreshPermissionStatus()
        guard !accessibilityTrusted else {
            openSettings()
            return
        }
        _ = inserter.requestAccessibilityTrust()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            refreshPermissionStatus()
            openSettings()
        }
    }

    func toggleRecordingFromMenu() {
        if isRecording {
            stopAndProcessRecording()
        } else {
            startRecording()
        }
    }

    func updateHotkey(_ hotkey: Hotkey) {
        settings.hotkey = hotkey
    }

    func microphonePermissionText() -> String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: "已允许"
        case .denied: "已拒绝"
        case .restricted: "受限"
        case .notDetermined: "尚未请求"
        @unknown default: "未知"
        }
    }

    func accessibilityPermissionText() -> String {
        accessibilityTrusted ? "已允许" : "未开启"
    }

    func refreshPermissionStatus() {
        accessibilityTrusted = inserter.isAccessibilityTrusted
    }

    func revealWhisperResources() {
        guard let url = transcriber.resourceDirectory else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy"
        ]
        for value in urls {
            guard let url = URL(string: value) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
    }

    private func registerHotkey() {
        do {
            try hotkeyManager.register(hotkey: settings.hotkey)
            hotkeyError = nil
        } catch {
            hotkeyError = "快捷键注册失败：\(error.localizedDescription)"
        }
    }

    private func hotkeyPressed() {
        switch settings.recordingMode {
        case .holdToTalk:
            if !isRecording {
                startRecording()
            }
        case .toggle:
            if isRecording {
                stopAndProcessRecording()
            } else {
                startRecording()
            }
        }
    }

    private func hotkeyReleased() {
        guard settings.recordingMode == .holdToTalk, isRecording else { return }
        stopAndProcessRecording()
    }

    private func startRecording() {
        guard !isRecording else { return }
        Task {
            do {
                let granted = await recorder.requestPermission()
                guard granted else {
                    status = .failure("请在系统设置中允许麦克风权限")
                    return
                }
                try recorder.startRecording()
                status = .recording(startedAt: Date())
            } catch {
                status = .failure(error.localizedDescription)
            }
        }
    }

    private func stopAndProcessRecording() {
        guard isRecording, !isStopping else { return }
        isStopping = true

        Task {
            do {
                let recording = try recorder.stopRecording()
                guard recording.duration >= 0.35 else {
                    status = .failure("录音太短，请稍微多说一点")
                    isStopping = false
                    return
                }
                guard recording.peakPower > -55 else {
                    try? FileManager.default.removeItem(at: recording.url)
                    status = .failure("没有检测到清晰声音，请检查麦克风输入")
                    isStopping = false
                    return
                }
                defer {
                    try? FileManager.default.removeItem(at: recording.url)
                }

                status = .transcribing
                let rawText = try await transcriber.transcribe(audioURL: recording.url, language: settings.language)
                var text = TranscriptionPostProcessor.process(rawText, settings: settings)
                if settings.language == "auto", TranscriptionPostProcessor.isLikelySilenceHallucination(text) {
                    let retryText = try await transcriber.transcribe(audioURL: recording.url, language: "zh")
                    text = TranscriptionPostProcessor.process(retryText, settings: settings)
                }

                guard !text.isEmpty, !TranscriptionPostProcessor.isLikelySilenceHallucination(text) else {
                    status = .failure("没有检测到有效语音")
                    isStopping = false
                    return
                }

                status = .inserting
                try await inserter.insert(text: text, fallbackToPaste: settings.fallbackToPaste, restoreClipboard: settings.restoreClipboard)
                status = .success(text)
            } catch {
                status = .failure(error.localizedDescription)
            }
            isStopping = false
        }
    }
}
