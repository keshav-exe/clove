import Foundation

enum ReleaseConfiguration {
    /// The newest GitHub release. Publishing one with `tools/release.sh` is all
    /// it takes for every copy of Clove to see the update.
    static let latestReleaseURL: URL? = URL(string: "https://api.github.com/repos/keshav-exe/clove/releases/latest")
}
