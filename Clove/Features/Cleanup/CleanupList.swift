import SwiftUI

/// Every unused skill, checked by default. Unchecking one keeps it.
struct CleanupList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let cleanup = model.cleanup
        let candidates = model.cleanupCandidates

        List {
            ForEach(candidates) { candidate in
                CleanupRow(
                    candidate: candidate,
                    isSelected: cleanup.isSelected(candidate),
                    toggle: { cleanup.toggle(candidate) }
                )
            }
        }
        .listStyle(.inset)
        .navigationSplitViewColumnWidth(
            min: Metrics.listMinWidth,
            ideal: Metrics.listIdealWidth + 40,
            max: 460
        )
        .navigationTitle("Cleanup")
        .overlay {
            CleanupListStatus(state: cleanup.usage, isEmpty: candidates.isEmpty, window: cleanup.window)
        }
        .toolbar {
            ToolbarItem {
                Button("Rescan History", systemImage: "arrow.clockwise", action: rescan)
                    .disabled(cleanup.usage.isLoading)
                    .help("Read your agent history again")
            }
        }
        .task {
            await cleanup.scanIfNeeded()
        }
    }

    private func rescan() {
        Task { await model.cleanup.scan() }
    }
}
