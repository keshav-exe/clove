import Foundation
import Testing
@testable import Clove

struct SkillManagementTests {
    @Test func lockFileKeepsUnknownKeys() throws {
        let url = URL.temporaryDirectory.appending(path: "clove-lock-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let original = """
        {"version":3,"dismissed":{"findSkillsPrompt":true},"skills":{"other":{"source":"a/b","sourceType":"github","skillPath":"other/SKILL.md","skillFolderHash":"abc","installedAt":"2026-04-28T20:39:58.287Z","updatedAt":"2026-04-28T20:39:58.287Z","extra":1}}}
        """
        try Data(original.utf8).write(to: url)

        let lock = SkillLockFile(url: url)
        try lock.record(SkillLockEntry(
            name: "demo",
            source: "owner/repo",
            sourceType: "github",
            skillPath: "skills/demo/SKILL.md",
            folderHash: "def",
            installedAt: nil,
            updatedAt: nil
        ))

        let entries = lock.entries()
        #expect(entries["demo"]?.folderPath == "skills/demo")
        #expect(entries["other"]?.installedAt != nil)

        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        #expect((root?["dismissed"] as? [String: Bool])?["findSkillsPrompt"] == true)
        let other = (root?["skills"] as? [String: Any])?["other"] as? [String: Any]
        #expect(other?["extra"] as? Int == 1)

        try lock.remove(name: "demo")
        #expect(lock.entries()["demo"] == nil)
    }

    @Test func linksAreRelativeToHome() {
        #expect(SkillInstaller.relativeLinkTarget(for: .claude, name: "demo") == "../../.agents/skills/demo")
    }

    @Test func rejectsUnsafeNames() {
        #expect(throws: SkillInstaller.Failure.self) { try SkillInstaller.validatedName("../etc") }
        #expect(throws: SkillInstaller.Failure.self) { try SkillInstaller.validatedName(".hidden") }
        #expect(throws: SkillInstaller.Failure.self) { try SkillInstaller.validatedName("a/b") }
        #expect((try? SkillInstaller.validatedName("swiftui-pro")) == "swiftui-pro")
    }

    @Test func locatesSkillFolderByNameThenFrontmatter() throws {
        let root = URL.temporaryDirectory.appending(path: "clove-repo-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = FileManager.default
        for (path, text) in [
            ("plugins/x/skills/grill-me/SKILL.md", "---\nname: grill-me\n---\n"),
            ("skills/renamed/SKILL.md", "---\nname: fancy\n---\n"),
        ] {
            let file = root.appending(path: path)
            try manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: file)
        }

        let byFolder = try SkillFolderLocator.folder(
            for: MarketplaceSkill(source: "a/b", skillId: "grill-me", name: "grill-me", installs: 0),
            in: root,
            hint: nil
        )
        #expect(byFolder.lastPathComponent == "grill-me")

        let byName = try SkillFolderLocator.folder(
            for: MarketplaceSkill(source: "a/b", skillId: "fancy", name: "fancy", installs: 0),
            in: root,
            hint: nil
        )
        #expect(byName.lastPathComponent == "renamed")

        #expect(throws: SkillInstaller.Failure.self) {
            try SkillFolderLocator.folder(
                for: MarketplaceSkill(source: "a/b", skillId: "missing", name: "missing", installs: 0),
                in: root,
                hint: nil
            )
        }
    }

    @Test func treeFolderHashLooksUpPaths() {
        let tree = GitHubClient.Tree(sha: "root", tree: [
            GitHubClient.TreeItem(path: "skills/demo", type: "tree", sha: "one"),
            GitHubClient.TreeItem(path: "skills/demo/SKILL.md", type: "blob", sha: "two"),
        ])
        #expect(tree.folderHash(at: "skills/demo") == "one")
        #expect(tree.folderHash(at: "") == "root")
        #expect(tree.folderHash(at: "skills/missing") == nil)
        #expect(SkillsDirectoryClient.skillPaths(in: tree.tree, matching: "demo") == ["skills/demo/SKILL.md"])
    }
}
