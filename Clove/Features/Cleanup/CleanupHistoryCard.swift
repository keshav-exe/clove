import SwiftUI

/// Disk space held by old agent sessions, and one action to reclaim it.
struct CleanupHistoryCard: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirming = false

    private var cleanup: CleanupStore { model.cleanup }

    var body: some View {
        let all = cleanup.usage.value?.transcripts ?? []
        let old = cleanup.oldTranscripts
        let oldBytes = old.reduce(0) { $0 + $1.size }

        SkillDetailSection(title: "Agent History") {
            VStack(alignment: .leading, spacing: Metrics.spacingM) {
                if let result = cleanup.historyResult {
                    Label(
                        "Moved \(result.count.formatted()) sessions, \(Self.bytes(result.bytes)), to the Trash.",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                    Button("Undo", systemImage: "arrow.uturn.backward", action: undo)
                        .buttonStyle(.glass)
                } else {
                    Text(summary(all: all, old: old, oldBytes: oldBytes))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !old.isEmpty {
                        HStack(spacing: Metrics.spacingM) {
                            Button("Move \(old.count.formatted()) Old Sessions to Trash", systemImage: "archivebox") {
                                isConfirming = true
                            }
                            .buttonStyle(.glass)
                            .disabled(cleanup.isClearingHistory)

                            if cleanup.isClearingHistory {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .font(.callout)
        }
        .confirmationDialog(
            "Move \(old.count.formatted()) sessions to the Trash?",
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive, action: clear)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't be able to resume these sessions. Clove keeps its record of which skills you used.")
        }
    }

    private func summary(all: [TranscriptFile], old: [TranscriptFile], oldBytes: Int) -> String {
        let total = all.reduce(0) { $0 + $1.size }
        let base = "Claude Code, Codex, and Cursor keep \(Self.bytes(total)) of session history on this Mac."
        guard !old.isEmpty else { return base + " None of it is older than \(cleanup.window.phrase)." }
        return base + " \(Self.bytes(oldBytes)) of it is from sessions older than \(cleanup.window.phrase)."
    }

    private static func bytes(_ count: Int) -> String {
        Int64(count).formatted(.byteCount(style: .file))
    }

    private func clear() {
        Task { await cleanup.clearOldHistory() }
    }

    private func undo() {
        Task { await cleanup.undoHistory() }
    }
}
