import SwiftUI

/// Starts an instruction file where an agent will find it, then opens it.
struct NewInstructionsMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Menu("New Instructions File", systemImage: "plus") {
            Section("For Every Project") {
                globalButton("Claude Code", path: ".claude/CLAUDE.md")
                globalButton("Codex", path: ".codex/AGENTS.md")
                globalButton("Gemini", path: ".gemini/GEMINI.md")
            }
            Section("For One Project") {
                ForEach(model.projects.prefix(15), id: \.self) { project in
                    Button(project.lastPathComponent) { create(at: project.appending(path: "AGENTS.md"), title: project.lastPathComponent) }
                        .disabled(hasContent(project.appending(path: "AGENTS.md")))
                }
                Divider()
                Button("Choose Folder…", action: chooseProject)
            }
        }
        .help("Create a CLAUDE.md or AGENTS.md")
    }

    private func globalButton(_ title: String, path: String) -> some View {
        let file = URL.homeDirectory.appending(path: path)
        return Button("\(title) (\(file.lastPathComponent))") { create(at: file, title: "Global instructions") }
            .disabled(hasContent(file))
    }

    private func chooseProject() {
        guard let project = FolderPicker.chooseProject() else { return }
        create(at: project.appending(path: "AGENTS.md"), title: project.lastPathComponent)
    }

    /// AGENTS.md for projects: Codex, Cursor, Copilot, and others read it, and
    /// Claude Code can link to it from Read By.
    private func create(at file: URL, title: String) {
        let manager = FileManager.default
        do {
            if !hasContent(file) {
                try manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(Self.template(title: title).utf8).write(to: file, options: .atomic)
            }
            openWindow(id: CloveWindowID.editor, value: file)
            Task { await model.refresh() }
        } catch {
            model.manager.failure = ManagerFailure(title: "Couldn't create \(file.lastPathComponent)", error: error)
        }
    }

    private func hasContent(_ file: URL) -> Bool {
        let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Headings agents look for, with nothing invented underneath.
    static func template(title: String) -> String {
        """
        # \(title)

        ## Commands

        - Install:
        - Run:
        - Test:

        ## Conventions

        -

        ## Don't

        -

        """
    }
}
