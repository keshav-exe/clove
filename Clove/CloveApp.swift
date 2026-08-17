import SwiftUI

@main
struct CloveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var license = LicenseService.shared

    var body: some Scene {
        Window("Clove", id: CloveWindowID.library) {
            LibraryRootView()
                .environment(appDelegate.model)
                .environment(license)
                .task {
                    #if !DEBUG
                    await license.bootstrap()
                    #endif
                }
        }
        .defaultSize(width: 980, height: 640)
        .commands {
            CloveCommands(model: appDelegate.model)
        }

        Settings {
            SettingsView()
                .environment(appDelegate.model)
                .environment(license)
        }
        .defaultSize(width: Metrics.settingsWidth, height: Metrics.settingsHeight)
    }
}

enum CloveWindowID {
    static let library = "library"
}
