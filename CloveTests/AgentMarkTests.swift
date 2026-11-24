import Foundation
import Testing
@testable import Clove

@MainActor
struct AgentMarkTests {
    @Test func theStillDotIsTheDefaultAndAPickSticks() {
        let defaults = UserDefaults(suiteName: "clove.agentmark.\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.agentMark == .dot)

        settings.agentMark = .orbit
        #expect(SettingsStore(defaults: defaults).agentMark == .orbit)

        defaults.set("sparkler", forKey: "agentMark")
        #expect(SettingsStore(defaults: defaults).agentMark == .dot)
    }
}
