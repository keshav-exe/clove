import SwiftUI

/// How the Now tab is laid out: which sections show and in what order, which
/// ports are listed, and plan limits.
struct NowSettingsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        SettingsPage {
            Section {
                NowLayoutPreview(sections: settings.nowSections)
                    .padding(.vertical, 4)
                ReorderableRows(items: orderBinding) { section in
                    Toggle(isOn: settings.sectionBinding(section)) {
                        SettingsLabel(title: section.title, subtitle: section.detail, symbol: section.symbol, tint: section.tint)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            } header: {
                Text("Sections")
            } footer: {
                Text("Drag to reorder. A section shows only when it has something in it; right-click one in the notch to move or hide it there.")
                    .settingsFooter()
            }

            Section {
                SettingsToggle(
                    title: "Dev servers",
                    subtitle: "Node, Vite, Rails, Postgres, and anything an agent starts",
                    symbol: "globe", tint: Palette.Vivid.green,
                    isOn: $settings.nowShowsDevServers
                )
                SettingsToggle(
                    title: "Ports apps keep open",
                    subtitle: "Raycast on :7265, Figma, Docker, and the like",
                    symbol: "app.connected.to.app.below.fill", tint: Palette.Vivid.blue,
                    isOn: $settings.nowShowsAppPorts
                )
                SettingsToggle(
                    title: "Ports macOS keeps open",
                    subtitle: "AirPlay Receiver on :5000 and :7000, Continuity",
                    symbol: "apple.logo", tint: Color(white: 0.45),
                    isOn: $settings.nowShowsSystemPorts
                )
                ForEach(settings.hiddenPortOwners, id: \.self) { key in
                    HiddenOwnerRow(key: key)
                }
            } header: {
                Text("Ports")
            } footer: {
                Text("Activity always lists every port. Hover one in the notch and click Hide to keep an app's ports out of Now.")
                    .settingsFooter()
            }

            Section {
                SettingsToggle(
                    title: "Claude and Codex limits",
                    subtitle: "Five-hour and weekly windows, and when they reset",
                    symbol: "gauge.with.dots.needle.67percent", tint: Palette.Vivid.blue,
                    isOn: $settings.showsUsageLimits
                )
                if settings.showsUsageLimits {
                    ForEach(model.limits.agents, id: \.self) { agent in
                        LimitStatusRow(agent: agent, state: model.limits.states[agent])
                    }
                }
            } header: {
                Text("Plan Limits")
            } footer: {
                Text("Only Anthropic and OpenAI know how much of your plan you've used, so Clove asks them, signed in as you: with the sign-in Claude Code saved in your Keychain, and the one Codex saved in ~/.codex. Clove reads them the same way the agents save them, so there's no password to type. It keeps them in memory only, sends them nowhere but to the agent's own maker, and never refreshes or changes them.")
                    .settingsFooter()
            }
        }
        .task(id: model.settings.showsUsageLimits) {
            if model.settings.showsUsageLimits { await model.limits.refresh() }
        }
    }

    /// Shown sections in order, then the hidden ones, so each has a row to drag.
    private var orderBinding: Binding<[NowSection]> {
        let settings = model.settings
        return Binding {
            settings.nowSections + NowSection.allCases.filter { !settings.nowSections.contains($0) }
        } set: { order in
            settings.nowSections = order.filter { settings.nowSections.contains($0) }
        }
    }
}

private struct HiddenOwnerRow: View {
    @Environment(AppModel.self) private var model
    let key: String

    var body: some View {
        LabeledContent {
            Button("Show Again") {
                withAnimation { model.settings.hiddenPortOwners.removeAll { $0 == key } }
            }
            .controlSize(.small)
        } label: {
            HStack(spacing: 10) {
                if key.hasSuffix(".app") {
                    Image(nsImage: AppIconCache.icon(key))
                        .resizable()
                        .frame(width: 22, height: 22)
                } else {
                    SettingsIcon(symbol: "gearshape.fill", tint: Color(white: 0.45))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(key.hasSuffix(".app") ? RunningScanner.appName(key) : key)
                    Text("Ports hidden from Now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct LimitStatusRow: View {
    let agent: AgentSession.Agent
    let state: UsageLimitsStore.State?

    var body: some View {
        LabeledContent {
            switch state {
            case .loaded(let limits):
                if let window = limits.windows.first {
                    StatusBadge(text: "\(Int(window.usedPercent.rounded()))% of \(window.title.lowercased()) used", tint: Palette.mint)
                }
            case .failed(let failure):
                StatusBadge(text: failure == .expired ? "Sign-in expired" : "Not connected", tint: Palette.Vivid.yellow)
                    .help(failure.message)
            case .loading, nil:
                ProgressView().controlSize(.small)
            }
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: AgentIcons.icon(for: agent))
                    .resizable()
                    .frame(width: 22, height: 22)
                Text([agent.title, state?.limits?.plan].compactMap(\.self).joined(separator: " "))
            }
        }
    }
}

extension Text {
    /// Footers in grouped forms: small, quiet, wrapping.
    func settingsFooter() -> some View {
        font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
