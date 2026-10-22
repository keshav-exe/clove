import SwiftUI

struct LibrarySidebar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings
    @State private var isCreatingGroup = false
    @State private var newGroupName = ""
    // Collapsed sections stay collapsed across launches.
    @AppStorage("sidebar.skills") private var showsSkills = true
    @AppStorage("sidebar.locations") private var showsLocations = false
    @AppStorage("sidebar.groups") private var showsGroups = true
    @AppStorage("sidebar.context") private var showsContext = true
    @AppStorage("sidebar.tools") private var showsTools = true

    var body: some View {
        @Bindable var model = model

        List(selection: $model.sidebarSelection) {
            // Places that span everything, without a header.
            Section {
                Label("Home", systemImage: "house")
                    .tag(SidebarItem.home)
                RunningSidebarRow()
                CleanupSidebarRow()
            }

            Section("Skills", isExpanded: $showsSkills) {
                LibrarySidebarRow(filter: .all, tint: .accentColor)
                Label("Discover", systemImage: "safari")
                    .tag(SidebarItem.discover)

                if !model.availableSources.isEmpty {
                    DisclosureGroup(isExpanded: $showsLocations) {
                        ForEach(model.availableSources, id: \.self) { source in
                            LibrarySidebarRow(filter: .source(source), tint: source.tint)
                        }
                    } label: {
                        Label("By Location", systemImage: "folder")
                    }
                }

                DisclosureGroup(isExpanded: $showsGroups) {
                    if model.allGroups.isEmpty {
                        Text("Group skills to copy them together")
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
                } label: {
                    Label("Groups", systemImage: "square.stack")
                }
            }

            Section("Context", isExpanded: $showsContext) {
                ForEach(ResourceKind.contextKinds) { kind in
                    ResourceSidebarRow(kind: kind)
                }
            }

            Section("Tools & Access", isExpanded: $showsTools) {
                ForEach(ResourceKind.toolKinds) { kind in
                    ResourceSidebarRow(kind: kind)
                }
                SecretsSidebarRow()
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: Metrics.sidebarMinWidth,
            ideal: Metrics.sidebarIdealWidth,
            max: 300
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
        }
        // At the foot of the sidebar, like Claude and Mail: the toolbar above
        // a narrow sidebar pushed it into the overflow menu.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: { openSettings() }) {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Metrics.spacingM)
                    .padding(.vertical, Metrics.spacingS)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Open Clove settings (⌘,)")
            .padding(.horizontal, Metrics.spacingS)
            .padding(.bottom, Metrics.spacingS)
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
