import SwiftUI

struct SkillDetailView: View {
    @Environment(AppModel.self) private var model
    let skill: Skill

    var body: some View {
        Form {
            Section {
                SkillDetailHeader(skill: skill)
            }

            Section("Description") {
                Text(skill.summary.isEmpty ? "This skill has no description." : skill.summary)
                    .font(.callout)
                    .foregroundStyle(skill.summary.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section("Tags") {
                SkillTagEditor(skill: skill)
            }

            Section {
                LabeledContent("Reference", value: skill.reference)

                LabeledContent("Folder", value: skill.directoryName)

                LabeledContent("Modified") {
                    Text(skill.modifiedAt, format: .dateTime.day().month().year().hour().minute())
                }

                LabeledContent("Path") {
                    Text(skill.resolvedPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .truncationMode(.middle)
                        .lineLimit(2)
                }
            } header: {
                Text("File")
            } footer: {
                Label(
                    "Clove reads this file and nothing else. It never edits, copies, or uploads it.",
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(skill.displayName)
        .toolbar {
            ToolbarItemGroup {
                Button("Insert", systemImage: "text.cursor") {
                    model.insert(skill)
                }
                .help("Paste \(skill.reference) into the focused prompt")

                Button("Copy Reference", systemImage: "doc.on.doc") {
                    model.copyReference(skill)
                }
                .help("Copy \(skill.reference)")

                Button("Reveal in Finder", systemImage: "folder") {
                    model.reveal(skill)
                }

                Button("Open", systemImage: "arrow.up.forward.app") {
                    model.open(skill)
                }
                .help("Open SKILL.md in your default editor")
            }
        }
    }
}
