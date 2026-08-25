import SwiftUI

struct SkillDetailView: View {
    @Environment(AppModel.self) private var model
    let entry: CatalogEntry

    private var skill: Skill { entry.primary }

    var body: some View {
        Form {
            Section {
                SkillDetailHeader(entry: entry)
            }

            Section("Description") {
                Text(entry.summary.isEmpty ? "This skill has no description." : entry.summary)
                    .font(.callout)
                    .foregroundStyle(entry.summary.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section("Groups") {
                SkillTagEditor(skill: skill)
            }

            if entry.isLinked {
                Section {
                    ForEach(entry.copies, id: \.id) { copy in
                        LabeledContent(copy.source.sectionTitle) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(copy.resolvedPath)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .truncationMode(.middle)
                                    .lineLimit(2)

                                HStack(spacing: Metrics.spacingS) {
                                    Button("Reveal") {
                                        model.reveal(copy)
                                    }

                                    Button("Open") {
                                        model.open(copy)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Installed In")
                } footer: {
                    Text("This skill uses the same reference everywhere it is linked.")
                }
            }

            Section {
                LabeledContent("Reference", value: entry.reference)

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
            }
        }
        .formStyle(.grouped)
        .navigationTitle(entry.displayName)
        .toolbar {
            ToolbarItemGroup {
                Button("Insert", systemImage: "text.cursor") {
                    model.insert(skill)
                }
                .help("Paste \(entry.reference) into the focused prompt")

                Button("Copy Reference", systemImage: "doc.on.doc") {
                    model.copyReference(skill)
                }
                .help("Copy \(entry.reference)")

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
