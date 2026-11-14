import Foundation

/// One agent conversation, as its transcript tells it: what it's doing now,
/// the steps of the current turn, and the file it last touched.
struct AgentSession: Identifiable, Equatable, Sendable {
    enum Agent: String, Sendable {
        case claude
        case codex

        var title: String {
            switch self {
            case .claude: "Claude"
            case .codex: "Codex"
            }
        }

        var app: AgentApp {
            switch self {
            case .claude: .claudeCode
            case .codex: .codex
            }
        }
    }

    enum State: Equatable, Sendable {
        /// Mid-turn: thinking or running tools.
        case working
        /// The turn ended and the agent is waiting for you.
        case finished
        /// You stopped it.
        case interrupted
    }

    struct Step: Identifiable, Equatable, Sendable {
        let id: String
        /// "Read", "Edit", "Run": a verb you'd say out loud.
        let verb: String
        /// The file name, command or query it acted on.
        let target: String?
        var isDone: Bool
    }

    /// Lines changed in the last file the agent edited this turn.
    struct FileChange: Equatable, Sendable {
        let name: String
        var added: Int
        var removed: Int
    }

    /// The transcript's path, unique per conversation.
    let id: String
    let agent: Agent
    var folder: URL?
    var title: String?
    var state: State
    /// This turn's steps, oldest first.
    var steps: [Step]
    var change: FileChange?
    /// The agent's last words, for a finished turn.
    var summary: String?
    var updatedAt: Date

    var project: String {
        folder?.lastPathComponent ?? agent.title
    }

    /// The step in flight, if any.
    var currentStep: Step? {
        steps.last { !$0.isDone }
    }

    var statusText: String {
        switch state {
        case .working:
            if let step = currentStep {
                return [step.verb, step.target].compactMap(\.self).joined(separator: " ")
            }
            return "Thinking"
        case .finished: return "Done"
        case .interrupted: return "Stopped"
        }
    }
}
