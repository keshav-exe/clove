import AppKit
import SwiftUI

/// A native push button that records the next key combination pressed, the
/// same control Shotput uses. Delete clears it, Esc or a click elsewhere keeps it.
struct KeyRecorderView: NSViewRepresentable {
    @Binding var chord: KeyChord?

    func makeNSView(context: Context) -> KeyRecorderButton {
        let button = KeyRecorderButton()
        button.onChange = { chord = $0 }
        button.chord = chord
        return button
    }

    func updateNSView(_ button: KeyRecorderButton, context: Context) {
        button.onChange = { chord = $0 }
        if button.chord != chord { button.chord = chord }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: KeyRecorderButton, context: Context) -> CGSize? {
        CGSize(width: max(140, nsView.intrinsicContentSize.width), height: nsView.intrinsicContentSize.height)
    }
}

final class KeyRecorderButton: NSButton {
    var onChange: ((KeyChord?) -> Void)?
    var chord: KeyChord? { didSet { refreshTitle() } }

    private var monitor: Any?
    private var isRecording: Bool { monitor != nil }

    init() {
        super.init(frame: .zero)
        bezelStyle = .push
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggleRecording)
        toolTip = "Click, then press the new shortcut. Delete clears it, Esc keeps it."
        refreshTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func refreshTitle() {
        if isRecording {
            title = "Press shortcut"
        } else {
            title = chord?.displayString ?? "Record Shortcut"
        }
        setAccessibilityLabel("Shortcut")
        setAccessibilityValue(chord?.displayString ?? "None")
    }

    @objc private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        // Release the live hotkey, otherwise pressing the current shortcut would toggle the panel.
        WindowBridge.shared.setHotKeySuspended(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .leftMouseDown {
                // A click on the button itself is handled by its action.
                if event.window === self.window, self.bounds.contains(self.convert(event.locationInWindow, from: nil)) {
                    return event
                }
                self.stopRecording()
                return event
            }
            let flags = KeyModifiers(cocoa: event.modifierFlags)
            if flags.isEmpty, event.keyCode == 53 {
                self.stopRecording()
            } else if flags.isEmpty, event.keyCode == 51 || event.keyCode == 117 {
                self.commit(nil)
            } else if let recorded = KeyChord(event: event) {
                self.commit(recorded)
            } else {
                NSSound.beep()
            }
            return nil
        }
        refreshTitle()
    }

    private func commit(_ newChord: KeyChord?) {
        chord = newChord
        onChange?(newChord)
        stopRecording()
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        refreshTitle()
        WindowBridge.shared.setHotKeySuspended(false)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil, isRecording { stopRecording() }
        super.viewWillMove(toWindow: newWindow)
    }
}
