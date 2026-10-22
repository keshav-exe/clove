import Foundation
import Testing
@testable import Clove

struct SkillScannerTests {
    /// A skill kept in a dotfiles repo and linked into ~/.claude/skills shows
    /// up as a Claude skill, and a link cycle doesn't hang the scan.
    @Test func findsSymlinkedSkillFolders() async throws {
        let home = URL.temporaryDirectory.appending(path: "clove-scan-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: home) }
        let manager = FileManager.default

        let dotfiles = home.appending(path: "dotfiles/skills/my-skill")
        try manager.createDirectory(at: dotfiles, withIntermediateDirectories: true)
        try Data("---\nname: my-skill\ndescription: Linked in.\n---\n".utf8).write(to: dotfiles.appending(path: "SKILL.md"))

        let claudeSkills = home.appending(path: ".claude/skills")
        try manager.createDirectory(at: claudeSkills, withIntermediateDirectories: true)
        try manager.createSymbolicLink(at: claudeSkills.appending(path: "my-skill"), withDestinationURL: dotfiles)
        // A link back to its own parent must not loop forever.
        try manager.createSymbolicLink(at: claudeSkills.appending(path: "loop"), withDestinationURL: claudeSkills)

        let configuration = ScanConfiguration(includePlugins: false, includeProjects: false, home: home, projectRoots: [])
        let skills = await SkillScanner().scan(configuration: configuration)

        let linked = try #require(skills.first { $0.name == "my-skill" })
        #expect(linked.source == .claude)
        #expect(linked.isSymlink)
        #expect(linked.originalURL.path(percentEncoded: false).contains("/.claude/skills/my-skill/"))
        #expect(linked.fileURL.path(percentEncoded: false).contains("/dotfiles/skills/my-skill/"))
    }

    /// The same file linked into two agents is two locations, so both show.
    @Test func keepsEachLinkedLocation() async throws {
        let home = URL.temporaryDirectory.appending(path: "clove-scan-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: home) }
        let manager = FileManager.default

        let shared = home.appending(path: ".agents/skills/review")
        try manager.createDirectory(at: shared, withIntermediateDirectories: true)
        try Data("---\nname: review\ndescription: Shared.\n---\n".utf8).write(to: shared.appending(path: "SKILL.md"))
        let cursorSkills = home.appending(path: ".cursor/skills")
        try manager.createDirectory(at: cursorSkills, withIntermediateDirectories: true)
        try manager.createSymbolicLink(atPath: cursorSkills.appending(path: "review").path(percentEncoded: false), withDestinationPath: "../../.agents/skills/review")

        let configuration = ScanConfiguration(includePlugins: false, includeProjects: false, home: home, projectRoots: [])
        let skills = await SkillScanner().scan(configuration: configuration)
        #expect(Set(skills.filter { $0.name == "review" }.map(\.source)) == [.agents, .cursor])

        let entry = try #require(SkillCatalog.build(from: skills).first)
        #expect(entry.copies.count == 2)
        #expect(Set(entry.copies.map(\.tagKey)).count == 1)
    }
}

struct SkillScannerLiveTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CLOVE_LIVE_TESTS"] == "1"))
    func countsRealClaudeSkills() async {
        let skills = await SkillScanner().scan(configuration: .make(includePlugins: false, includeProjects: false))
        let claude = skills.filter { $0.source == .claude }
        let names = Set(claude.map(\.directoryName))
        let onDisk = (try? FileManager.default.contentsOfDirectory(atPath: URL.homeDirectory.appending(path: ".claude/skills").path(percentEncoded: false))) ?? []
        let missing = onDisk.filter { !names.contains($0) }.sorted()
        let entries = SkillCatalog.build(from: skills).count { $0.copies.contains { $0.source == .claude } }
        let report = "claude=\(claude.count) entries=\(entries) total=\(skills.count) missing=\(missing)"
        try? report.write(to: URL(filePath: "/tmp/clove-live.txt"), atomically: true, encoding: .utf8)
    }
}
