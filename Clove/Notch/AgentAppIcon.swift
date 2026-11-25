import AppKit
import SwiftUI

/// The icon of the app an agent is running in: T3 Code, Cursor, Claude, your
/// terminal. It's the mark you already recognise, so the notch needs no
/// symbols of its own.
struct AgentAppIcon: View {
    let session: AgentSession
    var size: CGFloat = 18

    var body: some View {
        Image(nsImage: AgentIcons.icon(for: session))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A few app icons fanned out, overlapping, for several agents at once: one
/// per app, so three Cursor windows show one Cursor.
struct AgentIconStack: View {
    let sessions: [AgentSession]
    var size: CGFloat = 18
    var limit = 3

    /// How much each icon tucks under the one before it.
    static func overlap(for size: CGFloat) -> CGFloat { size * 0.42 }

    static func width(count: Int, size: CGFloat) -> CGFloat {
        guard count > 0 else { return 0 }
        return size + CGFloat(count - 1) * (size - overlap(for: size))
    }

    var body: some View {
        let shown = Array(AgentIcons.distinct(sessions).prefix(limit))
        HStack(spacing: -Self.overlap(for: size)) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, session in
                AgentAppIcon(session: session, size: size)
                    .modifier(StackedIconEdge(size: size))
                    .zIndex(Double(shown.count - index))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.36, bounce: 0.2), value: shown.map(\.id))
    }
}

/// A hairline around an icon's tile and a soft shadow under it, so icons
/// fanned over each other stay apart, and a dark icon still reads on black.
private struct StackedIconEdge: ViewModifier {
    let size: CGFloat

    func body(content: Content) -> some View {
        // macOS icons sit inside their canvas with a margin; the tile is about
        // 80% of it, with corners about a quarter of its width.
        let tile = size * 0.8
        content
            .overlay {
                RoundedRectangle(cornerRadius: tile * 0.225, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                    .frame(width: tile, height: tile)
            }
            .shadow(color: .black.opacity(0.6), radius: 1.5, x: 0.5, y: 0)
    }
}

@MainActor
enum AgentIcons {
    private static var byBundle: [String: NSImage] = [:]
    private static var fallbacks: [AgentSession.Agent: NSImage] = [:]

    static func icon(for session: AgentSession) -> NSImage {
        guard let host = session.host else { return fallback(for: session.agent) }
        if let cached = byBundle[host.bundlePath] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: host.bundlePath)
        byBundle[host.bundlePath] = icon
        return icon
    }

    /// One session per app, in order: the icons a stack shows.
    static func distinct(_ sessions: [AgentSession]) -> [AgentSession] {
        var seen: Set<String> = []
        return sessions.filter { seen.insert($0.host?.bundlePath ?? "agent:\($0.agent.rawValue)").inserted }
    }

    /// The agent maker's own app icon, for places without a session.
    static func icon(for agent: AgentSession.Agent) -> NSImage { fallback(for: agent) }

    /// Before the host is known: the agent maker's own app if it's installed,
    /// else Terminal, where CLI agents live.
    private static func fallback(for agent: AgentSession.Agent) -> NSImage {
        if let image = fallbacks[agent] { return image }
        let bundles: [String] = switch agent {
        case .claude: ["com.anthropic.claudefordesktop"]
        case .codex: ["com.openai.codex", "com.openai.chat"]
        }
        let workspace = NSWorkspace.shared
        let url = (bundles + ["com.apple.Terminal"]).lazy.compactMap { workspace.urlForApplication(withBundleIdentifier: $0) }.first
        let image = url.map { workspace.icon(forFile: $0.path(percentEncoded: false)) } ?? NSImage(systemSymbolName: "terminal", accessibilityDescription: nil) ?? NSImage()
        fallbacks[agent] = image
        return image
    }
}
