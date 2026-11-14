import SwiftUI

/// Something on this Mac that's worth a look, and where to deal with it.
struct HomeAttention: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbolName: String
    let destination: SidebarItem
    /// Some items are fixed in System Settings, not in Clove.
    var action: Action?
    /// Warnings lead the list and carry the warning tint.
    var isWarning = false

    enum Action {
        case fullDiskAccess
        case accessibility

        var title: String {
            switch self {
            case .fullDiskAccess, .accessibility: "Allow…"
            }
        }

        @MainActor
        func perform() {
            switch self {
            case .fullDiskAccess: StorageStore.openFullDiskAccessSettings()
            case .accessibility: AccessibilityAccess.openSettings()
            }
        }
    }

    @MainActor
    static func items(in model: AppModel) -> [HomeAttention] {
        var items: [HomeAttention] = []

        // The disk first: it's what most people open Clove for.
        let storage = model.storage
        if let volume = storage.volume, volume.capacity > 0 {
            let fullness = Double(volume.used) / Double(volume.capacity)
            if fullness >= 0.9 || volume.available < 20_000_000_000 {
                items.append(HomeAttention(
                    id: "low-space",
                    title: "Your Mac is \(Int((fullness * 100).rounded()))% full",
                    detail: "\(StorageFormat.gb(volume.available)) left. See what's taking up the space.",
                    symbolName: "internaldrive.badge.exclamationmark",
                    destination: .storage,
                    isWarning: true
                ))
            }
        }
        if let clean = storage.recommendation, clean == .caches {
            items.append(HomeAttention(
                id: "caches",
                title: "\(StorageFormat.gb(storage.clearableBytes(for: .caches))) of caches to clear",
                detail: storage.trashFirst ? "Safe to clear. They go to the Trash first." : "Safe to clear. Apps rebuild them as needed.",
                symbolName: "square.stack.3d.up",
                destination: .storage
            ))
        }

        // Permissions Clove works without, but less well. Each one says what it unlocks.
        if storage.reports[.trash]?.isRestricted == true {
            items.append(HomeAttention(
                id: "full-disk-access",
                title: "See what's in your Trash",
                detail: "Clove needs Full Disk Access to measure and empty it.",
                symbolName: "lock.shield",
                destination: .storage,
                action: .fullDiskAccess
            ))
        }
        if !AccessibilityAccess.isGranted {
            items.append(HomeAttention(
                id: "accessibility",
                title: "Insert skills into any app",
                detail: "Clove needs Accessibility access to type into your editor.",
                symbolName: "hand.raised",
                destination: .home,
                action: .accessibility
            ))
        }

        let updates = model.manager.updatesAvailable.count
        if updates > 0 {
            items.append(HomeAttention(
                id: "updates",
                title: updates == 1 ? "1 skill has an update" : "\(updates) skills have updates",
                detail: "Newer versions are on skills.sh.",
                symbolName: "arrow.down.circle",
                destination: .library(.all)
            ))
        }

        let candidates = model.cleanupCandidates
        if !candidates.isEmpty {
            let tokens = candidates.reduce(0) { $0 + $1.tokens }
            items.append(HomeAttention(
                id: "unused",
                title: candidates.count == 1 ? "1 skill you don't use" : "\(candidates.count) skills you don't use",
                detail: "They take up \(tokens.formatted()) tokens in every agent session.",
                symbolName: "leaf",
                destination: .cleanup
            ))
        }

        let leftoverBytes = (model.cleanup.leftovers.value ?? []).filter(\.isOutdated).reduce(Int64(0)) { $0 + $1.bytes }
        if leftoverBytes > 0 {
            items.append(HomeAttention(
                id: "leftovers",
                title: "Old agent downloads",
                detail: "\(leftoverBytes.formatted(.byteCount(style: .file))) of browsers and packages agents left behind.",
                symbolName: "shippingbox",
                destination: .cleanup
            ))
        }

        let history = Int64(model.cleanup.oldTranscripts.reduce(0) { $0 + $1.size })
        if history > 0 {
            items.append(HomeAttention(
                id: "history",
                title: "Old conversations",
                detail: "\(history.formatted(.byteCount(style: .file))) of saved agent transcripts.",
                symbolName: "clock.arrow.circlepath",
                destination: .cleanup
            ))
        }

        let findings = model.secrets.findings.count
        if findings > 0 {
            items.append(HomeAttention(
                id: "secrets",
                title: findings == 1 ? "1 API key in plain text" : "\(findings) API keys in plain text",
                detail: "They're in your shell profile. Move them to the Keychain.",
                symbolName: "key",
                destination: .secrets
            ))
        }

        let devServers = model.running.items(of: .devServer).count
        if devServers > 0 {
            items.append(HomeAttention(
                id: "servers",
                title: devServers == 1 ? "1 dev server still running" : "\(devServers) dev servers still running",
                detail: "Stop the ones you're done with.",
                symbolName: "server.rack",
                destination: .running
            ))
        }

        return items
    }
}
