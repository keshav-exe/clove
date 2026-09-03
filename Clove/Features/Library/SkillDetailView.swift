import SwiftUI

struct SkillDetailView: View {
    @Environment(AppModel.self) private var model
    let entry: CatalogEntry

    private var skill: Skill { entry.primary }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                SkillDetailHeader(entry: entry)

                SkillDetailSection(title: "Groups") {
                    SkillTagEditor(skill: skill)
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

                Menu("More", systemImage: "ellipsis") {
                    Button("Reveal in Finder", systemImage: "folder", action: reveal)
                    Button("Open in Default Editor", systemImage: "doc.text", action: open)
                    Button("Copy Name", systemImage: "textformat", action: copyName)
                }
                .menuIndicator(.hidden)
            }
        }
    }

    private func copyReference() {
        model.copyReference(skill)
    }

    private func insert() {
        model.insert(skill)
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
