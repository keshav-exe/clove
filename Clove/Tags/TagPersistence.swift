import Foundation

/// Tags live in a single JSON file inside Application Support. Nothing leaves the Mac.
struct TagPersistence: Sendable {
    let fileURL: URL

    static var defaultFile: URL {
        let folder = URL.applicationSupportDirectory.appending(path: "Clove", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "tags.json")
    }

    func load() -> [String: [String]] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? JSONDecoder().decode([String: [String]].self, from: data)) ?? [:]
    }

    func save(_ tags: [String: [String]]) {
        let folder = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(tags) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
