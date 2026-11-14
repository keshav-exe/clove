import Foundation
import Observation

/// Every repo's worktrees, what each is safe to do with, and removing them.
/// Safe ones start picked for cleanup; anything else is the person's call.
@MainActor
@Observable
final class WorktreeStore {
    struct RemovalResult: Sendable {
        let count: Int
        let bytes: Int64
    }

    private(set) var repositories: Loadable<[GitRepository]> = .idle
    /// The worktree open in the inspector.
    var selection: GitWorktree.ID?
    var failure: ManagerFailure?
    private(set) var isRemoving = false
    private(set) var lastResult: RemovalResult?
    /// Safe worktrees the person chose to keep.
    var kept: Set<GitWorktree.ID> = []
    /// Worktrees that aren't safe but the person picked anyway.
    var added: Set<GitWorktree.ID> = []

    func scanIfNeeded(projectContainers: [URL]) async {
        guard repositories.value == nil, !repositories.isLoading else { return }
        await scan(projectContainers: projectContainers)
    }

    func scan(projectContainers: [URL]) async {
        if repositories.value == nil {
            repositories = .loading
        }
        let found = await WorktreeScanner.scan(projectContainers: projectContainers)
        repositories = .loaded(found)
        let ids = Set(found.flatMap(\.worktrees).map(\.id))
        kept.formIntersection(ids)
        added.formIntersection(ids)
        if let selection, !ids.contains(selection) { self.selection = nil }
    }

    /// Linked worktrees across every repo, main checkouts left out.
    var linked: [GitWorktree] {
        (repositories.value ?? []).flatMap(\.linked)
    }

    var selected: GitWorktree? {
        guard let selection else { return nil }
        return repositories.value?.lazy.flatMap(\.worktrees).first { $0.id == selection }
    }

    func repository(of worktree: GitWorktree) -> GitRepository? {
        let path = StorageSafety.trimmedPath(worktree.repositoryURL)
        return repositories.value?.first { $0.worktrees.contains { $0.id == worktree.id } || StorageSafety.trimmedPath($0.url) == path }
    }

    func verdict(for worktree: GitWorktree) -> WorktreeVerdict {
        WorktreeSafety.verdict(for: worktree)
    }

    var safe: [GitWorktree] {
        linked.filter { verdict(for: $0).isSafe }
    }

    // MARK: - Picking for cleanup

    func isPicked(_ worktree: GitWorktree) -> Bool {
        let verdict = verdict(for: worktree)
        guard verdict.isRemovable else { return false }
        return verdict.isSafe ? !kept.contains(worktree.id) : added.contains(worktree.id)
    }

    func togglePick(_ worktree: GitWorktree) {
        let verdict = verdict(for: worktree)
        guard verdict.isRemovable else { return }
        if verdict.isSafe {
            if kept.remove(worktree.id) == nil { kept.insert(worktree.id) }
        } else {
            if added.remove(worktree.id) == nil { added.insert(worktree.id) }
        }
    }

    var picked: [GitWorktree] {
        linked.filter(isPicked)
    }

    // MARK: - Removing

    /// Removes each with `git worktree remove`, forcing only the ones whose
    /// loss the person confirmed, then scans again.
    func remove(_ worktrees: [GitWorktree], projectContainers: [URL]) async {
        let removable = worktrees.filter { verdict(for: $0).isRemovable }
        guard !removable.isEmpty, !isRemoving else { return }
        isRemoving = true
        defer { isRemoving = false }

        var removed: [GitWorktree] = []
        var problems: [String] = []
        for worktree in removable {
            if let problem = await WorktreeScanner.remove(worktree, force: verdict(for: worktree).needsForce) {
                problems.append("\(worktree.name): \(problem)")
            } else {
                removed.append(worktree)
            }
        }
        if !removed.isEmpty {
            lastResult = RemovalResult(count: removed.count, bytes: removed.reduce(0) { $0 + $1.bytes })
        }
        if !problems.isEmpty {
            failure = ManagerFailure(
                title: problems.count == 1 ? "Couldn't remove a worktree" : "Couldn't remove \(problems.count) worktrees",
                message: problems.joined(separator: "\n")
            )
        }
        kept = []
        added = []
        await scan(projectContainers: projectContainers)
    }

    func dismissResult() {
        lastResult = nil
    }
}
