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
            CalmEmptyState(title: "Nothing to clean up", message: "Every skill and command was used in the last \(window.phrase).") {
                SkillsArt()
            }
        case .loaded, .failed:
            EmptyView()
        }
    }
}
