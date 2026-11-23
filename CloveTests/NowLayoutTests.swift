import Foundation
import Testing
@testable import Clove

@MainActor
struct NowLayoutTests {
    private func makeSettings() -> (SettingsStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "clove.now-layout.\(UUID().uuidString)")!
        return (SettingsStore(defaults: defaults), defaults)
    }

    @Test func sectionsMoveHideAndComeBackInPlace() {
        let (settings, defaults) = makeSettings()
        #expect(settings.nowSections == NowSection.defaults)
        settings.moveSection(.limits, by: -1)
        #expect(settings.nowSections.prefix(3) == [.agents, .limits, .ports])
        settings.moveSection(.agents, by: -1)
        #expect(settings.nowSections.first == .agents)
        settings.setSection(.busy, shown: false)
        #expect(!settings.nowSections.contains(.busy))
        settings.setSection(.busy, shown: true)
        #expect(settings.nowSections == [.agents, .limits, .ports, .busy, .elsewhere])
        #expect(SettingsStore(defaults: defaults).nowSections == settings.nowSections)
    }
}
