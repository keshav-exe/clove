import Foundation

/// The checks every storage delete passes, at the moment it happens rather
/// than at scan time, so a path that changed since the scan can't be used to
/// reach anything outside the folder it was found in.
enum StorageSafety {
    /// Deletes `url`, which must sit directly inside `root`. A link is removed
    /// as a link, never followed. With `emptyingFolder`, a folder is kept and
    /// only its contents go (some apps expect their cache folder to exist).
    /// Returns how many things refused to go.
    static func remove(_ url: URL, inside root: URL, emptyingFolder: Bool) -> Int {
        guard isDirectChild(url, of: root) else { return 1 }
        let manager = FileManager.default
        let target = URL(filePath: trimmedPath(url), directoryHint: .notDirectory)
        guard let values = try? target.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]) else { return 0 }
        if values.isSymbolicLink == true {
            return (try? manager.removeItem(at: target)) == nil ? 1 : 0
        }
        if emptyingFolder, values.isDirectory == true {
            let children = (try? manager.contentsOfDirectory(at: target, includingPropertiesForKeys: nil, options: [])) ?? []
            var failures = 0
            for child in children where (try? manager.removeItem(at: child)) == nil {
                failures += 1
            }
            return failures
        }
        return (try? manager.removeItem(at: target)) == nil ? 1 : 0
    }

    /// `url` is one level inside `root`, with links in its parent resolved.
    static func isDirectChild(_ url: URL, of root: URL) -> Bool {
        let path = trimmedPath(url)
        let name = URL(filePath: path).lastPathComponent
        guard !name.isEmpty, name != ".", name != "..", !path.contains("/../"), !path.hasSuffix("/..") else { return false }
        let parent = URL(filePath: path).deletingLastPathComponent().resolvingSymlinksInPath()
        return trimmedPath(parent) == trimmedPath(root.resolvingSymlinksInPath())
    }

    /// `url` is somewhere inside one of `roots`, and isn't a root itself.
    static func isInside(_ url: URL, roots: [URL]) -> Bool {
        let path = trimmedPath(url.resolvingSymlinksInPath())
        return roots.contains { root in
            path.hasPrefix(trimmedPath(root.resolvingSymlinksInPath()) + "/")
        }
    }

    static func trimmedPath(_ url: URL) -> String {
        let path = url.path(percentEncoded: false)
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}
