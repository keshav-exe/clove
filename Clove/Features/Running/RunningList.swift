import SwiftUI

/// Live list of agent sessions, MCP servers, and dev servers.
struct RunningList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var running = model.running

        let kinds = RunningProcess.Kind.allCases

        ListPage(selection: $running.selection, order: kinds.flatMap { running.items(of: $0).map(\.id) }) {
            PageHeader(title: "Running", summary: "Agent sessions, the servers they started, and your containers. Stop anything you're done with.")

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
        .navigationTitle("Running")
        .overlay {
            switch running.processes {
            case .idle, .loading:
                ProgressView()
                    .controlSize(.small)
            case .loaded(let processes) where processes.isEmpty && model.containers.containers.isEmpty:
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
        .task {
            await running.watch { model.knownServers }
        }
        .task {
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
