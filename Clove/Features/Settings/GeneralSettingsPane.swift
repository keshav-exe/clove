import SwiftUI

struct GeneralSettingsPane: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = LaunchAtLogin()
    @State private var rivals: [NotchNeighbor] = []

    /// Where the island goes matters only with another display, or no notch at all.
    private var showsPlacement: Bool {
        NSScreen.screens.count > 1 || !NotchGeometry.hasHardwareNotch
    }

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
                        subtitle: "You might see both at once. Choose Menu Bar to stay out of the way.",
                        symbol: "rectangle.on.rectangle", tint: Palette.Vivid.yellow
                    ) { EmptyView() }
                }
            } header: {
                Text("Where Clove Lives")
            } footer: {
                Text(isNotch
                    ? "Hover the notch to see what's going on. Click it or press your shortcut to search, and right-click it for everything else. On screens without a notch, Clove sits in the menu bar as a small island that appears when something's happening."
                    : "Click the icon or press your shortcut to open Clove, and right-click it for everything else. Updates from your agents only show in the notch.")
                    .settingsFooter()
            }

            if isNotch {
                Section("Notch") {
                    if showsPlacement {
                        Picker(selection: $settings.islandPlacement) {
                            ForEach(NotchGeometry.Placement.allCases) { placement in
                                Text(placement.title).tag(placement)
                            }
                        } label: {
                            SettingsLabel(
                                title: "Show on",
                                subtitle: "Screens without a notch show it in the menu bar",
                                symbol: "display.2", tint: Palette.Vivid.blue
                            )
                        }
                    }
                    SettingsToggle(title: "Show working agents", subtitle: "Their app's icon sits beside the notch while they work", symbol: "sparkles", tint: Palette.Vivid.violet, isOn: $settings.notchShowsAgents)
                    if settings.notchShowsAgents {
                        SettingsRow(title: "Working indicator", subtitle: "Next to the notch while an agent works", symbol: "waveform", tint: Palette.Vivid.green) {
                            HStack(spacing: 6) {
                                ForEach(AgentMark.allCases) { mark in
                                    AgentMarkChoice(mark: mark, isPicked: settings.agentMark == mark) {
                                        settings.agentMark = mark
                                    }
                                }
                            }
                        }
                    }
                    SettingsToggle(title: "Open on hover", subtitle: "Opens when your pointer reaches it and closes when you move away", symbol: "cursorarrow.rays", tint: Palette.Vivid.blue, isOn: $settings.notchOpensOnHover)
                    SettingsToggle(title: "Liquid Glass", subtitle: "See your desktop through the open notch. Off, it's solid black.", symbol: "circle.lefthalf.filled", tint: Palette.Vivid.cyan, isOn: $settings.notchGlass)
                    if settings.notchGlass {
                        SettingsToggle(title: "Match macOS", subtitle: "Uses Clear or Tinted from Appearance settings", symbol: "apple.logo", tint: Color(white: 0.45), isOn: $settings.notchGlassFollowsSystem)
                        if !settings.notchGlassFollowsSystem {
                            SettingsRow(title: "Tint", symbol: "drop.halffull", tint: Palette.Vivid.cyan) {
                                // Laid out like the slider in Appearance settings: clear on the left, tinted on the right.
                                HStack(spacing: 8) {
                                    Image(systemName: "square.on.square")
                                        .help("Clear")
                                    Slider(value: $settings.notchGlassTint, in: 0...1)
                                        .frame(width: 160)
                                        .accessibilityLabel("Glass tint")
                                        .accessibilityValue(settings.notchGlassTint < 0.5 ? "Clearer" : "More tinted")
                                    Image(systemName: "square.fill.on.square.fill")
                                        .help("Tinted")
                                }
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    SettingsToggle(title: "Stay open when clicking elsewhere", symbol: "pin.fill", tint: Palette.Vivid.orange, isOn: $settings.keepPanelOnTop)
                }

                Section("Expand the Notch When") {
                    SettingsToggle(title: "An agent starts a task", subtitle: "Shows what it's working on for a few seconds", symbol: "sparkles", tint: Palette.Vivid.violet, isOn: $settings.notchAgentStartMoments)
                    SettingsToggle(title: "An agent finishes or needs you", subtitle: "Including questions and errors", symbol: "checkmark", tint: Palette.Vivid.green, isOn: $settings.notchAgentMoments)
                    SettingsToggle(title: "A dev server starts or stops", symbol: "globe", tint: Palette.Vivid.blue, isOn: $settings.notchServerMoments)
                    SettingsToggle(title: "The disk is nearly full", symbol: "internaldrive.fill", tint: Palette.Vivid.orange, isOn: $settings.notchStorageMoments)
                    SettingsToggle(title: "A plan limit is nearly used up", subtitle: settings.showsUsageLimits ? nil : "Turn on Plan limits in Now settings first", symbol: "gauge.with.dots.needle.100percent", tint: Palette.Vivid.red, isOn: $settings.notchLimitMoments)
                        .disabled(!settings.showsUsageLimits)
                }
            } else {
                Section("Menu Bar") {
                    Picker(selection: $settings.menuBarStat) {
                        ForEach(MenuBarStat.allCases) { stat in
                            Text(stat.title).tag(stat)
                        }
                    } label: {
                        SettingsLabel(title: "Next to the icon", subtitle: "A number you can check at a glance", symbol: "number", tint: Palette.Vivid.blue)
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
                Text("Choose up to four. Drag to reorder them. ⌘1 to ⌘4 switch tabs in this order.")
                    .settingsFooter()
            }

            Section {
                SettingsToggle(title: "Launch at login", symbol: "power", tint: Palette.Vivid.green, isOn: $launch.isEnabled)
                SettingsToggle(title: "Keep running when the window is closed", subtitle: "Clove stays in the \(isNotch ? "notch" : "menu bar")", symbol: "rectangle.on.rectangle", tint: Palette.Vivid.violet, isOn: $settings.keepRunningInMenuBar)
                SettingsToggle(title: "Hide Dock icon", subtitle: "Only while the Clove window is closed", symbol: "dock.rectangle", tint: Color(white: 0.45), isOn: $settings.hideDockIcon)
            } header: {
                Text("Startup")
            }

            Section {
                SettingsToggle(
                    title: "Move caches to the Trash first",
                    subtitle: "You can restore them until you empty the Trash",
                    symbol: "trash.fill", tint: Color(white: 0.45),
                    isOn: Binding { model.storage.trashFirst } set: { model.storage.trashFirst = $0 }
                )
                if !model.storage.kept.isEmpty {
                    SettingsRow(title: "Always kept", subtitle: "Clove won't suggest clearing these", symbol: "lock.fill", tint: Palette.Vivid.blue) {
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
