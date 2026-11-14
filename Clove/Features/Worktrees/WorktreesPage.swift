import SwiftUI

/// Every repo with worktrees, each drawn as a small commit graph: the default
/// branch as a trunk and a lane per worktree. Picking a lane opens it in the
/// inspector, where it can be removed.
struct WorktreesPage: View {
    @Environment(AppModel.self) private var model

    private var store: WorktreeStore { model.worktrees }

    var body: some View {
        @Bindable var store = model.worktrees
        let repositories = store.repositories.value ?? []

        ListPage(selection: $store.selection, order: order(repositories)) {
            PageHeader(
                title: "Worktrees",
                summary: "Each lane is a checkout of its own, often made by an agent. See where it split from the main branch, what's still unsaved, and which are safe to clear away."
            )

            if !store.safe.isEmpty {
                WorktreesSafeCallout(safe: store.safe) {
                    model.show(.cleanup)
                }
            }

            ForEach(repositories) { repository in
                WorktreeRepositoryGraph(repository: repository, selection: $store.selection) { store.verdict(for: $0) }
            }

            if !repositories.isEmpty {
                WorktreeLegend()
            }
        }
        .navigationTitle("Worktrees")
        .overlay {
            switch store.repositories {
            case .idle, .loading:
                ProgressView("Reading your repositories…")
                    .controlSize(.small)
            case .loaded(let found) where found.isEmpty:
                CalmEmptyState(
                    title: "No worktrees",
                    message: "When you or an agent check out a branch in a folder of its own with git worktree, it shows up here as a lane beside its main branch."
                ) {
                    WorktreesArt()
                }
            default:
                EmptyView()
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Check Again", systemImage: "arrow.clockwise", action: rescan)
                    .disabled(store.repositories.isLoading)
                    .help("Read every repository's worktrees again")
            }
        }
        .task {
            await store.scanIfNeeded(projectContainers: model.settings.scanConfiguration.projectRoots)
        }
    }

    /// Row ids in on-screen order, for the arrow keys.
    private func order(_ repositories: [GitRepository]) -> [GitWorktree.ID] {
        repositories.flatMap { repository in
            repository.worktrees.filter(\.isMain).map(\.id) + WorktreeGraphLayout.ordered(repository.linked).map(\.id)
        }
    }

    private func rescan() {
        Task { await store.scan(projectContainers: model.settings.scanConfiguration.projectRoots) }
    }
}

/// A one-line nudge when some worktrees can go without losing anything.
private struct WorktreesSafeCallout: View {
    let safe: [GitWorktree]
    let review: () -> Void

    var body: some View {
        let bytes = safe.reduce(Int64(0)) { $0 + $1.bytes }
        Tile {
            HStack(spacing: Metrics.spacingM) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Palette.mint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(safe.count == 1 ? "1 worktree is safe to remove" : "\(safe.count) worktrees are safe to remove")
                        .prose(13, .medium)
                        .foregroundStyle(Palette.ink)
                    Text(bytes > 0 ? "Merged or idle, clean, and not in use. Together they take \(bytes.formatted(.byteCount(style: .file)))." : "Merged or idle, clean, and not in use.")
                        .prose(12)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Spacer(minLength: Metrics.spacingM)
                Button("Review in Cleanup", action: review)
                    .buttonStyle(.glass)
            }
        }
    }
}

/// What the lane colours mean, once, under the graphs.
private struct WorktreeLegend: View {
    var body: some View {
        let samples: [WorktreeVerdict] = [.safe(.merged), .active, .unsaved(.changes(WorktreeChanges())), .blocked(.inUse([]))]
        HStack(spacing: Metrics.spacingL) {
            ForEach(samples, id: \.self) { verdict in
                HStack(spacing: 5) {
                    Capsule()
                        .fill(verdict.tint)
                        .frame(width: 14, height: 3)
                    Text(verdict.shortTitle)
                        .prose(11)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            Spacer(minLength: 0)
            Text("Dots are commits ahead; lanes split as far back as they're behind.")
                .prose(11)
                .foregroundStyle(Palette.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .padding(.horizontal, 10)
        .accessibilityElement(children: .combine)
    }
}

struct WorktreesArt: View {
    var body: some View {
        MockStack {
            MockProcessCard(name: "codex/tests", detail: "Codex · 2 ahead")
        } middle: {
            MockProcessCard(name: "fix-sidebar", detail: "Merged · 41 MB")
        } front: {
            MockProcessCard(name: "claude/notch", detail: "Claude Code · 3 ahead · 1 behind")
        }
    }
}

struct WorktreesSidebarRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Label("Worktrees", systemImage: "arrow.triangle.branch")
            .badge(badge)
            .tag(SidebarItem.worktrees)
    }

    /// How many can go safely, once a scan has run.
    private var badge: Text? {
        let count = model.worktrees.safe.count
        return count == 0 ? nil : Text(count, format: .number)
    }
}
