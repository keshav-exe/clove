import Foundation

/// An agent session, MCP server, or dev server running right now.
struct RunningProcess: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case agent
        case mcpServer
        case devServer
        /// A port an app keeps open for itself: Raycast's extension backend,
        /// Figma's font helper, AirPlay Receiver on :5000.
        case appPort

        var title: String {
            switch self {
            case .agent: "Agent Sessions"
            case .mcpServer: "MCP Servers"
            case .devServer: "Dev Servers"
            case .appPort: "App Ports"
            }
        }

        var symbolName: String {
            switch self {
            case .agent: "sparkles.rectangle.stack"
            case .mcpServer: "server.rack"
            case .devServer: "globe"
            case .appPort: "app.connected.to.app.below.fill"
            }
        }
    }

    var id: Int32 { pid }
    let pid: Int32
    let kind: Kind
    let name: String
    /// The agent or app that started it, when Clove can tell.
    let startedBy: String?
    let command: String
    let startedAt: Date
    /// Resident memory of this process and everything it started.
    let memoryBytes: Int64
    let ports: [Int]
    let folder: URL?
    /// The app holding the port, for app ports and servers an app started.
    var owner: PortOwner? = nil

    var localURL: URL? {
        ports.first.flatMap { URL(string: "http://localhost:\($0)") }
    }
}

/// The app, or part of macOS, a listening port belongs to.
struct PortOwner: Hashable, Sendable {
    /// "Raycast", "Figma Agent", "AirPlay Receiver".
    let name: String
    /// The app bundle, when there is one, for its icon and for activating it.
    let bundlePath: String?
    /// Part of macOS rather than an app you installed.
    let isSystem: Bool

    /// What hiding "ports from this app" remembers.
    var key: String { bundlePath ?? name }
}
