import SwiftUI

struct CleanupLeftoversDone: View {
    let result: CleanupStore.HistoryResult
    let undo: () -> Void

    var body: some View {
        Label(
            "Moved \(result.count.formatted()) items, \(CleanupLeftoversCard.bytes(Int64(result.bytes))), to the Trash.",
            systemImage: "checkmark.circle.fill"
        )
        .foregroundStyle(.green)
        Button("Undo", systemImage: "arrow.uturn.backward", action: undo)
            .buttonStyle(.glass)
    }
}
