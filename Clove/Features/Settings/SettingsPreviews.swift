import AppKit
import SwiftUI

// Small pictures of the notch, so a setting shows what it changes. Each is
// laid out at full size with the island's own type, symbols, cards and app
// icons, then shrunk, so it reads as the real thing rather than a cartoon.

extension NowSection {
    var tint: Color {
        switch self {
        case .agents: Palette.Vivid.violet
        case .ports: Palette.Vivid.green
        case .limits: Palette.Vivid.blue
        case .busy: Palette.Vivid.orange
        case .elsewhere: Color(white: 0.5)
        }
    }

    /// What the section shows, for its row in Settings.
    var detail: String {
        switch self {
        case .agents: "What each agent is doing, step by step, and which file it's changing"
        case .ports: "Running dev servers and the apps using ports"
        case .limits: "How much of your Claude, Codex and Cursor plans you've used"
        case .busy: "Apps using a lot of CPU right now"
        case .elsewhere: "How many MCP servers and containers are running"
        }
    }
}

// MARK: - Drawing at full size

/// Lays its content out at `width`, then shrinks it by `scale`, taking only
/// the shrunk space. With a `height` it's cropped to that, from the top.
struct Shrunk<Content: View>: View {
    let width: CGFloat
    var height: CGFloat?
    let scale: CGFloat
    @ViewBuilder let content: Content
    @State private var measured: CGFloat = 0

    var body: some View {
        let full = height ?? measured
        content
            .frame(width: width)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: width, height: height, alignment: .top)
            .clipped()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { measured = $0 }
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: width * scale, height: full * scale, alignment: .topLeading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The hardware notch, at its real size on a 14-inch MacBook Pro.
private let previewNotch = CGSize(width: 185, height: 32)

/// The strip of menu bar the notch sits in: a few menus on the left, the
/// usual status icons and the clock on the right.
private struct PreviewMenuBar: View {
    /// Draws Clove's own icon among the status icons, picked.
    var showsCloveIcon = false

    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(.primary.opacity(0.55)).frame(width: 12, height: 12)
            Capsule().fill(.primary.opacity(0.55)).frame(width: 46, height: 7)
            ForEach([30.0, 28, 34, 40], id: \.self) { width in
                Capsule().fill(.primary.opacity(0.28)).frame(width: width, height: 7)
            }
            Spacer(minLength: 0)
            if showsCloveIcon {
                Image(nsImage: Self.cloveIcon)
                    .renderingMode(.template)
                    .frame(width: 30, height: 24)
                    .background(.primary.opacity(0.16), in: .rect(cornerRadius: 6, style: .continuous))
            }
            Image(systemName: "battery.75percent")
            Image(systemName: "wifi")
            Image(systemName: "magnifyingglass")
            Image(systemName: "switch.2")
            Text("Tue 9:41")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .fixedSize()
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.primary.opacity(0.75))
        .padding(.horizontal, 18)
        .frame(height: previewNotch.height)
        .background(.primary.opacity(0.06))
    }

    private static let cloveIcon: NSImage = {
        let image = NSImage(resource: .menuBarIcon)
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }()
}

/// The open island hanging from the notch, black and dark-themed like the
/// real one, under a strip of menu bar.
private struct PreviewIsland<Content: View>: View {
    var width: CGFloat = NotchModel.panelWidth
    var radius: CGFloat = 26
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(width: width)
        .background(.black, in: UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous))
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(alignment: .top) {
            PreviewMenuBar()
        }
    }
}

/// The tab strip as it sits beside the notch: the tab's name on the left,
/// the tabs on the right, the camera in between.
private struct PreviewTabStrip: View {
    let blocks: [PanelBlock]
    var gap: CGFloat = previewNotch.width

