import AppKit
import Foundation
import Observation

/// The two things worth doing about a full disk, and what each says about itself.
enum StorageClean: Sendable, Equatable, CaseIterable {
    case caches
    case trash

    var kind: StorageKind {
        switch self {
        case .caches: .caches
        case .trash: .trash
        }
    }

    var verb: String {
        switch self {
        case .caches: "Clear Caches"
        case .trash: "Empty Trash"
        }
    }

    var doing: String {
        switch self {
        case .caches: "Clearing caches"
        case .trash: "Emptying the Trash"
        }
    }

    func line(_ size: String) -> String {
        switch self {
        case .caches: "\(size) of caches you can clear. Apps rebuild them as needed."
        case .trash: "The Trash is holding \(size) of things you've already deleted."
        }
    }

    /// The same, at panel width.
    func shortLine(_ size: String) -> String {
        switch self {
        case .caches: "\(size) of caches"
        case .trash: "\(size) in the Trash"
        }
    }

    /// The least time a clear takes on screen, so a fast delete still reads as one.
    var seconds: Double {
        switch self {
        case .caches: 2.5
        case .trash: 2.1
        }
    }

    /// Below this there's nothing worth offering.
    var threshold: Int64 {
        switch self {
        case .caches: 1_000_000_000
        case .trash: 50_000_000
        }
    }
}

/// Measures the disk by kind, and clears caches or the Trash. The bar reads
/// `live`, which counts up during a scan and drains during a clear.
@MainActor
@Observable
final class StorageStore {
    enum Phase: Equatable {
        case idle
        case scanning
        case cleaning(StorageClean)
    }

    struct Freed: Equatable {
        let kind: StorageKind
        let bytes: Int64
        /// The clear moved things to the Trash; this record puts them back.
        var record: ClearRecord.ID?
    }

    /// One clear or move to the Trash, kept so it can be put back until the
    /// Trash is emptied.
    struct ClearRecord: Codable, Identifiable, Hashable, Sendable {
        let id: UUID
        let date: Date
        let title: String
        let bytes: Int64
        let moves: [StorageSafety.Move]

        /// Whether anything is still in the Trash to put back.
        var canPutBack: Bool {
            moves.contains { FileManager.default.fileExists(atPath: $0.trashed.path(percentEncoded: false)) }
        }
    }

    private(set) var phase: Phase = .idle
    private(set) var volume: StorageVolume?
    private(set) var reports: [StorageKind: StorageKindReport] = [:]
    /// Bytes per kind right now.
    private(set) var live: [StorageKind: Int64] = [:]
    /// Where the scan or clear is, for the ticker under the total.
    private(set) var currentPath: String?
    private(set) var finished: Set<StorageKind> = []
    private(set) var freed: Freed?
    private(set) var hasScanned = false
    private(set) var cleanStarted: Date?
    private(set) var cleanFrom: Int64 = 0
    /// A part picked on the legend: the list below shows only it.
    var pinned: StorageKind?
    var pendingClean: StorageClean?
    var failure: String?

    /// What was cleared or trashed lately, newest first, so any of it can go back.
    private(set) var history: [ClearRecord] = []

    /// Folders the person chose to always keep: never cleared, never suggested.
    private(set) var kept: [String] = []

    /// Clear Caches moves to the Trash first, so a clear can be undone. Off,
    /// caches are deleted straight away and the space comes back at once.
    var trashFirst: Bool {
        didSet { UserDefaults.standard.set(trashFirst, forKey: Self.trashFirstKey) }
    }

    private static let keptKey = "storage.kept"
    private static let trashFirstKey = "storage.trashFirst"
    private static let historyLimit = 12

