import SwiftUI

/// Browser builds, npx installs, and old Claude Code versions agents left on
/// disk. Outdated ones start checked; the newest of each stays unchecked.
struct CleanupLeftoversCard: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirming = false

    private var cleanup: CleanupStore { model.cleanup }

    var body: some View {
        SkillDetailSection(title: "Agent Leftovers") {
            VStack(alignment: .leading, spacing: Metrics.spacingM) {
                switch cleanup.leftovers {
                case .idle, .loading:
                    ProgressView()
                        .controlSize(.small)
                case .failed(let message):
                    Text(message)
                        .foregroundStyle(.secondary)
                case .loaded(let items):
                    if let result = cleanup.leftoverResult {
                        CleanupLeftoversDone(result: result, undo: undo)
                    } else if items.isEmpty {
                        Text("No test browsers, npx installs, or old Claude Code versions on this Mac.")
                            .foregroundStyle(.secondary)
                    } else {
                        content(items)
                    }
                }
            }
            .font(.callout)
        }
        .task {
            await cleanup.scanLeftovers()
        }
        .confirmationDialog(
            "Move \(cleanup.selectedLeftovers.count) items to the Trash?",
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive, action: remove)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Tools download what they need again the next time they run. Removed browsers stop appearing as apps, though Notifications may list them until you log out.")
        }
    }

    @ViewBuilder
    private func content(_ items: [LeftoverItem]) -> some View {
        let total = items.reduce(0) { $0 + $1.bytes }
        let selected = cleanup.selectedLeftovers
        let selectedBytes = selected.reduce(0) { $0 + $1.bytes }

        Text("Your agents' tools have downloaded \(Self.bytes(total)). \(Self.bytes(selectedBytes)) of it is selected below.")
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        ForEach(LeftoverKind.allCases) { kind in
            let group = items.filter { $0.kind == kind }
            if !group.isEmpty {
                CleanupLeftoverGroup(kind: kind, items: group)
            }
        }

        HStack(spacing: Metrics.spacingM) {
            Button("Move \(selected.count) to Trash", systemImage: "trash") { isConfirming = true }
                .buttonStyle(.glass)
                .disabled(selected.isEmpty || cleanup.isRemovingLeftovers)
            if cleanup.isRemovingLeftovers {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    static func bytes(_ count: Int64) -> String {
        count.formatted(.byteCount(style: .file))
    }

    private func remove() {
        Task { await cleanup.removeLeftovers() }
    }

    private func undo() {
        Task { await cleanup.undoLeftovers() }
    }
}
