import Foundation

/// Something on the disk big enough to be a row: an app, a project, a cache folder.
struct StorageItem: Identifiable, Hashable, Sendable, Codable {
    let url: URL
    let kind: StorageKind
    var bytes: Int64
    /// A whole folder counted as one row, like ~/.claude or ~/.cargo. Agents and
    /// toolchains live there, so Clove shows it but never trashes it.
    var isWholeRoot = false

    /// Whether Clove offers Move to Trash for this row.
    var canMoveToTrash: Bool {
        kind.allowsMoveToTrash && !isWholeRoot
    }

    var id: URL { url }

    var name: String {
        let name = url.lastPathComponent
        return url.pathExtension == "app" ? url.deletingPathExtension().lastPathComponent : name
    }
}

/// What one kind measured to, plus what the notes under the bar need.
struct StorageKindReport: Sendable, Codable {
    var bytes: Int64 = 0
    var files = 0
    /// Rows, largest first.
    var items: [StorageItem] = []
    var largestFile: StorageItem?
    var appCount = 0
    var audioFiles = 0
    /// Named parts worth calling out, like simulators or node_modules.
    var buckets: [StorageBucket: Int64] = [:]
    /// A root exists but macOS wouldn't let Clove read it (the Trash, without Full Disk Access).
    var isRestricted = false
}

enum StorageBucket: String, Sendable, CaseIterable, Codable {
    case simulators = "Old simulators"
    case buildOutput = "Build output"
    case nodeModules = "node_modules"
    case agentHistory = "Agent history"
    case models = "Downloaded models"
    case docker = "Docker"
    case photosLibrary = "Photos library"
}

/// Walks the folders a kind lives in and adds up what's allocated on disk,
/// reporting as it goes so the bar can count itself up while the scan runs.
struct StorageScanner: Sendable {
    /// At most this often per kind, so a big folder doesn't flood the main actor.
    static let progressInterval: TimeInterval = 0.09

    private static let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
    private static let audio: Set<String> = ["m4a", "mp3", "aac", "flac", "wav", "aiff", "aif", "alac", "m4p", "ogg"]

    /// Rows Clove keeps per kind. Caches and the Trash keep all of theirs:
    /// clearing goes through every one.
    private static let rowLimit = 100

    func scan(_ kind: StorageKind, progress: @Sendable (_ bytes: Int64, _ path: URL) -> Void) -> StorageKindReport {
        var report = StorageKindReport()
        var lastReport = Date.distantPast
        var checked = 0

        for root in kind.roots {
            let rootPath = root.url.standardizedFileURL.path(percentEncoded: false)
            let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
            guard FileManager.default.fileExists(atPath: rootPath) else { continue }
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: rootPath)
            } catch {
                report.isRestricted = true
                continue
            }

            guard let walker = FileManager.default.enumerator(
                at: root.url,
                includingPropertiesForKeys: Array(Self.keys),
                options: [],
                errorHandler: { _, _ in true }
            ) else { continue }

            // Rows by name. The walk is depth-first, so files arrive grouped by
            // row: add into a running total and only touch the table on a change.
            var rows: [String: Int64] = [:]
            var rowIsFolder: [String: Bool] = [:]
            var currentRow = ""
            var currentSum: Int64 = 0
            func flush() {
                guard currentSum > 0 else { return }
                rows[currentRow, default: 0] += currentSum
                currentSum = 0
            }

            // A bucket is a subtree, like a node_modules folder: set when the walk
            // enters it, so files inside need only a prefix check, not six searches.
            var bucket: StorageBucket?
            var bucketPrefix = ""

