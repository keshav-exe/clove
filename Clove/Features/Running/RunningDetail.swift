import SwiftUI

struct RunningDetail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let running = model.running
        Group {
            if let process = running.selected {
                RunningDetailView(process: process, isStopping: running.stopping.contains(process.pid))
            } else if case .loaded(let processes) = running.processes, processes.isEmpty {
                Color.clear
            } else {
                CalmEmptyState(
                    title: "Pick a process",
                    message: "You'll see what started it, where it runs, and how much memory it holds. Stop it here if it's left over."
                ) {
                    RunningArt()
                }
            }
        }
        .alert(
            running.failure?.title ?? "",
            isPresented: Binding(get: { running.failure != nil }, set: { if !$0 { running.failure = nil } }),
            presenting: running.failure
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(failure.message)
        }
    }
}
