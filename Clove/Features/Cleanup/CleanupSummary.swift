import SwiftUI

/// The case for cleaning up, led by one number: the context every agent
/// session spends listing things nobody calls. Old session history sits below.
struct CleanupSummary: View {
    @Environment(AppModel.self) private var model

    private var cleanup: CleanupStore { model.cleanup }

    var body: some View {
        let candidates = model.cleanupCandidates

        Group {
            if let report = cleanup.usage.value {
                CleanupPage {
                    if let result = cleanup.lastResult {
                        CleanupDoneView(result: result, undo: undo, dismiss: cleanup.dismissResult)
                    } else if candidates.isEmpty {
                        CleanupAllClearView(skillCount: model.catalog.count, window: windowBinding)
                    } else {
                        CleanupCallout(
                            candidates: candidates,
                            selected: candidates.filter(cleanup.isSelected),
                            report: report,
                            window: windowBinding,
                            isRemoving: cleanup.isRemoving,
                            remove: { remove(candidates) }
                        )
                    }

                    CleanupHistoryCard()
                }
            } else {
                ProgressView("Reading agent history…")
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationSplitViewColumnWidth(min: Metrics.detailMinWidth, ideal: 460)
        .animation(.smooth(duration: 0.25), value: cleanup.lastResult == nil)
    }

    private var windowBinding: Binding<CleanupWindow> {
        Binding {
            cleanup.window
        } set: { window in
            cleanup.window = window
        }
    }

    private func remove(_ candidates: [CleanupCandidate]) {
        Task { await cleanup.remove(candidates, using: model.manager) }
    }

    private func undo() {
        Task { await cleanup.undo(using: model.manager) }
    }
}