    var body: some View {
        let picked = blocks.first
        HStack(spacing: 0) {
            Text(picked?.title ?? "")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: gap)
            HStack(spacing: 2) {
                ForEach(blocks) { block in
                    Image(systemName: block.symbol)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(block == picked ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .frame(width: 28, height: 24)
                        .background(.primary.opacity(block == picked ? 0.14 : 0), in: .capsule)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(height: previewNotch.height)
    }
}

// MARK: - Sample content

/// What the previews show: one agent mid-task, a dev server, two plans.
@MainActor
private enum PreviewSample {
    static let session = AgentSession(
        id: "settings-preview", agent: .claude, folder: URL(filePath: "/site"),
        title: "Tidy the onboarding copy", state: .working,
        steps: [
            .init(id: "1", verb: "Read", target: "Onboarding.swift", isDone: true),
            .init(id: "2", verb: "Edit", target: "Onboarding.swift", isDone: false),
        ],
        change: .init(name: "Onboarding.swift", added: 12, removed: 3),
        summary: nil, updatedAt: .now
    )
}

/// An agent at work, as its card on the Now board.
private struct PreviewAgentCard: View {
    var showsSteps = true

    var body: some View {
        let session = PreviewSample.session
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AgentAppIcon(session: session, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.title ?? "")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Claude · \(session.project)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    Circle().fill(session.glowColors.first ?? Palette.mint).frame(width: 6, height: 6)
                    Text("Working")
                }
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(.primary.opacity(0.06), in: .capsule)
            }
            if showsSteps {
                VStack(alignment: .leading, spacing: 5) {
                    step("checkmark", "Read Onboarding.swift", isCurrent: false)
                    step("arrow.right", "Edit Onboarding.swift", isCurrent: true)
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 12)
                        Text("Onboarding.swift")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("+12").foregroundStyle(Palette.mint)
                        Text("−3").foregroundStyle(Palette.Vivid.red)
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.top, 2)
                }
                .padding(.leading, 38)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, showsSteps ? 14 : 12)
        // The glow caught mid-breath: a picture shouldn't redraw every frame.
        .background {
            BreathingGlow(colors: session.glowColors, isStill: true)
                .clipShape(.rect(cornerRadius: 18, style: .continuous))
        }
        .notchCard()
    }

    private func step(_ symbol: String, _ text: String, isCurrent: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(isCurrent ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                .frame(width: 12)
            Text(text)
                .font(.system(size: 11.5, weight: isCurrent ? .medium : .regular))
                .foregroundStyle(isCurrent ? .primary : .secondary)
        }
    }
}

/// The Now tab's sections, drawn the way the board draws them.
private struct PreviewNowSection: View {
    let section: NowSection

    var body: some View {
        switch section {
        case .agents:
            PreviewAgentCard()
        case .ports:
            VStack(alignment: .leading, spacing: 2) {
                port(":3000", "vite · site", isServer: true)
                port(":5432", "Postgres", isServer: false)
            }
            .padding(4)
            .notchCard()
        case .limits:
            VStack(alignment: .leading, spacing: 14) {
                limit(.claude, plan: "Max", used: 42, footnote: "Resets in 2h 10m", week: 18)
                limit(.codex, plan: "Plus", used: 76, footnote: "Resets in 4h", week: 31)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .notchCard()
        case .busy:
            HStack(spacing: 8) {
                Image(systemName: "flame")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.Vivid.orange)
                    .frame(width: 12)
                Text("Xcode 180% · Simulator 64%")
                    .font(.system(size: 12, weight: .medium))
                Spacer(minLength: 6)
                Text("Busy")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .notchCard(radius: 10)
        case .elsewhere:
            HStack(spacing: 10) {
                label("3 MCP servers", "server.rack")
                label("1 container", "shippingbox")
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }

    private func port(_ port: String, _ detail: String, isServer: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isServer ? Palette.mint : Color.primary.opacity(0.3))
                .frame(width: 6, height: 6)
            Text(port)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            if isServer {
                Text("Open")
                    .font(.system(size: 11.5, weight: .semibold))
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(.primary.opacity(0.14), in: .capsule)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
    }

    private func limit(_ agent: LimitsAgent, plan: String, used: Double, footnote: String, week: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(nsImage: agent.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(agent.title)
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(plan)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 8)
                    Text("\(Int(used))%")
                        .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(used >= 70 ? LimitStyle.tint(used) : .primary)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.primary.opacity(0.1))
                        Capsule().fill(LimitStyle.tint(used))
                            .frame(width: proxy.size.width * used / 100)
                    }
                }
                .frame(height: 5)
                HStack(spacing: 6) {
                    Text(footnote).foregroundStyle(.tertiary)
                    Spacer(minLength: 6)
                    Text("Week \(week)%").foregroundStyle(.secondary)
                }
                .font(.system(size: 10.5).monospacedDigit())
            }
        }
    }

    private func label(_ text: String, _ symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
            Text(text)
        }
    }
}

