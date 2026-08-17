import Foundation
import Testing
@testable import Clove

struct LibraryFilterTests {
    private let skills = [
        TestSkill.make(
            name: "swiftui-pro",
            summary: "Review Swift and SwiftUI code.",
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
            summary: "Next.js App Router guidance.",
            path: "/tmp/nextjs/SKILL.md",
            directoryName: "nextjs",
            source: .plugin,
            sourceDetail: "vercel",
            frontmatterTags: ["next"]
        ),
    ]

    @Test func filtersBySource() {
        let results = SkillSearch.library(
            skills: skills,
            query: "",
            userTags: [:],
            filter: .source(.plugin)
        )
        #expect(results.map(\.name) == ["nextjs"])
    }

    @Test func filtersByTagIncludingUserTags() {
        let results = SkillSearch.library(
            skills: skills,
            query: "",
            userTags: ["/tmp/create-skill/SKILL.md": ["authoring"]],
            filter: .tag("authoring")
        )
        #expect(results.map(\.name) == ["create-skill"])
    }

    @Test func combinesFilterAndQuery() {
        let results = SkillSearch.library(
            skills: skills,
            query: "router",
            userTags: [:],
            filter: .source(.plugin)
        )
        #expect(results.map(\.name) == ["nextjs"])

        let empty = SkillSearch.library(
            skills: skills,
            query: "router",
            userTags: [:],
            filter: .source(.claude)
        )
        #expect(empty.isEmpty)
    }

    @Test func countsMatchFilters() {
        #expect(SkillSearch.count(of: .all, in: skills, userTags: [:]) == 3)
        #expect(SkillSearch.count(of: .source(.claude), in: skills, userTags: [:]) == 1)
        #expect(SkillSearch.count(of: .tag("swiftui"), in: skills, userTags: [:]) == 1)
    }
}
