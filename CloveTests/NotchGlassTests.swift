import Foundation
import Testing
@testable import Clove

@MainActor
struct NotchGlassTests {
    @Test func glassFollowsMacOSUntilYouPickATint() {
        let name = "clove.notch-glass.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = SettingsStore(defaults: defaults)
        #expect(settings.notchGlassFollowsSystem)
        #expect((0...1).contains(settings.glassTint))

        settings.notchGlassFollowsSystem = false
        #expect(settings.glassTint == SettingsStore.defaultGlassTint)

        settings.notchGlassTint = 0.8
        let reopened = SettingsStore(defaults: defaults)
        #expect(!reopened.notchGlassFollowsSystem)
        #expect(reopened.glassTint == 0.8)

        defaults.set(3.0, forKey: "notchGlassTint")
        #expect(SettingsStore(defaults: defaults).notchGlassTint == 1)
    }
}
