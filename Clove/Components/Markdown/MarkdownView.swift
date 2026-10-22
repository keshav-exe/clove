import SwiftUI

/// Renders a parsed SKILL.md body with system text styles.
struct MarkdownView: View {
    let document: MarkdownDocument

    var body: some View {
        LazyVStack(alignment: .leading, spacing: Metrics.spacingM) {
            ForEach(document.blocks) { block in
                MarkdownBlockView(block: block)
            }
        }
        .textSelection(.enabled)
    }
}
