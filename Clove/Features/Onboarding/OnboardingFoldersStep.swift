import SwiftUI

struct OnboardingFoldersStep: View {
    @Environment(AppModel.self) private var model

    private var roots: [ScanRoot] {
        ScanRoot.agentRoots() + ScanRoot.projectRoots(custom: model.settings.customProjectRoots)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(roots.enumerated()), id: \.element.id) { index, root in
                        if index > 0 {
                            Divider()
                        }

                        OnboardingScanLocationRow(
                            root: root,
                            onRemove: root.isCustom ? { remove(root) } : nil
                        )
                    }
                }
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 240)
            .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 8, style: .continuous))

            HStack(spacing: 10) {
                Button("Add Project Folder…", systemImage: "plus", action: addFolder)
                    .controlSize(.small)

                Spacer()

                Text("macOS asks before Clove can read a folder you add.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addFolder() {
        guard let url = FolderPicker.chooseProjectFolder() else { return }
        model.settings.addProjectRoot(url)
    }

    private func remove(_ root: ScanRoot) {
        model.settings.removeProjectRoot(root.path)
    }
}
