import Foundation

enum VoiceInputStatus: Equatable {
    case idle
    case recording(startedAt: Date)
    case transcribing
    case inserting
    case success(String)
    case failure(String)

    var title: String {
        switch self {
        case .idle: "准备就绪"
        case .recording: "正在录音"
        case .transcribing: "正在转写"
        case .inserting: "正在输入"
        case .success: "已输入"
        case .failure: "失败"
        }
    }

    var detail: String {
        switch self {
        case .idle: "按快捷键开始语音输入"
        case .recording: "说完后松开或再次按快捷键"
        case .transcribing: "本地 Whisper 正在处理音频"
        case .inserting: "正在写入当前光标位置"
        case .success(let text): text
        case .failure(let message): message
        }
    }

    var isTransient: Bool {
        switch self {
        case .success, .failure:
            true
        default:
            false
        }
    }
}
