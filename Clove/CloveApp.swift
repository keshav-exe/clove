import SwiftUI

@main
struct CloveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Clove", id: CloveWindowID.library) {
            LibraryRootView()
                .environment(appDelegate.model)
                .environment(appDelegate.updates)
        }
        .defaultSize(width: 980, height: 640)
        .commands {
            CloveCommands(model: appDelegate.model)
        }

        Settings {
            SettingsView()
                .environment(appDelegate.model)
                .environment(appDelegate.updates)
        }
    }
}

enum CloveWindowID {
    static let library = "library"
}
