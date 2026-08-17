import Carbon
import Foundation

final class HotKeyCenter: @unchecked Sendable {
    var handler: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    deinit {
        unregister()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    @discardableResult
    func register(_ chord: KeyChord) -> Bool {
        unregister()
        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        var hotKeyID = EventHotKeyID(signature: 0x434C5645, id: 1)
        let status = RegisterEventHotKey(
            chord.keyCode,
            chord.modifiers.carbonFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr else { return false }
        hotKeyRef = ref
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    fileprivate func pressed() {
        Task { @MainActor in
            self.handler?()
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            cloveHotKeyHandler,
            1,
            &spec,
            userData,
            &handlerRef
        )
        if status != noErr {
            handlerRef = nil
        }
    }
}

private func cloveHotKeyHandler(
    _: EventHandlerCallRef?,
    _: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return noErr }
    Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue().pressed()
    return noErr
}
