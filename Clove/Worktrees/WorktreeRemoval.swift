import Foundation

/// The words of a removal confirmation: what goes, and by name, anything that
/// can't be got back.
struct WorktreeRemoval: Sendable {
    let title: String
    let message: String
    let confirmLabel: String
    let losesWork: Bool

    init(_ worktrees: [GitWorktree], verdict: (GitWorktree) -> WorktreeVerdict) {
        let names = worktrees.map { "“\($0.name)”" }
        title = worktrees.count == 1 ? "Remove the worktree \(names[0])?" : "Remove \(worktrees.count) worktrees?"

        var paragraphs: [String] = []
        let losing = worktrees.filter { verdict($0).needsForce }
        for worktree in losing {
            guard let loss = verdict(worktree).lossDescription else { continue }
            var line = "\(worktree.name) has \(loss)"
            var files = Array((worktree.changes.modified + worktree.changes.untracked).prefix(4))
            if case .unsaved(.changes) = verdict(worktree), !files.isEmpty {
                let more = worktree.changes.count - files.count
                if more > 0 { files.append("\(more) more") }
                line = String(line.dropLast()) + ": " + ListFormatter.localizedString(byJoining: files) + "."
            }
            paragraphs.append(line)
        }
        let keepers = worktrees.flatMap { worktree in worktree.ignoredKeepers.map { "\(worktree.name)/\($0)" } }
        if !keepers.isEmpty {
            paragraphs.append("Ignored files that may exist nowhere else are deleted too: " + keepers.prefix(4).joined(separator: ", ") + (keepers.count > 4 ? ", and more." : "."))
        }
        let missing = worktrees.allSatisfy(\.isMissing)
        if missing {
            paragraphs.append("The folders are already gone; git only forgets them.")
        } else {
            paragraphs.append("Clove uses git worktree remove, so branches and their commits stay. The folders don't go to the Trash.")
        }
        losesWork = !losing.isEmpty
        message = paragraphs.joined(separator: "\n\n")
        confirmLabel = losesWork ? "Discard Work and Remove" : (worktrees.count == 1 ? "Remove Worktree" : "Remove \(worktrees.count) Worktrees")
    }
}
