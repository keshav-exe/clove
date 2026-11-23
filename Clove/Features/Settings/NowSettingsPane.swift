import SwiftUI

/// How the Now tab is laid out: which sections show and in what order,
/// which ports are listed, and plan limits.
struct NowSettingsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        SettingsForm {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                SettingsSection(
                    title: "Sections",
                    footer: "Sections show only when they have something in them. In the notch, right-click one to move or hide it."
                ) {
                    SettingsInsetGroup {
                        let ordered = settings.nowSections + NowSection.allCases.filter { !settings.nowSections.contains($0) }
                        ForEach(Array(ordered.enumerated()), id: \.element) { index, section in
                            if index > 0 { Divider() }
                            sectionRow(section)
                        }
                    }
                }

                SettingsPaneDivider()

                SettingsSection(
                    title: "Ports",
                    footer: "Activity always lists every port. Hover a port in the notch and click Hide to stop listing that app here."
                ) {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsCheckboxRow(title: "Dev servers: Node, Vite, Rails, Postgres, and anything an agent starts", isOn: $settings.nowShowsDevServers)
                        SettingsCheckboxRow(title: "Ports apps keep open, like Raycast, Figma, and Docker", isOn: $settings.nowShowsAppPorts)
                        SettingsCheckboxRow(title: "Ports macOS keeps open, like AirPlay Receiver on :5000", isOn: $settings.nowShowsSystemPorts)
                    }
                    if !settings.hiddenPortOwners.isEmpty {
                        hiddenOwners
                            .padding(.top, Metrics.spacingS)
                    }
                }

                SettingsPaneDivider()

                SettingsSection(
                    title: "Plan Limits",
                    footer: "Clove reads the sign-in Claude Code keeps in your Keychain and the one Codex keeps in ~/.codex, and asks Anthropic and OpenAI how much of each limit you've used. macOS asks before Clove can read the Keychain. Nothing else is sent anywhere."
                ) {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsCheckboxRow(title: "Show Claude and Codex limits", isOn: $settings.showsUsageLimits)
                        SettingsCheckboxRow(title: "Grow the notch when a limit is nearly used up", isOn: $settings.notchLimitMoments, isDisabled: !settings.showsUsageLimits)
                    }
                }
            }
        }
    }

    private func sectionRow(_ section: NowSection) -> some View {
        let settings = model.settings
        let index = settings.nowSections.firstIndex(of: section)
        return HStack(spacing: Metrics.spacingS) {
            Toggle(isOn: settings.sectionBinding(section)) {
                Label(section.title, systemImage: section.symbol)
                    .font(.callout)
            }
            .toggleStyle(.checkbox)
            Spacer(minLength: 0)
            if let index {
                Button("Move Up", systemImage: "chevron.up") { settings.moveSection(section, by: -1) }
                    .disabled(index == 0)
                Button("Move Down", systemImage: "chevron.down") { settings.moveSection(section, by: 1) }
                    .disabled(index == settings.nowSections.count - 1)
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, 5)
    }

    private var hiddenOwners: some View {
        SettingsInsetGroup {
            ForEach(Array(model.settings.hiddenPortOwners.enumerated()), id: \.element) { index, key in
                if index > 0 { Divider() }
                HStack(spacing: Metrics.spacingS) {
                    if key.hasSuffix(".app") {
                        Image(nsImage: AppIconCache.icon(key))
                            .resizable()
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    Text(key.hasSuffix(".app") ? RunningScanner.appName(key) : key)
                        .font(.callout)
                    Text("hidden")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("Show") {
                        model.settings.hiddenPortOwners.removeAll { $0 == key }
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, Metrics.spacingM)
                .padding(.vertical, 7)
            }
        }
    }
}
