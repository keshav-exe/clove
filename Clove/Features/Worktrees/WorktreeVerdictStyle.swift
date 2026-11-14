import SwiftUI

/// How a verdict reads at a glance: one colour for the lane and its mark, a
/// symbol, and a two-word label. Colour only where it carries meaning.
extension WorktreeVerdict {
    var tint: Color {
        switch self {
        case .safe(.missing): Palette.inkTertiary
        case .safe: Palette.mint
        case .active: Palette.Vivid.violet
        case .unsaved: Palette.Vivid.orange
        case .blocked(.inUse): Palette.accent
        case .blocked: Palette.inkSecondary
        }
    }

    var symbolName: String {
        switch self {
        case .safe(.missing): "questionmark.folder"
        case .safe: "checkmark.circle.fill"
        case .active: "hammer"
        case .unsaved: "exclamationmark.triangle.fill"
        case .blocked(.inUse): "waveform.path.ecg"
        case .blocked(.locked): "lock.fill"
        case .blocked(.main): "house"
        }
    }

    var shortTitle: String {
        switch self {
        case .safe(.missing): "Folder gone"
        case .safe: "Safe to remove"
        case .active: "In progress"
        case .unsaved: "Unsaved work"
        case .blocked(.inUse): "In use"
        case .blocked(.locked): "Locked"
        case .blocked(.main): "Main"
        }
    }

    /// One or two sentences for the inspector: why it's in this state, and what removing it does.
    var explanation: String {
        switch self {
        case .safe(.missing):
            "Its folder was deleted, but git still lists it. Removing it only tidies git's records."
        case .safe(.merged):
            "Everything on this branch is already in the default branch, and nothing is uncommitted. Removing it frees the folder; the branch stays."
        case .safe(.stale(let days)):
            "Nobody has committed here in \(days) days and nothing is uncommitted. Removing it frees the folder; the branch and its commits stay."
        case .active:
            "This branch has commits the default branch doesn't, made in the last \(WorktreeSafety.staleDays) days. Removing the folder keeps the branch and its commits."
        case .unsaved:
            "Removing it would lose the work below. Commit or stash it first, or confirm you don't need it."
        case .blocked(.inUse(let users)):
            "\(ListFormatter.localizedString(byJoining: users)) is working in this folder. Quit it there before removing the worktree."
        case .blocked(.locked):
            "Someone locked this worktree so it isn't removed by accident. Unlock it with git worktree unlock to remove it."
        case .blocked(.main):
            "The repository's own folder. Other worktrees branch from it, and it can't be removed as a worktree."
        }
    }
}

/// The status mark at the end of a row: a symbol and a label in the verdict's colour.
struct WorktreeStatusMark: View {
    let verdict: WorktreeVerdict

    var body: some View {
        Label(verdict.shortTitle, systemImage: verdict.symbolName)
            .labelStyle(StatusLabelStyle())
            .foregroundStyle(verdict.tint)
            .help(verdict.title)
    }

    private struct StatusLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 4) {
                configuration.icon
                    .font(.system(size: 11, weight: .semibold))
                configuration.title
                    .prose(12, .medium)
            }
        }
    }
}

extension GitWorktree {
    /// "~/Developer/clove/.claude/worktrees/fix-nav"
    var displayPath: String {
        url.path(percentEncoded: false).replacing(URL.homeDirectory.path(percentEncoded: false), with: "~/")
    }

    /// "3 ahead · 12 behind · 2 days ago"
    var graphSummary: String {
        if isMissing { return "Folder deleted" }
        var parts: [String] = []
        if !isMain {
            parts.append(ahead == 0 ? "nothing new" : "\(ahead) ahead")
            if behind > 0 { parts.append("\(behind) behind") }
        }
        if let lastCommit {
            parts.append(lastCommit.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
        }
        return parts.joined(separator: " · ")
    }
}