// MARK: - Previews

/// The Now tab as it will look: the shown sections, in order.
struct NowLayoutPreview: View {
    let sections: [NowSection]

    var body: some View {
        Shrunk(width: 1040, scale: 0.5) {
            PreviewIsland {
                PreviewTabStrip(blocks: [.now, .skills, .storage])
                VStack(spacing: 8) {
                    if sections.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "moon.zzz")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("All quiet")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                    ForEach(sections) { section in
                        PreviewNowSection(section: section)
                            .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.1), value: sections)
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Preview: " + (sections.isEmpty ? "nothing shown" : sections.map(\.title).joined(separator: ", ")))
    }
}

/// The tabs beside the notch, in order, with the first one picked.
struct TabStripPreview: View {
    let blocks: [PanelBlock]

    var body: some View {
        Shrunk(width: 740, scale: 0.74) {
            PreviewIsland(radius: 14) {
                PreviewTabStrip(blocks: blocks)
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.15), value: blocks)
        .frame(maxWidth: .infinity)
    }
}

/// One way to have Clove around, drawn: the notch, or an icon in the menu bar.
struct AccessModeCard: View {
    let mode: AccessMode
    let isPicked: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                picture
                    .frame(height: 72)
                    .frame(maxWidth: .infinity)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(.rect(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isPicked ? Color.accentColor : Color.primary.opacity(isHovered ? 0.2 : 0.1), lineWidth: isPicked ? 2 : 1)
                    }
                HStack(spacing: 5) {
                    Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isPicked ? Color.accentColor : Color.secondary)
                    Text(mode.title)
                        .font(.callout.weight(isPicked ? .semibold : .regular))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    /// The top of a 14-inch screen, shown at half size: the island open under
    /// the notch, or Clove's panel under its menu bar icon.
    @ViewBuilder
    private var picture: some View {
        switch mode {
        case .notch:
            Shrunk(width: 540, height: 144, scale: 0.5) {
                PreviewIsland(width: 380) {
                    PreviewTabStrip(blocks: [.now, .skills, .storage, .trending])
                    PreviewAgentCard(showsSteps: false)
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                }
            }
        case .menuBar:
            Shrunk(width: 540, height: 144, scale: 0.5) {
                ZStack(alignment: .topTrailing) {
                    PreviewMenuBar(showsCloveIcon: true)
                    VStack(spacing: 0) {
                        PreviewTabStrip(blocks: [.now, .skills, .storage, .trending], gap: 0)
                        PreviewAgentCard(showsSteps: false)
                            .padding(.horizontal, 10)
                            .padding(.top, 2)
                            .padding(.bottom, 12)
                    }
                    .frame(width: 380)
                    .background(Color(white: 0.1), in: .rect(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    }
                    .environment(\.colorScheme, .dark)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .padding(.top, previewNotch.height + 6)
                    .padding(.trailing, 150)
                }
            }
        }
    }
}

/// One working mark to pick, playing as it would beside the notch.
struct AgentMarkChoice: View {
    let mark: AgentMark
    let isPicked: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                AgentMarkView(mark: mark)
                    .environment(\.colorScheme, .dark)
                    .frame(width: 40, height: 26)
                    .background(Color(white: 0.07), in: .rect(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(isPicked ? Color.accentColor : Color.primary.opacity(isHovered ? 0.25 : 0.1), lineWidth: isPicked ? 2 : 1)
                    }
                Text(mark.title)
                    .font(.caption)
                    .fontWeight(isPicked ? .semibold : .regular)
                    .foregroundStyle(isPicked ? .primary : .secondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(mark.title)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}
