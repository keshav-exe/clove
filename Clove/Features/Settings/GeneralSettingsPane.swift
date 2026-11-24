import SwiftUI

struct GeneralSettingsPane: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = LaunchAtLogin()
    @State private var rivals: [NotchNeighbor] = []

    var body: some View {
        @Bindable var settings = model.settings
        @Bindable var launch = launchAtLogin
        let isNotch = settings.accessMode == .notch

        SettingsPage {
            Section {
                HStack(spacing: 14) {
                    ForEach(AccessMode.allCases) { mode in
                        AccessModeCard(mode: mode, isPicked: settings.accessMode == mode) {
                            withAnimation(.smooth(duration: 0.25)) { settings.accessMode = mode }
                        }
                    }
                }
                .padding(.vertical, 6)
                if isNotch, !rivals.isEmpty {
                    SettingsRow(
                        title: "\(NotchNeighbors.list(rivals)) also \(rivals.count == 1 ? "uses" : "use") the notch",
                        subtitle: "If both show up there, pick Menu Bar.",
                        symbol: "rectangle.on.rectangle", tint: Palette.Vivid.yellow
                    ) { EmptyView() }
                }
            } header: {
                Text("Where Clove Lives")
            } footer: {
                Text(isNotch
                    ? "Hover the notch to peek; click it or press the shortcut to search. Right-click it for every section. Macs without a notch get one at the top of the screen."
                    : "Click the icon or press the shortcut for the panel; right-click it for every section. Moments and agents at work need the notch.")
                    .settingsFooter()
            }

            if isNotch {
                Section("Notch") {
                    SettingsToggle(title: "Open on hover", subtitle: "Peek without clicking; it closes when you move away", symbol: "cursorarrow.rays", tint: Palette.Vivid.blue, isOn: $settings.notchOpensOnHover)
                    SettingsToggle(title: "Liquid Glass when open", subtitle: "Glass below the notch instead of solid black", symbol: "circle.lefthalf.filled", tint: Palette.Vivid.cyan, isOn: $settings.notchGlass)
                    SettingsToggle(title: "Stay open when clicking elsewhere", symbol: "pin.fill", tint: Palette.Vivid.orange, isOn: $settings.keepPanelOnTop)
                }

                Section("Grow the Notch When") {
                    SettingsToggle(title: "An agent starts a task", subtitle: "Opens a little, glowing in the app's colours, then tucks away", symbol: "sparkles", tint: Palette.Vivid.violet, isOn: $settings.notchAgentStartMoments)
                    SettingsToggle(title: "An agent finishes its task", subtitle: "Or has a question, or stops on an error", symbol: "checkmark", tint: Palette.Vivid.green, isOn: $settings.notchAgentMoments)
                    SettingsToggle(title: "A dev server starts or stops", symbol: "globe", tint: Palette.Vivid.blue, isOn: $settings.notchServerMoments)
                    SettingsToggle(title: "The disk is nearly full", symbol: "internaldrive.fill", tint: Palette.Vivid.orange, isOn: $settings.notchStorageMoments)
                    SettingsToggle(title: "A plan limit is nearly used up", subtitle: settings.showsUsageLimits ? nil : "Turn on plan limits in Now first", symbol: "gauge.with.dots.needle.100percent", tint: Palette.Vivid.red, isOn: $settings.notchLimitMoments)
                        .disabled(!settings.showsUsageLimits)
                }
            } else {
                Section("Menu Bar") {
                    Picker(selection: $settings.menuBarStat) {
                        ForEach(MenuBarStat.allCases) { stat in
                            Text(stat.title).tag(stat)
                        }
                    } label: {
                        SettingsLabel(title: "Beside the icon", subtitle: "A number worth a glance", symbol: "number", tint: Palette.Vivid.blue)
                    }
                    SettingsToggle(title: "Stay open when clicking elsewhere", symbol: "pin.fill", tint: Palette.Vivid.orange, isOn: $settings.keepPanelOnTop)
                }
            }

            Section {
                TabStripPreview(blocks: settings.panelBlocks)
                    .padding(.vertical, 2)
                ReorderableRows(items: settings.blockOrderBinding) { block in
                    Toggle(isOn: settings.blockBinding(block)) {
                        SettingsLabel(title: block.title, subtitle: block.detail, symbol: block.symbol, tint: block.tint)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(settings.panelBlocks == [block]
                        || (!settings.panelBlocks.contains(block) && settings.panelBlocks.count >= PanelBlock.maxTabs))
                }
            } header: {
                Text("Tabs")
            } footer: {
                Text("Up to four sit beside the notch. Drag to reorder; ⌘1 to ⌘4 follow the order.")
                    .settingsFooter()
            }

            Section {
                SettingsToggle(title: "Launch at login", symbol: "power", tint: Palette.Vivid.green, isOn: $launch.isEnabled)
                SettingsToggle(title: "Keep running when the window is closed", subtitle: "Clove stays in the \(isNotch ? "notch" : "menu bar")", symbol: "rectangle.on.rectangle", tint: Palette.Vivid.violet, isOn: $settings.keepRunningInMenuBar)
                SettingsToggle(title: "Hide Dock icon", subtitle: "Only while Clove's window is closed, so Settings stays reachable", symbol: "dock.rectangle", tint: Color(white: 0.45), isOn: $settings.hideDockIcon)
            } header: {
                Text("Startup")
            }

            Section {
                SettingsToggle(
                    title: "Move caches to the Trash first",
                    subtitle: "So Storage can put them back until you empty it",
                    symbol: "trash.fill", tint: Color(white: 0.45),
                    isOn: Binding { model.storage.trashFirst } set: { model.storage.trashFirst = $0 }
                )
                if !model.storage.kept.isEmpty {
                    SettingsRow(title: "Always kept", subtitle: "Never cleared or suggested", symbol: "lock.fill", tint: Palette.Vivid.blue) {
                        Text("\(model.storage.kept.count) folder\(model.storage.kept.count == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Storage")
            }
        }
        .task {
            rivals = await Task.detached { NotchNeighbors.rivals() }.value
        }
    }
}
