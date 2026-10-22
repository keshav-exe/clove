import Foundation
import Observation

/// What's running now. Refreshes every few seconds while someone is looking.
@MainActor
@Observable
final class RunningStore {
    private(set) var processes: Loadable<[RunningProcess]> = .idle
    var selection: RunningProcess.ID?
    var failure: ManagerFailure?
    /// Processes asked to stop that haven't exited yet.
    private(set) var stopping: Set<Int32> = []

    func refresh(known: [RunningScanner.KnownServer]) async {
        if processes.value == nil {
            processes = .loading
        }
        let found = await RunningScanner.scan(known: known)
        processes = .loaded(found)
        stopping = stopping.filter { pid in found.contains { $0.pid == pid } }
        if let selection, !found.contains(where: { $0.pid == selection }) {
            self.selection = nil
        }
    }

    /// Polls until the view goes away; the task is cancelled with it.
    func watch(known: @escaping @MainActor () -> [RunningScanner.KnownServer]) async {
        while !Task.isCancelled {
            await refresh(known: known())
            try? await Task.sleep(for: .seconds(3))
        }
    }

    func items(of kind: RunningProcess.Kind) -> [RunningProcess] {
        (processes.value ?? []).filter { $0.kind == kind }
    }

    var selected: RunningProcess? {
        guard let selection else { return nil }
        return processes.value?.first { $0.pid == selection }
    }

    /// Asks the process to quit (SIGTERM), the way closing it normally would.
    func stop(_ process: RunningProcess, force: Bool = false) {
        guard kill(process.pid, force ? SIGKILL : SIGTERM) == 0 else {
            failure = ManagerFailure(
                title: "Couldn't stop \(process.name)",
                message: String(cString: strerror(errno))
            )
            return
        }
        stopping.insert(process.pid)
    }
}
