import SwiftUI

struct GeneralSettingsPane: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = LaunchAtLogin()

    var body: some View {
        @Bindable var settings = model.settings
        @Bindable var launch = launchAtLogin

        SettingsPaneLayout {
            SettingsGroup(footnote: launchAtLogin.lastError) {
                SettingsToggleRow(
                    systemImage: "power",
                    tint: .blue,
                    title: "Launch at login",
                    detail: "Start Clove automatically when you log in to this Mac.",
                    isOn: $launch.isEnabled
                )
            }

            SettingsGroup(title: "Menu Bar and Dock") {
                SettingsToggleRow(
                    systemImage: "menubar.arrow.up.rectangle",
                    tint: .orange,
                    title: "Show menu bar icon",
                    detail: "Click the icon for the quick access panel. Right click for more options.",
                    isOn: $settings.showMenuBarIcon
                )

                Divider().padding(.leading, 46)

                SettingsToggleRow(
                    systemImage: "dock.rectangle",
                    tint: .purple,
                    title: "Hide Dock icon",
                    detail: "Run Clove from the menu bar only. Needs the menu bar icon turned on.",
                    isOn: $settings.hideDockIcon
                )
                .disabled(!settings.canHideDockIcon)
                .opacity(settings.canHideDockIcon ? 1 : 0.5)
            }

            SettingsGroup(title: "Quick Access Panel") {
                SettingsToggleRow(
                    systemImage: "pin",
                    tint: .pink,
                    title: "Keep panel on top",
                    detail: "The panel stays visible beside your editor or terminal instead of hiding when you switch apps.",
                    isOn: $settings.keepPanelOnTop
                )

                Divider().padding(.leading, 46)

                SettingsActionRow(
                    systemImage: "square.stack.3d.up",
                    tint: .accentColor,
                    title: "Skill library",
                    detail: "The full window with sources, tags, and skill details."
                ) {
                    Button("Open") {
                        WindowBridge.shared.showLibraryWindow()
                    }
                }
            }
        }
    }
}
