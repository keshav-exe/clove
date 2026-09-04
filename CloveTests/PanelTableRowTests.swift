import Testing
@testable import Clove

struct PanelTableRowTests {
    @Test func flattensHeadersThenSkillsInSectionOrder() {
        let cursor = TestSkill.make(
            name: "create-skill",
            summary: "Create a skill.",
            path: "/tmp/create-skill/SKILL.md",
            directoryName: "create-skill",
            source: .cursor
        )
        let claude = TestSkill.make(
            name: "swiftui-pro",
            summary: "Review SwiftUI.",
            path: "/tmp/swiftui-pro/SKILL.md",
            directoryName: "swiftui-pro",
            source: .claude
        )
        let catalog = SkillCatalog.build(from: [cursor, claude])
        let sections = SkillSearch.sections(from: catalog)
        let rows = PanelTableRow.rows(from: sections)

        let skillIDs = rows.compactMap(\.skillID)
        #expect(skillIDs == catalog.map(\.primary.id))
        #expect(rows.filter { $0.skillID == nil }.count == sections.count)
    }
}
