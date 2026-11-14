import AppKit
import Observation
import Sparkle

/// Updates through Sparkle, the way most Mac apps outside the App Store do it.
/// Clove checks once a day, downloads in the background, and installs when it
/// quits. Every update is checked against the public key in Info.plist first.
@MainActor
@Observable
final class UpdateService {
    @ObservationIgnored private let controller = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
    )
    @ObservationIgnored private var observation: NSKeyValueObservation?

    private(set) var canCheck = false

    private var updater: SPUUpdater { controller.updater }

    /// Starts the updater. Debug builds stay off: they aren't signed for
    /// release and would offer to replace themselves.
    func start() {
        #if DEBUG
        return
        #else
        do {
            try updater.start()
        } catch {
            // A bad feed URL or key in Info.plist. Check for Updates stays disabled.
            return
        }
        canCheck = updater.canCheckForUpdates
        observation = updater.observe(\.canCheckForUpdates) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.canCheck = self.updater.canCheckForUpdates
            }
        }
        #endif
    }

    /// Checking and installing on their own, as one choice.
    var isAutomatic: Bool {
        get {
            access(keyPath: \.isAutomatic)
            return updater.automaticallyChecksForUpdates && updater.automaticallyDownloadsUpdates
        }
        set {
            withMutation(keyPath: \.isAutomatic) {
                updater.automaticallyChecksForUpdates = newValue
                updater.automaticallyDownloadsUpdates = newValue
            }
        }
    }

    /// Sparkle's own window: it says whether you're up to date, or shows the
    /// release notes with Install and Later.
    func checkNow() {
        NSApp.activate()
        controller.checkForUpdates(nil)
    }
}
