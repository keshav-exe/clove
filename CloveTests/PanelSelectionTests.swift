import Foundation
import Testing
@testable import Clove

@MainActor
struct PanelSelectionTests {
    @Test func shiftUpExtendsPastTheFirstStep() {
        let model = makeModel()
        let items = model.visibleSkills
        #expect(items.count >= 3)

        model.selectExclusive(items[2])
        model.selectPrevious(extending: true)
        model.selectPrevious(extending: true)

        #expect(model.selectedIDs == Set(items[0...2].map(\.id)))
        #expect(model.selectionFocusID == items[0].id)
    }

    @Test func shiftDownKeepsTheAnchorAndMovesFocus() {
        let model = makeModel()
        let items = model.visibleSkills

        model.selectExclusive(items[0])
        model.selectNext(extending: true)
        model.selectNext(extending: true)

        #expect(model.selectedIDs == Set(items[0...2].map(\.id)))
        #expect(model.selectionAnchorID == items[0].id)
        #expect(model.selectionFocusID == items[2].id)
    }

    @Test func filteringReselectsTheFirstVisibleSkill() {
        let model = makeModel()
        let cursor = model.skills.first { $0.source == .cursor }
        let claude = model.skills.first { $0.source == .claude }
        #expect(cursor != nil && claude != nil)

        model.selectExclusive(cursor!)
        model.toggleTagFilter("swiftui")

        #expect(model.selectedIDs == [claude!.id])
        #expect(model.selectionFocusID == claude!.id)
    }

    @Test func downArrowFollowsOnScreenOrderNotSearchRank() {
        let model = makeModel(skills: [
            TestSkill.make(
                name: "alpha",
                summary: "Cursor skill A.",
                path: "/tmp/alpha/SKILL.md",
                directoryName: "alpha",
                source: .cursor
            ),
            TestSkill.make(
                name: "beta",
                summary: "Claude skill B.",
                path: "/tmp/beta/SKILL.md",
                directoryName: "beta",
                source: .claude
            ),
            TestSkill.make(
                name: "gamma",
                summary: "Cursor skill C.",
                path: "/tmp/gamma/SKILL.md",
                directoryName: "gamma",
                source: .cursor
            ),
        ])

        let items = model.visibleSkills
        #expect(items.map(\.name) == ["alpha", "gamma", "beta"])

        model.selectExclusive(items[0])
        model.selectNext()
        #expect(model.selectionFocusID == items[1].id)
        #expect(model.selectedSkill?.name == "gamma")

        model.selectNext()
        #expect(model.selectedSkill?.name == "beta")
    }

    private func makeModel(
        skills: [Skill] = [
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
                summary: "Next.js App Router expert guidance.",
                path: "/tmp/nextjs/SKILL.md",
                directoryName: "nextjs",
                source: .plugin,
                sourceDetail: "vercel",
                frontmatterTags: ["next"]
            ),
        ]
    ) -> AppModel {
        let defaults = UserDefaults(suiteName: "clove.panel-selection.\(UUID().uuidString)")!
        let model = AppModel(
            settings: SettingsStore(defaults: defaults),
            persistence: TagPersistence(
                fileURL: URL.temporaryDirectory.appending(path: "clove-panel-selection-\(UUID().uuidString).json")
            )
        )
        model.didScan = true
        model.skills = skills
        return model
    }
}
