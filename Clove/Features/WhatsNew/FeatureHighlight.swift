import Foundation

struct FeatureHighlight: Identifiable, Hashable, Sendable {
    var id: String { title }
    let symbolName: String
    let title: String
    let detail: String
}
