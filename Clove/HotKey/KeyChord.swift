import AppKit
import Carbon
import Foundation

struct KeyChord: Equatable, Codable, Hashable, Sendable {
    var keyCode: UInt32
    var modifiers: KeyModifiers

    static let `default` = KeyChord(keyCode: 49, modifiers: [.control, .option])

    var displayString: String {
        modifiers.symbols + keyName
    }

    var keyName: String {
        Self.name(for: keyCode)
    }

    /// The character an NSMenuItem needs to draw this chord on the right of a
    /// menu, the native way. Nil for keys a menu can't show.
    var menuKeyEquivalent: String? {
        if let special = Self.menuKeys[keyCode] {
            return String(Character(UnicodeScalar(special) ?? " "))
        }
        guard let letter = Self.translatedCharacter(for: keyCode), letter.count == 1 else { return nil }
        return letter.lowercased()
    }

    private static let menuKeys: [UInt32: UInt32] = [
        36: 0x0D,
        48: 0x09,
        49: 0x20,
        51: 0x08,
        53: 0x1B,
        76: 0x03,
        117: 0x7F,
        122: UInt32(NSF1FunctionKey), 120: UInt32(NSF2FunctionKey), 99: UInt32(NSF3FunctionKey),
        118: UInt32(NSF4FunctionKey), 96: UInt32(NSF5FunctionKey), 97: UInt32(NSF6FunctionKey),
        98: UInt32(NSF7FunctionKey), 100: UInt32(NSF8FunctionKey), 101: UInt32(NSF9FunctionKey),
        109: UInt32(NSF10FunctionKey), 103: UInt32(NSF11FunctionKey), 111: UInt32(NSF12FunctionKey),
        115: UInt32(NSHomeFunctionKey), 119: UInt32(NSEndFunctionKey),
        116: UInt32(NSPageUpFunctionKey), 121: UInt32(NSPageDownFunctionKey),
        123: UInt32(NSLeftArrowFunctionKey), 124: UInt32(NSRightArrowFunctionKey),
        125: UInt32(NSDownArrowFunctionKey), 126: UInt32(NSUpArrowFunctionKey),
    ]

    init(keyCode: UInt32, modifiers: KeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        let modifiers = KeyModifiers(cocoa: event.modifierFlags)
        guard !modifiers.isEmpty else { return nil }
        let keyCode = UInt32(event.keyCode)
        guard !Self.isModifierKey(keyCode) else { return nil }
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    static func isModifierKey(_ keyCode: UInt32) -> Bool {
        switch keyCode {
        case 54, 55, 56, 57, 58, 59, 60, 61, 62, 63:
            true
        default:
            false
        }
    }

    static func name(for keyCode: UInt32) -> String {
        if let name = specialNames[keyCode] {
            return name
        }
        if let letter = translatedCharacter(for: keyCode) {
            return letter
        }
        return "Key \(keyCode)"
    }

    private static let specialNames: [UInt32: String] = [
        36: "Return",
        48: "Tab",
        49: "Space",
        51: "Delete",
        53: "Esc",
        76: "Enter",
        96: "F5",
        97: "F6",
        98: "F7",
        99: "F3",
        100: "F8",
        101: "F9",
        103: "F11",
        105: "F13",
        107: "F14",
        109: "F10",
        111: "F12",
        113: "F15",
        114: "Help",
        115: "Home",
        116: "Page Up",
        117: "Forward Delete",
        118: "F4",
        119: "End",
        120: "F2",
        121: "Page Down",
        122: "F1",
        123: "←",
        124: "→",
        125: "↓",
        126: "↑",
    ]

    private static func translatedCharacter(for keyCode: UInt32) -> String? {
        let layout = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
        guard let raw = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer in
            guard let layoutPtr = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return nil
            }
            var deadKeys: UInt32 = 0
            var length: Int = 0
            var chars: [UniChar] = [0, 0, 0, 0]
            let status = UCKeyTranslate(
                layoutPtr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeys,
                4,
                &length,
                &chars
            )
            guard status == noErr, length > 0 else { return nil }
            let string = String(utf16CodeUnits: chars, count: length)
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return trimmed.uppercased()
        }
    }
}
