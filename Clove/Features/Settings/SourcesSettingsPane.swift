import SwiftUI

struct SourcesSettingsPane: View {
    @Environment(AppModel.self) private var model

    private var agentRoots: [ScanRoot] {
        ScanRoot.agentRoots()
    }

    private var projectRoots: [ScanRoot] {
        ScanRoot.projectRoots(custom: model.settings.customProjectRoots)
    }

    var body: some View {
        @Bindable var settings = model.settings

        SettingsPaneLayout {
            SettingsGroup(title: "What to Include") {
                SettingsToggleRow(
                    systemImage: "puzzlepiece.extension",
                    tint: .pink,
                    title: "Plugin skills",
                    detail: "Skills that ship inside installed Cursor plugins.",
                    isOn: $settings.includePlugins
                )

                Divider().padding(.leading, 46)

                SettingsToggleRow(
                    systemImage: "folder.badge.gearshape",
                    tint: .yellow,
                    title: "Project skills",
                    detail: "Skills committed inside your own repositories.",
                    isOn: $settings.includeProjects
                )
            }

            SettingsGroup(
                title: "Agent Folders",
                footnote: "Clove reads these folders in your home directory. They are never modified."
            ) {
                ForEach(Array(agentRoots.enumerated()), id: \.element.id) { index, root in
                    if index > 0 {
                        Divider().padding(.leading, 46)
                    }
                    ScanLocationRow(root: root)
                }
            }

            SettingsGroup(
                title: "Project Folders",
                footnote: "macOS grants Clove access to a folder only when you pick it here."
            ) {
                ForEach(Array(projectRoots.enumerated()), id: \.element.id) { index, root in
                    if index > 0 {
                        Divider().padding(.leading, 46)
                    }
                    ScanLocationRow(root: root, onRemove: root.isCustom ? { remove(root) } : nil)
                }

                if !projectRoots.isEmpty {
                    Divider().padding(.leading, 46)
                }

                SettingsActionRow(
                    systemImage: "plus",
                    tint: .blue,
                    title: "Add a folder",
                    detail: "Pick a folder that holds your repositories."
                ) {
                    Button("Choose…", action: addFolder)
                }
            }

            HStack {
                Button("Rescan Now", systemImage: "arrow.clockwise", action: refresh)
                    .disabled(model.isScanning)

                if model.isScanning {
                    ProgressView().controlSize(.small)
                } else {
                    Text("\(model.skills.count) skills")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: model.settings.includePlugins) { refresh() }
        .onChange(of: model.settings.includeProjects) { refresh() }
    }

    private func addFolder() {
        guard let url = FolderPicker.chooseProjectFolder() else { return }
        model.settings.addProjectRoot(url)
        refresh()
    }

    private func remove(_ root: ScanRoot) {
        model.settings.removeProjectRoot(root.path)
        refresh()
    }

    private func refresh() {
        Task { await model.refresh() }
    }
}
