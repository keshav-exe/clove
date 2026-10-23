import SwiftUI

/// Something on this Mac that's worth a look, and where to deal with it.
struct HomeAttention: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbolName: String
    let destination: SidebarItem

    @MainActor
    static func items(in model: AppModel) -> [HomeAttention] {
        var items: [HomeAttention] = []

        let updates = model.manager.updatesAvailable.count
        if updates > 0 {
            items.append(HomeAttention(
                id: "updates",
                title: updates == 1 ? "1 skill update" : "\(updates) skill updates",
                detail: "Newer versions on skills.sh",
                symbolName: "arrow.down.circle",
                destination: .library(.all)
            ))
        }

        let candidates = model.cleanupCandidates
        if !candidates.isEmpty {
            let tokens = candidates.reduce(0) { $0 + $1.tokens }
            items.append(HomeAttention(
                id: "unused",
                title: candidates.count == 1 ? "1 unused skill or command" : "\(candidates.count) unused skills and commands",
                detail: "\(tokens.formatted()) tokens loaded every session",
                symbolName: "leaf",
                destination: .cleanup
            ))
        }

        let leftoverBytes = (model.cleanup.leftovers.value ?? []).filter(\.isOutdated).reduce(Int64(0)) { $0 + $1.bytes }
        if leftoverBytes > 0 {
            items.append(HomeAttention(
                id: "leftovers",
                title: "Agent leftovers",
                detail: "\(leftoverBytes.formatted(.byteCount(style: .file))) of old browsers and packages",
                symbolName: "shippingbox",
                destination: .cleanup
            ))
        }

        let history = Int64(model.cleanup.oldTranscripts.reduce(0) { $0 + $1.size })
        if history > 0 {
            items.append(HomeAttention(
                id: "history",
                title: "Old session history",
                detail: "\(history.formatted(.byteCount(style: .file))) of past transcripts",
                symbolName: "clock.arrow.circlepath",
                destination: .cleanup
            ))
        }

        let findings = model.secrets.findings.count
        if findings > 0 {
            items.append(HomeAttention(
                id: "secrets",
                title: findings == 1 ? "1 key in plain text" : "\(findings) keys in plain text",
                detail: "Found in your shell profiles",
                symbolName: "key",
                destination: .secrets
            ))
        }

        let devServers = model.running.items(of: .devServer).count
        if devServers > 0 {
            items.append(HomeAttention(
                id: "servers",
                title: devServers == 1 ? "1 dev server running" : "\(devServers) dev servers running",
                detail: "Stop the ones you're done with",
                symbolName: "server.rack",
                destination: .running
            ))
        }

        return items
    }
}