    private let scanner = StorageScanner()
    /// This scan started from an empty bar and counts it back up.
    private var isDraining = false
    private var scanTask: Task<Void, Never>?
    /// The last scan, kept as a private file in Clove's own cache folder rather
    /// than Preferences: it names your files, so it's readable only by you and
    /// left out of backups. Clove's own cache is never one it clears.
    private static var snapshotURL: URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return caches
            .appending(path: Bundle.main.bundleIdentifier ?? "com.kshvbgde.clove", directoryHint: .isDirectory)
            .appending(path: "storage-scan.json", directoryHint: .notDirectory)
    }

    /// Earlier builds kept the scan in Preferences.
    private static let legacySnapshotKeys = ["storage.snapshot", "storage.snapshot.v2"]
    /// A full scan newer than this is still the answer: opening Storage again
    /// doesn't walk the disk again.
    private static let freshFor: TimeInterval = 30 * 60
    private var lastFullScan: Date?

    init() {
        trashFirst = UserDefaults.standard.object(forKey: Self.trashFirstKey) as? Bool ?? true
        kept = UserDefaults.standard.stringArray(forKey: Self.keptKey) ?? []
        restoreSnapshot()
        restoreHistory()
    }

    var isBusy: Bool { phase != .idle }

    var capacity: Int64 { volume?.capacity ?? 0 }

    var used: Int64 {
        StorageKind.allCases.reduce(0) { $0 + bytes(of: $1) }
    }

    var available: Int64 { max(0, capacity - used) }

    func bytes(of kind: StorageKind) -> Int64 {
        if kind == .system, phase == .scanning, isDraining {
            return systemEstimate
        }
        return max(0, live[kind] ?? 0)
    }

    /// System data is whatever the kinds don't account for, so it's only known
    /// once they're all counted. Until then it fills toward last time's figure,
    /// never past what's still unaccounted for, so it grows with the rest of the
    /// bar instead of swelling early and shrinking back.
    private var systemEstimate: Int64 {
        guard let volume else { return 0 }
        let counted = StorageKind.allCases.filter { $0 != .system }.reduce(Int64(0)) { $0 + max(0, live[$1] ?? 0) }
        let rest = max(0, volume.used - counted)
        guard let lastSystem, let lastCounted, lastCounted > 0 else {
            let fraction = Double(finished.count) / Double(StorageKind.allCases.count - 1)
            return Int64(Double(rest) * pow(fraction, 3))
        }
        // Small folders finish first, so go by bytes, not by kinds finished.
        let fraction = min(1, Double(counted) / Double(lastCounted))
        return min(rest, Int64(Double(lastSystem) * fraction))
    }

    /// System data, and everything else, from the last finished scan.
    private var lastSystem: Int64?
    private var lastCounted: Int64?

    func items(of kind: StorageKind) -> [StorageItem] {
        reports[kind]?.items ?? []
    }

    /// Rows worth a line: 50 MB or more, and not hidden files like .DS_Store.
    static let rowThreshold: Int64 = 50_000_000

    /// The biggest things on the disk, or in the pinned part.
    func largest(limit: Int = 14) -> [StorageItem] {
        let kinds = pinned.map { [$0] } ?? StorageKind.allCases.filter { $0 != .trash }
        return kinds
            .flatMap { items(of: $0) }
            .filter { $0.bytes >= Self.rowThreshold && !$0.url.lastPathComponent.hasPrefix(".") && !isKept($0) }
            .sorted { $0.bytes > $1.bytes }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - What to offer

    /// The first clear worth doing: caches, then the Trash.
    var recommendation: StorageClean? {
        guard hasScanned else { return nil }
        return StorageClean.allCases.first { clearableBytes(for: $0) >= $0.threshold }
    }

    func clearableBytes(for clean: StorageClean) -> Int64 {
        targets(for: clean).reduce(0) { $0 + $1.bytes }
    }

    /// Caches belonging to Apple or to an app that's open stay put: an app in use
    /// is holding its cache, and macOS's own rebuild slowly and noisily.
    private func targets(for clean: StorageClean) -> [StorageItem] {
        let items = items(of: clean.kind)
        guard clean == .caches else { return items }
        let running = NSWorkspace.shared.runningApplications
        let ids = Set(running.compactMap(\.bundleIdentifier).map { $0.lowercased() })
        let names = Set(running.compactMap(\.localizedName).map { $0.lowercased() })
        let own = Bundle.main.bundleIdentifier?.lowercased()
        return items.filter { item in
            if isKept(item) { return false }
            let name = item.url.lastPathComponent.lowercased()
            if name.hasPrefix("com.apple.") || name == "cloudkit" || name == own { return false }
            if ids.contains(name) || names.contains(name) { return false }
            return true
        }
    }

    // MARK: - Notes

    func note(for kind: StorageKind) -> String {
        guard let report = reports[kind] else {
            return kind == .system
                ? "macOS itself, and app data that isn't sorted anywhere else."
                : "Rescan to measure."
        }
        if report.isRestricted, report.bytes == 0 {
            return kind == .trash
                ? "Clove needs Full Disk Access to see inside the Trash."
                : "macOS didn't let Clove read this folder."
        }
        let largest = report.items.first
        switch kind {
        case .apps:
            let count = report.appCount == 1 ? "1 app" : "\(report.appCount) apps"
            let app = report.items.first { $0.url.pathExtension == "app" }
            guard let app else { return "\(count)." }
            return "\(count). \(app.name) is the largest at \(StorageFormat.gb(app.bytes))."
        case .developer:
            let top = report.buckets.filter { $0.value >= 500_000_000 }.sorted { $0.value > $1.value }.prefix(2)
            if !top.isEmpty {
                return top.map { "\(Self.phrase(for: $0.key)) \(StorageFormat.gb($0.value))." }.joined(separator: " ")
            }
        case .photos:
            if let library = report.buckets[.photosLibrary], library > 0 {
                return "Your Photos library takes \(StorageFormat.gb(library)), all kept on this Mac."
            }
        case .movies:
            if let file = report.largestFile {
                return "Your largest is \(file.name) at \(StorageFormat.gb(file.bytes))."
            }
        case .documents:
            if let file = report.largestFile {
                return "Your largest file is \(file.name) at \(StorageFormat.gb(file.bytes))."
            }
        case .music:
            if report.audioFiles > 0 {
                let count = report.audioFiles.formatted(.number)
                return "\(count) songs and recordings kept on this Mac."
            }
        case .system:
            return "macOS itself, and app data that isn't sorted anywhere else."
        case .caches:
            if let largest {
                return "Apps rebuild these when they need them. \(Self.owner(of: largest.url)) keeps the most, at \(StorageFormat.gb(largest.bytes))."
            }
            return "Apps rebuild these when they need them again."
        case .trash:
            let count = report.items.count
            if count == 0 { return "The Trash is empty." }
            return "\(count == 1 ? "1 item" : "\(count.formatted(.number)) items") you've already deleted."
        }
        guard let largest else { return "Nothing here yet." }
        return "\(largest.name) is the largest at \(StorageFormat.gb(largest.bytes))."
    }

    private static func phrase(for bucket: StorageBucket) -> String {
        switch bucket {
        case .simulators: "Old simulators take"
        case .buildOutput: "Build output takes"
        case .nodeModules: "node_modules take"
        case .agentHistory: "Agent history takes"
        case .models: "Downloaded models take"
        case .docker: "Docker takes"
        case .photosLibrary: "Your Photos library takes"
        }
    }

    /// A cache folder is usually named for its app's bundle ID.
    static func owner(of url: URL) -> String {
        let name = url.lastPathComponent
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name) {
            return FileManager.default.displayName(atPath: app.path(percentEncoded: false)).replacingOccurrences(of: ".app", with: "")
        }
        return name
    }

    // MARK: - Scanning

    /// The first scan of a launch keeps last time's bar and settles each part
    /// as it's measured, so opening Storage never shows an empty disk.
    ///
    /// The scan runs on its own task, not the caller's: a page's `.task` ends
    /// when you switch sections or close the panel, and a scan cut short must
    /// never be taken for a finished one.
    func scanIfNeeded() async {
        guard !hasScanned, phase == .idle, scanTask == nil else { return }
        if let lastFullScan, Date.now.timeIntervalSince(lastFullScan) < Self.freshFor {
            hasScanned = true
            return
        }
        let hasSnapshot = StorageKind.allCases.contains { (live[$0] ?? 0) > 0 }
        scanTask = Task { await scan(drain: !hasSnapshot) }
    }

    /// Rescan is the show: the bar drains and counts itself back up.
    func rescan() {
        guard phase == .idle else { return }
        scanTask = Task { await scan(drain: true) }
    }

    func scan(drain: Bool) async {
        guard phase == .idle else { return }
        phase = .scanning
        isDraining = drain
        freed = nil
        finished = []
        currentPath = nil
        volume = StorageVolume.current()
        if drain {
            for kind in StorageKind.allCases { live[kind] = 0 }
        }

        let scanner = scanner
        let events = AsyncStream<ScanEvent> { continuation in
            // Utility priority and three folders at a time: a full disk walk
            // shouldn't make the Mac feel busy.
            let task = Task.detached(priority: .utility) {
                await withTaskGroup(of: Void.self) { group in
                    var pending = StorageKind.allCases.filter { $0 != .system }[...]
                    func start(_ kind: StorageKind) {
                        group.addTask {
                            let report = scanner.scan(kind) { bytes, url in
                                continuation.yield(.progress(kind, bytes, url))
                            }
                            continuation.yield(.done(kind, report))
                        }
                    }
                    for _ in 0..<3 {
                        if let kind = pending.popFirst() { start(kind) }
                    }
                    while await group.next() != nil {
                        if let kind = pending.popFirst() { start(kind) }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }

        // Progress lands ~100 times a second across the kinds. Applied in
        // batches, so views reading `live` update 15 times a second, not 100.
        var pending: [StorageKind: Int64] = [:]
        var pendingPath: URL?
        var lastApply = Date.distantPast
        func flush() {
            for (kind, bytes) in pending {
                // Settling from last time's bar: a part only grows until it's measured.
                live[kind] = drain ? bytes : max(live[kind] ?? 0, bytes)
            }
            pending.removeAll(keepingCapacity: true)
            if let pendingPath { currentPath = StorageFormat.path(pendingPath) }
            pendingPath = nil
            lastApply = Date()
        }
        for await event in events {
            switch event {
            case .progress(let kind, let bytes, let url):
                pending[kind] = bytes
                pendingPath = url
                if Date().timeIntervalSince(lastApply) > 1.0 / 15 { flush() }
            case .done(let kind, let report):
                pending[kind] = nil
                flush()
                reports[kind] = report
                live[kind] = report.bytes
                finished.insert(kind)
            }
        }

        defer { scanTask = nil }
        // Cut short: the reports are partial, so keep the last full scan's bar.
        guard !Task.isCancelled, finished.count == StorageKind.allCases.count - 1 else {
            restoreSnapshot()
            currentPath = nil
            isDraining = false
            phase = .idle
            return
        }

        let counted = StorageKind.allCases.filter { $0 != .system }.reduce(Int64(0)) { $0 + (reports[$1]?.bytes ?? 0) }
        live[.system] = max(0, (volume?.used ?? counted) - counted)
        lastSystem = live[.system]
        lastCounted = counted
        lastFullScan = .now
        finished.insert(.system)
        currentPath = nil
        hasScanned = true
        phase = .idle
        isDraining = false
        saveSnapshot()
    }

    // MARK: - Clearing

    func clear(_ clean: StorageClean) async {
        guard phase == .idle else { return }
        let kind = clean.kind
        let targets = targets(for: clean)
        guard !targets.isEmpty else { return }
        // Caches go to the Trash first unless the person turned that off. The
        // Trash itself can only be emptied for real.
        let recoverable = clean == .caches && trashFirst

        phase = .cleaning(clean)
        freed = nil
        cleanFrom = bytes(of: kind)
        cleanStarted = .now

        let events = AsyncStream<ClearEvent> { continuation in
            let task = Task.detached(priority: .userInitiated) {
                var failures = 0
                var moves: [StorageSafety.Move] = []
                for item in targets {
                    if Task.isCancelled { break }
                    continuation.yield(.started(item.url))
                    guard let root = item.kind.roots.first?.url else {
                        failures += 1
                        continue
                    }
                    if recoverable {
                        let result = StorageSafety.trash(item.url, inside: root, emptyingFolder: true)
                        moves += result.moves
                        failures += result.failures
                    } else {
                        failures += StorageSafety.remove(item.url, inside: root, emptyingFolder: clean == .caches)
                    }
                    continuation.yield(.removed(item.bytes))
                }
                continuation.yield(.finished(failures: failures, moves: moves))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }

        var failures = 0
        var moves: [StorageSafety.Move] = []
        var remaining = cleanFrom
        for await event in events {
            switch event {
            case .started(let url):
                currentPath = StorageFormat.path(url)
            case .removed(let bytes):
                remaining -= bytes
                live[kind] = max(0, remaining)
            case .finished(let count, let moved):
                failures = count
                moves = moved
            }
        }

        // What's actually left: open apps keep part of their caches, and some
        // files refuse to go. A recoverable clear also grew the Trash.
        let scanner = scanner
        let measured: [StorageKind] = recoverable ? [kind, .trash] : [kind]
        let reportsAfter = await Task.detached(priority: .userInitiated) {
            measured.map { ($0, scanner.scan($0) { _, _ in }) }
        }.value

        let elapsed = Date.now.timeIntervalSince(cleanStarted ?? .now)
        if elapsed < clean.seconds + 0.25 {
            try? await Task.sleep(for: .seconds(clean.seconds + 0.25 - elapsed))
        }

        for (measuredKind, report) in reportsAfter {
            reports[measuredKind] = report
            live[measuredKind] = report.bytes
        }
        let cleared = max(0, cleanFrom - (reports[kind]?.bytes ?? 0))
        var recordID: ClearRecord.ID?
        if recoverable, !moves.isEmpty {
            let record = ClearRecord(id: UUID(), date: .now, title: "Caches", bytes: cleared, moves: moves)
            remember(record)
            recordID = record.id
        }
        if clean == .trash { forgetEmptiedTrash() }
        freed = Freed(kind: kind, bytes: cleared, record: recordID)
        currentPath = nil
        cleanStarted = nil
        phase = .idle
        if failures > 0 {
            failure = failures == 1
                ? "One item couldn't be removed. It may be in use."
                : "\(failures) items couldn't be removed. They may be in use."
        }
        saveSnapshot()
    }

    // MARK: - Putting back

    /// Puts a clear or a move back where it came from, then measures again.
    func putBack(_ record: ClearRecord) async {
        guard phase == .idle else { return }
        let moves = record.moves
        let result = await Task.detached(priority: .userInitiated) {
            StorageSafety.putBack(moves)
        }.value
        history.removeAll { $0.id == record.id }
        saveHistory()
        if freed?.record == record.id { freed = nil }
        if result.missing > 0 {
            failure = result.restored == 0
                ? "Nothing could go back: it's no longer in the Trash, or something new is in its place."
                : "\(result.restored) went back. \(result.missing) couldn't: no longer in the Trash, or something new is in its place."
        }
        let touched = Set(moves.compactMap { kind(containing: $0.original) })
        await remeasure(touched.union([.trash]))
    }

    private func kind(containing url: URL) -> StorageKind? {
        StorageKind.allCases.first { kind in
            StorageSafety.isInside(url, roots: kind.roots.map(\.url))
        }
    }

    private func remeasure(_ kinds: Set<StorageKind>) async {
        let scanner = scanner
        let list = Array(kinds.subtracting([.system]))
        let results = await Task.detached(priority: .userInitiated) {
            list.map { ($0, scanner.scan($0) { _, _ in }) }
        }.value
        for (kind, report) in results {
            reports[kind] = report
            live[kind] = report.bytes
        }
        saveSnapshot()
    }

    private func remember(_ record: ClearRecord) {
        history.insert(record, at: 0)
        if history.count > Self.historyLimit { history.removeLast(history.count - Self.historyLimit) }
        saveHistory()
    }

    /// Once the Trash is emptied, there's nothing to put back.
    private func forgetEmptiedTrash() {
        history.removeAll { !$0.canPutBack }
        saveHistory()
    }

    // MARK: - Keeping

    func isKept(_ item: StorageItem) -> Bool {
        let path = StorageSafety.trimmedPath(item.url)
        return kept.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    /// Never clear or suggest this folder again, in any scan.
    func keep(_ item: StorageItem) {
        let path = StorageSafety.trimmedPath(item.url)
        guard !kept.contains(path) else { return }
        kept.append(path)
        kept.sort()
        UserDefaults.standard.set(kept, forKey: Self.keptKey)
    }

    func stopKeeping(_ path: String) {
        kept.removeAll { $0 == path }
        UserDefaults.standard.set(kept, forKey: Self.keptKey)
    }

    // MARK: - Single items

    /// A row waiting on "Move to Trash?".
    var pendingTrash: StorageItem?

    func moveToTrash(_ item: StorageItem) {
        guard item.canMoveToTrash, phase == .idle else { return }
        // The row may be from a saved scan: make sure it's still there, still
        // inside its kind's folder, and still the size the dialog said.
        guard FileManager.default.fileExists(atPath: item.url.path(percentEncoded: false)), StorageSafety.isInside(item.url, roots: item.kind.roots.map(\.url)) else {
            failure = "“\(item.name)” isn't where the last scan found it. Rescan to see what's there now."
            return
        }
        var trashed: NSURL?
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: &trashed)
        } catch {
            failure = "Couldn't move “\(item.name)” to the Trash. \(error.localizedDescription)"
            return
        }
        var recordID: ClearRecord.ID?
        if let trashed = trashed as URL? {
            let record = ClearRecord(id: UUID(), date: .now, title: item.name, bytes: item.bytes, moves: [.init(original: item.url, trashed: trashed)])
            remember(record)
            recordID = record.id
        }
        freed = Freed(kind: item.kind, bytes: item.bytes, record: recordID)
        // The bytes don't leave the disk, they move to the end of the bar.
        live[item.kind] = max(0, (live[item.kind] ?? 0) - item.bytes)
        live[.trash] = (live[.trash] ?? 0) + item.bytes
        reports[item.kind]?.items.removeAll { $0.id == item.id }
        reports[item.kind]?.bytes -= item.bytes
        saveSnapshot()
    }

    func reveal(_ item: StorageItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Snapshot

    /// The last scan's sizes, so the bar has something to drain from next launch.
    private struct Snapshot: Codable {
        let capacity: Int64
        let available: Int64
        let sizes: [Int: Int64]
        let scannedAt: Date?
        /// What each part held, trimmed to its biggest rows, so a fresh scan
        /// can stand in for a new one next launch.
        let reports: [Int: StorageKindReport]?
    }

    private func saveSnapshot() {
        guard let volume else { return }
        let snapshot = Snapshot(
            capacity: volume.capacity,
            available: volume.available,
            sizes: Dictionary(uniqueKeysWithValues: StorageKind.allCases.map { ($0.rawValue, bytes(of: $0)) }),
            scannedAt: lastFullScan,
            reports: Dictionary(uniqueKeysWithValues: reports.map { kind, report in
                var trimmed = report
                trimmed.items = Array(report.items.prefix(30))
                return (kind.rawValue, trimmed)
            })
        )
        guard let url = Self.snapshotURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        Task.detached(priority: .background) {
            Self.write(data, to: url)
        }
    }

    private static var historyURL: URL? {
        snapshotURL?.deletingLastPathComponent().appending(path: "storage-history.json", directoryHint: .notDirectory)
    }

    private func saveHistory() {
        guard let url = Self.historyURL, let data = try? JSONEncoder().encode(history) else { return }
        Task.detached(priority: .background) {
            Self.write(data, to: url)
        }
    }

    private func restoreHistory() {
        guard let url = Self.historyURL,
              let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode([ClearRecord].self, from: data)
        else { return }
        // Anything emptied from the Trash since can't go back, so it isn't offered.
        history = saved.filter(\.canPutBack)
    }

    private nonisolated static func write(_ data: Data, to url: URL) {
        let manager = FileManager.default
        let folder = url.deletingLastPathComponent()
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard (try? data.write(to: url, options: .atomic)) != nil else { return }
        try? manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path(percentEncoded: false))
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
    }

    private func restoreSnapshot() {
        for key in Self.legacySnapshotKeys { UserDefaults.standard.removeObject(forKey: key) }
        guard let url = Self.snapshotURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else {
            volume = StorageVolume.current()
            return
        }
        volume = StorageVolume(capacity: snapshot.capacity, available: snapshot.available)
        for kind in StorageKind.allCases {
            live[kind] = snapshot.sizes[kind.rawValue] ?? 0
        }
        lastSystem = snapshot.sizes[StorageKind.system.rawValue]
        lastFullScan = snapshot.scannedAt
        for (raw, report) in snapshot.reports ?? [:] {
            if let kind = StorageKind(rawValue: raw) { reports[kind] = report }
        }
        lastCounted = StorageKind.allCases.filter { $0 != .system }.reduce(Int64(0)) { $0 + (snapshot.sizes[$1.rawValue] ?? 0) }
    }
}

private enum ScanEvent: Sendable {
    case progress(StorageKind, Int64, URL)
    case done(StorageKind, StorageKindReport)
}

private enum ClearEvent: Sendable {
    case started(URL)
    case removed(Int64)
    case finished(failures: Int, moves: [StorageSafety.Move])
}
