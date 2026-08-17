import Foundation
import Testing
@testable import Clove

struct SkillSourceTests {
    private let home = "/Users/keshav"

    @Test func classifiesKnownHomes() {
        #expect(SkillSource.classify(path: "\(home)/.cursor/skills/foo/SKILL.md", home: home) == .cursor)
        #expect(SkillSource.classify(path: "\(home)/.cursor/skills-cursor/bar/SKILL.md", home: home) == .cursorBuiltin)
        #expect(SkillSource.classify(path: "\(home)/.claude/skills/baz/SKILL.md", home: home) == .claude)
        #expect(SkillSource.classify(path: "\(home)/.agents/skills/baz/SKILL.md", home: home) == .agents)
        #expect(SkillSource.classify(path: "\(home)/.codex/skills/baz/SKILL.md", home: home) == .codex)
    }

    @Test func classifiesPluginsBeforeCursor() {
        let path = "\(home)/.cursor/plugins/cache/cursor-public/vercel/abc/skills/nextjs/SKILL.md"
        #expect(SkillSource.classify(path: path, home: home) == .plugin)
        #expect(SkillSource.detail(path: path, source: .plugin) == "vercel")
    }

    @Test func classifiesProjectSkills() {
        let path = "\(home)/Developer/photos-deduper/.cursor/skills/review/SKILL.md"
        #expect(SkillSource.classify(path: path, home: home) == .project)
        #expect(SkillSource.detail(path: path, source: .project) == "photos-deduper")
    }
}
