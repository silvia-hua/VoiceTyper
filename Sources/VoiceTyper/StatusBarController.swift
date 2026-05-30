import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []
    private var animationTimer: Timer?
    private var animationPhase = 0

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusButton()
        bindAppState()
        updateIcon()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.toolTip = "语音输入助手"
    }

    private func bindAppState() {
        appState.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateIcon()
            }
            .store(in: &cancellables)

        appState.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateTooltip()
            }
            .store(in: &cancellables)
    }

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        if NSApplication.shared.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            appState.toggleRecordingFromMenu()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        let primaryTitle = appState.isRecording ? "停止录音" : "开始录音"
        menu.addItem(NSMenuItem(title: primaryTitle, action: #selector(toggleRecording), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: appState.status.title, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        let modeMenu = NSMenu()
        for mode in RecordingMode.allCases {
            let item = NSMenuItem(title: mode.displayName, action: #selector(selectRecordingMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = appState.settings.recordingMode == mode ? .on : .off
            modeMenu.addItem(item)
        }
        let modeItem = NSMenuItem(title: "录音模式", action: nil, keyEquivalent: "")
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        let fallbackItem = NSMenuItem(title: "直写失败后粘贴", action: #selector(toggleFallbackToPaste), keyEquivalent: "")
        fallbackItem.target = self
        fallbackItem.state = appState.settings.fallbackToPaste ? .on : .off
        menu.addItem(fallbackItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "检查缺失权限", action: #selector(requestPermissions), keyEquivalent: ""))

        if let hotkeyError = appState.hotkeyError {
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: hotkeyError, action: nil, keyEquivalent: ""))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.target == nil && item.action != nil {
            item.target = self
        }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleRecording() {
        appState.toggleRecordingFromMenu()
    }

    @objc private func selectRecordingMode(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let mode = RecordingMode(rawValue: rawValue)
        else { return }
        appState.settings.recordingMode = mode
    }

    @objc private func toggleFallbackToPaste() {
        appState.settings.fallbackToPaste.toggle()
    }

    @objc private func openSettings() {
        appState.openSettings()
    }

    @objc private func requestPermissions() {
        appState.requestRequiredPermissions()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func updateTooltip() {
        statusItem.button?.toolTip = "语音输入助手\n\(appState.settings.hotkey.displayName)"
    }

    private func updateIcon() {
        switch appState.status {
        case .recording:
            startAnimation()
        default:
            stopAnimation()
            statusItem.button?.image = staticImage(for: appState.status)
        }
        updateTooltip()
    }

    private func startAnimation() {
        if animationTimer == nil {
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.16, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.tickRecordingAnimation()
                }
            }
        }
        tickRecordingAnimation()
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationPhase = 0
    }

    private func tickRecordingAnimation() {
        animationPhase = (animationPhase + 1) % 24
        statusItem.button?.image = recordingImage(phase: animationPhase)
    }

    private func staticImage(for status: VoiceInputStatus) -> NSImage? {
        let symbolName: String
        switch status {
        case .transcribing, .inserting:
            symbolName = "waveform"
        case .failure:
            symbolName = "exclamationmark.triangle"
        default:
            symbolName = "mic"
        }

        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "语音输入助手")
        image?.isTemplate = true
        return image
    }

    private func recordingImage(phase: Int) -> NSImage {
        let size = NSSize(width: 24, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let barWidth: CGFloat = 2.4
        let spacing: CGFloat = 2.1
        let startX: CGFloat = 4
        let midY = size.height / 2

        for index in 0..<6 {
            let progress = Double(phase + index * 3) * 0.72
            let normalized = (sin(progress) + 1) / 2
            let height = CGFloat(4 + normalized * 11)
            let rect = NSRect(
                x: startX + CGFloat(index) * (barWidth + spacing),
                y: midY - height / 2,
                width: barWidth,
                height: height
            )
            let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
            NSColor.systemRed.setFill()
            path.fill()
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
