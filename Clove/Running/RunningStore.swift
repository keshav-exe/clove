import AppKit
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
    /// Apps and commands by what they cost, busiest first. Empty until two
    /// looks apart, since processor use is a difference between them.
    private(set) var activity: [AppActivity] = []
    @ObservationIgnored private var previous: ProcessSample?

    func refresh(known: [RunningScanner.KnownServer]) async {
        if processes.value == nil {
            processes = .loading
        }
        let scan = await RunningScanner.scan(known: known)
        let found = scan.processes
        processes = .loaded(found)
        let next = ActivityReport.build(
            current: scan.sample,
            previous: previous,
            apps: Self.dockApps(),
            ownPID: getpid(),
            folder: ProcessMonitor.workingFolder(of:)
        )
        previous = scan.sample
        if next != activity { activity = next }
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

    /// Apps you can see in the Dock, by bundle path.
    static func dockApps() -> [String: RunningAppInfo] {
        var apps: [String: RunningAppInfo] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let url = app.bundleURL else { continue }
            var path = url.path(percentEncoded: false)
            if path.count > 1, path.hasSuffix("/") { path.removeLast() }
            apps[path] = RunningAppInfo(name: app.localizedName ?? url.deletingPathExtension().lastPathComponent, bundleID: app.bundleIdentifier)
        }
        return apps
    }

    /// Quits an app the way its own Quit menu would, or stops a command.
    func end(_ group: AppActivity) {
        switch group.kind {
        case .app(let path, _):
            let app = NSWorkspace.shared.runningApplications.first { $0.bundleURL?.path(percentEncoded: false).hasPrefix(path) == true }
            if app?.terminate() != true {
                failure = ManagerFailure(title: "Couldn't quit \(group.name)", message: "It may be showing a dialog. Switch to it and quit from there.")
            }
        case .command:
            guard kill(group.rootPID, SIGTERM) == 0 else {
                failure = ManagerFailure(title: "Couldn't stop \(group.name)", message: String(cString: strerror(errno)))
                return
            }
            stopping.insert(group.rootPID)
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
