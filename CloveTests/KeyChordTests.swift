import Foundation
import Testing
@testable import Clove

struct KeyChordTests {
    @Test func defaultShortcutIsControlOptionSpace() {
        #expect(KeyChord.default.keyCode == 49)
        #expect(KeyChord.default.modifiers == [.control, .option])
        #expect(KeyChord.default.displayString == "⌃⌥Space")
    }

    @Test func carbonFlagsMatchCarbonConstants() {
        #expect(KeyModifiers.command.carbonFlags == 256)
        #expect(KeyModifiers.shift.carbonFlags == 512)
        #expect(KeyModifiers.option.carbonFlags == 2_048)
        #expect(KeyModifiers.control.carbonFlags == 4_096)
        #expect(KeyModifiers([.control, .option]).carbonFlags == 6_144)
    }

    @Test func modifierOnlyEventsAreRejected() {
        #expect(KeyChord.isModifierKey(55))
        #expect(KeyChord.isModifierKey(58))
        #expect(!KeyChord.isModifierKey(49))
    }
}
