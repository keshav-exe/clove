import Foundation
import Testing
@testable import Clove

struct CleanupTests {
    @Test func readsSkillUseFromTranscriptLines() {
        let transcript = #"""
        {"type":"tool_use","name":"Skill","input":{"skill":"animations"}}
        {"message":"<command-name>/swiftui-pro:swiftui-pro</command-name>"}
        {"cmd":"cat /Users/me/.agents/skills/ui-polish/SKILL.md"}
        {"cmd":"sed -n 1p .claude\/skills\/escaped\/SKILL.md"}
        {"text":"the word skill and /SKILL.md alone"}
        """#
        let names = AgentUsageScanner.skillNames(in: Data(transcript.utf8))
        #expect(names.isSuperset(of: ["animations", "swiftui-pro", "ui-polish", "escaped"]))
        #expect(!names.contains(""))
    }

    @Test func listsOnlyIdleHomeSkills() {
        let now = Date.now
        let old = now.addingTimeInterval(-200 * 86_400)
        func entry(_ name: String, source: SkillSource, modified: Date = old) -> CatalogEntry {
            let skill = Skill(
                name: name,
                summary: "Does a thing.",
                originalURL: URL(filePath: "/tmp/\(source)/\(name)/SKILL.md"),
                fileURL: URL(filePath: "/tmp/\(source)/\(name)/SKILL.md"),
                resolvedPath: "/tmp/\(source)/\(name)/SKILL.md",
                directoryName: name,
                source: source,
                sourceDetail: nil,
                frontmatterTags: [],
                modifiedAt: modified,
                isSymlink: false,
                installKind: .homeLocal
            )
            return CatalogEntry(key: name, primary: skill, copies: [skill])
        }

        let catalog = [
            entry("never", source: .claude),
            entry("stale", source: .agents),
            entry("recent", source: .claude),
            entry("plugin", source: .plugin),
            entry("fresh-install", source: .claude, modified: now),
        ]
        let lastUsed = [
            "stale": now.addingTimeInterval(-100 * 86_400),
            "recent": now.addingTimeInterval(-2 * 86_400),
        ]

        let candidates = CleanupCandidate.candidates(in: catalog, lastUsed: lastUsed, window: .month, now: now)
        #expect(candidates.map(\.displayName) == ["never", "stale"])
        #expect(candidates[0].lastUsed == nil)
        #expect(candidates.allSatisfy { $0.tokens > 0 })
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["CLOVE_LIVE_TESTS"] == "1"))
    func scansRealHistory() async {
        let cache = URL.temporaryDirectory.appending(path: "clove-usage-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: cache) }
        let scanner = AgentUsageScanner(cacheURL: cache)

        let clock = ContinuousClock()
        var report: AgentUsageScanner.Report?
        let cold = await clock.measure { report = await scanner.scan() }
        let warm = await clock.measure { _ = await scanner.scan() }
        print("usage scan: \(report?.transcriptCount ?? 0) files, \(report?.lastUsed.count ?? 0) skills, cold \(cold), warm \(warm)")
        #expect((report?.transcriptCount ?? 0) > 0)
    }
}
