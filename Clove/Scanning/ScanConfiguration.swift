import Foundation

struct ScanConfiguration: Equatable, Sendable {
    var includePlugins: Bool
    var includeProjects: Bool
    var home: URL
    var projectRoots: [URL]

    /// Folders searched for project-level skills. These are all outside the
    /// folders macOS protects, so scanning them never triggers a system prompt.
    static let conventionalProjectFolders = ["Developer", "Projects", "src", "code", "repos"]

    static func make(
        includePlugins: Bool = true,
        includeProjects: Bool = true,
        customRoots: [URL] = [],
        home: URL = URL.homeDirectory
    ) -> ScanConfiguration {
        let manager = FileManager.default
        var roots = conventionalProjectFolders
            .map { home.appending(path: $0) }
            .filter { manager.fileExists(atPath: $0.path(percentEncoded: false)) }

        for root in customRoots where !roots.contains(root) {
            roots.append(root)
        }

        return ScanConfiguration(
            includePlugins: includePlugins,
            includeProjects: includeProjects,
            home: home,
            projectRoots: roots
        )
    }

    static func `default`(home: URL = URL.homeDirectory) -> ScanConfiguration {
        make(home: home)
    }
}
