import SwiftUI

struct SkillDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    let entry: CatalogEntry

    @State private var isConfirmingRemoval = false

    private var skill: Skill { entry.primary }
    private var name: String { skill.directoryName }

    /// Only skills in an agent's home folder are Clove's to change.
    private var isRemovable: Bool {
        entry.copies.contains { $0.source.isAgentHome }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                SkillDetailHeader(entry: entry)

                if let origin = model.manager.lockEntries[name] {
                    SkillOriginSection(entry: origin)
                }

                SkillDetailSection(title: "Groups") {
                    SkillTagEditor(skill: skill)
                }

                if isRemovable {
                    SkillAgentsSection(name: name)
                }

                if entry.isLinked {
                    SkillDetailSection(title: "Installed in") {
                        SkillInstallList(entry: entry)
                    }
                }

                SkillDetailSection(title: "File") {
                    SkillFileInfo(entry: entry, showsPath: !entry.isLinked)
                }
            }
            .padding(Metrics.spacingXL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollClipDisabled()
        .navigationTitle(entry.displayName)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup {
                Button("Copy Reference", systemImage: "doc.on.doc", action: copyReference)
                    .help("Copy \(entry.reference)")

                Button("Insert", systemImage: "text.cursor", action: insert)
                    .help("Paste \(entry.reference) into the focused prompt")

                Button("Edit", systemImage: "square.and.pencil", action: edit)
                    .keyboardShortcut("e")
                    .help("Edit SKILL.md (⌘E)")

                Menu("More", systemImage: "ellipsis") {
                    Button("Reveal in Finder", systemImage: "folder", action: reveal)
                    Button("Open in Default Editor", systemImage: "doc.text", action: open)
                    Button("Copy Name", systemImage: "textformat", action: copyName)
                    Divider()
                    Menu("Add to Project", systemImage: "folder.badge.plus") {
                        ForEach(model.projects.prefix(20), id: \.self) { project in
                            Button(project.lastPathComponent) {
                                addToProject(project)
                            }
                        }
                        Divider()
                        Button("Choose Folder…", action: chooseProject)
                    }
                    .help("Copy this skill into a project so it ships with the repo")
                    if isRemovable {
                        Divider()
                        Button("Move to Trash…", systemImage: "trash", role: .destructive) {
                            isConfirmingRemoval = true
                        }
                    }
                }
                .menuIndicator(.hidden)
            }
        }
        .confirmationDialog(
            "Move “\(entry.displayName)” to the Trash?",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive, action: remove)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every copy in your Claude, Cursor, Codex, and Agents folders is moved to the Trash. Plugin and project copies stay.")
        }
    }

    private func copyReference() {
        model.copyReference(skill)
    }

    private func insert() {
        model.insert(skill)
    }

    private func edit() {
        openWindow(id: CloveWindowID.editor, value: skill.fileURL)
    }

    private func reveal() {
        model.reveal(skill)
    }

    private func open() {
        model.open(skill)
    }

    private func copyName() {
        model.copyName(skill)
    }

    private func addToProject(_ project: URL) {
        Task { await model.manager.addToProject(entry, project: project, targets: model.manager.defaultTargets) }
    }

    private func chooseProject() {
        if let project = FolderPicker.chooseProject() {
            addToProject(project)
        }
    }

    private func remove() {
        Task { await model.manager.uninstall(entry) }
    }
}

#Preview {
    SkillDetailView(
        entry: CatalogEntry(
            key: "preview",
            primary: AppModel.preview.skills[0],
            copies: AppModel.preview.skills
        )
    )
    .environment(AppModel.preview)
    .frame(width: 420, height: 560)
}
