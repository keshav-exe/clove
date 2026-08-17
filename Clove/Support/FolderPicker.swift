import AppKit

@MainActor
enum FolderPicker {
    /// Asks for a folder to scan. macOS grants read access to whatever the user
    /// picks here, which is why Clove never asks for blanket disk access.
    static func chooseProjectFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Add Folder"
        panel.message = "Pick a folder that holds your projects. Clove only reads SKILL.md files inside it."
        panel.directoryURL = URL.homeDirectory
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
