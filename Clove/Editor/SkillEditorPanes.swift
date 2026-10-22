import SwiftUI

/// The markdown body, its preview, or both side by side.
struct SkillEditorPanes: View {
    @Bindable var editor: SkillEditorModel

    var body: some View {
        switch editor.mode {
        case .write:
            SkillBodyEditor(editor: editor)
        case .preview:
            SkillBodyPreview(document: editor.preview)
        case .split:
            HSplitView {
                SkillBodyEditor(editor: editor)
                    .frame(minWidth: 280)
                SkillBodyPreview(document: editor.preview)
                    .frame(minWidth: 240)
            }
        }
    }
}
