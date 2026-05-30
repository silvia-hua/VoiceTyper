import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsSection("快捷键") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.settings.hotkey.displayName)
                                .font(.headline)
                            Text("默认是 Option + Space。点击右侧按钮后，按下新的组合键。")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Spacer()
                        HotkeyRecorderButton(hotkey: appState.settings.hotkey) { hotkey in
                            appState.updateHotkey(hotkey)
                        }
                    }

                    if let error = appState.hotkeyError {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                SettingsSection("录音") {
                    Picker("录音模式", selection: $appState.settings.recordingMode) {
                        ForEach(RecordingMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    Text(appState.settings.recordingMode.helpText)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("麦克风权限")
                        Spacer()
                        Text(appState.microphonePermissionText())
                            .foregroundStyle(.secondary)
                    }

                    Button("请求麦克风权限") {
                        appState.requestMicrophonePermission()
                    }
                }

                SettingsSection("输入") {
                    HStack {
                        Text("辅助功能权限")
                        Spacer()
                        Text(appState.accessibilityPermissionText())
                            .foregroundStyle(.secondary)
                    }

                    Toggle("直写失败后自动粘贴", isOn: $appState.settings.fallbackToPaste)
                    Toggle("粘贴后恢复原剪贴板", isOn: $appState.settings.restoreClipboard)
                        .disabled(!appState.settings.fallbackToPaste)

                    HStack {
                        Button(appState.accessibilityTrusted ? "刷新权限状态" : "请求辅助功能权限") {
                            appState.requestAccessibilityPermission()
                        }
                        Button("打开系统设置") {
                            appState.openAccessibilitySettings()
                        }
                    }
                }

                SettingsSection("Whisper") {
                    Picker("语言", selection: $appState.settings.language) {
                        Text("自动识别").tag("auto")
                        Text("中文").tag("zh")
                        Text("英文").tag("en")
                    }

                    Toggle("输出简体中文", isOn: $appState.settings.convertChineseToSimplified)

                    Text("使用内置 ggml-base.bin 多语言模型和 whisper-cli，本地完成转写，不上传录音。")
                        .foregroundStyle(.secondary)

                    Button("显示 Whisper 资源") {
                        appState.revealWhisperResources()
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            appState.refreshPermissionStatus()
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
