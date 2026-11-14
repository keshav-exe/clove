import SwiftUI

/// The case for cleaning up, led by one number: the context every agent
/// session spends listing things nobody calls. Old session history sits below.
struct CleanupSummary: View {
    @Environment(AppModel.self) private var model

    private var cleanup: CleanupStore { model.cleanup }
    @State private var isShowingKept = false

    var body: some View {
        let candidates = model.cleanupCandidates

        Group {
            if let report = cleanup.usage.value {
                OverviewPage {
                    PageHeader(title: "Cleanup", summary: "Skills and commands you don't use still take up room in every agent session. Clove checks your history to find them.")

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
                            TileHeader(title: "Unused", note: candidates.count.formatted()) {
                                if !cleanup.alwaysKept.isEmpty {
                                    Button("\(cleanup.alwaysKept.count) always kept") {
                                        isShowingKept = true
                                    }
                                    .buttonStyle(.link)
                                    .prose(12)
                                    .help("Skills and commands you keep out of every cleanup")
                                }
                            }
                        } content: {
                            DividedRows {
                                ForEach(candidates) { candidate in
                                    CleanupRow(
                                        candidate: candidate,
                                        isSelected: cleanup.isSelected(candidate),
                                        toggle: { cleanup.toggle(candidate) }
                                    )
                                    .padding(.vertical, 3)
                                    .contextMenu {
                                        Button("Always Keep", systemImage: "lock") {
                                            withAnimation(.easeOut(duration: 0.2)) { cleanup.alwaysKeep(candidate) }
                                        }
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
        .sheet(isPresented: $isShowingKept) {
            AlwaysKeptSheet()
                .environment(model)
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

/// The skills and commands kept out of every cleanup, and the way to let one back in.
private struct AlwaysKeptSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let kept = model.cleanup.alwaysKept.sorted()
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            Text("Always Kept")
                .font(.headline)
            Text("Cleanup never lists these, however long they go unused.")
                .font(.callout)
                .foregroundStyle(.secondary)
            List(kept, id: \.self) { id in
                HStack {
                    Text(Self.name(for: id))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Stop Keeping") { model.cleanup.stopAlwaysKeeping(id) }
                        .controlSize(.small)
                }
            }
            .frame(minHeight: 180)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    /// "skill:/Users/…/animations" reads as "animations".
    private static func name(for id: String) -> String {
        let raw = id.hasPrefix("skill:") ? String(id.dropFirst("skill:".count)) : id
        return raw.contains("/") ? URL(filePath: raw).lastPathComponent : raw
    }
}
