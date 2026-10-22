import SwiftUI

/// Where a skill goes (everywhere or one project) and which agents get it.
/// Both choices are remembered for the next install.
struct InstallOptionsMenu: View {
    @Environment(AppModel.self) private var model
    @Binding var targets: Set<AgentTarget>
    @Binding var project: URL?

    var body: some View {
        Menu {
            Section("Install In") {
                Toggle("Everywhere", isOn: everywhere)
                Menu("One Project") {
                    ForEach(model.projects.prefix(20), id: \.self) { folder in
                        Toggle(folder.lastPathComponent, isOn: isProject(folder))
                    }
                    Divider()
                    Button("Choose Folder…", action: chooseFolder)
                }
            }
            Section("For") {
                ForEach(AgentTarget.allCases) { target in
                    Toggle(target.title, isOn: binding(for: target))
                }
            }
        } label: {
            Text(label)
        }
        .menuStyle(.button)
        .menuIndicator(.visible)
        .buttonStyle(.glass)
        .fixedSize()
        .help("Choose where this skill goes and which agents get it")
    }

    private var label: String {
        let scope = project?.lastPathComponent ?? "Everywhere"
        let chosen = AgentTarget.allCases.filter(targets.contains)
        let agents: String = switch chosen.count {
        case 0: "No Agents"
        case AgentTarget.allCases.count: "All Agents"
        default: chosen.map(\.title).formatted(.list(type: .and))
        }
        return "\(scope) · \(agents)"
    }

    private var everywhere: Binding<Bool> {
        Binding { project == nil } set: { if $0 { project = nil } }
    }

    private func isProject(_ folder: URL) -> Binding<Bool> {
        Binding { project == folder } set: { if $0 { project = folder } }
    }

    private func binding(for target: AgentTarget) -> Binding<Bool> {
        Binding {
            targets.contains(target)
        } set: { isOn in
            if isOn { targets.insert(target) } else { targets.remove(target) }
        }
    }

    private func chooseFolder() {
        if let folder = FolderPicker.chooseProject() {
            project = folder
        }
    }
}
