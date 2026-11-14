import AppKit
import SwiftUI

/// The icon of the app an agent is running in: Claude, ChatGPT, Cursor, your
/// terminal. It's the mark you already recognise, so the notch needs no
/// symbols of its own.
struct AgentAppIcon: View {
    @Environment(AppModel.self) private var model
    let session: AgentSession
    var size: CGFloat = 18

    var body: some View {
        Image(nsImage: AgentIcons.icon(for: session, running: model.running))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

@MainActor
enum AgentIcons {
    /// By session, once its host app is known. Before then the agent's own app
    /// stands in, and the cache stays open so the real host can replace it.
    private static var cache: [String: NSImage] = [:]

    static func icon(for session: AgentSession, running: RunningStore) -> NSImage {
        if let cached = cache[session.id] { return cached }
        if let host = HostApp.forAgent(in: session.folder, running: running), let icon = host.icon {
            cache[session.id] = icon
            return icon
        }
        return fallback(for: session.agent)
    }

    private static var fallbacks: [AgentSession.Agent: NSImage] = [:]

    /// The agent maker's own app if it's installed, else Terminal, where CLI agents live.
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
