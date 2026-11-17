import Foundation

/// A kind of leftover data that's safe to remove, and what removing it means:
/// Xcode's build files, old device support, package downloads, app logs,
/// installers you've already used. Caches in ~/Library/Caches aren't here;
/// Clear Caches already covers them.
struct TempSpot: Identifiable, Hashable, Sendable {
    enum Safety: Sendable {
        /// The app makes it again on its own when it needs it.
        case rebuilt
        /// Probably not needed, but only you know: look before you clear.
        case checkFirst
    }

    let id: String
    let title: String
    let symbol: String
    /// What it is, in a sentence.
    let what: String
    /// What happens once it's gone.
    let after: String
    let safety: Safety
}

/// One thing to move to the Trash, and the folder it must sit directly in.
struct TempTarget: Hashable, Sendable {
    let url: URL
    let root: URL
    let bytes: Int64
}

/// A spot as found on this Mac: how much it holds and what clearing it moves.
struct TempFinding: Identifiable, Hashable, Sendable {
    let spot: TempSpot
    let targets: [TempTarget]
    var id: String { spot.id }
    var bytes: Int64 { targets.reduce(0) { $0 + $1.bytes } }
}

enum TempDataScanner {
    /// Spots smaller than this aren't worth a row.
    static let minimumBytes: Int64 = 20_000_000

    static let derivedData = TempSpot(
        id: "derivedData", title: "Xcode build files", symbol: "hammer",
        what: "Compiled code and indexes Xcode keeps for each project in DerivedData.",
        after: "Xcode builds them again. The next build of each project takes longer.",
        safety: .rebuilt
    )
    static let deviceSupport = TempSpot(
        id: "deviceSupport", title: "Old device support", symbol: "iphone",
        what: "Debugging files Xcode copied from iPhones and other devices, one set per OS version.",
        after: "Clove keeps the newest set for each kind of device. Xcode copies an older one again if you plug in a device still running it.",
        safety: .rebuilt
    )
    static let simulatorCaches = TempSpot(
        id: "simulatorCaches", title: "Simulator caches", symbol: "ipad.and.iphone",
        what: "Caches the iOS Simulator builds as it runs. Your simulators and their apps aren't touched.",
        after: "Simulators rebuild them the next time they start.",
        safety: .rebuilt
    )
    static let packageDownloads = TempSpot(
        id: "packageDownloads", title: "Package downloads", symbol: "shippingbox",
        what: "Copies of every package npm, Bun, Gradle and Cargo have downloaded, kept to install faster.",
        after: "Projects keep working. Packages download again the next time a project installs them.",
        safety: .rebuilt
    )
    static let logs = TempSpot(
        id: "logs", title: "App logs", symbol: "doc.plaintext",
        what: "Diagnostic logs and crash reports apps write to ~/Library/Logs.",
        after: "Nothing changes. Apps start new logs; you only lose old ones you might have used to debug.",
        safety: .rebuilt
    )
    static let installers = TempSpot(
        id: "installers", title: "Installers in Downloads", symbol: "arrow.down.app",
        what: "Disk images and installer packages in Downloads that haven't been touched in a week.",
        after: "Apps you installed from them keep working. You'd download one again to reinstall.",
        safety: .checkFirst
    )
    static let nodeModules = TempSpot(
        id: "nodeModules", title: "node_modules in idle projects", symbol: "folder.badge.gearshape",
        what: "Installed packages in projects you haven't changed in two months.",
        after: "The project needs `npm install` (or bun, pnpm, yarn) before it runs again.",
        safety: .checkFirst
    )

    static let catalog = [derivedData, deviceSupport, simulatorCaches, packageDownloads, logs, installers, nodeModules]

    /// Looks in each spot under `home`. Slow on a big disk: run it off the main actor.
    static func scan(home: URL = FileManager.default.homeDirectoryForCurrentUser, now: Date = .now) -> [TempFinding] {
        func path(_ relative: String) -> URL { home.appending(path: relative, directoryHint: .isDirectory) }
        var findings: [TempFinding] = []
        func add(_ spot: TempSpot, _ targets: [TempTarget]) {
            let finding = TempFinding(spot: spot, targets: targets.filter { $0.bytes > 0 }.sorted { $0.bytes > $1.bytes })
            if finding.bytes >= minimumBytes { findings.append(finding) }
        }

        let xcode = path("Library/Developer/Xcode")
        add(derivedData, children(of: xcode.appending(path: "DerivedData")).map(target))

        var support: [TempTarget] = []
        for platform in ["iOS", "watchOS", "tvOS", "visionOS", "macOS"] {
            let folder = xcode.appending(path: "\(platform) DeviceSupport")
            // The newest set is likely the device on your desk: keep it.
            let sets = children(of: folder).sorted { modified($0) > modified($1) }
            support += sets.dropFirst().map(target)
        }
        add(deviceSupport, support)

        add(simulatorCaches, children(of: path("Library/Developer/CoreSimulator/Caches")).map(target))

        let downloads = [".npm/_cacache", ".bun/install/cache", ".gradle/caches", ".cargo/registry/cache"]
            .map(path)
            .filter { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
        add(packageDownloads, downloads.map(target))

        add(logs, children(of: path("Library/Logs")).map(target))

        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        let installerTypes: Set<String> = ["dmg", "pkg", "mpkg", "xip", "iso"]
        let oldInstallers = children(of: path("Downloads")).filter { url in
            installerTypes.contains(url.pathExtension.lowercased()) && modified(url) < weekAgo
        }
        add(installers, oldInstallers.map(target))

        let idleSince = now.addingTimeInterval(-60 * 86_400)
        let projectRoots = ["Developer", "Code", "Projects", "src", "GitHub", "Documents/GitHub"].map(path)
        let idleModules = projectRoots.flatMap { projects(in: $0, depth: 3) }
            .filter { lastChange(of: $0) < idleSince }
            .map { $0.appending(path: "node_modules", directoryHint: .isDirectory) }
        add(nodeModules, idleModules.map(target))

        return findings
    }

    // MARK: - Helpers

    private static func target(_ url: URL) -> TempTarget {
        TempTarget(url: url, root: url.deletingLastPathComponent(), bytes: allocatedSize(of: url))
    }

    static func children(of folder: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])) ?? []
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    /// Folders holding a `node_modules`, without looking inside any node_modules.
    private static func projects(in folder: URL, depth: Int) -> [URL] {
        guard depth > 0 else { return [] }
        var found: [URL] = []
        for child in children(of: folder) where (try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])).map({ $0.isDirectory == true && $0.isSymbolicLink != true }) == true {
            if child.lastPathComponent == "node_modules" { continue }
            if FileManager.default.fileExists(atPath: child.appending(path: "node_modules").path(percentEncoded: false)) {
                found.append(child)
            } else {
                found += projects(in: child, depth: depth - 1)
            }
        }
        return found
    }

    /// The newest change to a project's own files: its top level, its git
    /// index, and its source folder, never its packages.
    private static func lastChange(of project: URL) -> Date {
        var dates = children(of: project).filter { $0.lastPathComponent != "node_modules" }.map(modified)
        dates.append(modified(project.appending(path: ".git/index")))
        dates.append(modified(project.appending(path: "src")))
        return dates.max() ?? .distantPast
    }

    /// What a file or folder takes on disk, never following links.
    static func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isSymbolicLinkKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        if values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: []) else { return 0 }
        var total: Int64 = 0
        for case let item as URL in walker {
            guard let values = try? item.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}
