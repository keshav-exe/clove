import Foundation

/// How Clove and Shotput share the notch. Clove says when its island opens and
/// closes. Shotput claims the notch while you drag something to pin, and Clove
/// folds back to the bare notch, with no ears, so Shotput's island grows out of
/// a clean notch; when Shotput releases it, Clove's ears and moments come back.
///
/// Any notch app can join by posting the same pair of distributed notifications.
enum NotchHandshake {
    /// Posted by Clove.
    static let cloveDidOpen = Notification.Name("com.kshvbgde.clove.notch.didOpen")
    static let cloveDidClose = Notification.Name("com.kshvbgde.clove.notch.didClose")
    /// Posted by Shotput.
    static let shotputDidClaim = Notification.Name("app.shotput.notch.didClaim")
    static let shotputDidRelease = Notification.Name("app.shotput.notch.didRelease")

    /// A partner that quits or crashes mid-drag never releases; Clove takes the
    /// notch back on its own after this long.
    static let yieldTimeout: Duration = .seconds(10)

    static func post(_ name: Notification.Name) {
        DistributedNotificationCenter.default().postNotificationName(name, object: nil, userInfo: nil, deliverImmediately: true)
    }
}
