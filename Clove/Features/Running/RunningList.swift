import SwiftUI

/// Live list of agent sessions, MCP servers, and dev servers.
struct RunningList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var running = model.running

        List(selection: $running.selection) {
            ForEach(RunningProcess.Kind.allCases, id: \.self) { kind in
                let items = running.items(of: kind)
                if !items.isEmpty {
                    Section(kind.title) {
                        ForEach(items) { process in
                            RunningRow(process: process, isStopping: running.stopping.contains(process.pid))
                                .tag(process.id)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Running")
        .overlay {
            switch running.processes {
            case .idle, .loading:
                ProgressView()
                    .controlSize(.small)
            case .loaded(let processes) where processes.isEmpty:
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
    }
}
