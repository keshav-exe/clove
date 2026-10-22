import SwiftUI

/// Loading, empty, and error states laid over the Discover list.
struct DiscoverListStatus: View {
    let state: Loadable<[MarketplaceSkill]>
    let query: String
    let retry: () -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView()
                .controlSize(.small)
        case .failed(let message):
            ContentUnavailableView {
                Label("Can't Reach skills.sh", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again", action: retry)
            }
        case .loaded(let skills) where skills.isEmpty:
            ContentUnavailableView.search(text: query)
        case .loaded:
            EmptyView()
        }
    }
}
