import SwiftUI

struct LibrarySidebar: View {
    @Environment(AppModel.self) private var model
    @State private var isCreatingGroup = false
    @State private var newGroupName = ""

    var body: some View {
        @Bindable var model = model

        List(selection: $model.sidebarSelection) {
            Section("Library") {
                LibrarySidebarRow(filter: .all, tint: .primary)
            }

            if !model.availableSources.isEmpty {
                Section("Sources") {
                    ForEach(model.availableSources, id: \.self) { source in
                        LibrarySidebarRow(filter: .source(source), tint: source.tint)
                    }
                }
            }

            Section("Groups") {
                if model.allGroups.isEmpty {
                    Text("No groups yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.allGroups, id: \.self) { group in
                        LibrarySidebarRow(filter: .tag(group), tint: .teal)
                            .contextMenu {
                                groupContextMenu(group)
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: Metrics.sidebarMinWidth,
            ideal: Metrics.sidebarIdealWidth,
            max: 280
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Group", systemImage: "folder.badge.plus") {
                    newGroupName = ""
                    isCreatingGroup = true
                }
                .help("Create a new group")
            }

            ToolbarItem {
                Button("Settings", systemImage: "gearshape") {
                    WindowBridge.shared.showSettings()
                }
                .help("Open Clove settings")
            }
        }
        .alert("New Group", isPresented: $isCreatingGroup) {
            TextField("Group name", text: $newGroupName)
            Button("Create") {
                model.createGroup(named: newGroupName)
                let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    model.libraryFilter = .tag(name)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Create a group, then add skills from the list or detail view.")
        }
    }

    @ViewBuilder
    private func groupContextMenu(_ group: String) -> some View {
        Button("Copy Group", systemImage: "doc.on.doc") {
            model.copyGroup(group)
        }
        Button(model.isGroupPinned(group) ? "Unpin from Panel" : "Pin to Panel", systemImage: "pin") {
            model.togglePinGroup(group)
        }
        Divider()
        Button("Delete Group", systemImage: "trash", role: .destructive) {
            model.deleteGroup(group)
        }
    }
}
