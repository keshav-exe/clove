import Foundation
import Testing
@testable import Clove

struct SkillCatalogTests {
    @Test func mergesSameReferenceAcrossSources() {
        let skills = [
            TestSkill.make(
                name: "design",
                summary: "Design UI.",
                path: "/Users/me/.cursor/skills/design/SKILL.md",
                directoryName: "design",
                source: .cursor
            ),
            TestSkill.make(
                name: "design",
                summary: "Design UI.",
                path: "/Users/me/.claude/skills/design/SKILL.md",
                directoryName: "design",
                source: .claude
            ),
            TestSkill.make(
                name: "design",
                summary: "Design UI.",
                path: "/Users/me/.agents/skills/design/SKILL.md",
                directoryName: "design",
                source: .agents
            ),
        ]

        let catalog = SkillCatalog.build(from: skills)

        #expect(catalog.count == 1)
        #expect(catalog[0].isLinked)
        #expect(catalog[0].sources == [SkillSource.cursor, .claude, .agents])
        #expect(catalog[0].reference == "/design")
    }

    @Test func keepsProjectSkillsSeparate() {
        let skills = [
            TestSkill.make(
                name: "nextjs",
                summary: "Next.js guidance.",
                path: "/Users/me/Developer/app-a/.cursor/skills/nextjs/SKILL.md",
                directoryName: "nextjs",
                source: .project,
                sourceDetail: "app-a"
            ),
            TestSkill.make(
                name: "nextjs",
                summary: "Next.js guidance.",
                path: "/Users/me/Developer/app-b/.cursor/skills/nextjs/SKILL.md",
                directoryName: "nextjs",
                source: .project,
                sourceDetail: "app-b"
            ),
        ]

        let catalog = SkillCatalog.build(from: skills)

        #expect(catalog.count == 2)
    }
}
