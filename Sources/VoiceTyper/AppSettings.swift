import Carbon
import Foundation

enum RecordingMode: String, CaseIterable, Codable, Identifiable {
    case holdToTalk
    case toggle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .holdToTalk: "按住说话"
        case .toggle: "按一次开关"
        }
    }

    var helpText: String {
        switch self {
        case .holdToTalk: "按下快捷键开始录音，松开后自动转写并输入。"
        case .toggle: "按一次开始录音，再按一次结束并输入。"
        }
    }
}

struct Hotkey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let defaultHotkey = Hotkey(keyCode: 49, modifiers: UInt32(optionKey))

    var displayName: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("Control") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("Option") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("Shift") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("Command") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined(separator: " + ")
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case 36: "Return"
        case 48: "Tab"
        case 49: "Space"
        case 51: "Delete"
        case 53: "Escape"
        case 123: "Left"
        case 124: "Right"
        case 125: "Down"
        case 126: "Up"
        default: "Key \(keyCode)"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var recordingMode: RecordingMode
    var hotkey: Hotkey
    var fallbackToPaste: Bool
    var restoreClipboard: Bool
    var language: String
    var convertChineseToSimplified: Bool

    static let defaults = AppSettings(
        recordingMode: .holdToTalk,
        hotkey: .defaultHotkey,
        fallbackToPaste: true,
        restoreClipboard: true,
        language: "auto",
        convertChineseToSimplified: true
    )

    private enum CodingKeys: String, CodingKey {
        case recordingMode
        case hotkey
        case fallbackToPaste
        case restoreClipboard
        case language
        case convertChineseToSimplified
    }

    init(
        recordingMode: RecordingMode,
        hotkey: Hotkey,
        fallbackToPaste: Bool,
        restoreClipboard: Bool,
        language: String,
        convertChineseToSimplified: Bool
    ) {
        self.recordingMode = recordingMode
        self.hotkey = hotkey
        self.fallbackToPaste = fallbackToPaste
        self.restoreClipboard = restoreClipboard
        self.language = language
        self.convertChineseToSimplified = convertChineseToSimplified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.defaults
        recordingMode = try container.decodeIfPresent(RecordingMode.self, forKey: .recordingMode) ?? defaults.recordingMode
        hotkey = try container.decodeIfPresent(Hotkey.self, forKey: .hotkey) ?? defaults.hotkey
        fallbackToPaste = try container.decodeIfPresent(Bool.self, forKey: .fallbackToPaste) ?? defaults.fallbackToPaste
        restoreClipboard = try container.decodeIfPresent(Bool.self, forKey: .restoreClipboard) ?? defaults.restoreClipboard
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? defaults.language
        convertChineseToSimplified = try container.decodeIfPresent(Bool.self, forKey: .convertChineseToSimplified) ?? defaults.convertChineseToSimplified
    }
}

@MainActor
final class AppSettingsStore {
    private let key = "VoiceTyper.settings.v1"

    func load() -> AppSettings {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return .defaults
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
