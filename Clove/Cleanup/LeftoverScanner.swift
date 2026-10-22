import Foundation

/// Finds browser builds, npx installs, and old CLI versions that agents leave
/// on disk. Read-only; removal goes through `LeftoverScanner.trash`.
enum LeftoverScanner {
    @concurrent
    static func scan(home: URL = .homeDirectory, now: Date = .now) async -> [LeftoverItem] {
        testBrowsers(home: home) + npxPackages(home: home, now: now) + claudeVersions(home: home)
    }

    // MARK: - Test browsers

    static func testBrowsers(home: URL) -> [LeftoverItem] {
        var builds: [(name: String, version: [Int], label: String, url: URL, tool: String)] = []
        let fileManager = FileManager.default

        // Playwright: <cache>/chromium-1243, firefox-1490, ffmpeg-1011…
        for root in ["Library/Caches/ms-playwright", ".cache/ms-playwright"] {
            for folder in children(of: home.appending(path: root)) {
                guard let dash = folder.lastPathComponent.lastIndex(of: "-") else { continue }
                let name = String(folder.lastPathComponent[..<dash])
                let revision = String(folder.lastPathComponent[folder.lastPathComponent.index(after: dash)...])
                guard let number = Int(revision) else { continue }
                builds.append((name, [number], "build \(revision)", folder, "Playwright"))
            }
        }

        // Puppeteer: ~/.cache/puppeteer/chrome/mac_arm-130.0.6723.58
        // Selenium: ~/.cache/selenium/chrome/mac-arm64/130.0.6723.58
        for (root, tool, depth) in [(".cache/puppeteer", "Puppeteer", 1), (".cache/selenium", "Selenium", 2)] {
            for browser in children(of: home.appending(path: root)) {
                var folders = children(of: browser)
                if depth == 2 { folders = folders.flatMap(children(of:)) }
                for folder in folders {
                    let raw = folder.lastPathComponent.split(separator: "-").last.map(String.init) ?? folder.lastPathComponent
                    builds.append((browser.lastPathComponent, versionParts(raw), raw, folder, tool))
                }
            }
        }

        let newest = Dictionary(grouping: builds) { "\($0.tool)/\($0.name)" }
            .compactMapValues { $0.map(\.version).max(by: { $0.lexicographicallyPrecedes($1) }) }

        return builds.map { build in
            let isNewest = newest["\(build.tool)/\(build.name)"] == build.version
            return LeftoverItem(
                kind: .testBrowsers,
                title: "\(build.tool) \(readableBrowser(build.name))",
                detail: isNewest ? "\(build.label), the newest" : build.label,
                url: build.url,
                bytes: size(of: build.url, fileManager: fileManager),
                isOutdated: !isNewest
            )
        }
    }

    static func readableBrowser(_ name: String) -> String {
        switch name {
        case "chromium": "Chromium"
        case "chromium_headless_shell", "chrome-headless-shell": "headless Chrome"
        case "chrome": "Chrome for Testing"
        case "firefox": "Firefox"
        case "webkit": "WebKit"
        case "ffmpeg": "FFmpeg"
        default: name
        }
    }

    // MARK: - npx

    /// ~/.npm/_npx/<hash>: one folder per package npx ran.
    static func npxPackages(home: URL, now: Date) -> [LeftoverItem] {
        let fileManager = FileManager.default
        let idle = now.addingTimeInterval(-14 * 86_400)
        return children(of: home.appending(path: ".npm/_npx")).map { folder in
            let packages = npxPackageNames(in: folder)
            let modified = (try? folder.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? now
            return LeftoverItem(
                kind: .npxPackages,
                title: packages.isEmpty ? "Unfinished download" : packages.joined(separator: ", "),
                detail: "Last run " + modified.formatted(.relative(presentation: .named)),
                url: folder,
                bytes: size(of: folder, fileManager: fileManager),
                isOutdated: packages.isEmpty || modified < idle
            )
        }
    }

    static func npxPackageNames(in folder: URL) -> [String] {
        guard
            let data = try? Data(contentsOf: folder.appending(path: "package.json")),
            let package = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dependencies = package["dependencies"] as? [String: Any]
        else { return [] }
        return dependencies.keys.sorted()
    }

    // MARK: - Claude Code

    /// ~/.local/share/claude/versions/<version>, minus the one ~/.local/bin/claude runs.
    static func claudeVersions(home: URL) -> [LeftoverItem] {
        let fileManager = FileManager.default
        let active = (try? fileManager.destinationOfSymbolicLink(
            atPath: home.appending(path: ".local/bin/claude").path(percentEncoded: false)
        )).map { URL(filePath: $0).lastPathComponent }

        return children(of: home.appending(path: ".local/share/claude/versions")).map { file in
            let version = file.lastPathComponent
            let isActive = version == active
            return LeftoverItem(
                kind: .claudeVersions,
                title: "Claude Code \(version)",
                detail: isActive ? "The version you run" : "Not in use",
                url: file,
                bytes: size(of: file, fileManager: fileManager),
                // Without a link to compare against, keep everything.
                isOutdated: active != nil && !isActive
            )
        }
    }

    // MARK: - Removing

    /// Moves items to the Trash, unregistering any apps inside first so macOS
    /// stops listing them in Notifications, Open With, and Launchpad.
    @concurrent
    static func trash(_ items: [LeftoverItem]) async -> TrashReceipt {
        var receipt = TrashReceipt()
        for item in items {
            for app in appBundles(in: item.url) {
                unregister(app)
            }
            var trashed: NSURL?
            guard (try? FileManager.default.trashItem(at: item.url, resultingItemURL: &trashed)) != nil,
                  let trashed = trashed as URL?
            else { continue }
            receipt.moves.append(.init(original: item.url, trashed: trashed))
        }
        return receipt
    }

    static func appBundles(in folder: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var apps: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            if item.pathExtension == "app" {
                apps.append(item)
                // Helper apps inside are unregistered along with their parent.
                enumerator.skipDescendants()
            }
        }
        return apps
    }

    private static func unregister(_ app: URL) {
        let process = Process()
        process.executableURL = URL(filePath: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister")
        process.arguments = ["-u", app.path(percentEncoded: false)]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Helpers

    private static func children(of folder: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []).sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// "130.0.6723.58" → [130, 0, 6723, 58]
    static func versionParts(_ text: String) -> [Int] {
        text.split(separator: ".").compactMap { Int($0) }
    }

    /// Space on disk, counting each file's allocated size.
    static func size(of url: URL, fileManager: FileManager) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        if let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? 0)
        }
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: Array(keys)) else { return 0 }
        var total: Int64 = 0
        while let item = enumerator.nextObject() as? URL {
            total += Int64((try? item.resourceValues(forKeys: keys))?.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
