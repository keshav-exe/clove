import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class UpdateService {
    var availableUpdate: UpdateManifest?
    var isChecking = false
    var lastCheckError: String?

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func checkForUpdates(userInitiated: Bool = false) async {
        guard let manifestURL = ReleaseConfiguration.updateManifestURL else {
            if userInitiated {
                lastCheckError = "Updates are not configured for this build."
            }
            return
        }

        isChecking = true
        lastCheckError = nil
        defer { isChecking = false }

        do {
            let manifest = try await UpdateManifestLoader.load(from: manifestURL)
            guard VersionCompare.isNewer(manifest.version, than: AppVersion.short) else {
                availableUpdate = nil
                return
            }
            guard manifest.version != settings.skippedUpdateVersion else {
                availableUpdate = nil
                return
            }
            availableUpdate = manifest
        } catch {
            if userInitiated {
                lastCheckError = error.localizedDescription
            }
        }
    }

    func installNow(_ update: UpdateManifest) {
        settings.pendingUpdateURL = update.downloadURL.absoluteString
        settings.installUpdateOnLaunch = false
        NSWorkspace.shared.open(update.downloadURL)
        availableUpdate = nil
    }

    func installOnNextLaunch(_ update: UpdateManifest) {
        settings.pendingUpdateURL = update.downloadURL.absoluteString
        settings.installUpdateOnLaunch = true
        settings.skippedUpdateVersion = update.version
        availableUpdate = nil
    }

    func dismiss(_ update: UpdateManifest) {
        settings.skippedUpdateVersion = update.version
        availableUpdate = nil
    }

    func applyDeferredInstallIfNeeded() {
        guard settings.installUpdateOnLaunch,
              let raw = settings.pendingUpdateURL,
              let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
        settings.installUpdateOnLaunch = false
    }
}
