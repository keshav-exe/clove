import SwiftUI

/// Shown in place of the callout when nothing is idle for the chosen window.
struct CleanupAllClearView: View {
    let skillCount: Int
    @Binding var window: CleanupWindow

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            Label("Everything is pulling its weight", systemImage: "leaf")
                .font(.headline)
                .foregroundStyle(.green)

            Text("Your agents used all \(skillCount) skills, and every command and subagent, in the last \(window.phrase).")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Unused For", selection: $window) {
                ForEach(CleanupWindow.allCases) { window in
                    Text(window.title).tag(window)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.top, Metrics.spacingXS)
        }
    }
}
