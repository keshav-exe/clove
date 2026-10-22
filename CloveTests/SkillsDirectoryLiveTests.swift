import Foundation
import Testing
@testable import Clove

/// Hits skills.sh and GitHub for real. Off by default; run with
/// `CLOVE_LIVE_TESTS=1` to check that the site still looks the way the parsers expect.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["CLOVE_LIVE_TESTS"] == "1"))
struct SkillsDirectoryLiveTests {
    let client = SkillsDirectoryClient()

    @Test(arguments: DiscoverFeed.allCases)
    func leaderboardsParse(feed: DiscoverFeed) async throws {
        let skills = try await client.leaderboard(feed)
        #expect(skills.count > 50)
        #expect(skills.allSatisfy { !$0.skillId.isEmpty && !$0.source.isEmpty })
    }

    @Test func searchFindsKnownSkill() async throws {
        let results = try await client.search("swiftui")
        #expect(results.contains { $0.skillId == "swiftui-pro" })
    }

    @Test func detailFindsSkillFileAndPage() async throws {
        let skill = MarketplaceSkill(source: "mattpocock/skills", skillId: "grill-me", name: "grill-me", installs: 0)
        let file = try await client.skillFile(for: skill)
        #expect(file.path.hasSuffix("/grill-me/SKILL.md"))

        let page = try await client.pageDetails(for: skill)
        #expect(page.description != nil)
    }

    @Test func installsLinksAndRemovesInScratchHome() async throws {
        let home = URL.temporaryDirectory.appending(path: "clove-home-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: home) }
        let installer = SkillInstaller(home: home)
        let skill = MarketplaceSkill(source: "vercel-labs/skills", skillId: "find-skills", name: "find-skills", installs: 0)

        let folder = try await installer.install(skill, targets: [.claude, .cursor])
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: "SKILL.md").path(percentEncoded: false)))
        #expect(await installer.linkedTargets(for: "find-skills") == [.claude, .cursor])

        let entry = try #require(installer.lock.entries()["find-skills"])
        #expect(entry.skillPath == "skills/find-skills/SKILL.md")
        #expect(await installer.isEditedLocally(entry) == false)
        #expect(try await installer.entriesWithUpdates([entry]).isEmpty)

        try await installer.unlink("find-skills", from: .cursor)
        #expect(await installer.linkedTargets(for: "find-skills") == [.claude])

        try await installer.uninstall(folders: [folder], name: "find-skills")
        #expect(await installer.linkedTargets(for: "find-skills").isEmpty)
        #expect(installer.lock.entries().isEmpty)
    }
}
