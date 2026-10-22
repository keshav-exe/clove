import SwiftUI

struct GeneralSettingsPane: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = LaunchAtLogin()

    var body: some View {
        @Bindable var settings = model.settings
        @Bindable var launch = launchAtLogin

        SettingsForm {
            SettingsSection(
                footer: "Closing the library keeps Clove in the menu bar. The Dock icon hides only while the library is closed, so Settings and shortcuts stay reachable when it's open."
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsCheckboxRow(title: "Launch at login", isOn: $launch.isEnabled)
                    SettingsCheckboxRow(title: "Show menu bar icon", isOn: $settings.showMenuBarIcon)
                    SettingsCheckboxRow(
                        title: "Keep running in menu bar when window is closed",
                        isOn: $settings.keepRunningInMenuBar,
                        isDisabled: !settings.showMenuBarIcon
                    )
                    SettingsCheckboxRow(
                        title: "Hide Dock icon",
                        isOn: $settings.hideDockIcon,
                        isDisabled: !settings.canHideDockIcon
                    )
                    SettingsCheckboxRow(title: "Keep panel on top", isOn: $settings.keepPanelOnTop)
                }
            }

            SettingsPaneDivider()

            SettingsFieldRow(label: "Skill library") {
                Button("Open Library…") {
                    WindowBridge.shared.showLibraryWindow()
                }
            }
        }
    }
}
