import SwiftUI

struct CleanupListStatus: View {
    let state: Loadable<AgentUsageScanner.Report>
    let isEmpty: Bool
    let window: CleanupWindow

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView("Reading agent history…")
                .controlSize(.small)
        case .loaded where isEmpty:
            ContentUnavailableView(
                "No Unused Skills",
                systemImage: "checkmark.circle",
                description: Text("Nothing idle for \(window.phrase).")
            )
        case .loaded, .failed:
            EmptyView()
        }
    }
}
