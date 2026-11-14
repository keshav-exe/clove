import Foundation

/// A repository with at least one linked worktree, as `git worktree list` sees it.
struct GitRepository: Identifiable, Hashable, Sendable {
    var id: String { url.path(percentEncoded: false) }
    /// The main worktree: the folder that holds `.git`.
    let url: URL
    /// The branch the others are measured against: "main", "master", …
    let defaultBranch: String?
    /// The main worktree first, then linked ones, newest commit first.
    let worktrees: [GitWorktree]

    var name: String { url.lastPathComponent }

    var linked: [GitWorktree] { worktrees.filter { !$0.isMain } }
}

/// One checkout of a repository and everything Clove knows about it.
struct GitWorktree: Identifiable, Hashable, Sendable {
    var id: String { url.path(percentEncoded: false) }
    let url: URL
    let repositoryURL: URL
    let isMain: Bool
    /// Short branch name, nil when detached.
    let branch: String?
    let head: String
    let isLocked: Bool
    /// Its folder is gone; git only needs to forget it.
    let isMissing: Bool
    let lastCommit: Date?
    let lastCommitSubject: String?
    let changes: WorktreeChanges
    /// Ignored files that removing the folder would delete for good, like `.env.local`.
    let ignoredKeepers: [String]
    /// Commits on this branch that the default branch doesn't have.
    let ahead: Int
    /// Commits on the default branch since this one split off.
    let behind: Int
    /// Its work is already in the default branch, merged or squashed.
    let isMerged: Bool
    /// Programs with their working folder inside it right now.
    let users: [String]
    let bytes: Int64
    /// The agent that made it, when the folder or branch name says so.
    let agent: String?

    var name: String { branch ?? url.lastPathComponent }
    var isDetached: Bool { branch == nil }
    var isInUse: Bool { !users.isEmpty }
}

/// Uncommitted work in a worktree, from `git status`.
struct WorktreeChanges: Hashable, Sendable {
    var modified: [String] = []
    var untracked: [String] = []

    var isEmpty: Bool { modified.isEmpty && untracked.isEmpty }
    var count: Int { modified.count + untracked.count }

    /// "3 changed files and 1 new file"
    var summary: String {
        var parts: [String] = []
        if !modified.isEmpty {
            parts.append(modified.count == 1 ? "1 changed file" : "\(modified.count) changed files")
        }
        if !untracked.isEmpty {
            parts.append(untracked.count == 1 ? "1 new file" : "\(untracked.count) new files")
        }
        return parts.isEmpty ? "No changes" : parts.joined(separator: " and ")
    }
}
