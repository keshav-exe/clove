import SwiftUI

struct ShortcutsSettingsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        SettingsForm(centered: true) {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                SettingsSection {
                    SettingsCheckboxRow(title: "Global shortcut", isOn: $settings.hotKeyEnabled)

                    SettingsFieldRow(label: "Shortcut") {
                        KeyRecorderView(chord: $settings.hotKey)
                    }
                    .disabled(!settings.hotKeyEnabled)
                    .opacity(settings.hotKeyEnabled ? 1 : 0.5)

                    if settings.hotKeyEnabled, settings.hotKey != nil, !settings.hotKeyIsRegistered {
                        Text("Another app is already using that shortcut.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.leading, SettingsLayout.labelWidth + Metrics.spacingM)
                    }
                }

                SettingsPaneDivider()

                SettingsSection {
                    SettingsShortcutRow(action: "Copy", keys: "↩")
                    SettingsShortcutRow(action: "Insert", keys: "⌘↩")
                    SettingsShortcutRow(action: "Move selection", keys: "↑ ↓")
                    SettingsShortcutRow(action: "Extend selection", keys: "⇧ ↑ ↓")
                    SettingsShortcutRow(action: "Multi-select", keys: "⌘ click")
                    SettingsShortcutRow(action: "Copy group", keys: "⌘⇧C")
                    SettingsShortcutRow(action: "Cycle pinned groups", keys: "⇥")
                    SettingsShortcutRow(action: "Close panel", keys: "esc")
                }
            }
        }
    }
}
