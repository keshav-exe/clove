import SwiftUI

@main
struct CloveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var license = LicenseService.shared

    var body: some Scene {
        Window("Clove", id: CloveWindowID.library) {
            LibraryRootView()
                .environment(appDelegate.model)
                .environment(appDelegate.updates)
                .environment(license)
                .task {
                    await license.bootstrap()
                }
        }
        .defaultSize(width: 980, height: 640)
        .commands {
            CloveCommands(model: appDelegate.model)
        }

        Settings {
            SettingsView()
                .environment(appDelegate.model)
                .environment(appDelegate.updates)
                .environment(license)
        }
    }
}

enum CloveWindowID {
    static let library = "library"
}
