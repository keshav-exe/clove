import SwiftUI

struct ShortcutsSettingsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        SettingsPaneLayout {
            SettingsGroup(
                title: "Global Shortcut",
                footnote: "Works from any app. Control-Option-Space is the default."
            ) {
                SettingsToggleRow(
                    systemImage: "command",
                    tint: .indigo,
                    title: "Global shortcut",
                    detail: "Show or hide the quick access panel without leaving your editor.",
                    isOn: $settings.hotKeyEnabled
                )

                Divider().padding(.leading, 46)

                SettingsActionRow(
                    systemImage: "keyboard",
                    tint: .gray,
                    title: "Shortcut",
                    detail: "Click the field, then press the keys you want."
                ) {
                    KeyRecorderView(chord: $settings.hotKey)
                }
                .disabled(!settings.hotKeyEnabled)
                .opacity(settings.hotKeyEnabled ? 1 : 0.5)
            }

            if settings.hotKeyEnabled, settings.hotKey != nil, !settings.hotKeyIsRegistered {
                Label(
                    "Another app is already using that shortcut. Pick a different one.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.callout)
                .foregroundStyle(.orange)
            }

            SettingsGroup(title: "In the Panel") {
                ShortcutHintRow(keys: "↩", detail: "Copy selected skill references, space-separated if multiple are selected")
                Divider().padding(.leading, 46)
                ShortcutHintRow(keys: "↑ ↓", detail: "Move selection")
                Divider().padding(.leading, 46)
                ShortcutHintRow(keys: "⇧ ↑ ↓", detail: "Extend selection to a range")
                Divider().padding(.leading, 46)
                ShortcutHintRow(keys: "⌘ click", detail: "Add or remove skills from the selection")
                Divider().padding(.leading, 46)
                ShortcutHintRow(keys: "drag", detail: "Drop a skill reference into a prompt")
                Divider().padding(.leading, 46)
                ShortcutHintRow(keys: "esc", detail: "Clear the search, then close the panel")
                Divider().padding(.leading, 46)
                ShortcutHintRow(keys: "⌘⇧K", detail: "Toggle the panel while Clove is active")
            }
        }
    }
}
