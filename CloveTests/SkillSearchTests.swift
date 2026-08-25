import Foundation
import Testing
@testable import Clove

struct SkillSearchTests {
    private let skills = [
        TestSkill.make(
            name: "swiftui-pro",
            summary: "Review Swift and SwiftUI code for correctness.",
            path: "/tmp/swiftui-pro/SKILL.md",
            directoryName: "swiftui-pro",
            source: .claude,
            frontmatterTags: ["swiftui"]
        ),
        TestSkill.make(
            name: "create-skill",
            summary: "Create Cursor Agent Skills.",
            path: "/tmp/create-skill/SKILL.md",
            directoryName: "create-skill",
            source: .cursor
        ),
        TestSkill.make(
            name: "nextjs",
            summary: "Next.js App Router expert guidance.",
            path: "/tmp/nextjs/SKILL.md",
            directoryName: "nextjs",
            source: .plugin,
            sourceDetail: "vercel",
            frontmatterTags: ["next"]
        ),
    ]

    private var catalog: [CatalogEntry] {
        SkillCatalog.build(from: skills)
    }

    @Test func ranksNameMatchesAboveDescription() {
        let results = SkillSearch.results(
            catalog: catalog,
            query: "swiftui",
            userTags: [:],
            activeTag: nil
        )
        #expect(results.first?.displayName == "swiftui-pro")
    }

    @Test func matchesUserTags() {
        let results = SkillSearch.results(
            catalog: catalog,
            query: "authoring",
            userTags: ["/tmp/create-skill/SKILL.md": ["authoring"]],
            activeTag: nil
        )
        #expect(results.map(\.displayName) == ["create-skill"])
    }

    @Test func filtersByActiveTag() {
        let results = SkillSearch.results(
            catalog: catalog,
            query: "",
            userTags: [:],
            activeTag: "next"
        )
        #expect(results.map(\.displayName) == ["nextjs"])
    }

    @Test func requiresEveryToken() {
        let results = SkillSearch.results(
            catalog: catalog,
            query: "swift review",
            userTags: [:],
            activeTag: nil
        )
        #expect(results.map(\.displayName) == ["swiftui-pro"])
    }

    @Test func fuzzyMatchesName() {
        #expect(SkillSearch.fuzzyMatch("swui", in: "swiftui-pro"))
        #expect(!SkillSearch.fuzzyMatch("xyz", in: "swiftui-pro"))
    }
}
