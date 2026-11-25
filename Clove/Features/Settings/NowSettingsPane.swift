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
                Text("Drag to reorder. Empty sections stay hidden. You can also right-click a section in the notch to move or hide it.")
                    .settingsFooter()
            }

            Section {
                SettingsToggle(
                    title: "Dev servers",
                    subtitle: "Node, Vite, Rails, Postgres and anything your agents start",
                    symbol: "globe", tint: Palette.Vivid.green,
                    isOn: $settings.nowShowsDevServers
                )
                SettingsToggle(
                    title: "Ports apps keep open",
                    subtitle: "Like Raycast, Figma and Docker",
                    symbol: "app.connected.to.app.below.fill", tint: Palette.Vivid.blue,
                    isOn: $settings.nowShowsAppPorts
                )
                SettingsToggle(
                    title: "Ports macOS keeps open",
                    subtitle: "Like AirPlay Receiver and Continuity",
                    symbol: "apple.logo", tint: Color(white: 0.45),
                    isOn: $settings.nowShowsSystemPorts
                )
                ForEach(settings.hiddenPortOwners, id: \.self) { key in
                    HiddenOwnerRow(key: key)
                }
            } header: {
                Text("Ports")
            } footer: {
                Text("Activity always lists every port. To hide an app's ports here, hover one in the notch and click Hide.")
                    .settingsFooter()
            }

            Section {
                SettingsToggle(
                    title: "Plan limits",
                    subtitle: "How much of your Claude, Codex and Cursor plans you've used, and when it resets",
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
                Text("Only Anthropic, OpenAI and Cursor know how much you've used, so Clove asks them with the sign-ins your agents already saved. You never type a password. Clove keeps those sign-ins in memory, sends each one only to the company it came from, and never changes them.")
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
    let agent: LimitsAgent
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
                Image(nsImage: agent.icon)
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
