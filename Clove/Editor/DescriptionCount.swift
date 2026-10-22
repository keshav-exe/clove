import SwiftUI

/// Characters used against the format's limit. Quiet until it matters.
struct DescriptionCount: View {
    let count: Int

    private var limit: Int { SkillDocumentIssue.descriptionLimit }

    var body: some View {
        Text("\(count) / \(limit)")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(count > limit ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
            .accessibilityLabel("\(count) of \(limit) characters")
    }
}
