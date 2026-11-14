import Foundation
import Observation

/// The agent conversations happening now, kept current from their
/// transcripts as the agents write them. Nothing here polls the agents or
/// talks to them: it only reads what they already write to disk.
@MainActor
@Observable
final class AgentActivityStore {
    /// Working sessions first, then the most recently finished.
    private(set) var sessions: [AgentSession] = []
    /// A turn ended while Clove was watching.
    var onFinished: (AgentSession) -> Void = { _ in }

    @ObservationIgnored private var byID: [String: AgentSession] = [:]
    /// Sessions seen working, so a transcript that was already finished when
    /// Clove opened doesn't announce itself.
    @ObservationIgnored private var seenWorking: Set<String> = []
    @ObservationIgnored private var watcher: FileWatcher?
    @ObservationIgnored private var pruneTask: Task<Void, Never>?

    private let home: URL

    init(home: URL = .homeDirectory) {
        self.home = home
    }

    private var claudeRoot: URL { home.appending(path: ".claude/projects", directoryHint: .isDirectory) }
    private var codexRoot: URL { home.appending(path: ".codex/sessions", directoryHint: .isDirectory) }

    /// How long a session stays on the island after its last write.
    nonisolated static func isFresh(_ session: AgentSession, now: Date = .now) -> Bool {
        let age = now.timeIntervalSince(session.updatedAt)
        switch session.state {
        // An agent waiting on a permission prompt writes nothing; give it a while.
        case .working: return age < 10 * 60
        case .finished: return age < 20 * 60
        case .interrupted: return age < 2 * 60
        }
    }

    var working: [AgentSession] {
        sessions.filter { $0.state == .working }
    }

    func start() {
        guard watcher == nil else { return }
        let roots = [claudeRoot, codexRoot]
        watcher = FileWatcher(paths: roots) { [weak self] paths in
            let files = paths.filter { $0.hasSuffix(".jsonl") }
            guard !files.isEmpty else { return }
            Task { @MainActor in self?.reload(Set(files)) }
        }
        Task { await scanRecent() }
        pruneTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                self?.publish()
            }
        }
    }

    func stop() {
        watcher = nil
        pruneTask?.cancel()
        pruneTask = nil
    }

    // MARK: - Reading

    /// Transcripts written in the last few minutes, read once at launch.
    private func scanRecent() async {
        let claude = claudeRoot
        let codex = codexRoot
        let files = await Task.detached(priority: .utility) {
            let cutoff = Date.now.addingTimeInterval(-20 * 60)
            return Self.recentFiles(in: claude, depth: 1, since: cutoff) + Self.recentFiles(in: codex, depth: 3, since: cutoff)
        }.value
        reload(Set(files.map { $0.path(percentEncoded: false) }))
    }

    private func reload(_ paths: Set<String>) {
        let claudePrefix = claudeRoot.path(percentEncoded: false)
        let codexPrefix = codexRoot.path(percentEncoded: false)
        let jobs: [(String, AgentSession.Agent)] = paths.compactMap { path in
            if path.hasPrefix(codexPrefix) { return (path, .codex) }
            // Only a project's own transcripts: subagents keep theirs a level deeper.
            if path.hasPrefix(claudePrefix), path.dropFirst(claudePrefix.count).split(separator: "/").count == 2 {
                return (path, .claude)
            }
            return nil
        }
        guard !jobs.isEmpty else { return }
        Task {
            let read = await Task.detached(priority: .utility) {
                jobs.map { path, agent in (path, AgentTranscriptReader.read(URL(filePath: path), agent: agent)) }
            }.value
            for (path, session) in read {
                guard let session else {
                    byID[path] = nil
                    continue
                }
                let previous = byID[path]
                byID[path] = session
                if session.state == .working { seenWorking.insert(path) }
                if session.state == .finished, previous?.state != .finished, seenWorking.contains(path) {
                    onFinished(session)
                }
            }
            publish()
        }
    }

    private func publish() {
        let now = Date.now
        byID = byID.filter { Self.isFresh($0.value, now: now) }
        let next = byID.values.sorted { lhs, rhs in
            if (lhs.state == .working) != (rhs.state == .working) { return lhs.state == .working }
            return lhs.updatedAt > rhs.updatedAt
        }
        if next != sessions { sessions = next }
    }

    nonisolated private static func recentFiles(in root: URL, depth: Int, since cutoff: Date) -> [URL] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        var level = [root]
        var found: [URL] = []
        for remaining in (0...depth).reversed() {
            var next: [URL] = []
            for folder in level {
                guard let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { continue }
                for item in items {
                    let values = try? item.resourceValues(forKeys: Set(keys))
                    if values?.isDirectory == true {
                        // Folders change when a file is added, not appended to, so look in all of them.
                        if remaining > 0 { next.append(item) }
                    } else if item.pathExtension == "jsonl", let date = values?.contentModificationDate, date > cutoff {
                        found.append(item)
                    }
                }
            }
            level = next
        }
        return found
    }
}
