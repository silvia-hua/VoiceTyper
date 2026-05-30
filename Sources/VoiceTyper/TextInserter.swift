import AppKit
import ApplicationServices
import Foundation

@MainActor
final class TextInserter {
    var isAccessibilityTrusted: Bool {
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestAccessibilityTrust() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func insert(text: String, fallbackToPaste: Bool, restoreClipboard: Bool) async throws {
        guard isAccessibilityTrusted else {
            _ = requestAccessibilityTrust()
            throw TextInsertError.accessibilityNotTrusted
        }

        do {
            try directInsert(text)
            return
        } catch {
            guard fallbackToPaste else {
                throw error
            }
            try await pasteInsert(text, restoreClipboard: restoreClipboard)
        }
    }

    private func directInsert(_ text: String) throws {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusedResult == .success, let focusedElement = focusedValue else {
            throw TextInsertError.noFocusedElement
        }

        let element = focusedElement as! AXUIElement

        var valueRef: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
        guard valueResult == .success, let currentValue = valueRef as? String else {
            throw TextInsertError.directInsertUnavailable
        }

        var selectedRangeRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeRef
        )
        guard rangeResult == .success, let selectedRangeValue = selectedRangeRef else {
            throw TextInsertError.directInsertUnavailable
        }

        var selectedRange = CFRange()
        guard AXValueGetValue(selectedRangeValue as! AXValue, .cfRange, &selectedRange) else {
            throw TextInsertError.directInsertUnavailable
        }

        let currentNSString = currentValue as NSString
        guard selectedRange.location >= 0,
              selectedRange.length >= 0,
              selectedRange.location + selectedRange.length <= currentNSString.length
        else {
            throw TextInsertError.directInsertUnavailable
        }

        let nsRange = NSRange(location: selectedRange.location, length: selectedRange.length)
        let updatedValue = currentNSString.replacingCharacters(in: nsRange, with: text)
        let setResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, updatedValue as CFTypeRef)
        guard setResult == .success else {
            throw TextInsertError.directInsertUnavailable
        }

        var newRange = CFRange(location: selectedRange.location + (text as NSString).length, length: 0)
        if let rangeValue = AXValueCreate(.cfRange, &newRange) {
            _ = AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                rangeValue
            )
        }
    }

    private func pasteInsert(_ text: String, restoreClipboard: Bool) async throws {
        let pasteboard = NSPasteboard.general
        let snapshot = ClipboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw TextInsertError.pasteboardWriteFailed
        }

        guard sendPasteShortcut() else {
            if restoreClipboard {
                snapshot.restore(to: pasteboard)
            }
            throw TextInsertError.pasteShortcutFailed
        }

        if restoreClipboard {
            try? await Task.sleep(nanoseconds: 300_000_000)
            snapshot.restore(to: pasteboard)
        }
    }

    private func sendPasteShortcut() -> Bool {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

private struct ClipboardSnapshot {
    struct Item {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    let items: [Item]

    static func capture(from pasteboard: NSPasteboard) -> ClipboardSnapshot {
        let items = pasteboard.types?.compactMap { type -> Item? in
            guard let data = pasteboard.data(forType: type) else { return nil }
            return Item(type: type, data: data)
        } ?? []
        return ClipboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        for item in items {
            pasteboard.setData(item.data, forType: item.type)
        }
    }
}

enum TextInsertError: LocalizedError {
    case accessibilityNotTrusted
    case noFocusedElement
    case directInsertUnavailable
    case pasteboardWriteFailed
    case pasteShortcutFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityNotTrusted: "请在系统设置中允许辅助功能权限"
        case .noFocusedElement: "没有找到当前光标所在输入框"
        case .directInsertUnavailable: "当前 App 不支持辅助功能直写"
        case .pasteboardWriteFailed: "无法写入剪贴板"
        case .pasteShortcutFailed: "无法模拟粘贴快捷键"
        }
    }
}
