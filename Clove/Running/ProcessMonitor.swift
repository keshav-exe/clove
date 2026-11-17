import Darwin
import Foundation

/// One look at your processes: who started whom, what each costs, and the
/// ports they listen on.
struct ProcessSample: Sendable {
    let table: ProcessTable
    let ports: [Int32: [Int]]
    /// Processor time each process has used since it started, in nanoseconds.
    let cpuTime: [Int32: UInt64]
    /// When the look was taken, in nanoseconds of uptime.
    let takenAt: UInt64
}

/// Reads processes straight from the kernel with libproc, the way Activity
/// Monitor does, instead of starting `ps` and `lsof`. A look costs a few
/// milliseconds where the old pair cost a few hundred, and most of what it
/// learns is kept: a process's command line never changes, and its ports only
/// change while it runs.
actor ProcessMonitor {
    /// Lives as long as Clove; its argument buffer is never freed.
    static let shared = ProcessMonitor()

    private struct Identity {
        let started: UInt64
        let args: String
        let executable: String?
    }

    private var identities: [Int32: Identity] = [:]
    private var portCache: [Int32: (cpu: UInt64, ports: [Int])] = [:]
    private var last: ProcessSample?
    private let argumentBuffer: UnsafeMutableRawPointer
    private let argumentCapacity: Int

    init() {
        var mib: [Int32] = [CTL_KERN, KERN_ARGMAX]
        var max: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctl(&mib, 2, &max, &size, nil, 0)
        argumentCapacity = Int(max > 0 ? max : 1 << 20)
        argumentBuffer = .allocate(byteCount: argumentCapacity, alignment: 8)
    }

    /// A look no older than `maxAge`, so callers a moment apart share one.
    func sample(maxAge: Duration = .zero) -> ProcessSample {
        if let last, maxAge > .zero, Self.now() - last.takenAt < UInt64(maxAge.components.seconds) * 1_000_000_000 {
            return last
        }
        let next = take()
        last = next
        return next
    }

    private func take() -> ProcessSample {
        let user = getuid()
        let now = Self.now()
        let wall = Date.now
        var entries: [ProcessTable.Entry] = []
        var cpu: [Int32: UInt64] = [:]
        var ports: [Int32: [Int]] = [:]
        var alive: Set<Int32> = []

        for pid in Self.allPIDs() where pid > 0 {
            guard let info = Self.bsdInfo(pid), info.pbi_uid == user else { continue }
            alive.insert(pid)
            let started = UInt64(info.pbi_start_tvsec) * 1_000_000 + UInt64(info.pbi_start_tvusec)
            let identity: Identity
            if let known = identities[pid], known.started == started {
                identity = known
            } else {
                identity = Identity(started: started, args: arguments(of: pid) ?? Self.name(info), executable: Self.path(of: pid))
                identities[pid] = identity
            }
            let usage = Self.usage(pid)
            let time = usage.map { Self.nanoseconds($0.ri_user_time + $0.ri_system_time) } ?? 0
            cpu[pid] = time

            // Ports only change while a process runs; an idle one keeps its old list.
            if let cached = portCache[pid], cached.cpu == time {
                if !cached.ports.isEmpty { ports[pid] = cached.ports }
            } else {
                let found = Self.listeningPorts(of: pid)
                portCache[pid] = (time, found)
                if !found.isEmpty { ports[pid] = found }
            }

            let startDate = Date(timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec) + TimeInterval(info.pbi_start_tvusec) / 1_000_000)
            entries.append(ProcessTable.Entry(
                pid: pid,
                parent: Int32(info.pbi_ppid),
                elapsed: max(0, wall.timeIntervalSince(startDate)),
                residentKB: Int64(usage?.ri_phys_footprint ?? 0) / 1024,
                args: identity.args,
                executable: identity.executable
            ))
        }

        identities = identities.filter { alive.contains($0.key) }
        portCache = portCache.filter { alive.contains($0.key) }
        return ProcessSample(table: ProcessTable(entries: entries), ports: ports, cpuTime: cpu, takenAt: now)
    }

    // MARK: - Single processes

    /// The folder a process is working in, or nil for `/` and processes you don't own.
    nonisolated static func workingFolder(of pid: Int32) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafeBytes(of: info.pvi_cdir.vip_path) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        return path.isEmpty || path == "/" ? nil : path
    }

    /// The terminal a process is attached to, like `/dev/ttys003`.
    nonisolated static func terminal(of pid: Int32) -> String? {
        guard let info = bsdInfo(pid) else { return nil }
        guard info.e_tdev != UInt32.max, info.e_tdev != 0,
              let name = devname(dev_t(bitPattern: info.e_tdev), S_IFCHR) else { return nil }
        return "/dev/" + String(cString: name)
    }

    // MARK: - libproc

    nonisolated private static func allPIDs() -> [Int32] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(estimate) + 64)
        let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        return Array(pids.prefix(Int(max(0, count))))
    }

    nonisolated private static func bsdInfo(_ pid: Int32) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size ? info : nil
    }

    nonisolated private static func usage(_ pid: Int32) -> rusage_info_v4? {
        var usage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? usage : nil
    }

    nonisolated private static func path(of pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    nonisolated private static func name(_ info: proc_bsdinfo) -> String {
        withUnsafeBytes(of: info.pbi_comm) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    /// The command line, as `ps -o args` prints it, from `KERN_PROCARGS2`:
    /// argc, the executable path, padding, then each argument.
    private func arguments(of pid: Int32) -> String? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = argumentCapacity
        guard sysctl(&mib, 3, argumentBuffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        let bytes = UnsafeRawBufferPointer(start: argumentBuffer, count: size)
        let argc = Int(bytes.loadUnaligned(as: Int32.self))
        var index = MemoryLayout<Int32>.size
        // Skip the executable path, then the NULs padding it.
        while index < size, bytes[index] != 0 { index += 1 }
        while index < size, bytes[index] == 0 { index += 1 }
        var arguments: [String] = []
        while arguments.count < argc, index < size {
            let start = index
            while index < size, bytes[index] != 0 { index += 1 }
            arguments.append(String(decoding: bytes[start..<index], as: UTF8.self))
            index += 1
        }
        return arguments.isEmpty ? nil : arguments.joined(separator: " ")
    }

    /// TCP ports the process is listening on, from its open sockets.
    nonisolated private static func listeningPorts(of pid: Int32) -> [Int] {
        let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard needed > 0 else { return [] }
        let stride = MemoryLayout<proc_fdinfo>.stride
        var descriptors = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(needed) / stride + 8)
        let used = descriptors.withUnsafeMutableBytes { proc_pidinfo(pid, PROC_PIDLISTFDS, 0, $0.baseAddress, Int32($0.count)) }
        guard used > 0 else { return [] }

        var ports: Set<Int> = []
        let socketSize = Int32(MemoryLayout<socket_fdinfo>.size)
        for descriptor in descriptors.prefix(Int(used) / stride) where descriptor.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
            var socket = socket_fdinfo()
            guard proc_pidfdinfo(pid, descriptor.proc_fd, PROC_PIDFDSOCKETINFO, &socket, socketSize) == socketSize,
                  socket.psi.soi_kind == Int32(SOCKINFO_TCP) else { continue }
            let tcp = socket.psi.soi_proto.pri_tcp
            guard tcp.tcpsi_state == Int32(TSI_S_LISTEN) else { continue }
            let port = Int(UInt16(bigEndian: UInt16(truncatingIfNeeded: tcp.tcpsi_ini.insi_lport)))
            if port > 0 { ports.insert(port) }
        }
        return ports.sorted()
    }

    // MARK: - Time

    nonisolated private static let timebase: (numer: UInt64, denom: UInt64) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (UInt64(info.numer), UInt64(max(info.denom, 1)))
    }()

    /// rusage times are in Mach ticks on Apple silicon.
    nonisolated private static func nanoseconds(_ ticks: UInt64) -> UInt64 {
        ticks.multipliedReportingOverflow(by: timebase.numer).partialValue / timebase.denom
    }

    nonisolated static func now() -> UInt64 {
        nanoseconds(mach_continuous_time())
    }
}
