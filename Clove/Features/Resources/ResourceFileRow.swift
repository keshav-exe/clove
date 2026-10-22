import SwiftUI

struct ResourceFileRow: View {
    let resource: AgentResource

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(resource.fileURL.path(percentEncoded: false).replacing(URL.homeDirectory.path(percentEncoded: false), with: "~/"))
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
                if let key = resource.configKey, resource.kind == .mcpServers {
                    Text("Entry “\(key)”")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Reveal in Finder", systemImage: "folder", action: reveal)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Reveal in Finder")

            Button("Open in Default Editor", systemImage: "arrow.up.forward.app", action: open)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Open in Default Editor")
        }
    }

    private func reveal() {
        NSWorkspace.shared.activateFileViewerSelecting([resource.fileURL])
    }

    private func open() {
        NSWorkspace.shared.open(resource.fileURL)
    }
}
