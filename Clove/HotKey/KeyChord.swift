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
