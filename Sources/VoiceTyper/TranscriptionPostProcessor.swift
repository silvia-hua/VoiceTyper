import Foundation

enum TranscriptionPostProcessor {
    static func process(_ text: String, settings: AppSettings) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard settings.convertChineseToSimplified else {
            return trimmed
        }
        return convertToSimplifiedChinese(trimmed)
    }

    private static func convertToSimplifiedChinese(_ text: String) -> String {
        let mutable = NSMutableString(string: text)
        CFStringTransform(mutable, nil, "Traditional-Simplified" as CFString, false)
        return mutable as String
    }

    static func isLikelySilenceHallucination(_ text: String) -> Bool {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".。!！?？,， "))
            .lowercased()
        return ["you", "u"].contains(normalized)
    }
}
