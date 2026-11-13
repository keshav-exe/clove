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
                OverviewPage {
                    PageHeader(title: "Cleanup", summary: "Skills and commands nobody calls still cost context in every session. Clove reads your agent history to find them.")

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

                        Tile {
                            TileHeader(title: "Unused", note: candidates.count.formatted())
                        } content: {
                            VStack(spacing: 0) {
                                ForEach(candidates) { candidate in
                                    CleanupRow(
                                        candidate: candidate,
                                        isSelected: cleanup.isSelected(candidate),
                                        toggle: { cleanup.toggle(candidate) }
                                    )
                                    .padding(.vertical, 3)
                                    .overlay(alignment: .top) {
                                        Rectangle().fill(Palette.hairline).frame(height: 0.5)
                                    }
                                }
                            }
                        }
                    }

                    CleanupLeftoversCard()
                    CleanupHistoryCard()
                }
            } else {
                ProgressView("Reading agent history…")
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Cleanup")
        .animation(.smooth(duration: 0.25), value: cleanup.lastResult == nil)
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
