import Foundation
import Testing
@testable import Clove

@MainActor
struct NotchGlassTests {
    @Test func clarityStartsMidwaySticksAndStaysInRange() {
        let name = "clove.notch-glass.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = SettingsStore(defaults: defaults)
        #expect(settings.notchGlassClarity == SettingsStore.defaultGlassClarity)

        settings.notchGlassClarity = 0.8
        #expect(SettingsStore(defaults: defaults).notchGlassClarity == 0.8)

        defaults.set(3.0, forKey: "notchGlassClarity")
        #expect(SettingsStore(defaults: defaults).notchGlassClarity == 1)
    }
}
