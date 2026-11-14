import SwiftUI

/// Git worktrees agents and people left behind. Safe ones (clean, and merged
/// or idle, and not in use) start checked; others can be picked, and any work
/// they'd lose is named before anything goes.
struct CleanupWorktreesCard: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirming = false

    private var store: WorktreeStore { model.worktrees }

    var body: some View {
        Tile {
            TileHeader(title: "Worktrees", note: store.linked.isEmpty ? nil : store.linked.count.formatted()) {
                Button("Show Graph") { model.show(.worktrees) }
                    .buttonStyle(.link)
                    .prose(12)
                    .help("See every worktree as a lane beside its main branch")
            }
        } content: {
            VStack(alignment: .leading, spacing: Metrics.spacingM) {
                switch store.repositories {
                case .idle, .loading:
                    ProgressView()
                        .controlSize(.small)
                case .failed(let message):
                    Text(message)
                        .foregroundStyle(.secondary)
                case .loaded:
                    if let result = store.lastResult {
                        done(result)
                    } else if store.linked.isEmpty {
                        Text("No git worktrees in your projects or agents' worktree folders.")
                            .foregroundStyle(.secondary)
                    } else {
                        content
                    }
                }
            }
            .font(.callout)
        }
        .task {
            await store.scanIfNeeded(projectContainers: model.settings.scanConfiguration.projectRoots)
        }
        .worktreeRemovalConfirmation(isPresented: $isConfirming, worktrees: store.picked)
    }

    @ViewBuilder
    private var content: some View {
        let worktrees = store.linked.sorted { lhs, rhs in
            let left = rank(store.verdict(for: lhs)), right = rank(store.verdict(for: rhs))
            if left != right { return left < right }
            return lhs.bytes > rhs.bytes
        }
        let picked = store.picked
        let pickedBytes = picked.reduce(Int64(0)) { $0 + $1.bytes }

        Text(summary(safe: store.safe.count, total: worktrees.count, pickedBytes: pickedBytes))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        VStack(spacing: 0) {
            ForEach(worktrees) { worktree in
                row(worktree)
            }
        }

        HStack(spacing: Metrics.spacingM) {
            Button(picked.count == 1 ? "Remove 1 Worktree…" : "Remove \(picked.count) Worktrees…", systemImage: "trash") {
                isConfirming = true
            }
            .buttonStyle(.glass)
            .disabled(picked.isEmpty || store.isRemoving)
            if store.isRemoving {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func row(_ worktree: GitWorktree) -> some View {
        let verdict = store.verdict(for: worktree)
        return Toggle(isOn: Binding(get: { store.isPicked(worktree) }, set: { _ in store.togglePick(worktree) })) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingM) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: Metrics.spacingXS) {
                        Text(worktree.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(URL(filePath: worktree.repositoryURL.path(percentEncoded: false)).lastPathComponent)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: verdict.symbolName)
                            .foregroundStyle(verdict.tint)
                        Text(detail(worktree, verdict: verdict))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .font(.caption)
                }
                Spacer(minLength: Metrics.spacingM)
                if worktree.bytes > 0 {
                    Text(worktree.bytes.formatted(.byteCount(style: .file)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.checkbox)
        .disabled(!verdict.isRemovable)
        .padding(.vertical, 5)
        .help(worktree.displayPath)
        .contextMenu {
            Button("Show in Worktrees", systemImage: "arrow.triangle.branch") {
                store.selection = worktree.id
                model.show(.worktrees)
            }
            Button("Reveal in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([worktree.url])
            }
            .disabled(worktree.isMissing)
        }
    }

    private func detail(_ worktree: GitWorktree, verdict: WorktreeVerdict) -> String {
        var parts = [verdict.title]
        if let agent = worktree.agent { parts.append(agent) }
        return parts.joined(separator: " · ")
    }

    private func summary(safe: Int, total: Int, pickedBytes: Int64) -> String {
        let lead = safe == 0
            ? "None of your \(total) worktrees is clearly safe to remove."
            : "\(safe) of \(total) worktrees are clean, merged or idle, and not in use."
        return pickedBytes > 0 ? lead + " Removing the checked ones frees \(pickedBytes.formatted(.byteCount(style: .file)))." : lead
    }

    /// Safe first, then in progress, then unsaved, then the ones that can't go.
    private func rank(_ verdict: WorktreeVerdict) -> Int {
        switch verdict {
        case .safe: 0
        case .active: 1
        case .unsaved: 2
        case .blocked: 3
        }
    }

    private func done(_ result: WorktreeStore.RemovalResult) -> some View {
        HStack(spacing: Metrics.spacingM) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.mint)
            Text(result.count == 1 ? "Removed 1 worktree" : "Removed \(result.count) worktrees")
                + Text(result.bytes > 0 ? " and freed \(result.bytes.formatted(.byteCount(style: .file)))." : ".")
            Spacer(minLength: Metrics.spacingM)
            Button("Done") { store.dismissResult() }
                .controlSize(.small)
        }
    }
}
