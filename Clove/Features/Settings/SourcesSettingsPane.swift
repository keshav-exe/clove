import AppKit
import SwiftUI

/// Where Clove finds skills: each agent's folder, your projects, and plugins.
struct SourcesSettingsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        let agentRoots = ScanRoot.agentRoots()
        let projectRoots = ScanRoot.projectRoots(custom: settings.customProjectRoots)

        SettingsPage {
            Section {
                SettingsRow(title: "Skills indexed", subtitle: "Across every folder below", symbol: "square.stack.3d.up.fill", tint: Palette.Vivid.blue) {
                    HStack(spacing: 10) {
                        if model.isScanning {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(model.catalog.count.formatted())
                                .font(.title3.weight(.semibold).monospacedDigit())
                        }
                        Button("Rescan", action: refresh)
                            .disabled(model.isScanning)
                    }
                }
                SettingsRow(title: "Skill library", symbol: "books.vertical.fill", tint: Palette.Vivid.violet) {
                    Button("Open Library") { WindowBridge.shared.showLibraryWindow() }
                }
            }

            Section {
                SettingsToggle(title: "Plugin skills", subtitle: "Skills that ship inside Cursor and Claude plugins", symbol: "puzzlepiece.extension.fill", tint: Palette.Vivid.pink, isOn: $settings.includePlugins)
                SettingsToggle(title: "Project skills", subtitle: "Skills inside your repositories", symbol: "folder.fill.badge.gearshape", tint: Palette.Vivid.orange, isOn: $settings.includeProjects)
            } header: {
                Text("Include")
            }

            Section {
                ForEach(agentRoots) { root in
                    FolderRow(root: root)
                }
            } header: {
                Text("Agent Folders")
            } footer: {
                Text("Clove reads these folders in your home directory and never changes them.")
                    .settingsFooter()
            }

            Section {
                ForEach(projectRoots) { root in
                    FolderRow(root: root, onRemove: root.isCustom ? { remove(root) } : nil)
                }
                Button {
                    addFolder()
                } label: {
                    Label("Add Folder…", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Project Folders")
            } footer: {
                Text("macOS lets Clove into a folder only once you pick it here.")
                    .settingsFooter()
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

/// A folder Clove reads: its name, where it is, and whether it's there.
private struct FolderRow: View {
    let root: ScanRoot
    var onRemove: (() -> Void)?

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                if root.exists {
                    StatusBadge(text: "Found")
                } else {
                    StatusBadge(text: "Not on this Mac", tint: Color.secondary.opacity(0.5))
                }
                if let onRemove {
                    Button("Remove", systemImage: "minus.circle.fill", action: onRemove)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("Stop reading this folder")
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: root.exists ? root.path : "/System"))
                    .resizable()
                    .frame(width: 22, height: 22)
                    .opacity(root.exists ? 1 : 0.4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(root.title)
                    Text(root.path.replacingOccurrences(of: URL.homeDirectory.path(percentEncoded: false), with: "~/"))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
        }
        .contextMenu {
            if root.exists {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([root.url]) }
            }
        }
    }
}
