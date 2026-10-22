import Foundation
import Observation

/// Finds skills nobody uses and removes them in one step, with undo.
@MainActor
@Observable
final class CleanupStore {
    struct Result: Sendable {
        let count: Int
        let tokens: Int
        let receipt: TrashReceipt
    }

    private(set) var usage: Loadable<AgentUsageScanner.Report> = .idle
    var window: CleanupWindow = .month
    /// Candidates the person chose to keep. Everything else is selected.
    var kept: Set<CleanupCandidate.ID> = []
    private(set) var lastResult: Result?
    private(set) var isRemoving = false
    private(set) var historyResult: HistoryResult?
    private(set) var isClearingHistory = false

    private let scanner: AgentUsageScanner

    init(scanner: AgentUsageScanner = AgentUsageScanner()) {
        self.scanner = scanner
    }

    func scanIfNeeded() async {
        guard usage.value == nil, !usage.isLoading else { return }
        await scan()
    }

    func scan() async {
        if usage.value == nil {
            usage = .loading
        }
        usage = .loaded(await scanner.scan())
    }

    func candidates(in catalog: [CatalogEntry], resources: [AgentResource]) -> [CleanupCandidate] {
        guard let report = usage.value else { return [] }
        return CleanupCandidate.candidates(in: catalog, resources: resources, lastUsed: report.lastUsed, window: window)
    }

    /// Sessions last touched before the window, oldest first.
    var oldTranscripts: [TranscriptFile] {
        let cutoff = window.cutoff()
        return (usage.value?.transcripts ?? []).filter { $0.modified < cutoff }
    }

    func isSelected(_ candidate: CleanupCandidate) -> Bool {
        !kept.contains(candidate.id)
    }

    func toggle(_ candidate: CleanupCandidate) {
        if kept.contains(candidate.id) {
            kept.remove(candidate.id)
        } else {
            kept.insert(candidate.id)
        }
    }

    func remove(_ candidates: [CleanupCandidate], using manager: SkillManager) async {
        let chosen = candidates.filter(isSelected)
        guard !chosen.isEmpty, !isRemoving else { return }
        isRemoving = true
        defer { isRemoving = false }

        var entries: [CatalogEntry] = []
        var files: [URL] = []
        for candidate in chosen {
            switch candidate.item {
            case .skill(let entry): entries.append(entry)
            case .resource(let resource): files.append(resource.fileURL)
            }
        }

        var receipt = TrashReceipt()
        if !files.isEmpty, let moved = await manager.trash(files) {
            receipt.append(moved)
        }
        if !entries.isEmpty, let removed = await manager.uninstall(entries) {
            receipt.append(removed)
        }
        if !receipt.moves.isEmpty || !receipt.links.isEmpty {
            lastResult = Result(count: chosen.count, tokens: chosen.reduce(0) { $0 + $1.tokens }, receipt: receipt)
        }
    }

    func undo(using manager: SkillManager) async {
        guard let result = lastResult else { return }
        lastResult = nil
        await manager.restore(result.receipt)
    }

    func dismissResult() {
        lastResult = nil
    }

    // MARK: - Leftovers

    private(set) var leftovers: Loadable<[LeftoverItem]> = .idle
    /// Leftovers the person chose to keep. Outdated ones start selected.
    var keptLeftovers: Set<LeftoverItem.ID> = []
    /// Up-to-date items the person chose to remove anyway.
    var addedLeftovers: Set<LeftoverItem.ID> = []
    private(set) var leftoverResult: HistoryResult?
    private(set) var isRemovingLeftovers = false

    func scanLeftovers() async {
        if leftovers.value == nil {
            leftovers = .loading
        }
        leftovers = .loaded(await LeftoverScanner.scan())
    }

    func isSelected(_ item: LeftoverItem) -> Bool {
        item.isOutdated ? !keptLeftovers.contains(item.id) : addedLeftovers.contains(item.id)
    }

    func toggle(_ item: LeftoverItem) {
        if item.isOutdated {
            if keptLeftovers.remove(item.id) == nil { keptLeftovers.insert(item.id) }
        } else {
            if addedLeftovers.remove(item.id) == nil { addedLeftovers.insert(item.id) }
        }
    }

    var selectedLeftovers: [LeftoverItem] {
        (leftovers.value ?? []).filter(isSelected)
    }

    func removeLeftovers() async {
        let chosen = selectedLeftovers
        guard !chosen.isEmpty, !isRemovingLeftovers else { return }
        isRemovingLeftovers = true
        defer { isRemovingLeftovers = false }

        let receipt = await LeftoverScanner.trash(chosen)
        leftoverResult = HistoryResult(
            count: receipt.moves.count,
            bytes: Int(chosen.reduce(0) { $0 + $1.bytes }),
            receipt: receipt
        )
        keptLeftovers = []
        addedLeftovers = []
        await scanLeftovers()
    }

    func undoLeftovers() async {
        guard let result = leftoverResult else { return }
        leftoverResult = nil
        await Self.restore(result.receipt)
        await scanLeftovers()
    }

    // MARK: - History

    struct HistoryResult: Sendable {
        let count: Int
        let bytes: Int
        let receipt: TrashReceipt
    }

    /// Moves sessions older than the window to the Trash. Usage dates are
    /// remembered separately, so Cleanup still knows what was used.
    func clearOldHistory() async {
        let files = oldTranscripts
        guard !files.isEmpty, !isClearingHistory else { return }
        isClearingHistory = true
        defer { isClearingHistory = false }

        let receipt = await Self.trash(files.map(\.url))
        historyResult = HistoryResult(
            count: receipt.moves.count,
            bytes: files.reduce(0) { $0 + $1.size },
            receipt: receipt
        )
        await scan()
    }

    func undoHistory() async {
        guard let result = historyResult else { return }
        historyResult = nil
        await Self.restore(result.receipt)
        await scan()
    }

    @concurrent
    private static func trash(_ files: [URL]) async -> TrashReceipt {
        var receipt = TrashReceipt()
        for file in files {
            var trashed: NSURL?
            guard (try? FileManager.default.trashItem(at: file, resultingItemURL: &trashed)) != nil,
                  let trashed = trashed as URL?
            else { continue }
            receipt.moves.append(.init(original: file, trashed: trashed))
        }
        return receipt
    }

    @concurrent
    private static func restore(_ receipt: TrashReceipt) async {
        for move in receipt.moves {
            try? FileManager.default.moveItem(at: move.trashed, to: move.original)
        }
    }
}
