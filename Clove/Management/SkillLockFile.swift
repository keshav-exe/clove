import Foundation

/// The `skills` CLI's record of installed skills. Clove reads it to show where a
/// skill came from and writes to it on install, so `npx skills update` and Clove
/// agree. Keys Clove doesn't know about are kept as they are.
struct SkillLockFile: Sendable {
    let url: URL

    static func `default`(home: URL = .homeDirectory) -> SkillLockFile {
        SkillLockFile(url: home.appending(path: ".agents/.skill-lock.json"))
    }

    func entries() -> [String: SkillLockEntry] {
        guard let skills = readRoot()["skills"] as? [String: [String: Any]] else { return [:] }
        var entries: [String: SkillLockEntry] = [:]
        for (name, fields) in skills {
            guard let source = fields["source"] as? String else { continue }
            entries[name] = SkillLockEntry(
                name: name,
                source: source,
                sourceType: fields["sourceType"] as? String ?? "github",
                skillPath: fields["skillPath"] as? String ?? "SKILL.md",
                folderHash: fields["skillFolderHash"] as? String ?? "",
                installedAt: Self.date(fields["installedAt"]),
                updatedAt: Self.date(fields["updatedAt"])
            )
        }
        return entries
    }

    func record(_ entry: SkillLockEntry) throws {
        var root = readRoot()
        var skills = root["skills"] as? [String: Any] ?? [:]
        var fields = skills[entry.name] as? [String: Any] ?? [:]
        let now = Self.timestamp(.now)

        fields["source"] = entry.source
        fields["sourceType"] = entry.sourceType
        if entry.isGitHub {
            fields["sourceUrl"] = "https://github.com/\(entry.source).git"
        }
        fields["skillPath"] = entry.skillPath
        fields["skillFolderHash"] = entry.folderHash
        if fields["installedAt"] == nil {
            fields["installedAt"] = now
        }
        fields["updatedAt"] = now

        skills[entry.name] = fields
        root["skills"] = skills
        try write(root)
    }

    func remove(name: String) throws {
        var root = readRoot()
        guard var skills = root["skills"] as? [String: Any], skills[name] != nil else { return }
        skills[name] = nil
        root["skills"] = skills
        try write(root)
    }

    private func readRoot() -> [String: Any] {
        guard
            let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ["version": 3, "skills": [String: Any]()]
        }
        return root
    }

    private func write(_ root: [String: Any]) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: url, options: .atomic)
    }

    private static func date(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        return (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text))
            ?? (try? Date(text, strategy: .iso8601))
    }

    private static func timestamp(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }
}
