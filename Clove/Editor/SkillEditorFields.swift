import SwiftUI

/// The two frontmatter fields agents read, with live checks under them.
struct SkillEditorFields: View {
    @Bindable var editor: SkillEditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Metrics.spacingM, verticalSpacing: Metrics.spacingS) {
                GridRow {
                    Text("Name")
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    TextField("Name", text: $editor.document.name, prompt: Text("release-notes"))
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                        .labelsHidden()
                }
                GridRow {
                    Text("Description")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .trailing, spacing: 2) {
                        TextField(
                            "Description",
                            text: $editor.document.description,
                            prompt: Text("What it does, and when an agent should use it."),
                            axis: .vertical
                        )
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...5)
                        .labelsHidden()

                        DescriptionCount(count: editor.document.description.count)
                    }
                }
            }

            SkillIssueList(issues: editor.issues)
        }
        .font(.callout)
        .padding(.horizontal, Metrics.spacingL)
        .padding(.vertical, Metrics.spacingM)
    }
}
