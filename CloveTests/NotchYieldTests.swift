import Foundation
import Testing
@testable import Clove

@MainActor
struct NotchYieldTests {
    private func makeNotch() -> NotchModel {
        let defaults = UserDefaults(suiteName: "clove.notch-yield.\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        settings.accessMode = .notch
        let home = URL.temporaryDirectory.appending(path: "notch-yield-\(UUID().uuidString)", directoryHint: .isDirectory)
        return NotchModel(agents: AgentActivityStore(home: home, defaults: nil), settings: settings)
    }

    private func moment(_ title: String) -> NotchMoment {
        NotchMoment(symbol: "checkmark", tone: .done, title: title, detail: nil)
    }

    @Test func momentsWaitWhileYieldingAndShowOnRelease() {
        let notch = makeNotch()
        notch.isYielding = true
        notch.present(moment("First"))
        notch.present(moment("Second"))
        #expect(notch.phase == .collapsed)
        #expect(notch.moment == nil)

        notch.isYielding = false
        notch.resumeMoments()
        #expect(notch.phase == .moment)
        #expect(notch.moment?.title == "First")

        notch.advanceMoments()
        #expect(notch.moment?.title == "Second")
    }

    @Test func yieldingDropsTheEars() {
        let notch = makeNotch()
        notch.isYielding = true
        #expect(!notch.isLive)
        #expect(notch.size.width < notch.notchSize.width)
    }

    @Test func resumingWithNothingQueuedStaysCollapsed() {
        let notch = makeNotch()
        notch.resumeMoments()
        #expect(notch.phase == .collapsed)
        #expect(notch.moment == nil)
    }
}
