import SwiftUI

struct OnboardingFoldersStep: View {
    @Environment(AppModel.self) private var model

    private var roots: [ScanRoot] {
        ScanRoot.agentRoots() + ScanRoot.projectRoots(custom: model.settings.customProjectRoots)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(roots.enumerated()), id: \.element.id) { index, root in
                        if index > 0 {
                            Divider().padding(.leading, 44)
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
            .frame(maxHeight: 262)
            .background(.fill.quinary, in: .rect(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.separator.opacity(0.4), lineWidth: 1)
            }

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
