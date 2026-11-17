import AppKit

/// Decides which changes deserve a moment:
/// an agent finishing a turn, a dev server starting or stopping, the disk
/// running low. Everything else waits quietly in the Now board.
@MainActor
final class NotchLiveMonitor {
    private let model: AppModel
    private let notch: NotchModel
    private var tasks: [Task<Void, Never>] = []
    /// Dev servers from the last look, by pid, so the first look announces nothing.
    private var knownServers: [Int32: RunningProcess]?
    private var lastLowDiskWarning: Date?

    init(model: AppModel, notch: NotchModel) {
        self.model = model
        self.notch = notch
        notch.agents.onFinished = { [weak self] sessions in
            self?.agentsFinished(sessions)
        }
    }

    func start() {
        guard tasks.isEmpty else { return }
        notch.agents.start()
        tasks = [
            Task { [weak self] in await self?.watchServers() },
            Task { [weak self] in await self?.watchDisk() },
        ]
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
    }

    // MARK: - Agents

    /// Quick replies take less than this; you were likely watching anyway.
    static let shortTask: TimeInterval = 10

    private func agentsFinished(_ sessions: [AgentSession]) {
        guard model.settings.notchAgentMoments else { return }
        let front = NSWorkspace.shared.frontmostApplication?.bundleURL?.path(percentEncoded: false)
        let worth = sessions.filter { session in
            // An error is always worth saying; otherwise skip what you're already looking at.
            if session.failure != nil { return true }
            if let host = session.host?.bundlePath, let front, front.hasPrefix(host) { return false }
            return (session.duration ?? .infinity) >= Self.shortTask
        }
        guard let first = worth.first else { return }

        if worth.count > 1 {
            notch.present(NotchMoment(
                symbol: "checkmark",
                tone: worth.contains { $0.failure != nil } ? .warning : .done,
                title: "\(worth.count) agents finished",
                detail: worth.map(\.project).joined(separator: ", "),
                duration: .seconds(6)
            ))
            return
        }

        let session = first
        let who = session.agent.title
        let show = NotchMoment.Action(title: "Show") { AgentReveal.show(session) }
        if let failure = session.failure {
            notch.present(NotchMoment(symbol: "exclamationmark.triangle", tone: .warning, title: "\(who) stopped in \(session.project)", detail: failure, action: show, duration: .seconds(8)))
        } else if session.asksQuestion {
            notch.present(NotchMoment(symbol: "questionmark.bubble", tone: .neutral, title: "\(who) has a question in \(session.project)", detail: session.summary ?? session.title, action: show, duration: .seconds(8)))
        } else {
            let took = session.duration.flatMap(Self.durationText).map { " · \($0)" } ?? ""
            notch.present(NotchMoment(symbol: "checkmark", tone: .done, title: "\(who) finished in \(session.project)\(took)", detail: session.summary ?? session.title, action: show, duration: .seconds(6)))
        }
    }

    /// "4 min", "1 hr 5 min": how long the whole task ran, background work included.
    nonisolated static func durationText(_ seconds: TimeInterval) -> String? {
        guard seconds >= 60 else { return nil }
        return Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    // MARK: - Servers

    /// Looks every ten seconds, every two while the board is on screen. The
    /// same look keeps the Now board and the Running block current. A look is
    /// a few milliseconds of kernel reads, and it waits out sleep and a hot Mac.
    private func watchServers() async {
        while !Task.isCancelled {
            if model.settings.notchServerMoments || notch.isExpanded {
                let stopping = model.running.stopping
                await model.running.refresh(known: model.knownServers)
                guard !Task.isCancelled else { return }
                compareServers(stoppedByYou: stopping)
            }
            let hot = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
            try? await Task.sleep(for: notch.isExpanded ? .seconds(2) : .seconds(hot ? 30 : 10))
        }
    }

    private func compareServers(stoppedByYou: Set<Int32>) {
        let current = Dictionary(model.running.items(of: .devServer).map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        defer { knownServers = current }
        guard let previous = knownServers, model.settings.notchServerMoments else { return }

        for (pid, server) in current where previous[pid] == nil {
            guard let port = server.ports.first, let url = server.localURL else { continue }
            notch.present(NotchMoment(
                symbol: "globe",
                tone: .neutral,
                title: "localhost:\(port) is up",
                detail: [server.name, server.folder?.lastPathComponent].compactMap(\.self).joined(separator: " · "),
                action: NotchMoment.Action(title: "Open") { NSWorkspace.shared.open(url) }
            ))
        }
        for (pid, server) in previous where current[pid] == nil && !stoppedByYou.contains(pid) {
            guard let port = server.ports.first else { continue }
            notch.present(NotchMoment(
                symbol: "stop.fill",
                tone: .warning,
                title: "localhost:\(port) stopped",
                detail: [server.name, server.folder?.lastPathComponent].compactMap(\.self).joined(separator: " · ")
            ))
        }
    }

    // MARK: - Disk

    private static let lowDiskBytes: Int64 = 10 * 1_000_000_000

    private func watchDisk() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(120))
            guard !Task.isCancelled, model.settings.notchStorageMoments,
                  let volume = StorageVolume.current(), volume.available < Self.lowDiskBytes else { continue }
            // Once every few hours is a reminder; more is nagging.
            if let last = lastLowDiskWarning, Date.now.timeIntervalSince(last) < 6 * 3600 { continue }
            lastLowDiskWarning = .now
            notch.present(NotchMoment(
                symbol: "internaldrive",
                tone: .warning,
                title: "Only \(StorageFormat.capacity(volume.available)) free",
                detail: "Caches and agent leftovers are often the quickest win.",
                action: NotchMoment.Action(title: "Review") { [weak self] in
                    self?.openStorage()
                },
                duration: .seconds(7)
            ))
        }
    }

    var openStorage: () -> Void = {}
}
