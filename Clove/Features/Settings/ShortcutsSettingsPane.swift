import SwiftUI

struct ShortcutsSettingsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        SettingsPage {
            Section {
                SettingsToggle(title: "Global shortcut", subtitle: "Opens Clove from any app", symbol: "command", tint: Palette.Vivid.blue, isOn: $settings.hotKeyEnabled)
                SettingsRow(title: "Shortcut", subtitle: "Click, then press the keys you want", symbol: "keyboard.fill", tint: Color(white: 0.45)) {
                    KeyRecorderView(chord: $settings.hotKey)
                        .fixedSize()
                }
                .disabled(!settings.hotKeyEnabled)
                if settings.hotKeyEnabled, settings.hotKey != nil, !settings.hotKeyIsRegistered {
                    SettingsRow(title: "Another app is using that shortcut", subtitle: "Pick a different one, or quit the other app", symbol: "exclamationmark.triangle.fill", tint: Palette.Vivid.yellow) { EmptyView() }
                }
            } header: {
                Text("Open Clove")
            }

            Section("In the Panel") {
                shortcut("Insert into the app you were in", ["↩"])
                shortcut("Copy, and keep the panel open", ["⌥", "↩"])
                shortcut("Move the selection", ["↑", "↓"])
                shortcut("Extend the selection", ["⇧", "↑", "↓"])
                shortcut("Select several", ["⌘", "Click"])
                shortcut("Copy a whole group", ["⌘", "⇧", "C"])
                shortcut("Cycle pinned groups", ["⇥"])
                shortcut("Close", ["esc"])
            }

            Section("In the Notch") {
                shortcut("Switch tabs", ["⌘", "1 – 4"])
                shortcut("Close", ["esc"])
            }
        }
    }

    private func shortcut(_ action: String, _ keys: [String]) -> some View {
        LabeledContent(action) {
            KeyCaps(keys: keys)
        }
    }
}
