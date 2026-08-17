import Foundation
import Testing
@testable import Clove

struct SkillReferenceTests {
    @Test func homeSkillsUseSlashPrefix() {
        let skill = Skill(
            name: "swiftui-pro",
            summary: "Review SwiftUI.",
            originalURL: URL(filePath: "/Users/me/.cursor/skills/swiftui-pro/SKILL.md"),
            fileURL: URL(filePath: "/Users/me/.cursor/skills/swiftui-pro/SKILL.md"),
            resolvedPath: "/Users/me/.cursor/skills/swiftui-pro/SKILL.md",
            directoryName: "swiftui-pro",
            source: .cursor,
            sourceDetail: nil,
            frontmatterTags: [],
            modifiedAt: .now,
            isSymlink: false,
            installKind: .homeLocal
        )
        #expect(skill.reference == "/swiftui-pro")
    }

    @Test func symlinksUseSlashPrefix() {
        let skill = Skill(
            name: "color",
            summary: "Color guidance.",
            originalURL: URL(filePath: "/Users/me/.cursor/skills/color/SKILL.md"),
            fileURL: URL(filePath: "/Users/dev/shared/color/SKILL.md"),
            resolvedPath: "/Users/dev/shared/color/SKILL.md",
            directoryName: "color",
            source: .cursor,
            sourceDetail: nil,
            frontmatterTags: [],
            modifiedAt: .now,
            isSymlink: true,
            installKind: .homeSymlink
        )
        #expect(skill.reference == "/color")
    }

    @Test func projectSkillsUseAtPrefix() {
        let skill = Skill(
            name: "nextjs",
            summary: "Next.js guidance.",
            originalURL: URL(filePath: "/Users/me/Developer/app/.cursor/skills/nextjs/SKILL.md"),
            fileURL: URL(filePath: "/Users/me/Developer/app/.cursor/skills/nextjs/SKILL.md"),
            resolvedPath: "/Users/me/Developer/app/.cursor/skills/nextjs/SKILL.md",
            directoryName: "nextjs",
            source: .project,
            sourceDetail: "app",
            frontmatterTags: [],
            modifiedAt: .now,
            isSymlink: false,
            installKind: .project
        )
        #expect(skill.reference == "@nextjs")
    }
}
