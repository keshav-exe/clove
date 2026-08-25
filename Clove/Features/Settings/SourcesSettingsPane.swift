import AppKit
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

        SettingsForm {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                SettingsSection(
                    footer: "Plugin skills ship inside Cursor plugins. Project skills live in your repositories."
                ) {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsCheckboxRow(title: "Plugin skills", isOn: $settings.includePlugins)
                        SettingsCheckboxRow(title: "Project skills", isOn: $settings.includeProjects)
                    }
                }

                SettingsSection(
                    title: "Agent Folders",
                    footer: "Clove reads these folders in your home directory. They are never modified."
                ) {
                    folderGroup(agentRoots)
                }

                SettingsSection(
                    title: "Project Folders",
                    footer: "macOS grants Clove access to a folder only when you pick it here."
                ) {
                    folderGroup(projectRoots, removable: true)

                    Button("Add Project Folder…", systemImage: "plus", action: addFolder)
                        .controlSize(.small)
                        .padding(.top, Metrics.spacingS)
                }

                SettingsPaneDivider()

                SettingsSection {
                    SettingsFieldRow(label: "Indexed skills") {
                        if model.isScanning {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("\(model.catalog.count)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Rescan Now", action: refresh)
                        .disabled(model.isScanning)
                }
            }
        }
        .onChange(of: model.settings.includePlugins) { refresh() }
        .onChange(of: model.settings.includeProjects) { refresh() }
    }

    @ViewBuilder
    private func folderGroup(_ roots: [ScanRoot], removable: Bool = false) -> some View {
        SettingsInsetGroup {
            ForEach(Array(roots.enumerated()), id: \.element.id) { index, root in
                if index > 0 {
                    Divider()
                }

                OnboardingScanLocationRow(
                    root: root,
                    onRemove: removable && root.isCustom ? { remove(root) } : nil
                )
            }
        }
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
