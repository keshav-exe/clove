import Foundation

/// One `ps` snapshot of the user's processes, with parent links.
struct ProcessTable: Sendable {
    struct Entry: Hashable, Sendable {
        let pid: Int32
        let parent: Int32
        let elapsed: TimeInterval
        let residentKB: Int64
        let args: String
        /// The executable's path from `ps -o comm`. Unlike splitting `args`,
        /// it survives paths with spaces, like Application Support.
        var executable: String?

        /// The program's file name: "claude", "node", "gk".
        var program: String {
            let path = executable ?? args.split(separator: " ").first.map(String.init) ?? args
            return (path as NSString).lastPathComponent
        }
    }

    let entries: [Int32: Entry]
    let children: [Int32: [Int32]]

    init(entries: [Entry]) {
        var byPID: [Int32: Entry] = [:]
        var children: [Int32: [Int32]] = [:]
        for entry in entries {
            byPID[entry.pid] = entry
            children[entry.parent, default: []].append(entry.pid)
        }
        self.entries = byPID
        self.children = children
    }

    /// `ps -axo pid=,ppid=,etime=,rss=,args=` output, plus `ps -axo pid=,comm=`
    /// for executable paths.
    static func parse(_ output: String, executables: String = "") -> ProcessTable {
        var paths: [Int32: String] = [:]
        for line in executables.split(separator: "\n") {
            let trimmed = line.drop { $0 == " " }
            guard let space = trimmed.firstIndex(of: " "), let pid = Int32(trimmed[..<space]) else { continue }
            paths[pid] = String(trimmed[trimmed.index(after: space)...]).trimmingCharacters(in: .whitespaces)
        }
        let entries = output.split(separator: "\n").compactMap { line -> Entry? in
            let fields = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard fields.count == 5,
                  let pid = Int32(fields[0]),
                  let parent = Int32(fields[1]),
                  let rss = Int64(fields[3])
            else { return nil }
            return Entry(
                pid: pid,
                parent: parent,
                elapsed: elapsed(String(fields[2])),
                residentKB: rss,
                args: String(fields[4]),
                executable: paths[pid]
            )
        }
        return ProcessTable(entries: entries)
    }

    /// ps elapsed time: `[[dd-]hh:]mm:ss`.
    static func elapsed(_ text: String) -> TimeInterval {
        var days = 0.0
        var clock = Substring(text)
        if let dash = text.firstIndex(of: "-") {
            days = Double(text[..<dash]) ?? 0
            clock = text[text.index(after: dash)...]
        }
        let parts = clock.split(separator: ":").compactMap { Double($0) }
        let seconds = parts.reversed().enumerated().reduce(0.0) { total, item in
            total + item.element * pow(60, Double(item.offset))
        }
        return days * 86_400 + seconds
    }

    func ancestors(of pid: Int32) -> [Entry] {
        var chain: [Entry] = []
        var current = entries[pid]?.parent
        var seen: Set<Int32> = [pid]
        while let next = current, next > 1, seen.insert(next).inserted, let entry = entries[next] {
            chain.append(entry)
            current = entry.parent
        }
        return chain
    }

    /// This process and everything below it.
    func subtree(of pid: Int32) -> [Entry] {
        var result: [Entry] = []
        var stack = [pid]
        var seen: Set<Int32> = []
        while let next = stack.popLast(), seen.insert(next).inserted {
            if let entry = entries[next] { result.append(entry) }
            stack += children[next] ?? []
        }
        return result
    }
}
