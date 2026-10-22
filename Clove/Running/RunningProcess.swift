import Foundation

/// An agent session, MCP server, or dev server running right now.
struct RunningProcess: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case agent
        case mcpServer
        case devServer

        var title: String {
            switch self {
            case .agent: "Agent Sessions"
            case .mcpServer: "MCP Servers"
            case .devServer: "Dev Servers"
            }
        }

        var symbolName: String {
            switch self {
            case .agent: "sparkles.rectangle.stack"
            case .mcpServer: "server.rack"
            case .devServer: "globe"
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

    var localURL: URL? {
        ports.first.flatMap { URL(string: "http://localhost:\($0)") }
    }
}
