import SwiftUI

/// What's running on your Mac and what it costs: the busiest apps first, then
/// agent sessions, the servers they started, and your containers.
struct RunningList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var running = model.running

        let kinds = RunningProcess.Kind.allCases

        ListPage(selection: $running.selection, order: kinds.flatMap { running.items(of: $0).map(\.id) }) {
            PageHeader(title: "Activity", summary: "What's running on your Mac and what it's costing. Quit or stop anything you're done with.")

            MacStatusTile()
            ActivitySection()

            ForEach(kinds, id: \.self) { kind in
                let items = running.items(of: kind)
                if !items.isEmpty {
                    ListSection(title: kind.title, note: items.count.formatted()) {
                        ForEach(items) { process in
                            SelectableRow(id: process.id, selection: $running.selection) {
                                RunningRow(process: process, isStopping: running.stopping.contains(process.pid))
                            }
                        }
                    }
                }
            }

            ContainersSection()
        }
        .navigationTitle("Activity")
        .overlay {
            switch running.processes {
            case .idle, .loading:
                ProgressView()
                    .controlSize(.small)
            case .loaded(let processes) where processes.isEmpty && model.containers.containers.isEmpty && running.activity.isEmpty:
                CalmEmptyState(
                    title: "Nothing running",
                    message: "Agent sessions, the MCP servers they start, and dev servers they leave behind show up here. Clove checks every few seconds."
                ) {
                    RunningArt()
                }
            default:
                EmptyView()
            }
        }
        .whileWindowVisible {
            await running.watch { model.knownServers }
        }
        .whileWindowVisible {
            await model.containers.watch()
        }
        .alert(
            model.containers.failure?.title ?? "",
            isPresented: Binding { model.containers.failure != nil } set: { if !$0 { model.containers.failure = nil } },
            presenting: model.containers.failure
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(failure.message)
        }
    }
}
