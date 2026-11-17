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
    /// The app it's running in, once Clove has found it.
    var host: AgentHost? = nil
    /// The message that started the current task, so a task is announced once
    /// however many times the agent pauses inside it.
    var promptID: String? = nil
    /// When you sent that message.
    var startedAt: Date? = nil
    /// Background commands and subagents it started this task that haven't
    /// reported back. The task isn't done while any are out.
    var backgroundJobs: Set<String> = []
    /// Why it stopped, when it stopped on an error rather than finishing.
    var failure: String? = nil
    /// Its last words end in a question: it's waiting on you, not done.
    var asksQuestion = false

    /// How long the task took, once it's over.
    var duration: TimeInterval? {
        startedAt.map { updatedAt.timeIntervalSince($0) }
    }

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
