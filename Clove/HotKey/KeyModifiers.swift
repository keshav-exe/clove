import AppKit
import Carbon
import Foundation

struct KeyModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt

    static let control = KeyModifiers(rawValue: 1 << 0)
    static let option = KeyModifiers(rawValue: 1 << 1)
    static let shift = KeyModifiers(rawValue: 1 << 2)
    static let command = KeyModifiers(rawValue: 1 << 3)

    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.control) { flags |= UInt32(controlKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        if contains(.command) { flags |= UInt32(cmdKey) }
        return flags
    }

    var symbols: String {
        var parts = ""
        if contains(.control) { parts += "⌃" }
        if contains(.option) { parts += "⌥" }
        if contains(.shift) { parts += "⇧" }
        if contains(.command) { parts += "⌘" }
        return parts
    }

    init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    init(cocoa flags: NSEvent.ModifierFlags) {
        var value: KeyModifiers = []
        if flags.contains(.control) { value.insert(.control) }
        if flags.contains(.option) { value.insert(.option) }
        if flags.contains(.shift) { value.insert(.shift) }
        if flags.contains(.command) { value.insert(.command) }
        self = value
    }
}