            // The enumerator hands back autoreleased objects; without a pool they
            // pile up for the whole walk, hundreds of megabytes on a big disk.
            var isDone = false
            while !isDone {
                isDone = autoreleasepool { () -> Bool in
                    for _ in 0..<512 {
                        guard let url = walker.nextObject() as? URL else { return true }
                        checked += 1
                        if checked & 0x3FF == 0, Task.isCancelled { return true }

                        guard let values = try? url.resourceValues(forKeys: Self.keys) else { continue }
                        let path = url.path(percentEncoded: false)

                        if bucket != nil, !path.hasPrefix(bucketPrefix) { bucket = nil }

                        guard values.isRegularFile == true else {
                            // A folder (or a link, which the walk doesn't follow).
                            if bucket == nil, let entered = Self.bucket(for: kind, folder: url, path: path) {
                                bucket = entered
                                bucketPrefix = path.hasSuffix("/") ? path : path + "/"
                            }
                            // Apps: a bundle at the top, or one folder down (Utilities), but
                            // not the helper apps nested inside another bundle.
                            if kind == .apps, url.pathExtension == "app", path.hasPrefix(prefix) {
                                let relative = path.dropFirst(prefix.count)
                                let parents = relative.dropLast(relative.hasSuffix("/") ? 1 : 0).split(separator: "/").dropLast()
                                if !parents.contains(where: { $0.hasSuffix(".app") }) { report.appCount += 1 }
                            }
                            continue
                        }

                        let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
                        guard size > 0 else { continue }
                        report.bytes += size
                        report.files += 1

                        if root.listsChildren, path.hasPrefix(prefix) {
                            let relative = path.dropFirst(prefix.count)
                            let slash = relative.firstIndex(of: "/")
                            let head = slash.map { relative[..<$0] } ?? relative
                            if head != currentRow[...] {
                                flush()
                                currentRow = String(head)
                                if rowIsFolder[currentRow] == nil { rowIsFolder[currentRow] = slash != nil }
                            }
                            currentSum += size
                        } else {
                            currentSum += size
                        }

                        if let bucket { report.buckets[bucket, default: 0] += size }
                        if size > (report.largestFile?.bytes ?? 0) {
                            report.largestFile = StorageItem(url: url, kind: kind, bytes: size)
                        }
                        if kind == .music, Self.audio.contains(url.pathExtension.lowercased()) {
                            report.audioFiles += 1
                        }

                        // Reading the clock every file costs more than it tells us.
                        if checked & 0x1FF == 0 {
                            let now = Date()
                            if now.timeIntervalSince(lastReport) >= Self.progressInterval {
                                lastReport = now
                                progress(report.bytes, url)
                            }
                        }
                    }
                    return false
                }
            }
            if Task.isCancelled { return report }
            flush()

            if root.listsChildren {
                for (name, bytes) in rows {
                    let url = root.url.appending(path: name, directoryHint: rowIsFolder[name] == true ? .isDirectory : .notDirectory)
                    report.items.append(StorageItem(url: url, kind: kind, bytes: bytes))
                }
            } else if let whole = rows[""] {
                report.items.append(StorageItem(url: root.url, kind: kind, bytes: whole, isWholeRoot: true))
            }
        }

        report.items.sort { $0.bytes > $1.bytes }
        if kind != .caches, kind != .trash, report.items.count > Self.rowLimit {
            report.items.removeSubrange(Self.rowLimit...)
        }
        return report
    }

    /// Re-measures one folder, after clearing it.
    func size(of url: URL) -> Int64 {
        guard let walker = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(Self.keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }
        var total: Int64 = 0
        for case let child as URL in walker {
            guard let values = try? child.resourceValues(forKeys: Self.keys), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        // A single file measures as itself.
        if total == 0, let values = try? url.resourceValues(forKeys: Self.keys), values.isRegularFile == true {
            total = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }

    /// Which bucket a folder starts, if any. Checked once per folder, outermost
    /// first, so node_modules inside a simulator still counts as simulators.
    private static func bucket(for kind: StorageKind, folder: URL, path: String) -> StorageBucket? {
        let name = folder.lastPathComponent
        switch kind {
        case .developer:
            switch name {
            case "CoreSimulator": return .simulators
            case "DerivedData": return .buildOutput
            case "node_modules": return .nodeModules
            case "com.docker.docker": return .docker
            default: break
            }
            let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
            if trimmed.hasSuffix("/.claude/projects") || trimmed.hasSuffix("/.codex/sessions") || trimmed.hasSuffix("/.cursor/projects") { return .agentHistory }
            if trimmed.hasSuffix("/.ollama") || trimmed.hasSuffix("/.cache/huggingface") || trimmed.hasSuffix("/.cache/lm-studio") { return .models }
            return nil
        case .photos:
            return folder.pathExtension == "photoslibrary" ? .photosLibrary : nil
        default:
            return nil
        }
    }
}

/// How much the disk holds and how much of it is free, the way Finder counts it:
/// purgeable space is free.
struct StorageVolume: Sendable {
    let capacity: Int64
    let available: Int64

    var used: Int64 { max(0, capacity - available) }

    static func current() -> StorageVolume? {
        let root = URL(filePath: "/")
        guard let values = try? root.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
              let capacity = values.volumeTotalCapacity
        else { return nil }
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        return StorageVolume(capacity: Int64(capacity), available: available)
    }
}
