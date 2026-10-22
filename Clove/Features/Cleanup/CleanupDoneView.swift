import SwiftUI

struct CleanupDoneView: View {
    let result: CleanupStore.Result
    let undo: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            Label("Cleaned up", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Text(result.tokens, format: .number)
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Text("tokens back in every agent session. \(result.count) skills are in the Trash.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        HStack(spacing: Metrics.spacingS) {
            Button("Undo", systemImage: "arrow.uturn.backward", action: undo)
                .buttonStyle(.glass)
                .keyboardShortcut("z")
            Button("Done", action: dismiss)
                .buttonStyle(.glass)
        }
        .controlSize(.large)
    }
}
