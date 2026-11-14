import Foundation

/// Whether a worktree can go, and why. Removing one never deletes its branch,
/// so committed work survives; what can be lost is uncommitted changes and
/// commits that only a detached HEAD points at.
enum WorktreeVerdict: Hashable, Sendable {
    /// Safe to remove: nothing would be lost.
    case safe(Reason)
    /// Fine to remove, but it has recent work of its own, so it's not picked for you.
    case active
    /// Removing it would lose work; it needs a confirmation that names what.
    case unsaved(Loss)
    /// Can't be removed from Clove right now.
    case blocked(Block)

    enum Reason: Hashable, Sendable {
        /// Its folder is already gone; git just needs to forget it.
        case missing
        /// Everything it has is in the default branch.
        case merged
        /// No commits for a while; its branch keeps them.
        case stale(days: Int)
    }

    enum Loss: Hashable, Sendable {
        case changes(WorktreeChanges)
        /// Commits reachable only from a detached HEAD.
        case detachedCommits(Int)
        case both(WorktreeChanges, commits: Int)
    }

    enum Block: Hashable, Sendable {
        case main
        case inUse([String])
        case locked
    }

    var isSafe: Bool {
        if case .safe = self { true } else { false }
    }

    var isRemovable: Bool {
        if case .blocked = self { false } else { true }
    }

    var needsForce: Bool {
        if case .unsaved = self { true } else { false }
    }

    /// A few words for a row: "Merged", "In use by Claude Code".
    var title: String {
        switch self {
        case .safe(.missing): "Folder already gone"
        case .safe(.merged): "Merged"
        case .safe(.stale(let days)): "No commits in \(days) days"
        case .active: "Work in progress"
        case .unsaved(.changes(let changes)): changes.summary
        case .unsaved(.detachedCommits(let count)): count == 1 ? "1 commit on no branch" : "\(count) commits on no branch"
        case .unsaved(.both(let changes, let commits)): "\(changes.summary), \(commits) commits on no branch"
        case .blocked(.main): "Main checkout"
        case .blocked(.inUse(let users)): "In use by " + ListFormatter.localizedString(byJoining: users)
        case .blocked(.locked): "Locked"
        }
    }

    /// What removing it would cost, said plainly for a confirmation.
    var lossDescription: String? {
        switch self {
        case .unsaved(.changes(let changes)):
            "\(changes.summary) that were never committed."
        case .unsaved(.detachedCommits(let count)):
            "\(count == 1 ? "1 commit" : "\(count) commits") that no branch points to."
        case .unsaved(.both(let changes, let commits)):
            "\(changes.summary) that were never committed, and \(commits == 1 ? "1 commit" : "\(commits) commits") that no branch points to."
        default:
            nil
        }
    }
}

enum WorktreeSafety {
    /// A branch with no commits for this long is stale.
    static let staleDays = 30

    static func verdict(for worktree: GitWorktree, now: Date = .now) -> WorktreeVerdict {
        if worktree.isMain { return .blocked(.main) }
        if worktree.isMissing { return .safe(.missing) }
        if worktree.isInUse { return .blocked(.inUse(worktree.users)) }
        if worktree.isLocked { return .blocked(.locked) }

        let orphaned = worktree.isDetached && !worktree.isMerged ? worktree.ahead : 0
        switch (worktree.changes.isEmpty, orphaned) {
        case (false, 0): return .unsaved(.changes(worktree.changes))
        case (false, let commits): return .unsaved(.both(worktree.changes, commits: commits))
        case (true, 0): break
        case (true, let commits): return .unsaved(.detachedCommits(commits))
        }

        if worktree.isMerged { return .safe(.merged) }
        if let last = worktree.lastCommit {
            let days = Int(now.timeIntervalSince(last) / 86_400)
            if days >= staleDays { return .safe(.stale(days: days)) }
        }
        return .active
    }
}
