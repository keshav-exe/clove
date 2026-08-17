import SwiftUI

struct CloveCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Refresh Skills", systemImage: "arrow.clockwise") {
                Task { await model.refresh() }
            }
            .keyboardShortcut("r")
        }

        CommandGroup(after: .sidebar) {
            Divider()

            Button("Quick Access Panel", systemImage: "command") {
                WindowBridge.shared.toggleQuickPanel()
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Toggle("Keep Panel on Top", isOn: keepOnTop)
        }
    }

    private var keepOnTop: Binding<Bool> {
        Binding {
            model.settings.keepPanelOnTop
        } set: { newValue in
            model.settings.keepPanelOnTop = newValue
        }
    }
}
