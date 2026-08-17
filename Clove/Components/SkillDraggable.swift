import SwiftUI

struct SkillDragPreview: View {
    let reference: String

    var body: some View {
        Text(reference)
            .font(.caption.weight(.medium).monospaced())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThickMaterial, in: .capsule)
    }
}

extension View {
    func skillDraggable(_ skill: Skill) -> some View {
        draggable(skill.reference) {
            SkillDragPreview(reference: skill.reference)
        }
    }
}
