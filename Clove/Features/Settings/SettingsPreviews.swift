import SwiftUI

// Small drawings of the notch, so a setting shows what it changes. They're
// built from the same shapes as the island, at a fraction of the size.

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
        case .agents: "Each conversation at work, its steps, and the file it's changing"
        case .ports: "Dev servers, and the apps holding ports"
        case .limits: "How much of each Claude and Codex window you've used"
        case .busy: "Apps using more than half a core"
        case .elsewhere: "A count of MCP servers and containers"
        }
    }
}

/// A notch hanging from a strip of menu bar, its open island underneath.
struct MiniIsland<Content: View>: View {
    var width: CGFloat = 250
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // The menu bar, flat and faint.
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 12)
                UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16, style: .continuous)
                    .fill(Color(white: 0.06))
                    .frame(width: width)
                    .overlay(alignment: .top) {
                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                // The camera housing.
                                Capsule().fill(Color.black).frame(width: 62, height: 12)
                                Spacer()
                            }
                            content
                                .padding(.horizontal, 9)
                                .padding(.top, 7)
                                .padding(.bottom, 10)
                        }
                    }
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

/// The Now tab as it will look: the shown sections, in order.
struct NowLayoutPreview: View {
    let sections: [NowSection]

    var body: some View {
        MiniIsland {
            VStack(spacing: 5) {
                if sections.isEmpty {
                    Text("All quiet")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(height: 30)
                }
                ForEach(sections) { section in
                    block(section)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.15), value: sections)
        }
        .frame(height: 210, alignment: .top)
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Preview: " + (sections.isEmpty ? "nothing shown" : sections.map(\.title).joined(separator: ", ")))
    }

    @ViewBuilder
    private func block(_ section: NowSection) -> some View {
        switch section {
        case .agents:
            card(height: 30) {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.85, green: 0.47, blue: 0.34)).frame(width: 11, height: 11)
                    VStack(alignment: .leading, spacing: 2.5) {
                        line(width: 70, opacity: 0.6)
                        line(width: 46, opacity: 0.3)
                    }
                    Spacer()
                    Capsule().fill(Color.white.opacity(0.1)).frame(width: 24, height: 7)
                }
            }
            .background(alignment: .bottom) {
                // The breathing glow, caught mid-breath.
                Ellipse()
                    .fill(Color(red: 0.85, green: 0.47, blue: 0.34).opacity(0.55))
                    .frame(width: 120, height: 18)
                    .blur(radius: 9)
                    .offset(y: 4)
                    .clipShape(.rect(cornerRadius: 6))
            }
        case .ports:
            card(height: 22) {
                VStack(alignment: .leading, spacing: 3) {
                    portLine(":3000", dev: true)
                    portLine(":7265", dev: false)
                }
            }
        case .limits:
            card(height: 16) {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(red: 0.85, green: 0.47, blue: 0.34)).frame(width: 7, height: 7)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule().fill(Color.white.opacity(0.75)).frame(width: 70)
                    }
                    .frame(height: 2.5)
                }
            }
        case .busy:
            card(height: 14) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.system(size: 6)).foregroundStyle(Palette.Vivid.orange)
                    line(width: 80, opacity: 0.45)
                    Spacer()
                }
            }
        case .elsewhere:
            HStack(spacing: 4) {
                Image(systemName: "server.rack").font(.system(size: 6))
                line(width: 50, opacity: 0.35)
                Spacer()
            }
            .foregroundStyle(.secondary)
            .frame(height: 9)
            .padding(.horizontal, 3)
        }
    }

    private func card<Inner: View>(height: CGFloat, @ViewBuilder _ inner: () -> Inner) -> some View {
        inner()
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .background(Color.white.opacity(0.06), in: .rect(cornerRadius: 6, style: .continuous))
    }

    private func line(width: CGFloat, opacity: Double) -> some View {
        Capsule().fill(Color.white.opacity(opacity)).frame(width: width, height: 3)
    }

    private func portLine(_ port: String, dev: Bool) -> some View {
        HStack(spacing: 4) {
            Circle().fill(dev ? Palette.mint : Color.white.opacity(0.35)).frame(width: 3.5, height: 3.5)
            Text(port).font(.system(size: 6.5, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
            line(width: 34, opacity: 0.25)
        }
    }
}

/// The tabs beside the notch, in order, with the first one picked.
struct TabStripPreview: View {
    let blocks: [PanelBlock]

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 12)
            UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14, style: .continuous)
                .fill(Color(white: 0.06))
                .frame(width: 300, height: 34)
                .overlay {
                    HStack(spacing: 0) {
                        Text(blocks.first?.title ?? "")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Capsule().fill(Color.black).frame(width: 80, height: 14)
                        HStack(spacing: 2) {
                            ForEach(Array(blocks.enumerated()), id: \.element) { index, block in
                                Image(systemName: block.symbol)
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(index == 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                                    .frame(width: 20, height: 15)
                                    .background(Color.white.opacity(index == 0 ? 0.14 : 0), in: .capsule)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 2)
                }
                .animation(.spring(duration: 0.3, bounce: 0.15), value: blocks)
        }
        .frame(height: 46, alignment: .top)
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, .dark)
        .accessibilityHidden(true)
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
                    .frame(height: 64)
                    .frame(maxWidth: .infinity)
                    .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 8, style: .continuous))
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

    @ViewBuilder
    private var picture: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 10)
            switch mode {
            case .notch:
                UnevenRoundedRectangle(bottomLeadingRadius: 9, bottomTrailingRadius: 9, style: .continuous)
                    .fill(Color(white: 0.07))
                    .frame(width: 110, height: 40)
                    .overlay(alignment: .top) {
                        VStack(spacing: 4) {
                            Capsule().fill(Color.black).frame(width: 38, height: 9)
                            RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.1)).frame(width: 90, height: 9)
                            RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.07)).frame(width: 90, height: 6)
                        }
                    }
            case .menuBar:
                HStack(spacing: 5) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.25)).frame(width: 8, height: 6)
                    RoundedRectangle(cornerRadius: 2).fill(Color.accentColor).frame(width: 8, height: 6)
                    RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.25)).frame(width: 8, height: 6)
                    Spacer().frame(width: 18)
                }
                .frame(height: 10)
                .overlay(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .overlay {
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.15)).frame(height: 6)
                                RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.1)).frame(height: 6)
                                RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.1)).frame(height: 6)
                            }
                            .padding(6)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                        .frame(width: 70, height: 42)
                        .offset(x: -6, y: 14)
                }
            }
        }
        .clipShape(.rect(cornerRadius: 8, style: .continuous))
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
