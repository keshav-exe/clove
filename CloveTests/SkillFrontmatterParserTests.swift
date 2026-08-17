import Foundation
import Testing
@testable import Clove

struct SkillFrontmatterParserTests {
    @Test func parsesNameAndFoldedDescription() {
        let markdown = """
        ---
        name: create-skill
        description: >-
          Create Cursor Agent Skills. Use when authoring a new skill
          or asking about SKILL.md structure.
        ---
        # Creating Skills
        """

        let (matter, _) = SkillFrontmatterParser.parse(markdown)
        #expect(matter.name == "create-skill")
        #expect(matter.summary?.localizedStandardContains("authoring") == true)
    }

    @Test func parsesQuotedDescriptionAndTags() {
        let markdown = """
        ---
        name: ios-hig-design
        description: 'Design native iOS interfaces following Apple Human Interface Guidelines.'
        tags: [ios, hig, swiftui]
        ---
        Body
        """

        let (matter, body) = SkillFrontmatterParser.parse(markdown)
        #expect(matter.name == "ios-hig-design")
        #expect(matter.summary?.hasPrefix("Design native") == true)
        #expect(matter.tags == ["ios", "hig", "swiftui"])
        #expect(body.trimmingCharacters(in: .whitespacesAndNewlines) == "Body")
    }

    @Test func parsesYamlTagList() {
        let markdown = """
        ---
        name: demo
        description: A demo skill
        tags:
          - search
          - tags
        ---
        """

        let (matter, _) = SkillFrontmatterParser.parse(markdown)
        #expect(matter.tags == ["search", "tags"])
    }

    @Test func fallsBackToBodyWhenFrontmatterIsMissing() {
        let markdown = """
        # Find Skills

        Helps users discover and install agent skills from the open ecosystem.
        """

        let (matter, _) = SkillFrontmatterParser.parse(markdown)
        #expect(matter.name == nil)
        #expect(matter.summary == "Helps users discover and install agent skills from the open ecosystem.")
    }
}
