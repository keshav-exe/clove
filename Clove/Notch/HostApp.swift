import AppKit
import Darwin

/// The app a process runs inside: the terminal, editor or Claude window an
/// agent was started from, found by walking up its parents.
enum HostApp {
    static func find(for pid: Int32) -> NSRunningApplication? {
        var current = pid
        for _ in 0..<24 {
            if let app = NSRunningApplication(processIdentifier: current), app.activationPolicy == .regular {
                return app
            }
            guard let parent = parent(of: current), parent > 1, parent != current else { return nil }
            current = parent
        }
        return nil
    }

    private static func parent(of pid: Int32) -> Int32? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ppid
    }

    /// The app hosting the agent working in `folder`, if Clove can see it running.
    @MainActor
    static func forAgent(in folder: URL?, running: RunningStore) -> NSRunningApplication? {
        guard let folder else { return nil }
        let path = folder.standardizedFileURL.path(percentEncoded: false)
        let agent = running.items(of: .agent).first { $0.folder?.standardizedFileURL.path(percentEncoded: false) == path }
        return agent.flatMap { find(for: $0.pid) }
    }
}
