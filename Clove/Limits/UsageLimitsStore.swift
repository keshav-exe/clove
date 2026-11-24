import Foundation
import Observation

/// Claude, Codex and Cursor plan limits, checked every few minutes while turned on.
@MainActor
@Observable
final class UsageLimitsStore {
    enum State: Equatable {
        case loading
        case loaded(AgentLimits)
        case failed(LimitsFailure)

        var limits: AgentLimits? {
            if case .loaded(let limits) = self { return limits }
            return nil
        }
    }

    /// One entry per agent that's installed, Claude first.
    private(set) var states: [LimitsAgent: State] = [:]
    /// A window crossed into its last tenth since the previous check.
    var onNearlyUsed: (LimitsAgent, UsageWindow) -> Void = { _, _ in }

    @ObservationIgnored private var claudeCredentials: ClaudeLimitsClient.Credentials?
    @ObservationIgnored private var lastCheck: Date?
    @ObservationIgnored private var isChecking = false
    @ObservationIgnored private var warned: Set<String> = []

    var agents: [LimitsAgent] {
        LimitsAgent.allCases.filter { states[$0] != nil }
    }

    static var anyInstalled: Bool {
        ClaudeLimitsClient.isInstalled || CodexLimitsClient.isInstalled || CursorLimitsClient.isInstalled
    }

    /// Checks unless a check finished less than `maxAge` ago.
    func refresh(maxAge: Duration = .seconds(60)) async {
        if let lastCheck, Date.now.timeIntervalSince(lastCheck) < Double(maxAge.components.seconds) { return }
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false; lastCheck = .now }

        async let claude: State? = ClaudeLimitsClient.isInstalled ? await checkClaude() : nil
        async let codex: State? = CodexLimitsClient.isInstalled ? Self.state(await CodexLimitsClient.fetch()) : nil
        async let cursor: State? = CursorLimitsClient.isInstalled ? Self.state(await CursorLimitsClient.fetch()) : nil
        let results: [(LimitsAgent, State?)] = [(.claude, await claude), (.codex, await codex), (.cursor, await cursor)]

        for (agent, state) in results {
            guard let state else { states[agent] = nil; continue }
            // A failed check keeps the last good numbers rather than blanking the card.
            if case .failed(let failure) = state, failure != .expired, states[agent]?.limits != nil { continue }
            states[agent] = state
            if let limits = state.limits { noteNearlyUsed(limits) }
        }
    }

    /// Polls while turned on. The window resets slowly, so a few minutes is plenty.
    func watch(isEnabled: @escaping @MainActor () -> Bool) async {
        while !Task.isCancelled {
            if isEnabled() {
                await refresh(maxAge: .seconds(240))
            }
            try? await Task.sleep(for: .seconds(300))
        }
    }

    #if DEBUG
    /// For previews and snapshot checks.
    func showPreview(_ states: [LimitsAgent: State]) { self.states = states }
    #endif

    func reset() {
        states = [:]
        claudeCredentials = nil
        lastCheck = nil
    }

    private func checkClaude() async -> State {
        if claudeCredentials == nil || claudeCredentials?.expiresAt.map({ $0 < .now }) == true {
            // Only reread the Keychain when needed: each read may prompt.
            switch await ClaudeLimitsClient.credentials() {
            case .success(let credentials): claudeCredentials = credentials
            case .failure(let failure): return .failed(failure)
            }
        }
        guard let credentials = claudeCredentials else { return .failed(.denied) }
        let result = await ClaudeLimitsClient.fetch(credentials)
        if case .failure(.expired) = result { claudeCredentials = nil }
        return Self.state(result)
    }

    private static func state(_ result: Result<AgentLimits, LimitsFailure>) -> State {
        switch result {
        case .success(let limits): .loaded(limits)
        case .failure(let failure): .failed(failure)
        }
    }

    private func noteNearlyUsed(_ limits: AgentLimits) {
        for window in limits.windows {
            let key = "\(limits.agent.rawValue).\(window.id).\(window.resetsAt?.timeIntervalSince1970 ?? 0)"
            if window.isNearlyUsed {
                if warned.insert(key).inserted, lastCheck != nil { onNearlyUsed(limits.agent, window) }
            }
        }
    }
}
