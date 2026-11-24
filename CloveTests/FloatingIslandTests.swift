import Foundation
import Testing
@testable import Clove

@MainActor
struct FloatingIslandTests {
    private func makeNotch(_ style: NotchGeometry.Style) -> NotchModel {
        let defaults = UserDefaults(suiteName: "clove.floating.\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        settings.accessMode = .notch
        let home = URL.temporaryDirectory.appending(path: "floating-\(UUID().uuidString)", directoryHint: .isDirectory)
        let notch = NotchModel(agents: AgentActivityStore(home: home, defaults: nil), settings: settings)
        notch.geometry = style == .island
            ? NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440), size: CGSize(width: NotchGeometry.pillWidth, height: 22), midX: 1280, style: .island, topInset: 2)
            : NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), size: CGSize(width: 185, height: 32), midX: 756, style: .notch)
        return notch
    }

    private func working() -> AgentSession {
        AgentSession(id: "a", agent: .claude, folder: nil, title: "Fix the hero", state: .working, steps: [], change: nil, summary: nil, updatedAt: .now)
    }

    @Test func theFloatingIslandWaitsOutOfSightUntilSomethingIsLive() {
        let notch = makeNotch(.island)
        #expect(notch.isFloating)
        #expect(notch.isHiddenAtRest)
        notch.agents.showPreview([working()])
        #expect(notch.isLive)
        #expect(!notch.isHiddenAtRest)
        // A pill: its label between two ears, rounded all round.
        #expect(notch.size.width == NotchModel.islandLabelWidth + notch.earWidth * 2)
        #expect(notch.shoulderRadius == 0)
        #expect(notch.bottomRadius == 11)
        #expect(LiveEarsLabel.text([working()]) == "Fix the hero")
    }

    @Test func itFoldsAwayWhileShotputHasTheNotch() {
        let notch = makeNotch(.island)
        notch.agents.showPreview([working()])
        notch.isYielding = true
        #expect(!notch.isLive)
        #expect(notch.isHiddenAtRest)
    }

    @Test func itSitsInsideTheMenuBarNotOnItsEdge() {
        let notch = makeNotch(.island)
        let rect = notch.geometry!.hangingRect(CGSize(width: 128, height: 22))
        #expect(abs(rect.maxY - 1438) < 0.01)
    }

    @Test func theNotchKeepsItsEarsAndStaysVisible() {
        let notch = makeNotch(.notch)
        #expect(!notch.isFloating)
        #expect(!notch.isHiddenAtRest)
        notch.agents.showPreview([working()])
        #expect(notch.size.width == 185 + notch.earWidth * 2 + 12)
        notch.settings.notchShowsAgents = false
        #expect(!notch.isLive)
    }
}
