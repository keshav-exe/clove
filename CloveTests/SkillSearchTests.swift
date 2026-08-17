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

    @Test func ranksNameMatchesAboveDescription() {
        let results = SkillSearch.results(
            skills: skills,
            query: "swiftui",
            userTags: [:],
            activeTag: nil
        )
        #expect(results.first?.name == "swiftui-pro")
    }

    @Test func matchesUserTags() {
        let results = SkillSearch.results(
            skills: skills,
            query: "authoring",
            userTags: ["/tmp/create-skill/SKILL.md": ["authoring"]],
            activeTag: nil
        )
        #expect(results.map(\.name) == ["create-skill"])
    }

    @Test func filtersByActiveTag() {
        let results = SkillSearch.results(
            skills: skills,
            query: "",
            userTags: [:],
            activeTag: "next"
        )
        #expect(results.map(\.name) == ["nextjs"])
    }

    @Test func requiresEveryToken() {
        let results = SkillSearch.results(
            skills: skills,
            query: "swift review",
            userTags: [:],
            activeTag: nil
        )
        #expect(results.map(\.name) == ["swiftui-pro"])
    }

    @Test func fuzzyMatchesName() {
        #expect(SkillSearch.fuzzyMatch("swui", in: "swiftui-pro"))
        #expect(!SkillSearch.fuzzyMatch("xyz", in: "swiftui-pro"))
    }
}
