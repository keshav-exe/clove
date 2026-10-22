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
        .defaultSize(width: 1240, height: 780)
        .commands {
            CloveCommands(model: appDelegate.model)
        }

        WindowGroup("Skill Editor", id: CloveWindowID.editor, for: URL.self) { $fileURL in
            if let fileURL {
                SkillEditorView(fileURL: fileURL)
                    .environment(appDelegate.model)
            }
        }
        .defaultSize(width: 960, height: 680)
        .commandsRemoved()

        Settings {
            SettingsView()
                .environment(appDelegate.model)
                .environment(appDelegate.updates)
        }
    }
}

enum CloveWindowID {
    static let library = "library"
    static let editor = "skill-editor"
}
