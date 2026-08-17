import AppKit
import SwiftUI

struct KeyRecorderView: View {
    @Binding var chord: KeyChord?
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggleRecording) {
            Text(label)
                .font(.body.monospaced())
                .frame(minWidth: 132)
        }
        .buttonStyle(.bordered)
        .onExitCommand(perform: stopRecording)
        .onDisappear(perform: stopRecording)
        .help("Click, then press the new shortcut. Delete clears it.")
        .accessibilityLabel("Shortcut")
        .accessibilityValue(chord?.displayString ?? "None")
    }

    private var label: String {
        if isRecording {
            "Type a shortcut"
        } else {
            chord?.displayString ?? "Click to record"
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKey(event) ? nil : event
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard isRecording else { return false }
        if event.keyCode == 53 {
            stopRecording()
            return true
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            chord = nil
            stopRecording()
            return true
        }
        guard let recorded = KeyChord(event: event) else { return true }
        chord = recorded
        stopRecording()
        return true
    }
}
