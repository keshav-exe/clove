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
        notch.agents.onFinished = { [weak self] session in
            self?.agentFinished(session)
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

    private func agentFinished(_ session: AgentSession) {
        guard model.settings.notchAgentMoments else { return }
        let host = HostApp.forAgent(in: session.folder, running: model.running)
        notch.present(NotchMoment(
            symbol: "checkmark",
            tone: .done,
            title: "\(session.agent.title) finished in \(session.project)",
            detail: session.summary ?? session.title,
            action: host.map { app in
                NotchMoment.Action(title: "Show") { app.activate() }
            },
            duration: .seconds(6)
        ))
    }

    // MARK: - Servers

    /// Looks every few seconds, faster while the board is on screen. The same
    /// look keeps the Now board and the Running block current.
    private func watchServers() async {
        while !Task.isCancelled {
            if model.settings.notchServerMoments || notch.isExpanded {
                let stopping = model.running.stopping
                await model.running.refresh(known: model.knownServers)
                guard !Task.isCancelled else { return }
                compareServers(stoppedByYou: stopping)
            }
            try? await Task.sleep(for: notch.isExpanded ? .seconds(2) : .seconds(5))
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
