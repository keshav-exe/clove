import SwiftUI

struct SkillBodyEditor: View {
    @Bindable var editor: SkillEditorModel

    var body: some View {
        TextEditor(text: $editor.document.body)
            .font(.body.monospaced())
            .lineSpacing(3)
            .autocorrectionDisabled()
            .contentMargins(Metrics.spacingL, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background(.background)
            .onChange(of: editor.document.body) {
                editor.bodyDidChange()
            }
            .accessibilityLabel("Skill instructions")
    }
}
