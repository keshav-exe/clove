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

    private var catalog: [CatalogEntry] {
        SkillCatalog.build(from: skills)
    }

    @Test func filtersBySource() {
        let results = SkillSearch.library(
            catalog: catalog,
            query: "",
            userTags: [:],
            filter: .source(.plugin)
        )
        #expect(results.map(\.displayName) == ["nextjs"])
    }

    @Test func filtersByTagIncludingUserTags() {
        let results = SkillSearch.library(
            catalog: catalog,
            query: "",
            userTags: ["/tmp/create-skill/SKILL.md": ["authoring"]],
            filter: .tag("authoring")
        )
        #expect(results.map(\.displayName) == ["create-skill"])
    }

    @Test func combinesFilterAndQuery() {
        let results = SkillSearch.library(
            catalog: catalog,
            query: "router",
            userTags: [:],
            filter: .source(.plugin)
        )
        #expect(results.map(\.displayName) == ["nextjs"])

        let empty = SkillSearch.library(
            catalog: catalog,
            query: "router",
            userTags: [:],
            filter: .source(.claude)
        )
        #expect(empty.isEmpty)
    }

    @Test func countsMatchFilters() {
        #expect(SkillSearch.count(of: .all, in: catalog, userTags: [:]) == 3)
        #expect(SkillSearch.count(of: .source(.claude), in: catalog, userTags: [:]) == 1)
        #expect(SkillSearch.count(of: .tag("swiftui"), in: catalog, userTags: [:]) == 1)
    }
}
