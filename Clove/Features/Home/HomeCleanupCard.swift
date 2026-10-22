import SwiftUI

struct HomeCleanupCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let candidates = model.cleanupCandidates
        let tokens = candidates.reduce(0) { $0 + $1.tokens }
        let leftovers = (model.cleanup.leftovers.value ?? []).filter(\.isOutdated)
        let leftoverBytes = leftovers.reduce(Int64(0)) { $0 + $1.bytes }
        let oldHistory = model.cleanup.oldTranscripts.reduce(0) { $0 + $1.size }

        HomeCard(
            title: "Cleanup",
            symbolName: "leaf",
            value: tokens.formatted(),
            caption: "tokens to give back every session",
            destination: .cleanup
        ) {
            HomeRow(label: "Unused skills and commands", value: candidates.count.formatted(), destination: .cleanup)
            HomeRow(label: "Agent leftovers", value: leftoverBytes.formatted(.byteCount(style: .file)), destination: .cleanup)
            HomeRow(label: "Old session history", value: Int64(oldHistory).formatted(.byteCount(style: .file)), destination: .cleanup)
        }
    }
}
