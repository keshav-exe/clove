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
    /// Tasks that ended while Clove was watching, gathered over a few seconds
    /// so agents finishing together arrive together.
    var onFinished: ([AgentSession]) -> Void = { _ in }
    /// How long a task has to stay ended before it's announced: a stop hook or
    /// a queued message can start it again straight away.
    static let settleDelay: Duration = .seconds(4)

    @ObservationIgnored private var byID: [String: AgentSession] = [:]
    /// Sessions seen working, so a transcript that was already finished when
    /// Clove opened doesn't announce itself.
    @ObservationIgnored private var seenWorking: Set<String> = []
    @ObservationIgnored private var watcher: FileWatcher?
    @ObservationIgnored private var pruneTask: Task<Void, Never>?
    /// Hosts found so far, by session. A conversation never changes app.
    @ObservationIgnored private var hosts: [String: AgentHost] = [:]
    @ObservationIgnored private var lastHostLookup: [String: Date] = [:]
    /// The task each session last announced, so one task is announced once.
    @ObservationIgnored private var announced: [String: String] = [:]
    @ObservationIgnored private var settling: Set<String> = []
    @ObservationIgnored private var settleTask: Task<Void, Never>?

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
        // Background work can run a long time without a word in the transcript.
        case .working where !session.backgroundJobs.isEmpty: return age < 60 * 60
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
                    settle(path)
                }
            }
            publish()
            findHosts()
        }
    }

    /// Announces a task once it has stayed ended for the settle delay, along
    /// with any others that ended meanwhile.
    private func settle(_ path: String) {
        settling.insert(path)
        guard settleTask == nil else { return }
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard let self, !Task.isCancelled else { return }
            let ready = settling.compactMap { path -> AgentSession? in
                guard var session = byID[path], session.state == .finished,
                      announced[path] != session.promptID ?? "" else { return nil }
                announced[path] = session.promptID ?? ""
                session.host = hosts[path]
                return session
            }
            settling.removeAll()
            settleTask = nil
            if !ready.isEmpty { onFinished(ready) }
        }
    }

    /// Looks for the app each new conversation runs in, from its agent's
    /// process. One that isn't found yet is tried again a little later.
    private func findHosts() {
        let now = Date.now
        let missing = byID.values.filter { session in
            hosts[session.id] == nil && session.folder != nil
                && (lastHostLookup[session.id].map { now.timeIntervalSince($0) > 15 } ?? true)
        }
        guard !missing.isEmpty else { return }
        for session in missing { lastHostLookup[session.id] = now }
        let jobs = missing.compactMap { session in session.folder.map { (session.id, WorktreeScanner.realPath($0), session.agent) } }
        let apps = RunningStore.dockApps()
        Task {
            let sample = await ProcessMonitor.shared.sample(maxAge: .seconds(5))
            let found = await Task.detached(priority: .utility) {
                jobs.compactMap { id, folder, agent in
                    AgentHostFinder.find(folder: folder, agent: agent, sample: sample, apps: apps, workingFolder: ProcessMonitor.workingFolder(of:))
                        .map { (id, $0) }
                }
            }.value
            guard !found.isEmpty else { return }
            for (id, host) in found { hosts[id] = host }
            publish()
        }
    }

    private func publish() {
        let now = Date.now
        byID = byID.filter { Self.isFresh($0.value, now: now) }
        hosts = hosts.filter { byID[$0.key] != nil }
        lastHostLookup = lastHostLookup.filter { byID[$0.key] != nil }
        let next = byID.values.map { session in
            var session = session
            session.host = hosts[session.id]
            return session
        }.sorted { lhs, rhs in
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
