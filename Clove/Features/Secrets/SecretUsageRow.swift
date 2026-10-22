import SwiftUI

struct SecretUsageRow: View {
    let title: String
    let detail: String
    let snippet: String

    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingXS) {
            HStack {
                Text(title)
                    .font(.callout.weight(.medium))
                Spacer()
                Button(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc", action: copy)
                    .labelStyle(.titleAndIcon)
                    .controlSize(.small)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
            MarkdownCodeView(text: snippet)
        }
        .task(id: didCopy) {
            guard didCopy else { return }
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
        didCopy = true
    }
}
