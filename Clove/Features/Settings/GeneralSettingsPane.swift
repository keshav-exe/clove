import SwiftUI

struct GeneralSettingsPane: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = LaunchAtLogin()
    @State private var rivals: [NotchNeighbor] = []

    @ViewBuilder
    private var notchOptions: some View {
        @Bindable var settings = model.settings
        SettingsCheckboxRow(title: "Open on hover", isOn: $settings.notchOpensOnHover)
        SettingsCheckboxRow(title: "Liquid Glass when open", isOn: $settings.notchGlass)
        SettingsCheckboxRow(title: "Stay open when clicking elsewhere", isOn: $settings.keepPanelOnTop)
        Text("Grow to tell me when")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.top, 10)
            .padding(.bottom, 2)
        SettingsCheckboxRow(title: "An agent finishes its turn", isOn: $settings.notchAgentMoments)
        SettingsCheckboxRow(title: "A dev server starts or stops", isOn: $settings.notchServerMoments)
        SettingsCheckboxRow(title: "The disk is nearly full", isOn: $settings.notchStorageMoments)
    }

    var body: some View {
        @Bindable var settings = model.settings
        @Bindable var launch = launchAtLogin

        SettingsForm {
            SettingsSection(
                footer: "Closing the library keeps Clove running. The Dock icon hides only while the library is closed, so Settings and shortcuts stay reachable when it's open."
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsCheckboxRow(title: "Launch at login", isOn: $launch.isEnabled)
                    SettingsCheckboxRow(title: "Keep running when the window is closed", isOn: $settings.keepRunningInMenuBar)
                    SettingsCheckboxRow(title: "Hide Dock icon", isOn: $settings.hideDockIcon)
                }
            }

            SettingsPaneDivider()

            SettingsSection(
                footer: settings.accessMode == .notch
                    ? "Hover the notch to peek, click it or press the shortcut to search. Esc, a click elsewhere, or a click on the notch closes it. Right-click it for every section. Macs without a notch get one at the top of the menu bar."
                    : "Click the icon or press the shortcut for the panel; right-click it for every section. Moments and the live view of agents at work need the notch."
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Where Clove lives")
                        .font(.headline)
                        .padding(.bottom, 8)
                    Picker("Where Clove lives", selection: $settings.accessMode) {
                        ForEach(AccessMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .padding(.bottom, 8)
                    if settings.accessMode == .menuBar {
                        Picker("Beside the icon", selection: $settings.menuBarStat) {
                            ForEach(MenuBarStat.allCases) { stat in
                                Text(stat.title).tag(stat)
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                        .padding(.vertical, 4)
                        SettingsCheckboxRow(title: "Stay open when clicking elsewhere", isOn: $settings.keepPanelOnTop)
                    } else {
                        if !rivals.isEmpty {
                            Label("\(NotchNeighbors.list(rivals)) also \(rivals.count == 1 ? "uses" : "use") the notch. If both show up there, pick Menu Bar.", systemImage: "rectangle.on.rectangle")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 6)
                        }
                        notchOptions
                    }
                }
            }

            SettingsPaneDivider()

            SettingsSection(
                footer: "Clearing caches moves them to the Trash first, so Storage can put them back until you empty it. Folders you mark Always Keep are never cleared or suggested."
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Storage")
                        .font(.headline)
                        .padding(.bottom, 6)
                    SettingsCheckboxRow(
                        title: "Move caches to the Trash before clearing",
                        isOn: Binding { model.storage.trashFirst } set: { model.storage.trashFirst = $0 }
                    )
                    if !model.storage.kept.isEmpty {
                        Text(model.storage.kept.count == 1 ? "1 folder always kept" : "\(model.storage.kept.count) folders always kept, listed in Storage")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }

            SettingsPaneDivider()

            SettingsSection(
                footer: "Up to four tabs sit beside the notch. ⌘1 to ⌘4 switch between them while it's open."
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Tabs")
                        .font(.headline)
                        .padding(.bottom, 6)
                    ForEach(PanelBlock.allCases) { block in
                        SettingsCheckboxRow(
                            title: "\(block.title): \(block.detail.prefix(1).lowercased() + block.detail.dropFirst())",
                            isOn: settings.blockBinding(block),
                            isDisabled: settings.panelBlocks == [block]
                                || (!settings.panelBlocks.contains(block) && settings.panelBlocks.count >= PanelBlock.maxTabs)
                        )
                    }
                }
            }

            SettingsPaneDivider()

            SettingsFieldRow(label: "Skill library") {
                Button("Open Library…") {
                    WindowBridge.shared.showLibraryWindow()
                }
            }
        }
        .task {
            rivals = await Task.detached { NotchNeighbors.rivals() }.value
        }
    }
}
