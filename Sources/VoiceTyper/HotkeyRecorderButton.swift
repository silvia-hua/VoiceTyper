import Carbon
import SwiftUI

struct HotkeyRecorderButton: View {
    let hotkey: Hotkey
    let onChange: (Hotkey) -> Void

    @State private var isRecording = false

    var body: some View {
        Button(isRecording ? "按下组合键..." : "更改") {
            isRecording = true
        }
        .background(
            HotkeyCaptureView(isRecording: $isRecording, onCapture: onChange)
                .frame(width: 0, height: 0)
        )
    }
}

private struct HotkeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (Hotkey) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onCapture = { hotkey in
            onCapture(hotkey)
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.isCapturing = isRecording
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class CaptureView: NSView {
        var onCapture: ((Hotkey) -> Void)?
        var isCapturing = false

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard isCapturing else {
                super.keyDown(with: event)
                return
            }

            let modifiers = carbonModifiers(from: event.modifierFlags)
            guard modifiers != 0 else {
                NSSound.beep()
                return
            }

            onCapture?(Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers))
        }

        private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
            var modifiers: UInt32 = 0
            if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
            if flags.contains(.option) { modifiers |= UInt32(optionKey) }
            if flags.contains(.control) { modifiers |= UInt32(controlKey) }
            if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
            return modifiers
        }
    }
}
