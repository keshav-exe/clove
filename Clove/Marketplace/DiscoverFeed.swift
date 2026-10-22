import Foundation

/// The three leaderboards on skills.sh.
enum DiscoverFeed: String, CaseIterable, Identifiable, Hashable, Sendable {
    case top
    case trending
    case hot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top: "Top"
        case .trending: "Trending"
        case .hot: "Hot"
        }
    }

    var subtitle: String {
        switch self {
        case .top: "Most installed of all time"
        case .trending: "Fastest growing in the last day"
        case .hot: "This hour against the same hour yesterday"
        }
    }

    var symbolName: String {
        switch self {
        case .top: "trophy"
        case .trending: "chart.line.uptrend.xyaxis"
        case .hot: "flame"
        }
    }

    var path: String {
        switch self {
        case .top: ""
        case .trending: "trending"
        case .hot: "hot"
        }
    }
}
