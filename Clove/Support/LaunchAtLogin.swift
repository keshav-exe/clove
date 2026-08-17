import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class LaunchAtLogin {
    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            apply(isEnabled)
        }
    }

    var lastError: String?

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    private func apply(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }
}
