import SwiftUI

/// The inspector beside Worktrees: the picked worktree, or a hint to pick one.
struct WorktreeDetail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let store = model.worktrees
        Group {
            if let worktree = store.selected {
                WorktreeDetailView(
                    worktree: worktree,
                    verdict: worktree.isMain ? .blocked(.main) : store.verdict(for: worktree),
                    defaultBranch: store.repository(of: worktree)?.defaultBranch
                )
            } else {
                CalmEmptyState(
                    title: "Pick a worktree",
                    message: "You'll see its branch, what's uncommitted, who's working in it, and whether it's safe to remove."
                ) {
                    WorktreesArt()
                }
            }
        }
        .alert(
            store.failure?.title ?? "",
            isPresented: Binding(get: { store.failure != nil }, set: { if !$0 { store.failure = nil } }),
            presenting: store.failure
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(failure.message)
        }
    }
}

struct WorktreeDetailView: View {
    @Environment(AppModel.self) private var model
    let worktree: GitWorktree
    let verdict: WorktreeVerdict
    let defaultBranch: String?

    @State private var isConfirming = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    Text(worktree.name)
                        .font(.title2.weight(.semibold))
                        .textSelection(.enabled)
                    WorktreeStatusMark(verdict: verdict)
                }

                Text(verdict.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SkillDetailSection(title: "Details") {
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Metrics.spacingL, verticalSpacing: Metrics.spacingS) {
                        row("Branch", worktree.branch ?? "None (detached at \(worktree.head.prefix(7)))", code: true)
                        if let defaultBranch, !worktree.isMain {
                            row("Against \(defaultBranch)", standing)
                        }
                        if let date = worktree.lastCommit {
                            row("Last commit", date.formatted(.relative(presentation: .named)))
                        }
                        if let agent = worktree.agent {
                            row("Made by", agent)
                        }
                        if worktree.isInUse {
                            row("In use by", ListFormatter.localizedString(byJoining: worktree.users))
                        }
                        if worktree.bytes > 0 {
                            row("Size", worktree.bytes.formatted(.byteCount(style: .file)))
                        }
                    }
                    .font(.callout)
                }

                SkillDetailSection(title: "Folder") {
                    // Its own block, wrapped: a long path in the grid would widen the inspector past the window.
                    Text(worktree.displayPath)
                        .codeLabel(11.5)
                        .foregroundStyle(Palette.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let subject = worktree.lastCommitSubject {
                    SkillDetailSection(title: "Latest commit") {
                        Text(subject)
                            .font(.callout)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !worktree.changes.isEmpty {
                    SkillDetailSection(title: "Uncommitted") {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(worktree.changes.modified.prefix(12), id: \.self) { path in
                                fileLine(path, symbol: "pencil", tint: Palette.Vivid.orange)
                            }
                            ForEach(worktree.changes.untracked.prefix(12), id: \.self) { path in
                                fileLine(path, symbol: "plus", tint: Palette.mint)
                            }
                            let shown = min(worktree.changes.modified.count, 12) + min(worktree.changes.untracked.count, 12)
                            if worktree.changes.count > shown {
                                Text("and \(worktree.changes.count - shown) more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !worktree.ignoredKeepers.isEmpty {
                    SkillDetailSection(title: "Ignored, only here") {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(worktree.ignoredKeepers, id: \.self) { path in
                                fileLine(path, symbol: "key", tint: Palette.inkSecondary)
                            }
                            Text("Git ignores these, so removing the worktree deletes them with nothing to restore from.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(Metrics.spacingXL)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(worktree.name)
        .toolbar {
            ToolbarItemGroup {
                if !worktree.isMissing {
                    Button("Reveal in Finder", systemImage: "folder") {
                        NSWorkspace.shared.activateFileViewerSelecting([worktree.url])
                    }
                    .help("Show this worktree in Finder")
                    Button("Open in Terminal", systemImage: "terminal") {
                        openInTerminal()
                    }
                    .help("Open a Terminal window in this folder")
                }
                if !worktree.isMain {
                    Button("Remove…", systemImage: "trash") { isConfirming = true }
                        .disabled(!verdict.isRemovable || model.worktrees.isRemoving)
                        .help(verdict.isRemovable ? "Remove with git worktree remove" : verdict.title)
                }
            }
        }
        .worktreeRemovalConfirmation(isPresented: $isConfirming, worktrees: [worktree])
    }

    private var standing: String {
        if worktree.isMerged { return worktree.ahead == 0 ? "Nothing new, \(worktree.behind) behind" : "Merged" }
        return "\(worktree.ahead) ahead, \(worktree.behind) behind"
    }

    private func row(_ label: String, _ value: String, code: Bool = false) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .font(code ? .callout.monospaced() : .callout)
                .textSelection(.enabled)
                .lineLimit(3)
                .truncationMode(.middle)
        }
    }

    private func fileLine(_ path: String, symbol: String, tint: Color) -> some View {
        Label {
            Text(path)
                .codeLabel(11.5)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 12)
        }
    }

    private func openInTerminal() {
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
        NSWorkspace.shared.open([worktree.url], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }
}

extension View {
    /// Asks before removing worktrees, naming any work that would be lost.
    func worktreeRemovalConfirmation(isPresented: Binding<Bool>, worktrees: [GitWorktree]) -> some View {
        modifier(WorktreeRemovalConfirmation(isPresented: isPresented, worktrees: worktrees))
    }
}

private struct WorktreeRemovalConfirmation: ViewModifier {
    @Environment(AppModel.self) private var model
    @Binding var isPresented: Bool
    let worktrees: [GitWorktree]

    func body(content: Content) -> some View {
        let store = model.worktrees
        let removal = WorktreeRemoval(worktrees, verdict: store.verdict(for:))
        content.confirmationDialog(removal.title, isPresented: $isPresented, titleVisibility: .visible) {
            Button(removal.confirmLabel, role: .destructive) {
                let chosen = worktrees
                Task { await store.remove(chosen, projectContainers: model.settings.scanConfiguration.projectRoots) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(removal.message)
        }
    }
}
