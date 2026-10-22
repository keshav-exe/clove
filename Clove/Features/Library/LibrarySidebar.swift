import SwiftUI

struct LibrarySidebar: View {
    @Environment(AppModel.self) private var model
    @State private var isCreatingGroup = false
    @State private var newGroupName = ""

    var body: some View {
        @Bindable var model = model

        List(selection: $model.sidebarSelection) {
            Section("Discover") {
                ForEach(DiscoverFeed.allCases) { feed in
                    Label(feed.title, systemImage: feed.symbolName)
                        .tag(SidebarItem.discover(feed))
                }
            }

            Section("Library") {
                LibrarySidebarRow(filter: .all, tint: .primary)
                CleanupSidebarRow()
            }

            Section("Agent Setup") {
                ForEach(ResourceKind.allCases) { kind in
                    ResourceSidebarRow(kind: kind)
                }
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
                                LibraryGroupMenu(group: group)
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
                Menu("New", systemImage: "plus") {
                    Button("New Skill…", systemImage: "doc.badge.plus", action: newSkill)
                        .keyboardShortcut("n")
                    Button("New Group…", systemImage: "folder.badge.plus", action: beginNewGroup)
                }
                .help("Create a skill or group")
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
            Button("Create", action: createGroup)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Create a group, then add skills from the list or detail view.")
        }
    }

    private func newSkill() {
        model.isShowingSkillBuilder = true
    }

    private func beginNewGroup() {
        newGroupName = ""
        isCreatingGroup = true
    }

    private func createGroup() {
        model.createGroup(named: newGroupName)
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            model.show(.library(.tag(name)))
        }
    }
}
